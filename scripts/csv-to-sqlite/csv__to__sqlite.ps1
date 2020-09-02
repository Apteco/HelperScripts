################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)

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
$processId = [guid]::NewGuid()
$modulename = "sqlitefileimport"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{

    # Security settings
    aesFile = "$( $scriptPath )\aes.key"

    # Create a secure string like
    # Get-PlaintextToSecure -String "token" -keyFile "$( $scriptPath )\aes.key"
    # And get it plaintext back by
    # Get-SecureToPlaintext -String $settings.token 
    mailSecureString = "8709a78sdfasdf09879709870asdf"

    exportDir = "D:\Apteco\Build\system\Data\OrbitAPI\"             # folder with files to import
    sqliteDb = "D:\Apteco\Build\system\Data\database.sqlite"    # database to load the files into
    backupDir = "$( $scriptPath )\backup"                       # backup folder for files and database
    filterForSqliteImport = @("*.csv";"*.txt";"*.tab")          # files to import
    logfile = "$( $scriptPath )\sqlite_import.log"              # logfile
    backupSqlite = $true                                        # $true|$false if you wish to create backups of the sqlite database
    
    createBuildNow = $false # $true|$false if you want to create an empty file for "build.now"
    buildNowFile = "D:\Apteco\build\system\preload\buildmarker\build.now" # Path to the build now file
    
    # Settings for smtp mails
    mailSettings = @{
        smtpServer = "smtp.example.de"
        from = "admin@example.de"
        to = "responsible-person@example.de"
        port = 587
    }
    
}

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Items to backup
$itemsToBackup = @(
    "$( $settings.sqliteDb )"
)

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
    $settings.sqliteDb = "$( $settings.sqliteDb ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################


# Create general settings
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
$successFile = $settings.buildNowFile

# Create credentials for mails
$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext -String $settings.mailSecureString ) -AsPlainText -Force
$smtpcred = New-Object PSCredential $settings.mailSettings.from,$stringSecure

# Exit for manually creating secure strings
# exit 0
# Get-PlaintextToSecure -String "9xt..." -keyFile "$( $scriptPath )\aes.key"


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
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################

