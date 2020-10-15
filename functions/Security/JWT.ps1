
<#
based on this example from: https://jwt.io/
https://stackoverflow.com/questions/30246497/using-statement-for-base64urlencode
https://medium.com/@nikitafed9292/net-base64-decoding-workaround-82b797162b6e
https://blog.angular-university.io/angular-jwt/
https://gist.github.com/kucukkanat/1ef77db8120323db2b89087735ef8a5d
#>

################################################
#
# DEBUG
#
################################################


<#
$headers = [ordered]@{
    "alg"="HS512"    
    "typ"="JWT"
}

$payload = [ordered]@{
  "sub" = "1234567890"
  "name" = "John Doe"
  "iat" = 1516239022
}

$secret = "secret" #"GQDstcKsx0NHjPOuXOYg5MbeJ1XT0uFiwDVvVBrk"
#>


################################################
#
# SETTINGS
#
################################################


Add-Type -AssemblyName System.Security


################################################
#
# FUNCTIONS
#
################################################
<#
Function Get-Unixtime {
    
    param(
        [Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
    )

    $multiplier = 1

    if ( $inMilliseconds ) {
        $multiplier = 1000
    }

    [long]$unixtime = [double]::Parse((Get-Date(Get-Date).ToUniversalTime() -UFormat %s)) * $multiplier

   return [int]$unixtime 

}
#>

# inspired by https://gallery.technet.microsoft.com/scriptcenter/Get-StringHash-aa843f71
# needs more methods to implement, if needed
Function Get-HMACSHA512 {
    
    param(
         [Parameter(Mandatory=$true)][String]$data
        ,[Parameter(Mandatory=$true)][String]$key
    )
    
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA512 
    $hmacsha.key = [Text.Encoding]::UTF8.GetBytes($key)
    $bytesToSign = [Text.Encoding]::UTF8.GetBytes($data)
    $sign = $hmacsha.ComputeHash($bytesToSign)

    return $sign

}

Function Get-StringFromByte {
    
    param(
        [Parameter(Mandatory=$true)][byte[]]$byteArray
    )

    $stringBuilder = ""
    $byteArray | ForEach { $stringBuilder += $_.ToString("x2") }
    return $stringBuilder

}

Function Get-Base64UrlEncodeFromString {
    
    param(
         [Parameter(Mandatory=$true)][String]$inputString
    )

    $inputBytes = [Text.Encoding]::UTF8.GetBytes($inputString)
    
    # Special "url-safe" base64 encode.
    $base64 = [System.Convert]::ToBase64String($inputBytes,[Base64FormattingOptions]::None).Replace('+', '-').Replace('/', '_').Replace("=", "")

    return $base64

}

Function Get-StringFromBase64UrlEncode {
    
    param(
         [Parameter(Mandatory=$true)][String]$inputString
    )

    $inputBytes = [System.Convert]::FromBase64String($inputString)

    $string = [System.Text.Encoding]::UTF8.GetString($inputBytes)

    return $string

}

Function Get-Base64UrlEncodeFromByteArray {
    
    param(
         [Parameter(Mandatory=$true)][byte[]]$byteArray
    )
   
    # Special "url-safe" base64 encode.
    $base64 = [System.Convert]::ToBase64String($byteArray,[Base64FormattingOptions]::None).Replace('+', '-').Replace('/', '_').Replace("=", "")

    return $base64

}

Function Get-Base64FromString {
    
    param(
         [Parameter(Mandatory=$true)][String]$inputString
    )

    $inputBytes = [Text.Encoding]::UTF8.GetBytes($inputString)
    
    # Special "url-safe" base64 encode.
    $base64 = [System.Convert]::ToBase64String($inputBytes,[Base64FormattingOptions]::None)

    return $base64

}

Function Get-Base64FromByteArray {
    
    param(
         [Parameter(Mandatory=$true)][byte[]]$byteArray
    )
    
    $base64 = [System.Convert]::ToBase64String($byteArray,[Base64FormattingOptions]::None)

    return $base64

}

# Add missing "=" at the end and check url-safe encodings
Function Check-Base64 {

    param(
         [Parameter(Mandatory=$true)][String]$inputString
    )

    #$input
    $encoded = $inputString.Replace('-','+').Replace('_','/')
    $d = $encoded.Length % 4
    if ( $d -ne 0 ) {
        $encoded  = $encoded.TrimEnd('=')
        if ( $d % 2 -gt 0 ) {
            $encoded += '='
        } else {
            $encoded += '=='
        }
    }
    return $encoded

}

Function Encode-JWT {

    param(
          [Parameter(Mandatory=$true)][PSCustomObject]$headers
         ,[Parameter(Mandatory=$true)][PSCustomObject]$payload
         ,[Parameter(Mandatory=$true)][string]$secret
    )

    $headersJson = $headers | ConvertTo-Json -Compress
    $payloadJson = $payload | ConvertTo-Json -Compress
    $headersEncoded = Get-Base64UrlEncodeFromString -inputString $headersJson #[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($headersJson),[Base64FormattingOptions]::None)
    $payloadEncoded = Get-Base64UrlEncodeFromString -inputString $payloadJson #[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($payloadJson),[Base64FormattingOptions]::None)

    $content = "$( $headersEncoded ).$( $payloadEncoded )"

    $signatureByte = Get-HMACSHA512 -data $content -key $secret
    $signature = Get-Base64UrlEncodeFromByteArray -byteArray $signatureByte

    $jwt = "$( $headersEncoded ).$( $payloadEncoded ).$( $signature )"

    return $jwt

}

<# 

https://jwt.io/

#>
Function Decode-JWT {

    param(
       [Parameter(Mandatory=$true)][string]$token
       ,[Parameter(Mandatory=$false)][string]$secret = ""
       #,[Parameter(Mandatory=$false)][switch]$secretBase64Encoded      # needs to be implemented
    )

    # Splitting the string
    $splittedJwt = $token -split "\."

    # Decoding all parts
    $header = Get-StringFromBase64UrlEncode ( Check-Base64 -inputString $splittedJwt[0] ) | ConvertFrom-Json
    $payload = Get-StringFromBase64UrlEncode ( Check-Base64 -inputString $splittedJwt[1] ) | ConvertFrom-Json
    $signature = $splittedJwt[2]

    # Checking the signature if secret is provided -> not fully tested yet!!!
    $verified = $false
    if ( $secret -ne "" ) {
        $content = "$( Check-Base64 -inputString $splittedJwt[0] ).$( Check-Base64 -inputString $splittedJwt[1] )"
        $signatureByte = Get-HMACSHA512 -data $content -key $secret
        $signatureCheck = Get-Base64UrlEncodeFromByteArray -byteArray $signatureByte
        if ($signature -eq $signatureCheck) {
            $verified = $true
        }
    }

    return @{
        "header" = $header
        "payload" = $payload
        "verified" = $verified
    }

}


################################################
#
# TEST
#
################################################

# creation of jwt
<#
$jwt = Create-JWT -headers $headers -payload $payload -secret $secret

$jwt
#>
