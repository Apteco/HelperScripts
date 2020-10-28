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
$modulename = "CDCDOWNLOAD"
$timestamp = [datetime]::Now


$settings = @{

    baseUrl = "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/daily/kl/recent/"
    changeTLS = $true

    backupDir = "$( $scriptPath )\backup"
    sqliteDb = "$( $scriptPath )\data\dwd_cdc.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    filterForSqliteImport = @("*.csv";"*.txt";"*.tab")
    logfile = "$( $scriptPath )\import_to_sqlite.log"
    backupSqlite = $true # $true|$false if you wish to create backups of the sqlite database
    removeFilesAfterImport = $false # $true|$false


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

# Import Bits to download all files in once
Import-Module BitsTransfer



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
# DOWNLOAD AND UNZIP FILES
#
################################################

#-----------------------------------------------
# LOAD CDC DATA INDEX
#-----------------------------------------------

# Load the CDC climate data file overview and do a basic parsing to extract links
$w = Invoke-WebRequest -Method Get -Uri $settings.baseUrl -UseBasicParsing


#-----------------------------------------------
# PARSE WEBSITE AND EXTRACT LINKS
#-----------------------------------------------

# exclude everything that contains "../" or ".pdf", case-insensitive
# to build bigger exlusion lists, there are some good hints here: https://devblogs.microsoft.com/scripting/speed-up-array-comparisons-in-powershell-with-a-runtime-regex/
$links = $w.Links.href | where { $_ -inotmatch "(?i)^*(\.\./|\.pdf$)$" } #| select -first 10

#-----------------------------------------------
# ROOT FOLDER
#-----------------------------------------------

$root = "$( $scriptPath )\processing\$( $processId )"

#-----------------------------------------------
# DOWNLOAD FILES
#-----------------------------------------------

$downloadFolder = "$( $root )\01_download"
New-Item -ItemType Directory -Path $downloadFolder

$links | select @{ name="Source";expression={ "$( $settings.baseUrl )$( $_ )" }}, @{name="Destination";expression={ "$( $downloadFolder )" }} | Start-BitsTransfer #-Destination $downloadFolder #-Asynchronous
    

#-----------------------------------------------
# UNZIP DATA
#-----------------------------------------------

$extractFolder = "$( $root )\02_extract"
New-Item -ItemType Directory -Path $extractFolder

$7zexe = $libExecutables.Where({$_.name -eq "7za.exe"}).FullName

# extracts (x) all zip files 
& $7zexe x "$( $downloadFolder )\*.zip" -o"$( $extractFolder )\*" 


#-----------------------------------------------
# FIND IMPORTANT FILES
#-----------------------------------------------

$climateFileFilter = "*produkt_klima_tag_*.txt"
$climateFiles = Get-ChildItem -Path $extractFolder -Filter $climateFileFilter -Recurse

$stationFileFilter = "*Metadaten_Geographie*.txt"
$stationFiles = Get-ChildItem -Path $extractFolder -Filter $stationFileFilter -Recurse

$filesToPrepare = $climateFiles.FullName + $stationFiles.FullName #Get-ChildItem -Path $settings.exportDir -Include $settings.filterForSqliteImport -Recurse


#-----------------------------------------------
# REWRITE FILES BECAUSE OF UNNECCESARY SPACES
#-----------------------------------------------

$rewriteFolder = "$( $root )\03_rewrite"
New-Item -ItemType Directory -Path $rewriteFolder

$filesToPrepare | ForEach {
    $f = Get-Item -Path $_
    $encoding = Switch -wildcard ( $f.Name ) {
        $stationFileFilter { "Default" }
        default { "UTF8" }
    }
    Import-Csv -Path $f.FullName -Delimiter ";" -Encoding $encoding -Verbose | Select *, @{name="ExtractTimestamp";expression={ Get-Date $timestamp -Format "yyyyMMddHHmmss" }} | Export-Csv -Verbose -Encoding UTF8 -Delimiter "`t" -Path "$( $rewriteFolder )\$( $f.Name )" -NoTypeInformation
}

$filesToImport = Get-ChildItem -Path $rewriteFolder -Recurse

################################################
#
# BACKUP SQLITE FIRST
#
################################################

Write-Log -message "Setting for creating backups $( $settings.backupSqlite )"

if ( $settings.backupSqlite -and ( Check-Path -Path $settings.sqliteDb )) {
    
    # TODO [ ] put these into settings
    # Create backup folder if not present
    If ( -not ( Check-Path -Path $settings.backupDir )) {
        New-Item -Path $settings.backupDir -ItemType Directory
    }

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
$processIdSqliteSafe = "temp__$( $processId.Guid.Replace('-','') )" # sqlite table names are not allowed to contain dashes or begin with numbers
<#
If ( -not ( Check-Path -Path $settings.sqliteDb )) {
    #New-Item -Path $settings.backupDir -ItemType Directory
    New-Item -Path $settings.sqliteDb -ItemType Directory  
}
#>

# Create database if not existing
# In sqlite the database gets automatically created if it does not exist



# Import the files temporarily with process id
$filesToImport |  ForEach {
    
    # Create object name
    $f = $_
    $objectName = Switch -wildcard ( $f.Name ) {
        $climateFileFilter { "produkt_klima_tag" }
        $stationFileFilter { "stationen_geographie" }
        default { $f.BaseName }
    }
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"

    # Import data
    ImportCsv-ToSqlite -sourceCsv $f.FullName -destinationTable $destination -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe

    # Create persistent tables if not existing
    $tableCreationStatement  = ( Read-Sqlite -query ".schema '$( $destination )'" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false ) -replace $destination, "IF NOT EXISTS '$( $objectName )'"
    $tableCreation = Read-Sqlite -query $tableCreationStatement -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false

    Write-Log -message "Import temporary table '$( $destination )' and create persistent table if not exists"    

}

# Import data from temporary tables to persistent tables
$filesToImport | ForEach {
    
    # Create object name
    $f = $_
    $objectName = Switch -wildcard ( $f.Name ) {
        $climateFileFilter { "produkt_klima_tag" }
        $stationFileFilter { "stationen_geographie" }
        default { $f.BaseName }
    }
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"

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
        #         -Body "Creating new columns $( $colsInTemporaryButNotPersistent.Name -join ", " ) in persistent table $( $objectName ). Please have a look if those should be added in Apteco Designer." `
        #         -Subject "[CRM/GV] Creating new columns in persistent table $( $objectName )"
    }
    $colsInTemporaryButNotPersistent | ForEach {
        $newColumnName = $_.Name
        Write-Log -message "WARNING: Creating a new column '$( $newColumnName )' in table '$( $objectName )'"
        Read-Sqlite -query "ALTER TABLE '$( $objectName )' ADD '$( $newColumnName )' TEXT" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    
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
    Read-Sqlite -query "INSERT INTO '$( $objectName )' ( $( $columnsString ) ) SELECT $( $columnsString ) FROM $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    

}

# Drop temporary tables
$filesToImport | ForEach {  
    # Create object name
    $f = $_
    $objectName = Switch -wildcard ( $f.Name ) {
        $climateFileFilter { "produkt_klima_tag" }
        $stationFileFilter { "stationen_geographie" }
        default { $f.BaseName }
    }
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"

    Read-Sqlite -query "Drop table '$( $destination )'" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    Write-Log -message "Dropping temporary table '$( $destination )'"

    If ( $settings.removeFilesAfterImport ) {
        Remove-Item -Path $f.FullName -Force
            Write-Log -message "Removed temporary file '$( $f.FullName )'"
    }


}  


Write-Log -message "Done!"
