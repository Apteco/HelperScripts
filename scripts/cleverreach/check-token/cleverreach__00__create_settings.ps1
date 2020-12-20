
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
$token = Read-Host -AsSecureString "Please enter the token for cleverreach"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password)

$login = @{
    "accesstoken" = $tokenEncrypted
    "refreshTokenAutomatically" = $true
    "refreshTtl" = 604800 # seconds; refresh one week before expiration
}

#-----------------------------------------------
# MAIL SETTINGS
#-----------------------------------------------
$smtpPass = Read-Host -AsSecureString "Please enter the SMTP password"
$smtpPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$smtpPass).GetNetworkCredential().Password)
@{
    smptServer = "smtp.example.com"
    port = 587
    from = "admin@example.com"
    username = "admin@example.com"
    password = $smtpPassEncrypted
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{
    
    # general
    "base" = "https://rest.cleverreach.com/v3/"
    "logfile" = "$( $scriptPath )\cr.log"
    "contentType" = "application/json; charset=utf-8"
    
    # Token specific
    "tokenfile" = "$( $scriptPath )\cr.token"
    "sendMailOnCheck" = $true
    "sendMailOnSuccess" = $true
    "sendMailOnFailure" = $true
    "notificationReceiver" = "admin@example.com"

    # Mail settings for notification
    "mail" = $mailSettings

    # authentication
    "login" = $login
    
    # network
    "changeTLS" = $true
    
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
# EXPORT THE TOKEN
#
################################################

# save token to file
(New-Object PSCredential "dummy",$token).GetNetworkCredential().Password | Set-Content -path "$( $settings.tokenfile )" -Encoding UTF8 -Force
