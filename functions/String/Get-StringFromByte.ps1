
# transform bytes into hexadecimal string (e.g. for hash values)
function getStringFromByte($byteArray) {

    $stringBuilder = ""
    $byteArray | ForEach { $stringBuilder += $_.ToString("x2") }
    return $stringBuilder

}