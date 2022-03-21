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


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

#if ( $debug ) {
#    $params = [hashtable]@{
#	    scriptPath= "C:\faststats\scripts\emarsys\response_gathering"
#    }
#}


################################################
#
# NOTES
#
################################################


<#

TODO

- [ ] implement creation of windows scheduled task for gathering responses


NOTE

!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TO CAPTURE ALL LOG ENTRIES RENAME THE INTEGRATIONS FOLDER LIKE "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\xIntegrations"
! OTHERWISE FERGE WILL START A SUBPROCESS WHICH CANNOT BE CAPTURED
!!!!!!!!!!!!!!!!!!!!!!!!!!!


# Return codes

Errorlevel return values :

0 - Success
1 - No configuration specfied
2 - Invalid configuration
3 - Error occurred retrieving responses (database)
4 - Error occurred retrieving responses

#>

$errorDescriptions = [Hashtable]@{
    "0" = "Success"
    "1" = "No configuration specfied"
    "2" = "Invalid configuration"
    "3" = "Error occurred retrieving responses (database)"
    "4" = "Error occurred retrieving responses"
}


################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
#if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
#} else {
#    $scriptPath = "$( $params.scriptPath )" 
#}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

$script:moduleName = "EMARSYS-GET-RESPONSES"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    #. ".\bin\load_networksettings.ps1"

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
    # TRY
    #
    ################################################

    Write-Log -message "Starting to load emarsys responses"

    $outputfile = "$( $settings.detailsSubfolder )\out__$( $timestamp.ToString("yyyyMMddHHmmss") ).txt"
    $errorfile = "$( $settings.detailsSubfolder )\err__$( $timestamp.ToString("yyyyMMddHHmmss") ).txt"
    
    $of = Get-item -path $outputfile 
    $ef = Get-item -path $errorfile

    Write-Log -message "Writing output to '$( $of.FullName )'"
    Write-Log -message "Writing output to '$( $ef.FullName )'"
    
    $t = Measure-Command {

        Set-Location -Path "$( $scriptPath )"
        $processArgs = [Hashtable]@{
            "FilePath" = $ferge
            "ArgumentList" = $gathererConfig
            "Wait" = $true
            "PassThru" = $true
            "NoNewWindow" = $true
            "RedirectStandardOutput" = $of.FullName #  [guid]::NewGuid().toString()
            "RedirectStandardError" = $ef.FullName
            #-windowstyle Hidden
        }
        $process = Start-Process @processArgs

    }

    Write-Log -message "Last exit code: $( $process.ExitCode ) - $( $errorDescriptions.Item([String]$process.ExitCode) )"
    Write-Log -message "Needed $( [int]$t.TotalMinutes ) minutes and $( [int]$t.Seconds ) seconds"

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

    $process.ExitCode

}
