
################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true
$configMode = $true


################################################
#
# NOTES
#
################################################

<#

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "SYNWACREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"


################################################
#
# START
#
################################################


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
$logfileDefault = "$( $scriptPath )\synwa.log"

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
# LOAD LOGGING MODULE NOW
#-----------------------------------------------

$settings = @{
    "logfile" = $logfile
}

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


#-----------------------------------------------
# LOG THE NEW SETTINGS CREATION
#-----------------------------------------------

Write-Log -message "Creating a new settings file" -severity ( [Logseverity]::WARNING )


################################################
#
# SETTINGS
#
################################################


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$accessToken = Read-Host -AsSecureString "Please enter the accessToken for syniverse"
$accessTokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessToken).GetNetworkCredential().Password)

$authentication = @{
    accessToken = $accessTokenEncrypted
}


#-----------------------------------------------
# SYNIVERSE SETTINGS
#-----------------------------------------------

$sendMethod = "sender_id" # sender_id|channel

$senderId = ""
if ($sendMethod -eq "sender_id") {
    $senderId = Read-Host "Please enter the senderId for syniverse"
}


#-----------------------------------------------
# SETTINGS OBJECT
#-----------------------------------------------

# TODO [ ] check if some settings could be brought together

$settings = @{

    # General
    "base"="https://api.syniverse.com/"					# Default url
    "changeTLS" = $true                      	        # should tls be changed on the system?
    "providername" = "synwa"                           # identifier for this custom integration, this is used for the response allocation
    "logfile" = $logfile                        # Logfile for this process

    # Proxy settings, if needed - will be automatically used
    "useDefaultCredentials" = $false
    "ProxyUseDefaultCredentials" = $false
    "proxyUrl" = "" # ""|"http://proxyurl:8080"

    # Authentication
    "authentication" = $authentication

    # Watchdog specific
    "watcher" = @{
        folderToWatch = "/root/go/payloads/synsms"     # The directory to watch
        watchSubDirs = $false                                            # Should subdirectories watched too?
        filter = "*.json"                                             # Filter for the files in the watched directory
        notifyFilter = @(                                               # Define which attributes of the files should trigger the event
            [System.IO.NotifyFilters]::FileName
            [System.IO.NotifyFilters]::Size
            #[System.IO.NotifyFilters]::LastWrite
        )
    }

    # Event settings
    "waitForExportFinishedTimeout" = 120                                  # If files arrive in the directory, a process is checking if it is still locked due to a still active writing thread 
                                                                        # This parameter defines the max seconds timeout to wait for that process to finish
    #exportDir = "D:\Apteco\Build\systemname\Data\OrbitAPI"              # Where should the files copied to
    
    # General settings

    # Settings for sqlite
    "sqliteDll" =  "$( $scriptPath )/lib/nuget/System.Data.SQLite.dll"
    "sqliteDb" = "$( $scriptPath )/test.sqlite" # :memory:
    
    # Upload settings
    #"uploadsFolder" = "$( $scriptPath )\uploads"
    #"rowsPerUpload" = 100
    "sendMethod" = $sendMethod
    "senderId" = $senderId
    #"firstResultWaitTime" = 15                          # First wait time after sending out SMS for the first results
                                                        # and also wait time after each loop
    #"maxResultWaitTime" = 100                           # Maximum time to request SMS sending status

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# rename settings file if it already exists
If ( Test-Path -Path $settingsFile ) {
    $backupPath = "$( $settingsFile ).$( $timestamp.ToString("yyyyMMddHHmmss") )"
    Write-Log -message "Moving previous settings file to $( $backupPath )" -severity ( [Logseverity]::WARNING )
    Move-Item -Path $settingsFile -Destination $backupPath
} else {
    Write-Log -message "There was no settings file existing yet"
}

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $settingsFile -Encoding UTF8


################################################
#
# CREATE FOLDERS IF NEEDED
#
################################################

# Creating the lib folder for the sqlite stuff
$libFolder = ".\$( $libSubfolder )"
if ( !(Test-Path -Path "$( $libFolder )") ) {
    Write-Log -message "lib folder '$( $libFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $libFolder )" -ItemType Directory
}
<#
$exportDir = $settings.response.exportDirectory
if ( !(Test-Path -Path "$( $exportDir )") ) {
    Write-Log -message "export folder '$( $exportDir )' does not exist. Creating the folder now!"
    New-Item -Path "$( $exportDir )" -ItemType Directory
}
#>


################################################
#
# DOWNLOAD AND INSTALL THE SQLITE PACKAGE
#
################################################
# TODO [ ] add some hints here on sqlite code
<#
$winscpDll = "WinSCPnet.dll"

if ( $libDlls.Name -notcontains $winscpDll ) {

    Write-Log -message "A browser page is opening now. Please download the .NET assembly library zip file"
    Write-Log -message "Please unzip the file and put it into the lib folder"
        
    Start-Process "https://winscp.net/download/WinSCP-5.19.2-Automation.zip"
    
    # Wait for key
    Write-Host -NoNewLine 'Press any key if you have put the files there';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

    # Confirm you read the licence details
    $decision = $Host.UI.PromptForChoice("Confirmation", "Can you confirm you read 'license-dotnet.txt' and 'license-winscp.txt'", @('&Yes'; '&No'), 1)

    If ( $decision -eq "0" ) {

        # Means yes and proceed

    } else {
        
        # Leave the process here
        exit 0

    }

}
#>


################################################
#
# DO SOME MORE SETTINGS DIRECTLY
#
################################################

#-----------------------------------------------
# RELOAD SETTINGS
#-----------------------------------------------

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the preparation file to prepare the connections
. ".\bin\preparation.ps1"



################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');