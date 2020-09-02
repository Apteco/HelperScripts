
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
$modulename = "gv_filewatcher"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# TODO  [ ] unify settings in json file
$settings = @{
    
    watcher = @{
        folderToWatch = "\\vm75960D2\FastStatsTemporaryFileService"     # The directory to watch
        watchSubDirs = $true                                            # Should subdirectories watched too?
        filter = "GV-*.csv"                                             # Filter for the files in the watched directory
        notifyFilter = @(                                               # Define which attributes of the files should trigger the event
            [System.IO.NotifyFilters]::FileName
            [System.IO.NotifyFilters]::Size
            #[System.IO.NotifyFilters]::LastWrite
        )
    }

    waitForExportFinishedTimeout = 120                                  # If files arrive in the directory, a process is checking if it is still locked due to a still active writing thread 
                                                                        # This parameter defines the max seconds timeout to wait for that process to finish

    exportDir = "D:\Apteco\Build\systemname\Data\OrbitAPI"              # Where should the files copied to
    logfile = "$( $scriptPath )\filewatcher.log"                        # Logfile for this process
        
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
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# SETUP FILEWATCHER TRIGGER OBJECT
#
################################################

$watcher = New-Object System.IO.FileSystemWatcher 
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

# This defines what happens when the event "Created" happens.
Register-ObjectEvent $watcher -EventName "Created" -Action {
    
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

    # Copy file to another place and enforce overwriting (which cannot happen if the OrbitAPI was used to upload because a GUID got appended)
    Copy-Item "$( $e.SourceEventArgs.FullPath )" $settings.exportDir -Force

    # Log
    Write-Log -message "Copied over to '$( $settings.exportDir )'"

    # Remove item if wished (but OrbitAPI supports a garbage collection which removes all files after a certain time)
    #Remove-Item -Path "$( $e.SourceEventArgs.FullPath )"

    # Trigger another script as an example
    #.\powershell.exe -file "D:\ttt.ps1" -fileToUpload $e.SourceEventArgs.FullPath -scriptPath "D:\Scripts\Upload\"
    
}

# Keep this process running otherwise the filewatcher will be removed because it is connected to the running thread
# When debugging this in PowerShell ISE the watcher and the events are staying as long as ISE is open
# so then this part is not needed in that case
while ($true){
  Start-Sleep -Seconds 20
}

################################################
#
# MORE CODE SNIPPETS
#
################################################

# show possible events
#$SupportedEvents = $watcher | Get-Member | where {$_.membertype -eq 'Event' }
#$SupportedEvents


<#
Register-ObjectEvent $watcher -EventName Changed -Action {
    
    # This is the triggered event
    $e = $event
    ( $e.TimeGenerated,$e.SourceEventArgs.ChangeType,$e.SourceEventArgs.FullPath ) -join ", " | Write-Host
    
    powershell.exe -file "D:\Scripts\ttt.ps1" -fileToUpload $e.SourceEventArgs.FullPath -scriptPath "D:\Upload\"

}

#>
