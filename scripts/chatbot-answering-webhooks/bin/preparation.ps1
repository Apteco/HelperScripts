
#-----------------------------------------------
# REST AUTHENTICATION
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}
$contentType = "application/json; charset=utf-8"


#-----------------------------------------------
# LOADING SQLITE ASSEMBLIES
#-----------------------------------------------

Write-Log -message "Loading cache assembly from '$( $settings.sqliteDll )'"

# Make sure the interop dll file is in the same directory
sqlite-Load-Assemblies -dllFile $settings.sqliteDll


#-----------------------------------------------
# DEBUGGING REASONS
#-----------------------------------------------

# Unregister all actions
. "./99__filewatcher__unregister.ps1"

# Removing sqlite database
If ( Test-Path -Path $settings.sqliteDb ) {
	Remove-Item -Path $settings.sqliteDb
}

