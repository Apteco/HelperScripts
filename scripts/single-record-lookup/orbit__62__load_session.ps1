
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
Set-Location -Path $scriptPath


################################################
#
# PREPARATION AND SESSION CREATION
#
################################################

. ".\orbit__60__preparation_for_examples.ps1"


################################################
#
# GET SESSION DETAILS
#
################################################

if ( $settings.encryptToken ) {
    $sessionId = Get-SecureToPlaintext -String $Script:sessionId
} else {
    $sessionId = $Script:sessionId
}
$sessionDetails = Invoke-Apteco -key "GetSessionDetails" -additional @{sessionId=$sessionId}
$sessionDetails.user

Write-Log -message "Got session details for user '$( $sessionDetails.user.username )'"


