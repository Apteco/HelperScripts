
#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = $settings.contentType
$header = @{
    "Authorization" = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
}
