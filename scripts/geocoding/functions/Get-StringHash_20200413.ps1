
# this is a way of hashing of the id column

Function Get-StringHash()
{
      param(
        [Parameter(Mandatory=$true)][string]$inputString,
        [Parameter(Mandatory=$true)][string]$hashName,
        [Parameter(Mandatory=$false)][string]$salt,
        [Parameter(Mandatory=$false)][boolean]$uppercase=$false
    )

    $string = $inputString + $salt

    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($hashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($string))|%{
        [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $res = $StringBuilder.ToString()
    
    if ( $uppercase ) {
        $res.ToUpper()
    } else {
        $res
    }


}