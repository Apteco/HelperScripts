
<#

Requisites

* loaded variable $settings

#>

Function Get-Endpoints {

    $pageSize = 50
    $offset = 0
    $Script:endpoints = @()
    Do {
        $uri = "$( $settings.base )About/Endpoints?excludeEndpointsWithNoLicenceRequirements=false&excludeEndpointsWithNoRoleRequirements=false&count=$( $pageSize )&offset=$( $offset )"
        $res = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json; charset=utf-8" -Verbose
        $Script:endpoints += $res.list
        $offset += $pageSize
    } Until ( $Script:endpoints.count -eq $res.totalCount )

    #$Script:endpoints | out-gridview

}


# Get-Endpoint -Key "CreateLoginParameters"
Function Get-Endpoint{

    param(
        [String]$Key
    )
    
    $Script:endpoints | where { $_.name -eq $Key }

}


# Resolve the endpoint by adding baseUrl and replace some parameters
Function Resolve-Url {

    param(
        [Parameter(Mandatory=$true)][PSCustomObject] $endpoint,
        [Parameter(Mandatory=$false)][Hashtable] $additional,
        [Parameter(Mandatory=$false)][Hashtable] $query
    )

    # build the endpoint
    $uri = "$( $Script:settings.base )$( $endpoint.urlTemplate )"

    # replace the dataview
    $uri = $uri -replace "{dataViewName}", $Script:settings.login.dataView

    # replace other parameters in path
    if ($additional) {
        $additional.Keys | ForEach {
            
            $uri = $uri -replace "{$( $_ )}", $additional[$_]

        }
    }

    # add parts to the query
    if ($query) {

        $uri += "?"
        $i = 0
        $query.Keys | ForEach {

            if ($i -ne $query.Count -and $i -ne 0) {
                $uri += "&"
            }

            $uri += "$( $_ )=$( [System.Web.HttpUtility]::UrlEncode($query[$_]) )"            

            $i+=1

        }
    }

    $uri
}

Function Create-AptecoSession {

    #-----------------------------------------------
    # LOAD ENDPOINTS
    #-----------------------------------------------

    Get-Endpoints


    #-----------------------------------------------
    # LOAD CREDENTIALS
    #-----------------------------------------------

    #$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $settings.user,($settings.password | ConvertTo-SecureString)
    $user = $settings.login.user #$credentials.GetNetworkCredential().Username
    #$pw = $credentials.GetNetworkCredential().password
    #$pw = Get-SecureToPlaintext -String $settings.login.pass

    #-----------------------------------------------
    # PREPARE LOGIN
    #-----------------------------------------------

    $headers = @{
        "accept"="application/json"
    }

    switch ( $settings.loginType ) {


        #-----------------------------------------------
        # SIMPLE LOGIN PREPARATION
        #-----------------------------------------------

        "SIMPLE" {

            $endpointKey = "CreateSessionSimple"

            $body = @{
                "UserLogin" = $user
                "Password" = Get-SecureToPlaintext -String $settings.login.pass
            }

        }



        #-----------------------------------------------
        # SALTED LOGIN PREPARATION
        #-----------------------------------------------

        "SALTED" {

            # GET LOGIN DETAILS FIRST

            #$endpoint = Get-Endpoint -key "CreateLoginParameters"
            
            $body = @{
                "userName"=$user
            }

            #$uri = Resolve-Url -endpoint $endpoint
            $loginDetails = Invoke-Apteco -key "CreateLoginParameters" -body $body -contentType "application/x-www-form-urlencoded" -verboseCall
            #$loginDetails = Invoke-RestMethod -Uri $uri -Method $endpoint.method -ContentType "application/x-www-form-urlencoded" -Headers $headers -Body $body -Verbose


            # GET ALL INFORMATION TOGETHER

            $endpointKey = "CreateSessionSalted"

            <#
            1. "Encrypt" password + optionally add salt
            2. Hash that string
            3. Add LoginSalt and hash again
            #>

            $pwStepOne = Crypt-Password -password ( Get-SecureToPlaintext -String $settings.login.pass )

            if ($loginDetails.saltPassword -eq $true -and $loginDetails.userSalt -ne "") {

                # TODO [ ] test password salting (and if userSalt from API is the correct value for that)
                # TODO [ ] put salt in settings
                $pwStepOne += $loginDetails.userSalt

            }

            $pwStepTwo = Get-StringHash -inputString $pwStepOne -hashName $loginDetails.hashAlgorithm -uppercase $false
            $pwStepThree = Get-StringHash -inputString $pwStepTwo -hashName $loginDetails.hashAlgorithm -salt $loginDetails.loginSalt -uppercase $false

            $body = @{
                "Username"=$user
                "LoginSalt"=$loginDetails.loginSalt
                "PasswordHash"=$pwStepThree
            }
                
        }

    }

    #-----------------------------------------------
    # LOGIN + GET SESSION
    #-----------------------------------------------

    #$uri = Resolve-Url -endpoint $endpoint
    $login = Invoke-Apteco -key $endpointKey -body $body -contentType "application/x-www-form-urlencoded" -verboseCall
    #$login = Invoke-RestMethod -Uri $uri -Method $endpoint.method -ContentType "application/x-www-form-urlencoded" -Headers $headers -Body $body -Verbose


    #-----------------------------------------------
    # SAVE SESSION
    #-----------------------------------------------
    
    # Encrypt token?
    if ( $settings.encryptToken ) {
        $Script:sessionId = Get-PlaintextToSecure -String $login.sessionId
        $Script:accessToken = Get-PlaintextToSecure -String $login.accessToken
    } else {
        $Script:sessionId = $login.sessionId
        $Script:accessToken = $login.accessToken
    }

    # Calculate expiration date
    $expire = [datetime]::now.AddMinutes($settings.ttl).ToString("yyyyMMddHHmmss")

    # Create session file and save it
    $session = @{
        sessionId=$Script:sessionId
        accessToken=$Script:accessToken
        expire=$expire
    }
    $session | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $settings.sessionFile


    #-----------------------------------------------
    # RETURN SUCCESS OR FAILURE
    #-----------------------------------------------

    # true, if the functions is coming to the end?
    return $true

}

