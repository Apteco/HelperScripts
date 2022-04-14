

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

#-----------------------------------------------
# MAIL STYLE
#-----------------------------------------------

$mailStyle = @'
<style>
    BODY{}
    TABLE{border-width: 0.5px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}
    TH{border-width: 0.5px;padding: 5px;border-style: solid;border-color: lightgrey;}
    TD{border-width: 0.5px;padding: 5px;border-style: solid;border-color: lightgrey;}
</style>
'@

# BODY{background-color:lightgrey;}