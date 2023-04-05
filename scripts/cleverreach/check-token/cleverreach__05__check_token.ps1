################################################
#
# INPUT
#
################################################

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false


################################################
#
# NOTES
#
################################################

<#

https://rest.cleverreach.com/explorer/v3

#>

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

$script:moduleName = "CRCHECK"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Host -message "Got exception during start phase" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Type: '$( $_.Exception.GetType().Name )'" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Message: '$( $_.Exception.Message )'" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Stacktrace: '$( $_.ScriptStackTrace )'" #-severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}

################################################
#
# PROGRAM
#
################################################

try {

    #-----------------------------------------------
    # VALIDATE
    #-----------------------------------------------

    $object = "debug"
    $validateParameters = @{
        Uri = "$( $apiRoot )$( $object )/validate.json"
        Method = "Get"
        Headers = $header
        Verbose = $true
        ContentType = $contentType
    }

    $success = $false
    try {
        
        # Check via REST API
        $valid = Invoke-RestMethod @validateParameters
        $success = $true

        # Log
        Write-Log "Test was successful"

    # Token not valid anymore
    } catch {
        
        # Log
        Write-Log "Test was not successful, closing the script"

        # Mail
        if ( $settings.sendMailOnFailure ) {
            $splattedArguments = @{
                "to" = $settings.notificationReceiver
                "subject" = "[CLEVERREACH] Token is invalid, please check"
                "body" = "Refreshment failed, please check if you can create a valid token"
            }
            Send-Mail @splattedArguments # note the @ instead of $    
        }
        
        # Exception
        throw [System.IO.InvalidDataException] "Test was not successful"  
        
    }



    #-----------------------------------------------
    # WHO AM I
    #-----------------------------------------------

    # Load information about the account

    $object = "debug"
    $endpoint = "$( $apiRoot )$( $object )/whoami.json"
    $whoAmI = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType

    # Logging of whoami
    Write-Log -message "Entries of WhoAmI"
    $whoAmI | Get-Member -MemberType NoteProperty | ForEach {
        $propName = $_.Name
        Write-Log "    $( $propName ) = $( $whoAmI.$propName )"
    }


    #-----------------------------------------------
    # TTL
    #-----------------------------------------------

    $object = "debug"
    $validateParameters = @{
        Uri = "$( $apiRoot )$( $object )/ttl.json"
        Method = "Get"
        Headers = $header
        Verbose = $true
        ContentType = $contentType
    }
    $ttl = Invoke-RestMethod @validateParameters
    Write-Log -message "Token is valid for $( $ttl.ttl ) seconds until $( $ttl.date )"

    # Mail for valid check
    if ( $settings.sendMailOnCheck ) {
        $splattedArguments = @{
            "to" = $settings.notificationReceiver
            "subject" = "[CLEVERREACH] Token is still valid"
            "body" = "Token is still valid until $( $ttl.date )"
        }
        Send-Mail @splattedArguments # note the @ instead of $    
    }


    #-----------------------------------------------
    # EXCHANGE TOKEN IF NEEDED
    #-----------------------------------------------

    if ( $settings.login.refreshTokenAutomatically -and $ttl.ttl -lt $settings.login.refreshTtl ) {
        
        # Log
        Write-Log -message "Creating new token, it will expire in $( $ttl.ttl ) seconds"

        # Exchange token
        $object = "debug"
        $validateParameters = @{
            Uri = "$( $apiRoot )$( $object )/exchange.json"
            Method = "Get"
            Headers = $header
            Verbose = $true
            ContentType = $contentType
        }
        # TODO [ ] check the return value of the new created token
        $newToken = Invoke-RestMethod @validateParameters

        # Log
        Write-Log -message "Got new token valid for $( $newToken.expires_in ) seconds and scope '$( $newToken.scope )'"

        # Put token into settings file
        $settings.login.accesstoken = Get-PlaintextToSecure $newToken.access_token
        $json = $settings | ConvertTo-Json -Depth 8 # -compress
        $json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8

        # Put token in text file
        $newToken.access_token | Set-Content -path "$( $settings.tokenfile )" -Encoding UTF8 -Force

        # Check expiration of new token
        $object = "debug"
        $validateParameters = @{
            Uri = "$( $apiRoot )$( $object )/ttl.json"
            Method = "Get"
            Headers = @{
                "Authorization" = "Bearer $( $newToken.access_token )"
            }
            Verbose = $true
            ContentType = $contentType
        }
        $ttl = Invoke-RestMethod @validateParameters
        Write-Log -message "New token is valid for $( $ttl.ttl ) seconds until $( $ttl.date )"
            
        # Mail for valid token
        if ( $settings.sendMailOnSuccess ) {

            # TODO [ ] allow sending of mails without credentials

            # build the credentials object from the settings
            if ( $settings.mail.deactivateServerCertificateValidation ) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
            }

            $mailParams = [Hashtable]@{
                To = $settings.notificationReceiver
                Subject = "[CLEVERREACH] Token is refreshed now"
                Body = "New token is created and valid until $( $ttl.date )"
                SmtpServer = $settings.mail.smtpServer 
                From = $settings.mail.from
                UseSsl = $settings.mail.useSsl
                Port = $settings.mail.port
                encoding = ([System.Text.Encoding]::UTF8)
                verbose = $true
            }

            If ($settings.mail.useCredentials -eq $true ) {
                $cred = New-Object System.Management.Automation.PSCredential $settings.mail.username, ( Get-SecureToPlaintext $settings.mail.password | ConvertTo-SecureString -asplaintext -force  )
                $mailParams.Add("Credential", $cred)
            }
    
            Send-MailMessage @mailParams 

            # $splattedArguments = @{
            #     "to" = $settings.notificationReceiver
            #     "subject" = "[CLEVERREACH] Token is refreshed now"
            #     "body" = "New token is created and valid until $( $ttl.date )"
            # }
            # Send-Mail @splattedArguments # note the @ instead of $    

        }

        # Log
        Write-Log -message "Creating new token, it will expire in $( $ttl.ttl ) seconds"

    } else {
    
        Write-Log -message "No new token creation needed, still valid for $( $ttl.ttl ) seconds"
        
    }


    #-----------------------------------------------
    # LOG
    #-----------------------------------------------
    <#
    if ( $success ) {

        Write-Log -message "Entries of WhoAmI"

        $whoAmI | Get-Member -MemberType NoteProperty | ForEach {
            $name = $_.Name
            $value = $whoAmI.$name
            Write-Host "$( $name ): $( $value )"
            Write-Log -message "$( $name ): $( $value )"
        }

    }
    #>

} catch {


    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

    exit 1


} finally {


    ################################################
    #
    # RETURN VALUES
    #
    ################################################


    # return object
    $return = [Hashtable]@{

        "Success"=$success

    }

    # return the results
    $return

    exit 0

}