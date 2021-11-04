
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

$script:moduleName = "SYNIVERSE-WHATSAPP"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}


################################################
#
# PROGRAM
#
################################################


try {


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
                throw $_.exception
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

    # load $action part
    . "./bin/action_script.ps1"

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



} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

} finally {

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


}