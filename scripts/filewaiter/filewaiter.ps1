
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

$debug = $false

if ($debug) {
    # Unregister all events
    Get-EventSubscriber -Force | Unregister-Event -Force
}


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
$modulename = "wait-for-files"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# TODO  [ ] unify settings in json file
$settings = @{
    
    watcher = @{
        folderToWatch = "D:\Apteco\Build\system\Data\OrbitAPI"
        watchSubDirs = $true
        filter = "fileprefix-*.csv"
        notifyFilter = @(
            [System.IO.NotifyFilters]::FileName
            [System.IO.NotifyFilters]::Size
            #[System.IO.NotifyFilters]::LastWrite
        )
    }

    # Wait for input files if they are getting written at the moment
    waitForExportFinishedTimeout = 120
    
    #exportDir = "D:\Apteco\Build\GV\Data\OrbitAPI"
    logfile = "$( $scriptPath )\file_waiter.log"
    
    # Timer
    timerTimeout = 180 # seconds until the event gets triggered, a new file resets the timer
    interval = 1 # check and refresh the script every n seconds

    # Script to trigger when timerTimeout is reached
    csvToSqliteScript = "D:\Scripts\Watcher\do_something_else.ps1"
    buildDesign = "D:\Apteco\Build\system\Design\design.xml"


}


# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
    #$settings.sqliteDb = "$( $settings.sqliteDb ).debug"
}

# https://www.powershell.amsterdam/2015/11/09/using-local-functions-on-remote-computers/
# Functions to load for scriptblocks (because scriptblock does not know about the functions; out of scope)
$functions = @('Write-Log','Retry-Command','Wait-Action')


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

# Concatenate all functions to load for scriptblocks
$functionString = Get-FunctionString -Function $functions


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
# SETUP TIMER EVENT
#
################################################

#-----------------------------------------------
# CREATE TIMER OBJECT
#-----------------------------------------------

$timer = New-Object -Type Timers.Timer
$timer.Interval  = ( $settings.interval * 1000 ) # milliseconds, the interval defines how often the event gets fired
$Global:timerStartTime = Get-Date # needs to be global so the events can change it
$timerTimeout = $settings.timerTimeout # seconds to timeout


#-----------------------------------------------
# CREATE TIMER EVENT
#-----------------------------------------------

# Register an event for every passed interval
Register-ObjectEvent -InputObject $timer  -EventName "Elapsed" -SourceIdentifier "Timer.Elapsed" -MessageData @{ timeout=$timerTimeout ;settings=$settings;functions=$functionString;logfile=$logfile;process=$processId} -Action {
    
    # Input variables and objects    
    $currentStart = $Global:timerStartTime
    $timeout = $Event.MessageData.timeout
    $timer = $Sender

    # Calculate current timespan
    $timeSpan = New-TimeSpan -Start $currentStart -End ( Get-Date )

    # Is timeout reached? Do something!
    if ( $timeSpan.TotalSeconds -gt $timeout ) {
        
        # Load functions for logging and more only when needed        
        $scriptblock = [System.Management.Automation.ScriptBlock]::Create($Event.MessageData.functions)
        . $scriptblock
        $processId = $Event.MessageData.process
        $logfile = $Event.MessageData.logfile
        $settings = $Event.MessageData.settings

        # Log
        Write-Host "Timeout reached!"
        Write-Log -message "Timeout reached! Starting to do something..."
        Write-Host "Current dir: $( ( Get-Location ).Path )"

        # Stop timer now (it is important to do this before the next processes run)
        $timer.Stop()
        Write-Host "Done! Timer stopped!"
        Write-Log -message "Done! Timer stopped!"

        # Load data into sqlite
        Start-Process powershell -ArgumentList "$( $settings.csvToSqliteScript )" -Wait

        # Build system
        #& DesignerConsole.exe "$( $settings.buildDesign )" /load
        #Start-Process DesignerConsole.exe -ArgumentList "$( $settings.buildDesign ) /load" -Wait

    }
    
    # Output the results to console
    Write-Host -NoNewLine "`r$( $timeSpan.TotalSeconds )/$( $timeout )"

} | Out-Null


################################################
#
# FILEWATCHER EVENT
#
################################################

#-----------------------------------------------
# CREATE FILEWATCHER OBJECT
#-----------------------------------------------

$watcher = New-Object System.IO.FileSystemWatcher 
$watcher.Path = $settings.watcher.folderToWatch
$watcher.IncludeSubdirectories = $settings.watcher.watchSubDirs
$watcher.EnableRaisingEvents = $true
$watcher.Filter = $settings.watcher.filter
$watcher.NotifyFilter = $settings.watcher.notifyFilter


#-----------------------------------------------
# CREATE FILEWATCHER EVENT
#-----------------------------------------------

# This defines what happens when the event "Created" happens.
Register-ObjectEvent -InputObject $watcher -EventName "Created" <#-SourceIdentifier "Timer.Elapsed"#> -MessageData @{timer=$timer;settings=$settings;functions=$functionString;logfile=$logfile;process=$processId} -Action {
    
    # Initiate the script block with custom funtions and needed variables
    $scriptblock = [System.Management.Automation.ScriptBlock]::Create($Event.MessageData.functions)
    . $scriptblock
    $processId = $Event.MessageData.process
    $logfile = $Event.MessageData.logfile
    $settings = $Event.MessageData.settings

    # This is the triggered event
    $e = $event

    # This is the timer send to this event
    $timer = $Event.MessageData.timer

    # This is the changed file
    $filePath = $e.SourceEventArgs.FullPath
    $f = Get-Item -Path $filePath

    # Log event
    ( $e.TimeGenerated,$e.SourceEventArgs.ChangeType,$e.SourceEventArgs.FullPath ) -join ", " | Write-Host
    "Timer state: $( $timer.Enabled )" | Write-Host
    "StartDate: $( $Global:timerStartTime )" | Write-Host
    Write-Log -message "Event '$( $e.SourceEventArgs.ChangeType )' on '$( $e.TimeGenerated )' with file '$( $filePath )'"
    
    # Wait for file writing to the end
    #Wait-Action -Condition { Is-FileLocked -file $filePath -inverseReturn } -Timeout $settings.waitForExportFinishedTimeout -RetryInterval 1 #-ArgumentList @{"file" = $filePath}
    Write-Log -message "File not locked"
    
    # Start timer
    if ( -not ($timer.Enabled )) {
        Write-Log -message "Started the timer"
        $timer.Start()
    }
    Write-Log -message "Reset the Timer"
    $Global:timerStartTime = Get-Date
    
} | Out-Null


################################################
#
# KEEP PROCESS RUNNING
#
################################################


# Keep this process running otherwise the filewatcher will be removed
while ($true){
  Start-Sleep -Seconds $settings.interval
}





