
# Load settings
#$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"

$settings = [Hashtable]@{
    "logfile" = ".\responses.log"
    "fergeExe" = "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"
    "fergeConfig" = "D:\Apteco\scripts\response_gathering\espconfig.xml"
    "detailsSubfolder" = ".\detail_log"
}