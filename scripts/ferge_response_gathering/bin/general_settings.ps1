
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
if ( $params.ProcessId ) {
    $processId = $params.ProcessId
} else {    
    $processId = [guid]::NewGuid()
}
$timestamp = [datetime]::Now
