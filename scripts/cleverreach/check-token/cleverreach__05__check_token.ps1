################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

# TODO [ ] check input parameter

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\CleverReach"
    }
}


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

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "CLVRTEST"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}
<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>

################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ) = $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$header = @{
    "Authorization" = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
}


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
        $splattedArguments = @{
            "to" = $settings.notificationReceiver
            "subject" = "[CLEVERREACH] Token is refreshed now"
            "body" = "New token is created and valid until $( $ttl.date )"
        }
        Send-Mail @splattedArguments # note the @ instead of $    
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
