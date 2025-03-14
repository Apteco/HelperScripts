# Load settings
#$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"
<#
try {
    $settings = ( Get-Content -Path $settingsFilename -ReadCount 0 -Encoding UTF8 -Raw ) | ConvertFrom-Json #-Depth 99
} catch {
    Write-Host "Something is wrong with the settings file: '$( $_.Exception.Message )'"
    Write-Host "-----------------------------------------------"
    Exit 1
}
Write-Host "Found $( $settings.count ) join operations in the settings"
#>




# TODO [ ] encrypt the global db parameter
# TODO [ ] activate the clear log functionality
$settings = [PSCustomObject]@{
    logfile = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\MongoDB\mdb.log"
}


#-----------------------------------------------
# ADD SOME SETTINGS
#-----------------------------------------------

# TODO [ ] put those later in the settings creation script
# $settings | Add-Member -MemberType NoteProperty -Name "fergeExe" -Value "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"
# $settings | Add-Member -MemberType NoteProperty -Name "fergeConfig" -Value "D:\Apteco\scripts\response_gathering\espconfig.xml"
# $settings | Add-Member -MemberType NoteProperty -Name "detailsSubfolder" -Value ".\detail_log"
