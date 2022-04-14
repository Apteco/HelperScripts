
# Log
$logfile = $settings.logfile

# Checking filename
$logfileCheck = Test-Path -LiteralPath $logfile -IsValid
If ( $logfileCheck -eq $true ) {
    Write-Host "Logfile path is valid"
}

# adding timestamp in filename if configured
If ( $settings.appendDateToLogfile -eq $true ) {
    $datetimeSuffix = [datetime]::Today.toString("yyyyMMdd")
    $newlogfilename = "$( [System.IO.Path]::GetFileNameWithoutExtension($logfile) )__$( $datetimeSuffix )$( [System.IO.Path]::GetExtension($logfile) )"
    $logfileDirectory = [System.IO.Path]::GetDirectoryName($logfile)
    $logfile = [System.IO.Path]::Combine($logfileDirectory,$newlogfilename)
}

# append a suffix, if in debug mode
if ( $debug -and -not $configMode) {
    $logfile = [System.IO.Path]::ChangeExtension($logfile,"$( [System.IO.Path]::GetExtension($logfile) ).debug")
    #$logfile = "$( $logfile ).debug"
}

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )" -writeToHostToo $false

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
        Write-Log -message "    $( $param ) = '$( $params[$param] )'" -writeToHostToo $false
    }
}

# Add note in log file, that the file is a converted file
# TODO [ ] Add these notes to other scripts, too
if ( $params.path -match "\.converted$") {
    Write-Log -message "Be aware, that the exports are generated in Codepage 1252 and not UTF8. Please change this in the Channel Editor." -severity ( [LogSeverity]::WARNING )
}
