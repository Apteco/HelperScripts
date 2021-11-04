
#-----------------------------------------------
# REST AUTHENTICATION
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}
$contentType = "application/json; charset=utf-8"
