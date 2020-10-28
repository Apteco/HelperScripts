Add-Type -AssemblyName System.Security, System.Text.Encoding

Function Get-StringHash
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

# settings
$csvPath = "C:\input.csv"
$columnToHash = "kundennummer"

# load data
Get-StringHash -inputString "Hello" -hashName "SHA256" -salt "apt456" -uppercase $true
$c = Import-Csv -path $csvPath -Delimiter ";" -Encoding UTF8
$c | select @{name="ID";expression={ ( Get-StringHash -inputString $_.$columnToHash -hashName "SHA256" -salt "apt456" -uppercase $true ) }},* -ExcludeProperty $columnToHash | export-csv -Path "$( $csvPath ).2" -NoTypeInformation -Encoding UTF8 -Delimiter "`t"