
# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug -and -not $configMode) {
    $logfile = "$( $logfile ).debug"
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