Function Get-AptecoSession {

    $sessionPath = "$( $settings.sessionFile )"
    
    # if file exists -> read it and check ttl
    $createNewSession = $true
    if ( (Test-Path -Path $sessionPath) -eq $true ) {

        $sessionContent = Get-Content -Encoding UTF8 -Path $sessionPath | ConvertFrom-Json
        
        $expire = [datetime]::ParseExact($sessionContent.expire,"yyyyMMddHHmmss",[CultureInfo]::InvariantCulture)

        if ( $expire -gt [datetime]::Now ) {

            $createNewSession = $false
            $Script:sessionId = $sessionContent.sessionId
            $Script:accessToken = $sessionContent.accessToken

        }

        Get-Endpoints

    }
    
    # file does not exist or date is not valid -> create session
    if ( $createNewSession -eq $true ) {
        
       Create-AptecoSession
        
    }

}



Function Invoke-Apteco {

    param(   
         [Parameter(Mandatory=$true)][String]$key                   # The endpoint name to call
        ,[Parameter(Mandatory=$false)]$additional = @{}             # Additional params for the url path
        ,[Parameter(Mandatory=$false)]$query = @{}                  # Addtional params for the url query
        ,[Parameter(Mandatory=$false)]$headers = @{} # Headers to send with the request
        ,[Parameter(Mandatory=$false)]$body = ""            # Body to upload
        ,[Parameter(Mandatory=$false)][String]$contentType = "application/json" # contentType to override
        ,[Parameter(Mandatory=$false)][String]$outFile = "" # contentType to override
        ,[Parameter(Mandatory=$false)][switch]$verboseCall = $true # Output verbose mode        
    )

    # Get endpoint information first
    $endpoint = Get-Endpoint -key $key
    
    # Build uri
    $uri = Resolve-Url -endpoint $endpoint -additional $additional -query $query
    
    # Base headers

    $headers += @{
        "accept"="application/json"
    }

    $tries = 0
    Do {

        try {
            
            if ( $endpoint.AllowsAnonymousAccess -eq $false ) {
                
                # decrypt secure string
                if ( $settings.encryptToken ) {
                    $accessToken = Get-SecureToPlaintext -String $Script:accessToken
                } else {
                    $accessToken = $Script:accessToken
                }

                $auth = "Bearer $( $accessToken )"

                if ($tries -eq 1) {  
                    # remove auth header first, if this is the second try
                    $headers.Remove("Authorization")                                      
                } 

                $headers += @{
                    "Authorization"=$auth
                }
                
            }
           
            switch ( $endpoint.method ) {
                
                "GET" {
                    $response = Invoke-RestMethod -Uri $uri -ContentType $contentType -Method $endpoint.method -Headers $headers -Verbose:$verboseCall -OutFile $outFile

                }

                default {
                    $response = Invoke-RestMethod -Uri $uri -ContentType $contentType -Method $endpoint.method -Body $body -Headers $headers -Verbose:$verboseCall -OutFile $outFile

                }

            }

        } catch {
            #Write-Host $_.Exception.Response.StatusDescription
            $e = ParseErrorForResponseBody($_)
            Write-Host ( $e | ConvertTo-Json -Depth 20 )

            #If ($_.Exception.Response.StatusCode.value__ -eq "500") {
                Create-AptecoSession
            #}
        }

    } until ( $tries++ -eq 1 -or $response ) # this gives us one retry

    return $response

}
