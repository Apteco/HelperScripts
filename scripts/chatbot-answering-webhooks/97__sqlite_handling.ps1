################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

# $params = [hashtable]@{
#     "scriptPath" = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\parquet"
# }

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
    }
}


################################################
#
# NOTES
#
################################################

<#


# Example is based on: https://github.com/G-Research/ParquetSharp/blob/master/csharp.test/TestParquetFileReader.cs

TODO [ ] Add more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "SQLITELOAD"
$processId = [guid]::NewGuid()

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{
    "logfile" = "$( $scriptPath )/sqlite.log"
    "sqliteDll" =  "$( $scriptPath )/lib/nuget/System.Data.SQLite.dll"
    "sqliteDb" = ":memory:" #"$( $scriptPath )/test.sqlite"
}

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        [System.Net.SecurityProtocolType]::Tls13
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

#-----------------------------------------------
# LOAD ALL POWERSHELL CODE
#-----------------------------------------------

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# LOAD MORE LIBS (DLL,EXE)
#-----------------------------------------------
<#
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}
#>


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
        Write-Log -message "    $( $param )= ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# MORE CHECKS
#-----------------------------------------------

<#
# Possibly some checks for the future to make sure we are in Windows and having a 64bit shell
# Check the current OS
[System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
# Check if 64 bit
[Environment]::Is64BitProcess
#>
#[System.Environment]::SetEnvironmentVariable("SQLITEDB",$settings.sqliteDb)

################################################
#
# PREPARE DATABASE
#
################################################

#-----------------------------------------------
# PREPARE CONNECTION
#-----------------------------------------------

# Journal Mode = MEMORY can cause data loss as everything is written into memory instead of the disk
# Page size is 4096 as default
# Cache size is -2000 as default
$additionalParameters = "Journal Mode=MEMORY;Cache Size=-4000;Page Size=4096;"

Write-Log -message "Loading cache assembly from '$( $settings.sqliteDll )'"

sqlite-Load-Assemblies -dllFile $settings.sqliteDll

#[Reflection.Assembly]::LoadFile("~/pwsh/watchdog/lib/nuget/SQLite.Interop.dll")

Write-Log -message "Establishing connection to cache database '$( $settings.sqliteDB )'"

$retries = 10
$retrycount = 0
$secondsDelay = 2
$completed = $false

while (-not $completed) {
    try {
        #$sqliteConnection = sqlite-Open-Connection -sqliteFile ":memory:" -new
        $sqliteConnection = sqlite-Open-Connection -sqliteFile "$( $settings.sqliteDB )" -new -additionalParameters $additionalParameters
        Write-Log -message "Connection succeeded."
        $completed = $true
    } catch [System.Management.Automation.MethodInvocationException] {
        if ($retrycount -ge $retries) {
            Write-Log -message "Connection failed the maximum number of $( $retries ) times." -severity ([LogSeverity]::ERROR)
            throw $_
            exit 0
        } else {
            Write-Log -message "Connection failed $( $retrycount ) times. Retrying in $( $secondsDelay ) seconds." -severity ([LogSeverity]::WARNING)
            Start-Sleep -Seconds $secondsDelay
            $retrycount++
        }
    }
}


# Setting some pragmas for the connection
$sqlitePragmaCommand = $sqliteConnection.CreateCommand()

# With an unplanned event this can cause data loss, but in this case the database is not persistent, so good to go
# Good explanation here: https://stackoverflow.com/questions/1711631/improve-insert-per-second-performance-of-sqlite
$sqlitePragmaCommand.CommandText = "PRAGMA synchronous = OFF"
[void]$sqlitePragmaCommand.ExecuteNonQuery()
Write-Log -message "Setting the pragma '$( $sqlitePragmaCommand.CommandText )'"


################################################
#
# READ DATA AND INSERT
#
################################################


#-----------------------------------------------
# DEFINE DATA
#-----------------------------------------------

$tablename = "input"
$arr = [System.Collections.ArrayList]@(
    [PSCustomObject]@{
        "name" = "Florian"
        "phone" = "+4917664787187"
    }
    [PSCustomObject]@{
        "name" = "Martin"
        "phone" = "123"
    }
    [PSCustomObject]@{
        "name" = "Stefan"
        "phone" = "456"
    }
)


#-----------------------------------------------
# CREATE COMMAND AND DEFINE INSERT COLUMNS
#-----------------------------------------------

# Create database input parameters for INSERT statement
$sqliteInsertCommand = $sqliteConnection.CreateCommand()
$sqliteCreateFields = [System.Collections.ArrayList]@()
$colNames = [System.Collections.ArrayList]@()
$arr | Get-Member -MemberType NoteProperty | ForEach {
    
    $columnName = $_.Name

    $sqliteParameterObject = $sqliteInsertCommand.CreateParameter()
    $sqliteParameterObject.ParameterName = ":$( $columnName )"
    [void]$sqliteInsertCommand.Parameters.Add($sqliteParameterObject)

    [void]$colNames.Add( $columnName )
    [void]$sqliteCreateFields.Add( """$( $columnName )"" TEXT" )

}


#-----------------------------------------------
# CREATE TEMPORARY TABLE
#-----------------------------------------------

# Create temporary table in database
$sqliteCommand = $sqliteConnection.CreateCommand()
$sqliteCommand.CommandText = @"
CREATE TABLE IF NOT EXISTS "$( $tablename )" (
    $( $sqliteCreateFields -join ",`n" )
);
"@

Write-Host $sqliteCommand.CommandText

[void]$sqliteCommand.ExecuteNonQuery()


#-----------------------------------------------
# PREPARE INSERT STATEMENT
#-----------------------------------------------

$sqliteInsertCommand.CommandText = "INSERT INTO ""$( $tablename )"" (""$( $colNames -join '" ,"' )"") VALUES ($( $sqliteInsertCommand.Parameters.ParameterName -join ', ' ))"


#-----------------------------------------------
# INSERT DATA WITH TRANSACTION
#-----------------------------------------------

$sqliteTransaction = $sqliteConnection.BeginTransaction()

$inserts = 0
$t = Measure-Command {

    try {

        # Insert the data
        $arr | ForEach {
            $row = $_
            $colNames | ForEach {
                $colName = $_
                #Write-Host ":$( $colName )"
                $sqliteInsertCommand.Parameters[":$( $colName )"].Value = $row.$colName
            }
            $inserts += $sqliteInsertCommand.ExecuteNonQuery()
            $sqliteInsertCommand.Reset()
        }

    } catch {

        throw $_

    } finally {

        # Commit the transaction
        $sqliteTransaction.Commit()

    }

}


#-----------------------------------------------
# LOG
#-----------------------------------------------


Write-Log -message "Inserted $( $inserts ) rows in $( $t.TotalSeconds ) seconds and will commit now"
$totalSeconds += $t.TotalSeconds

# Read the data
$count = sqlite-Load-Data -sqlCommand "Select count(*) as c from $( $tablename )" -connection $sqliteConnection
Write-Log -message "Written the data in $( $totalSeconds ) seconds, having '$( $count.c )' rows in total now"

exit 0


################################################
#
# CLOSE CONNECTION
#
################################################

<#
# Close the connection if it is not in-memory
if ( $settings.sqliteDb -like "*:memory:*"  ) { 
    Write-Log -message "Closing connection to cache"
    $sqliteConnection.Dispose()
} else {
    Write-Log -message "Keeping the database open"
}
#>
