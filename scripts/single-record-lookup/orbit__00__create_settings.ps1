
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

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem ".\$( $functionsSubfolder )" -Filter "*.ps1" -Recurse | ForEach {
    . $_.FullName
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$keyFile = "$( $scriptPath )\aes.key"
$pass = Read-Host -AsSecureString "Please enter the password for your api user"
$passEncrypted = Get-PlaintextToSecure ((New-Object System.Management.Automation.PSCredential ('dummy', $pass) ).GetNetworkCredential().Password) -keyFile $keyFile

$loginSettings = @{
    dataView = "GV"
    user = "fbracht"
    pass = $passEncrypted 
}
    
#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    type = "MULTIPART" # ONEPART|MULTIPART
}


#-----------------------------------------------
# MULTIPART SETTINGS
#-----------------------------------------------

$multipartSettings = @{
    noParts = 3           # How many parts do you want to have? Another todo could be in future to enter fixed 
    partPrefix = "part"
    secondsToWait = 30
}

#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------


$settings = @{
    
    # General
    base="https://wscrm.apteco.io/OrbitAPI/"             # Default url
    changeTLS = $true                                   # should tls be changed on the system?
    logfile="$( $scriptPath )\orbit_api_upload.log"     # path and name of log file
    providername = "orbitapiupload"                     # identifier for this custom integration, this is used for the response allocation
    loginType = "SIMPLE"                                # SIMPLE|SALTED

    # Session 
    aesFile = $keyFile
    sessionFile = "$( $scriptPath )\session.json"       # name of the session file
    ttl = 60                                            # Time to live in minutes for the current session
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    login = $loginSettings                              # login object from code above
    upload = $uploadSettings                            # upload settings
    multipart = $multipartSettings                      # multipart settings

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8


################################################
#
# SOME ADDITIONAL INFORMATION FROM API
#
################################################

<#
if ( $settings.login.dataView -eq "" ) {
    $endpoint = Get-Endpoint -key "GetDataViews" # GetDataViews|GetDataViewsForDomain|GetDataViewsForSystemName
    $uri = Resolve-Url -endpoint $endpoint
    $dataviews = Invoke-RestMethod -Uri $uri -Method $endpoint.method -ContentType "application/json"
    $settings.Item("dataViewName") = ( $dataviews.list | Out-GridView -PassThru ).Name
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################


# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8
#>


