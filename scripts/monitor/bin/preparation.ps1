

#-----------------------------------------------
# LOAD LAST SESSION
#-----------------------------------------------

$sessionFile = $settings.sessionFile

# Load last session
If ( Test-Path -Path $sessionFile ) {
    $lastSession = Get-Content -Path $sessionFile -Encoding UTF8 -Raw | ConvertFrom-Json
}

# Do some time calculations straight away
If ( $lastSession -ne $null ) {
    $lastSessionTime = Get-DateTimeFromUnixtime -unixtime $lastSession.lastSession -convertToLocalTimezone
    $timespanSinceMidnight = New-TimeSpan -Start ( [datetime]::Today ) -End $timestamp
    $timespanSinceLastSession = New-TimeSpan -Start $lastSessionTime -end $timestamp    
}
