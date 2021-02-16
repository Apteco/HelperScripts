
################################################
#
# START
#
################################################

#-----------------------------------------------
# LOAD SCRIPTPATH
#-----------------------------------------------

if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


#-----------------------------------------------
# LOAD MORE FUNCTIONS
#-----------------------------------------------

# Assemblies
Add-Type -AssemblyName System.Web

$functionsSubfolder = ".\functions"

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\s3backup.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# 7ZIP ENCRYPTION PASSWORD
#-----------------------------------------------

$encryptionPassword = Get-RandomString -length 24
Write-Host "The zip files will be encrypted with this password, please note it:" -ForegroundColor Black -BackgroundColor White
Write-Host "$( $encryptionPassword )" -ForegroundColor Black -BackgroundColor White


#-----------------------------------------------
# ASK FOR UPLOAD FOLDER
#-----------------------------------------------

# Default file
$uploadDefault = "$( $scriptPath )\uploads"

# Ask for another path
$upload = Read-Host -Prompt "Where do you want the files to be processed? Just press Enter for this default [$( $uploadDefault )]"

# If prompt is empty, just use default path
if ( $upload -eq "" -or $null -eq $upload) {
    $upload = $uploadDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $upload -IsValid ) {
    Write-Host "Upload folder '$( $upload )' is valid"
} else {
    Write-Host "Upload folder '$( $upload )' contains invalid characters"
}


################################################
#
# SETUP SETTINGS
#
################################################


$keyFile = "$( $scriptPath )\aes.key"


#-----------------------------------------------
# S3 SETTINGS
#-----------------------------------------------


$s3SecretKey = Read-Host -AsSecureString "Please enter the secret key for your s3 storage"
$s3SecretKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$s3SecretKey).GetNetworkCredential().Password)

$s3Settings = @{

    baseUrl = "https://s3-de-central.profitbricks.com/"
    accessKey = "accesskey" # ENTER YOUR ACCESS KEY
    secretKey = $s3SecretKeyEncrypted # ENTER YOUR SECRET KEY
    region = "s3-de-central"
    service = "s3"
    bucket = ""

}



#-----------------------------------------------
# 7ZIP SETTINGS
#-----------------------------------------------

$encryptionPasswordSecure = ConvertTo-SecureString -String ( $encryptionPassword ) -AsPlainText -Force
$encryptionPasswordEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$encryptionPasswordSecure).GetNetworkCredential().Password)

$7zSettings = @{
    encryptionPassword = $encryptionPasswordEncrypted 
}


#-----------------------------------------------
# ALL SETTINGS TOGETHER
#-----------------------------------------------

$settings = [PSCustomObject]@{
    
    # General settings
    aesFile = $keyFile
    logfile = $logfile

    # Connection settings
    changeTLS = $true

    # Backup settings
    uploadFolder = $upload                    # Default folder for preparing the upload
    
    # Cleanup
    maxAgeOfArchives = 10                     # Days to keep the files in the bucket

    # Detail settings
    "s3" = $s3Settings    
    "7z" = $7zSettings

}


################################################
#
# SOME MORE SETTINGS WITH THE API
#
################################################


#-----------------------------------------------
# PREPARATION
#-----------------------------------------------

$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.s3.secretKey ) -AsPlainText -Force
$cred = [pscredential]::new( $settings.s3.accessKey, $stringSecure )
$s3 = [S3]::new( $cred, $settings.s3.baseUrl, $settings.s3.region, $settings.s3.service )


#-----------------------------------------------
# CHOOSE THE BUCKET FOR BACKUP
#-----------------------------------------------

# TODO [ ] alternatively a bucket creation could also be implemented

$buckets = $s3.getBuckets()
$bucket = $buckets | Out-GridView -PassThru | select -First 1
$settings.s3.bucket = $bucket.name


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8


################################################
#
# CREATE FOLDER STRUCTURE
#
################################################

#-----------------------------------------------
# CHECK UPLOADS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.uploadFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}
