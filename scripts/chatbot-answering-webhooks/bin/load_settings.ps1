
# Load settings
$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"

# TODO [x] put things below to the normal settings creation
#$settings | Add-Member -MemberType NoteProperty -Name "datastore" -Value "$( $scriptPath )/data_lookup.sqlite"