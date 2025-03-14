
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

https://sdcsupport.syniverse.com/hc/en-us/articles/360012065193-Syniverse-WhatsApp-Business-API-Channel-Messaging-Rules
https://sdcdocumentation.syniverse.com/index.php/omni-channel/user-guides/whatsapp-business-api-guide

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

$script:moduleName = "FREETRIAL-TO-HUBSPOT"

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
    

    # load/dotsource the variable $action
    . "./bin/action_script.ps1"

    # This defines what happens when the event "Created" happens.
    $ev = Register-ObjectEvent $watcher -EventName "Created" -Action $action #-MessageData $messageData
    $ev | ft

    # Keep this process running otherwise the filewatcher will be removed because it is connected to the running thread
    # When debugging this in PowerShell ISE the watcher and the events are staying as long as ISE is open
    # so then this part is not needed in that case
    # On linux I realised all things are queued up and the things happen only when I execute a command, so this wait-command with only a few milliseconds is fine, too.
    while ($true){
        Start-Sleep -Milliseconds 500
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



}