[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
$currentTimestampDateTime = Get-DateTimeFromUnixtime -unixtime $currentTimestamp -inMilliseconds -convertToLocalTimezone

Write-Log -message "Current timestamp: $( $currentTimestamp )"


################################################
#
# REMOVE BUILD.NOW FILE IF PRESENT
#
################################################

If ( Test-Path $successFile -and $settings.createBuildNow ) {
    Remove-Item -Path $successFile -Force
}


################################################
#
# BACKUP SQLITE FIRST
#
################################################

Write-Log -message "Setting for creating backups $( $settings.backupSqlite )"

if ( $settings.backupSqlite -and ( Check-Path -Path $settings.sqliteDb )) {
    
    # Create backup subfolder
    $destination = $settings.backupDir
    $destinationWithTimestamp = "$( $destination )\$( Get-Date $timestamp -Format "yyyyMMddHHmmss" )_$( $processId )\"
    New-Item -Path $destinationWithTimestamp -ItemType Directory

    Write-Log -message "Creating backup into $( $destinationWithTimestamp )"

    # backup
    $itemsToBackup | foreach {

        $source = $_
        
        # Check if it is a file or folder
        if ( Test-Path -Path $source -PathType Leaf ) {
            # File
        } else {
            #Folder
            $source = "$( $source )\*"
        }

        Write-Log -message "Creating backup of $( $source )"    

        Copy-Item -Path $source -Destination $destinationWithTimestamp -Force -Recurse

    }

}


################################################
#
# LOAD CSV INTO SQLITE
#
################################################



# TODO [ ] make use of transactions for sqlite to get it safe

Write-Log -message "Import data into sqlite '$( $settings.sqliteDb )'"    

# Settings for sqlite
$sqliteExe = $libExecutables.Where({$_.name -eq "sqlite3.exe"}).FullName
$processIdSqliteSafe = Sanitize-SqliteTableName -tableName "temp__$( $processId.Guid )"
$filesToImport = Get-ChildItem -Path $settings.exportDir -Include $settings.filterForSqliteImport -Recurse

#-----------------------------------------------
# IMPORT THE FILES TEMPORARILY WITH PROCESS ID
#-----------------------------------------------

# Create database if not existing
# In sqlite the database gets automatically created if it does not exist

$filesToImport | ForEach {
    
    $f = $_
    $objectName = Sanitize-SqliteTableName -tableName $f.BaseName.Split("-")[1]
    $destination = "$( $processIdSqliteSafe )__$( $objectName )"

    # Import data
    ImportCsv-ToSqlite -sourceCsv $f.FullName -destinationTable $destination -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 

    # Create persistent tables if not existing
    $tableCreationStatement  = ( Read-Sqlite -query ".schema $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false ) -replace $destination, "IF NOT EXISTS $( $objectName )"
    $tableCreation = Read-Sqlite -query $tableCreationStatement -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false

    Write-Log -message "Import temporary table '$( $destination )' and create persistent table if not exists"    

}

#-----------------------------------------------
# IMPORT DATA FROM TEMPORARY TABLES TO PERSISTENT TABLES
#-----------------------------------------------

$filesToImport | ForEach {
    
    $f = $_
    $objectName = Sanitize-SqliteTableName -tableName $f.BaseName.Split("-")[1]
    $destination = "$( $processIdSqliteSafe )__$( $objectName )"

    Write-Log -message "Import temporary table '$( $destination )' into persistent table '$( $objectName )'"    


    # Column names of temporary table    
    $columnsTemp = Read-Sqlite -query "PRAGMA table_info($( $destination ))" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 

    # Column names of persistent table
    $columnsPersistent = Read-Sqlite -query "PRAGMA table_info($( $objectName ))" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    $columnsPersistensString = $columnsPersistent.Name -join ", "

    # Compare columns
    $differences = Compare-Object -ReferenceObject $columnsPersistent -DifferenceObject $columnsTemp -Property Name
    $colsInPersistentButNotTemporary = $differences | where { $_.SideIndicator -eq "<=" }
    $colsInTemporaryButNotPersistent = $differences | where { $_.SideIndicator -eq "=>" }

    # Add new columns in persistent table that are only present in temporary tables
    if ( $colsInTemporaryButNotPersistent.count -gt 0 ) {
        #Send-MailMessage -SmtpServer $settings.mailSettings.smtpServer -From $settings.mailSettings.from -To $settings.mailSettings.to -Port $settings.mailSettings.port -UseSsl -Credential $smtpcred
        #         -Body "Creating new columns $( $colsInTemporaryButNotPersistent.Name -join ", " ) in persistent table $( $objectName ). Please have a look if interested." `
        #         -Subject "[systemname] Creating new columns in persistent table $( $objectName )"
    }
    $colsInTemporaryButNotPersistent | ForEach {
        $newColumnName = $_.Name
        Write-Log -message "WARNING: Creating a new column '$( $newColumnName )' in table '$( $objectName )'"
        Read-Sqlite -query "ALTER TABLE $( $objectName ) ADD $( $newColumnName ) TEXT" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    
    }

    # Add new columns in temporary table
    # There is no need to do that because the new columns in the persistent table are now created and if there are columns missing in the temporary table they won't just get filled.
    # The only problem could be to have index values not filled. All entries will only be logged.
    $colsInPersistentButNotTemporary | ForEach {
        $newColumnName = $_.Name
        Write-Log -message "WARNING: There is column '$( $newColumnName )' missing in the temporary table for persistent table '$( $objectName )'. This will be ignored."
    }

    # Import the files temporarily with process id
    $columnsString = """$( $columnsTemp.Name -join '", "' )"""
    Read-Sqlite -query "INSERT INTO $( $objectName ) ( $( $columnsString ) ) SELECT $( $columnsString ) FROM $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    

}


#-----------------------------------------------
# DROP TEMPORARY TABLES
#-----------------------------------------------

$filesToImport | ForEach {  

    $f = $_
    $objectName = Sanitize-SqliteTableName -tableName $f.BaseName.Split("-")[1]
    $destination = "$( $processIdSqliteSafe )__$( $objectName )"
    Read-Sqlite -query "Drop table $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    Write-Log -message "Dropping temporary table '$( $destination )'"
    Remove-Item -Path $f.FullName -Force
    Write-Log -message "Removed temporary file '$( $f.FullName )'"

}  


################################################
#
# CREATE SUCCESS FILES
#
################################################

if ( $settings.createBuildNow -and $settings.createBuildNow ) {
    Write-Log -message "Creating file '$( $settings.buildNowFile )'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.buildNowFile -Encoding utf8 -Force
}


################################################
#
# SEND EMAIL
#
################################################


Send-MailMessage -SmtpServer $settings.mailSettings.smtpServer -From $settings.mailSettings.from -To $settings.mailSettings.to -Port $settings.mailSettings.port -UseSsl -Credential $smtpcred
         -Body "[systemname] Data was extracted from files and imported into database" `
         -Subject "[systemname] Data was extracted from files and imported into database"
