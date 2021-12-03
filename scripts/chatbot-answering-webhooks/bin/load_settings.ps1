
# Load settings
$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"

# TODO [ ] put things below to the normal settings creation

# Add some settings
#$settings.addmember ("datastore","$( $scriptPath )/data_lookup.sqlite")

$settings | Add-Member -MemberType NoteProperty -Name "datastore" -Value "$( $scriptPath )/data_lookup.sqlite"