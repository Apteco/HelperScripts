
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
$modulename = "syn_filewatcher"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# TODO  [ ] unify settings in json file

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

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
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

<#
# Load all exe and dll files in subfolder
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
# PREPARE DATABASE
#
################################################

#-----------------------------------------------
# DEBUGGING REASONS
#-----------------------------------------------

# Unregister all actions
. "./99__filewatcher__unregister.ps1"

# Removing sqlite database
Remove-Item -Path $settings.sqliteDb


#-----------------------------------------------
# PREPARE CONNECTION
#-----------------------------------------------

# Journal Mode = MEMORY can cause data loss as everything is written into memory instead of the disk
# Page size is 4096 as default
# Cache size is -2000 as default
$additionalParameters = "Journal Mode=MEMORY;Cache Size=-4000;Page Size=4096;"

Write-Log -message "Loading cache assembly from '$( $settings.sqliteDll )'"

# Make sure the interop dll file is in the same directory
sqlite-Load-Assemblies -dllFile $settings.sqliteDll

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


#-----------------------------------------------
# DUMMY DATA FIRST
#-----------------------------------------------

$tablename = "input"

# Example template for database insert preparation
$arr = [System.Collections.ArrayList]@(
    [PSCustomObject]@{
        "from"       = "+4917964712345" # $eventValues.from_address
        "body"       = "Hello World"  #$eventValues.message_body
        "to"         = "447743123456" # $eventValues.to_address
        "senderid"   = "gd6OXXXXXXXXXXXXXXXXXX" # $eventValues.sender_id_id
        "timestamp"  = "2021-11-02T17:33:56.656Z" # $eventData.event.timestamp
        "eventid"    = "8a0aNb97TnmPmgOYPVY-RQ" # $eventData."event-id"
        "response_text" = ""    # placeholder for the algorithm to fill out the data
        "response_media" = ""   # comma separated list of urls to be send as rich media
    }
)

# Example template for database update preparation
$arr2 = [System.Collections.ArrayList]@(
    [PSCustomObject]@{
        "set" = [PSCustomObject]@{
            "response_text" = "Hello World"    # placeholder for the algorithm to fill out the data
            "response_media" = ""   # comma separated list of urls to be send as rich media
        }
        "where" = [PSCustomObject]@{
            "eventid"    = "8a0aNb97TnmPmgOYPVY-RQ" # $eventData."event-id"
        }
    }
)


#-----------------------------------------------
# CREATE INSERT COMMAND AND DEFINE INSERT COLUMNS
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
$sqliteCreateCommand = $sqliteConnection.CreateCommand()
$sqliteCreateCommand.CommandText = @"
CREATE TABLE IF NOT EXISTS "$( $tablename )" (
    $( $sqliteCreateFields -join ",`n" )
);
"@

Write-Host $sqliteCreateCommand.CommandText
[void]$sqliteCreateCommand.ExecuteNonQuery()


#-----------------------------------------------
# PREPARE INSERT STATEMENT
#-----------------------------------------------

$sqliteInsertCommand.CommandText = "INSERT INTO ""$( $tablename )"" (""$( $colNames -join '" ,"' )"") VALUES ($( $sqliteInsertCommand.Parameters.ParameterName -join ", " ))"


#-----------------------------------------------
# LOAD LAST N FILES TO PICKUP ON EARLIER EVENTS
#-----------------------------------------------

# TODO [ ] think about this later


#-----------------------------------------------
# CREATE UPDATE COMMAND AND DEFINE UPDATE AND WHERE COLUMNS
#-----------------------------------------------

# Create database input parameters for INSERT statement
$sqliteUpdateCommand = $sqliteConnection.CreateCommand()
$updateSetColNames = [System.Collections.ArrayList]@( ( $arr2.set | Get-Member -MemberType NoteProperty ).Name )
$updateWhereColNames = [System.Collections.ArrayList]@( ( $arr2.where | Get-Member -MemberType NoteProperty ).Name )
$sqliteUpdateFields = $updateSetColNames + $updateWhereColNames

$sqliteUpdateFields | ForEach {
    
    $columnName = $_

    $sqliteParameterObject = $sqliteUpdateCommand.CreateParameter()
    $sqliteParameterObject.ParameterName = ":$( $columnName )"
    [void]$sqliteUpdateCommand.Parameters.Add($sqliteParameterObject)

}


#-----------------------------------------------
# PREPARE UPDATE STATEMENT
#-----------------------------------------------

