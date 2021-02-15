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



################################################
#
# NOTES
#
################################################

<#

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

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
#$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "S3BACKUP"
$timestamp = [datetime]::Now


if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}



<#

Ask for the settings file
Add/Replace parts for the backupfolders
Save settings file again


# TODO [ ] think about relative folder to drive

#>



################################################
#
# ADD SOME BACKUP FOLDERS WITHOUT THE NEED TO CHANGE THE SETTINGS SCRIPT
# 
################################################

$propName = "objectsToBackup"

$backupFolders = @(
    "C:\Users\Florian\Pictures\Camera Roll"
)

if ( $settings.PSObject.Properties.Name -contains $propName ) {
    # Replace property
    $settings.$propName = $backupFolders
} else {
    # Add property
    $settings | Add-Member -MemberType NoteProperty -Name $propName -Value $backupFolders
}




################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8
