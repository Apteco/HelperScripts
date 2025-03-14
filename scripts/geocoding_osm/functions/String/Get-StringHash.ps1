<#

This is a way of hashing strings
Please be aware, that algorithms like HMAC need a key that
The hashing algorithm should be in this class System.Security.Cryptography

# examples

# This results in 872e4e50ce9990d8b041330c47c9ddd11bec6b503ae9386a99da8584e9bb12c4
Get-StringHash -inputString "HelloWorld" -hashName "SHA256"

# This results in b9e217df88dc1bc96c1e69e1b09a798d6efe0ef69cd3511e7f4becd319fe6036
Get-StringHash -inputString "HelloWorld" -hashName "HMACSHA256" -key "GoGoGo"


#>
Function Get-StringHash()

{
    [cmdletbinding()]
    param(
         [Parameter(Mandatory=$true)][String]$inputString
        ,[Parameter(Mandatory=$true)][String]$hashName
        ,[Parameter(Mandatory=$false)][String]$salt = ""
        ,[Parameter(Mandatory=$false)][String]$key = ""
        ,[Parameter(Mandatory=$false)][switch]$uppercase = $false
        ,[Parameter(Mandatory=$false)][switch]$keyIsHex = $false
        ,[Parameter(Mandatory=$false)][switch]$returnBytes = $false
    )

    # Add salt if needed
    $string = $inputString + $salt

    # Choose algorithm
    $alg = [System.Security.Cryptography.HashAlgorithm]::Create($hashName)

    # Change key, e.g. for HMACSHA256
    if ( $key -ne "" ) {
        if ( $keyIsHex ) {
            $alg.key = Convert-HexToByteArray -HexString $key
        } else {
            $alg.key = [Text.Encoding]::UTF8.GetBytes($key)
        }
    }

    $bytes = $alg.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($string))

    # Create bytes from string and hash
    
    if ( $returnBytes -eq $true ) {
        $bytes
    } else {
        $res = Convert-ByteArrayToHex -Bytes $bytes

        # Create hex string from bytes
        #[System.Text.Encoding]::UTF8.GetString($bytes)
        <#
        $StringBuilder = [System.Text.StringBuilder]::new()
        $bytes | ForEach {
            [Void]$StringBuilder.Append($_.ToString("x2"))
        }
        $res = $StringBuilder.ToString()
        #>

        # Transform uppercase, if needed, and return the result
        if ( $uppercase ) {
            $res.ToUpper()
        } else {
            $res
        }
    }

}

# Needed for the things above
# From: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/

Function Convert-ByteArrayToHex {

    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][Byte[]]$Bytes
    )

    $HexString = [System.Text.StringBuilder]::new($Bytes.Length * 2)

    ForEach($byte in $Bytes){
        $HexString.AppendFormat("{0:x2}", $byte) | Out-Null
    }

    $HexString.ToString()
}

Function Convert-HexToByteArray {

    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][String]$HexString
    )

    $Bytes = [byte[]]::new($HexString.Length / 2)

    For($i=0; $i -lt $HexString.Length; $i+=2){
        $Bytes[$i/2] = [convert]::ToByte($HexString.Substring($i, 2), 16)
    }

    $Bytes
}