$setColumns = [System.Collections.ArrayList]@()
$whereColumns = [System.Collections.ArrayList]@()
$updateSetColNames | ForEach {
    $colName = $_
    $colParam = $sqliteUpdateCommand.Parameters[":$( $colName )"]
    [void]$setColumns.Add("""$( $colName )"" = $( $colParam.ParameterName )")
}
$updateWhereColNames | ForEach {
    $colName = $_
    $colParam = $sqliteUpdateCommand.Parameters[":$( $colName )"]
    [void]$whereColumns.Add("""$( $colName )"" = $( $colParam.ParameterName )")
}

$sqliteUpdateCommand.CommandText = "UPDATE ""$( $tablename )"" SET $( $setColumns -join ', ' ) WHERE $( $whereColumns -join ' AND ' )"


#-----------------------------------------------
# LOGGING STATEMENTS
#-----------------------------------------------

Write-Log -message "Using insert command '$( $sqliteInsertCommand.CommandText )'"
Write-Log -message "Using update command '$( $sqliteUpdateCommand.CommandText )'"


################################################
#
# FUNCTIONS
#
################################################

function Insert-Data {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][System.Collections.ArrayList] $data
        #,[Parameter(Mandatory=$true)][System.Collections.ArrayList] $data

    )
    
    begin {
        
        # Build references to sqlite objects
        #$sqliteConnection = $event.MessageData.conn
        #$sqliteInsertCommand = $event.MessageData.insert
        Write-Host "Inserting $( $data.count ) records"
        Write-Host -Object ( $data | ConvertTo-Json -Depth 99 -Compress )
        #$colNames = $event.MessageData.columns

    }
    
    process {
        
        #-----------------------------------------------
        # INSERT DATA WITH TRANSACTION
        #-----------------------------------------------
            
        # Start transaction
        $sqliteTransaction = $sqliteConnection.BeginTransaction()

        # Insert data
        $inserts = 0
        $t = Measure-Command {

            try {

                # Insert the data
                $data | ForEach {
                    $row = $_
                    $colNames | ForEach {
                        $colName = $_
                        Write-Host ":$( $colName )"
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

    }
    
    end {
            
        #-----------------------------------------------
        # LOG
        #-----------------------------------------------

        Write-Log -message "Inserted $( $inserts ) rows in $( $t.TotalSeconds ) seconds and will commit now"
        #$totalSeconds += $t.TotalSeconds

        # return
        $true

    }
}


function Update-Data {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][System.Collections.ArrayList] $data
        #,[Parameter(Mandatory=$true)][System.Collections.ArrayList] $data

    )
    
    begin {
        
        # Build references to sqlite objects
        #$sqliteConnection = $event.MessageData.conn
        #$sqliteInsertCommand = $event.MessageData.insert
        #$colNames = $event.MessageData.columns
        Write-Host "Updating $( $data.count ) records"
        #Write-Host $sqliteUpdateFields
    }
    
    process {
        
        #-----------------------------------------------
        # UPDATE DATA WITH TRANSACTION
        #-----------------------------------------------
            
        # Start transaction
        $sqliteTransaction = $sqliteConnection.BeginTransaction()
        # Insert data
        $updates = 0
        $t = Measure-Command {

            try {

                # Insert the data
                $data | ForEach {
                    $row = $_
                    $sqliteUpdateFields | ForEach {
                        $colName = $_
                        Write-Host ":$( $colName )"
                        $sqliteUpdateCommand.Parameters[":$( $colName )"].Value = $row.$colName
                    }
                    Write-Host "Prepared command"
                    $updates += $sqliteUpdateCommand.ExecuteNonQuery()
                    $sqliteUpdateCommand.Reset()
                }

            } catch {

                throw $_

            } finally {

                # Commit the transaction
                $sqliteTransaction.Commit()

            }

        }

    }
    
    end {
            
        #-----------------------------------------------
        # LOG
        #-----------------------------------------------

        Write-Log -message "Updated $( $updates ) rows in $( $t.TotalSeconds ) seconds and will commit now"
        #$totalSeconds += $t.TotalSeconds

        # return
        $true

    }
}



################################################
#
# SETUP FILEWATCHER TRIGGER OBJECT
#
################################################

$watcher = [System.IO.FileSystemWatcher]::new() 
$watcher.Path = $settings.watcher.folderToWatch
$watcher.IncludeSubdirectories = $settings.watcher.watchSubDirs
$watcher.EnableRaisingEvents = $true
$watcher.Filter = $settings.watcher.filter
$watcher.NotifyFilter = $settings.watcher.notifyFilter


################################################
#
# CREATE EVENT FOR TRIGGER
#
################################################
<#
# Data for this event
$messageData = [PSCustomObject]@{
    "conn" = $sqliteConnection
    "insert" = $sqliteInsertCommand
    "columns" = $colNames
}
#>

# Script to take place
$action = {
    
    #-----------------------------------------------
    # LOG INCOMING EVENT AND WAIT UNTIL FILE IS FINISHED
    #-----------------------------------------------

    # This is the triggered event and the file
    $e = $event
    $filePath = $e.SourceEventArgs.FullPath
    
    # Write a message to the console and log it in the logfile
    ( $e.TimeGenerated,$e.SourceEventArgs.ChangeType,$e.SourceEventArgs.FullPath ) -join ", " | Write-Host
    Write-Log -message "Event '$( $e.SourceEventArgs.ChangeType )' on '$( $e.TimeGenerated )' to copy from '$( $filePath )'"

    # Wait for file writing to the end
    Wait-Action -Condition { Is-FileLocked -file $filePath -inverseReturn } -Timeout $settings.waitForExportFinishedTimeout -RetryInterval 1 #-ArgumentList @{"file" = $filePath}

    # Log
    Write-Log -message "File not locked anymore and ready to copy"


    #-----------------------------------------------
    # CHECK, FILTER, TRANSFORM AND INSERT DATA
    #-----------------------------------------------

    $eventData = Get-Content -Path $filePath -Encoding utf8 -Raw | ConvertFrom-Json -Depth 99

    Switch ( $eventData.event."evt-tp" ) {

        "mo_message_received" {

            Write-Log "Event relevant"

            # Create object to import
            $eventValues = $eventData.event."fld-val-list"
            $obj = [PSCustomObject]@{
                "from"       = $eventValues.from_address
                "body"       = $eventValues.message_body           
                "to"         = $eventValues.to_address
                "senderid"   = $eventValues.sender_id_id
                "timestamp"  = $eventData.event.timestamp
                "eventid"    = $eventData."event-id"
            }

            # Insert data into database
            $locArr = [System.Collections.ArrayList]@(
                $obj
            )
            Write-Host -Object ( $locArr | ConvertTo-Json -Depth 99 -Compress )
            Insert-Data -data $locArr

            # Trigger response attribution - could also be an external program and run async
            Write-Log -message "Checking text"
            Switch -wildcard ( $obj.body ) {

                # {$_ -is [String]}
                "Hello*" {
                    Write-Log -message "Hello"

                    $upd = [PSCustomObject]@{
                        "eventid"    = $obj.eventid
                        "response_text" = "Hi"
                        "response_media" = ""
                    }

                    Break # Continue|Break
                }

                default {
                    Write-Log -message "Default"

                    $upd = [PSCustomObject]@{
                        "eventid"    = $obj.eventid
                        "response_text" = "Sorry, don't understand"
                        "response_media" = ""
                    }
                }

            }

            # Update the entry
            Write-Log -message "Response '$( $upd | ConvertTo-Json -Depth 99 -Compress )'"
            $locArr2 = [System.Collections.ArrayList]@(
                $upd
            )
            Update-Data -data $locArr2

            # send responses back to user - could also be an external program and run async
            $updatedData = sqlite-Load-Data -sqlCommand "Select * from ""$( $tablename )"" where eventid = '$( $obj.eventid )'" -connection $sqliteConnection
            #Write-Host ( $updatedData | ConvertTo-Json -Compress )
            $responseText = $updatedData.response_text
            $responseMedia = $updatedData.response_media
            Write-Log "Sending back text '$( $responseText )' and media '$( $responseMedia )'"

        }

        Default {
            Write-Log "Event not relevant"
        }

    }
    
    # Trigger another script as an example
    #.\powershell.exe -file "D:\ttt.ps1" -fileToUpload $e.SourceEventArgs.FullPath -scriptPath "D:\Scripts\Upload\"
    
}

# This defines what happens when the event "Created" happens.
$ev = Register-ObjectEvent $watcher -EventName "Created" -Action $action #-MessageData $messageData
$ev | ft

# Keep this process running otherwise the filewatcher will be removed because it is connected to the running thread
# When debugging this in PowerShell ISE the watcher and the events are staying as long as ISE is open
# so then this part is not needed in that case
# On linux I realised all things are queued up and the things happen only when I execute a command, so this wait-command with only a few milliseconds is fine, too.
while ($true){
  Start-Sleep -Milliseconds 10
}


################################################
#
# CLOSE CONNECTION
#
################################################


# Close the connection if it is not in-memory
# if ( $settings.sqliteDb -like "*:memory:*"  ) { 
#     Write-Log -message "Closing connection to cache"
     $sqliteConnection.Dispose()
# } else {
#     Write-Log -message "Keeping the database open"
# }
