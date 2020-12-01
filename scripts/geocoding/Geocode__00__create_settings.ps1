
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

$useFilePicker = $true #  choose if you want to enter the path manually or use the filepicker

################################################
#
# FUNCTIONS
#
################################################

if ( $useFilePicker ) {

    Add-Type -AssemblyName System.Windows.Forms

}

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}



################################################
#
# SETUP SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$keyFile = "$( $scriptPath )\aes.key"
$pass = Read-Host -AsSecureString "Please enter the password for bing maps API" 
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password) -keyFile $keyFile

$loginSettings = @{
    token = $passEncrypted 
}

#-----------------------------------------------
# INPUT / MPPPING
#-----------------------------------------------

# mappings to the api format
$mapping = @{
    "storeID" = "Id"
    "street" = "GeocodeRequest/Address/AddressLine"
    "postcode" = "GeocodeRequest/Address/PostalCode"
    "city" = "GeocodeRequest/Address/PostalTown"
}

# fixed values not contained in the file
$fixedValue = @{
    "GeocodeRequest/Culture" = "de-DE"
    "GeocodeRequest/Address/CountryRegion" = "Germany"
}

$inputMethod = "file" # file|sqlserver

if ($inputMethod -eq "file") {

    if ($useFilePicker) {
        $inputFile =  Get-FileName -initialDirectory $scriptPath -filter "All files (*.*)|*.*";
    } else {
        $inputFile = "$( $scriptPath )\input.csv"
    }

}

$inputFileSettings = @{
    path = $inputFile
    delimiter = "`t"
    encoding = "UTF8" # not used yet
    mapping = $mapping
    fixedValues = $fixedValue
}

if ($inputMethod -eq "sqlserver") {
    # TODO [ ] implement this sqlserver read
}

#-----------------------------------------------
# SECURITY
#-----------------------------------------------

$encryptionSettings = @{
    hashId = $true # set to true if the ID should be hashed first, maybe not allowed on the machine
    hashMethod = "SHA256"
}


#-----------------------------------------------
# PROXY
#-----------------------------------------------

# ask for credentials if e.g. a proxy is used (normally without the prefixed domain)
#$cred = Get-Credential
#$proxyUrl = "http://proxy:8080"

# TODO [ ] use GUID instead of timestamp and on runtime
# TODO [ ] implement file picker for input file
# TODO [ ] load data into datatable first instead of using a file directly to prepare the optional load from a sqlserver query 


#-----------------------------------------------
# FILES
#-----------------------------------------------

# filenames
$translationFile = "$( $timestamp )_translation.txt"
$translationSuccess = "$( $timestamp )_success_translation.txt"
$translationFailed = "$( $timestamp )_failed_translation.txt"
$successFile = "$( $timestamp )_success.txt"
$failedFile = "$( $timestamp )_failed.txt"

$exportFiles = @{
    translationFile = $translationFile
    translationSuccess = $translationSuccess
    translationFailed = $translationFailed
    successFile = $successFile
    failedFile = $failedFile
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{

    # General
    logfile = "$( $scriptPath )\bingmaps.log"

    # Connection
    connection = @{
        changeTLSEncryption = $true # maybe set to false if not allowed to set
    }
    proxy = @{
        # not configured yet as setting
    }

    # Security 
    aesFile = $keyFile

    # Detail settings    
    login = $loginSettings
    #bingmapsKey=$passEncrypted

    # Input
    inputMethod = $inputMethod
    inputfile = $inputFileSettings
    encryption = $encryptionSettings

    # Output
    rewrite = @{
        active = $true # set to true if the files should be rewritten
        method = "stream" # full|stream
    }
    exportfiles = $exportFiles

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
