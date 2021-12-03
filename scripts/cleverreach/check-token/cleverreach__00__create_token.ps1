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

[HKEY_CLASSES_ROOT\chk]
@="URL: CHK Protocol handler"
"URL Protocol"=""
[HKEY_CLASSES_ROOT\chk\DefaultIcon]
@="C:\\Program Files (x86)\\Jitsi\\sc-logo.ico"
[HKEY_CLASSES_ROOT\chk\shell]
[HKEY_CLASSES_ROOT\chk\shell\open]
[HKEY_CLASSES_ROOT\chk\shell\open\command]
@="\"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -File C:\\DNC\\dnc.ps1 %1"


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

# Some basic settings
$settings = @{
    
    # general
    "logfile" = "$( $scriptPath )\cr.log"
    
    "powershellExePath" = "powershell.exe" # e.g. use pwsh.exe for PowerShell7

    # Token specific
    "tokenfile" = "$( $scriptPath )\cr.token"
    
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

Add-Type -AssemblyName System.Web



################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

$customProtocol = "apttoken$( Get-RandomString -length 6 -noSpecialChars )"
$clientId = "ssCNo32SNf"    # Certified CleverReach App for Apteco
$authUrl = [uri]"https://rest.cleverreach.com/oauth/authorize.php"
$tokenUrl = [uri]"https://rest.cleverreach.com/oauth/token.php"
$callbackFile = "$( $env:TEMP )\crcallback.txt"

#-----------------------------------------------
# PREPARE REGISTRY
#-----------------------------------------------

# current path - choose the current user to not need admin rights
$root = "Registry::HKEY_CURRENT_USER\Software\Classes" # "Registry::HKEY_CLASSES_ROOT"
$currentLocation = Get-Location

# Switch to registry
Set-Location -Path $root

# Remove the entries, if already existing
If ( Test-Path -path $customProtocol ) {
    Remove-Item -Path $customProtocol
}

# Create the entries now
New-Item -Path $customProtocol
New-ItemProperty -Path $customProtocol -Name "(Default)" -PropertyType String -Value "URL:$( $customProtocol )"
New-ItemProperty -Path $customProtocol -Name "URL Protocol" -PropertyType String -Value ""

Set-Location -Path ".\$( $customProtocol )"
New-Item -Path ".\DefaultIcon"
#New-ItemProperty -Path $customProtocol -Name "(Default)" -PropertyType String -Value "Launcher64.exe"
New-Item -Path ".\shell\open\command" -force # Creates the items recursively
New-ItemProperty -Path ".\shell\open\command" -Name "(Default)" -PropertyType String -Value """powershell.exe"" -File ""$( $scriptPath )\bin\callback.ps1"" ""%1"""  
#New-ItemProperty -Path ".\shell\open\command" -Name PowerShellPath -PropertyType String -Value """powershell.exe"" -File """C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\cleverreach\check-token\writefile.ps1""" ""%1"""
#Set-ItemProperty -Path ".\shell\open\command" -Name "(Default)" -Value "abc"

Write-Host "Entry does exist now"

# Go back to original path
Set-Location -path $currentLocation.Path


#-----------------------------------------------
# START OAUTHv2 PROCESS
#-----------------------------------------------

# Ask APTECO
$clientSecret = Read-Host -AsSecureString "Please ask Apteco to enter the client secret"
#qFXIwqU4NFoPawAriavxmY0ZLo2OhQ3H
$clientCred = New-Object PSCredential $clientId,$clientSecret

# Prepare redirect URI
$redirectUri = "$( $customProtocol )://www.apteco.de"

# STEP 1: Prepare the first call to let the user log into cleverreach
# SOURCE: https://powershellmagazine.com/2019/06/14/pstip-a-better-way-to-generate-http-query-strings-in-powershell/
$nvCollection  = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
$nvCollection.Add('response_type','code')
$nvCollection.Add('client_id',$clientId)
$nvCollection.Add('grant',"basic")
$nvCollection.Add('redirect_uri', $redirectUri) # a dummy url like apteco.de is needed

# Create the url
$uriRequest = [System.UriBuilder]$authUrl
$uriRequest.Query = $nvCollection.ToString()

# Remove callback file if it exists
If ( Test-Path -Path $callbackFile ) {
    "Removing callback file '$( $callbackFile )'"
    Remove-Item $callbackFile -Force
}

# Open the default browser with the generated url
Start-Process $uriRequest.Uri.OriginalString

# Wait
"Waiting for the callback file $( $callbackFile )"
Do {
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 500
} Until ( Test-Path -Path $callbackFile )

"Callback file found"

# Read and parse callback file
$callback = Get-Content -Path $callbackFile -Encoding utf8
$callbackUri = [uri]$callback
$callbackUriSegments = [System.Web.HttpUtility]::ParseQueryString($callbackUri.Query)
$code = $callbackUriSegments["code"]

# Remove callback file
Remove-Item $callbackFile -Force

# STEP 2: Prepare the second call to exchange the code quickly for a token

$postParams = [Hashtable]@{
    Method = "Post"
    Uri = $tokenUrl
    Body = [Hashtable]@{
        "client_id" = $clientCred.UserName
        "client_secret" = $clientCred.GetNetworkCredential().Password
        "redirect_uri" = $redirectUri
        "grant_type" = "authorization_code"
        "code" = $code
    }
    Verbose = $true
}
$response = Invoke-RestMethod @postParams

"Got a token with scope '$( $response.scope )'"

#$response.access_token
#$response.refresh_token

# Trying an API call
$headers = @{
    "Authorization" = "Bearer $( $response.access_token )"
}
$ttl = Invoke-RestMethod -Uri "https://rest.cleverreach.com/v3/debug/ttl.json" -Method Get -ContentType "application/json; charset=utf-8" -Headers $headers

"Used token successfully. Token expires at '$( $ttl.date.toString() )'"

# Clear the variable straight away
$clientCred = $null
$clientSecret = ""


#-----------------------------------------------
# HOUSEKEEPING OF REGISTRY
#-----------------------------------------------

# Switch to root path of registry
Set-Location -Path $root

# Remove item now
Remove-Item $customProtocol -Recurse

# Go back to original path
Set-Location -path $currentLocation.Path

