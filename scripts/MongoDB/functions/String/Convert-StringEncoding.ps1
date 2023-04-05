
<#

Use one of these encodings header names for input and output
Especially for Pwsh7 make sure to use the HeaderName of the encoding like "Windows-1252" instead of "iso-8859-1"
[System.Text.Encoding]::GetEncodings()

# Example calls (will create some strange outputs, depending on your configuration, so better look at example below function):

Convert-StringEncoding -string "žluťoučký kůň úpěl ďábelské ódy" -inputEncoding "Windows-1252" -outputEncoding "utf-8"
Convert-StringEncoding -string "žluťoučký kůň úpěl ďábelské ódy" -inputEncoding ([Console]::OutputEncoding.HeaderName) -outputEncoding ([System.Text.Encoding]::UTF8.HeaderName)

#>

Function Convert-StringEncoding {

    [CmdletBinding()]

    param(
         [Parameter(Mandatory=$true)][String]$string
        ,[Parameter(Mandatory=$true)][String]$inputEncoding
        ,[Parameter(Mandatory=$true)][String]$outputEncoding
    )    

    # Check input encoding, if wrong it throws an exception
    [System.Text.Encoding]::GetEncoding($inputEncoding) | Out-Null

    # Check output encoding, if wrong it throws an exception
    [System.Text.Encoding]::GetEncoding($inputEncoding) | Out-Null

    # Convert the bytes back
    $bytesArr = [System.Text.Encoding]::GetEncoding($inputEncoding).getbytes($string)
    $str = [System.Text.encoding]::GetEncoding($outputEncoding).GetString($bytesArr)

    # Return result
    return $str

}

<#
# representation as bytes from this string: žluťoučký kůň úpěl ďábelské ódy
# [System.Text.encoding]::UTF8.GetBytes("žluťoučký kůň úpěl ďábelské ódy") -join ","
$utf8StringBytesArr = @(197,190,108,117,197,165,111,117,196,141,107,195,189,32,107,197,175,197,136,32,195,186,112,196,155,108,32,196,143,195,161,98,101,108,115,107,195,169,32,195,179,100,121)

# Output of original string
Write-Host "`nThis is the correct encoding representation of the string:`n$( [System.Text.encoding]::UTF8.GetString($utf8StringBytesArr) )"

# Create a wrong encoding representation of the UTF-8 string and output it,  be aware default encoding and console encoding diffes in some powershell environments like Pwsh7
$stringDefaultEncoding = [System.Text.encoding]::GetEncoding(([Console]::OutputEncoding.HeaderName)).GetString($utf8StringBytesArr)
Write-Host "`nThis is the wrong encoding representation of the string:`n$( $stringDefaultEncoding )"

# Convert the string from the default encoding to the original encoding utf8 in this example
$stringCorrectEncoding = Convert-StringEncoding -string $stringDefaultEncoding -inputEncoding ([Console]::OutputEncoding.HeaderName) -outputEncoding ([System.Text.Encoding]::UTF8.HeaderName)
Write-Host "`nThis is the correct encoding representation of the string after reverse conversion:`n$( $stringCorrectEncoding )"
#>


<#

To solve these problems, load the content with Invoke-WebRequest rather than Invoke-RestMethod, and convert the content with the function above

# So instead of
$response = Invoke-RestMethod -Uri "https://www.example.com/api"

# Do this
$response = Invoke-WebRequest -Uri "https://www.example.com/api"

# Convert data to utf8 encoding
$fixedResponse = Convert-StringEncoding -string $response.Content -inputEncoding ([Console]::OutputEncoding.HeaderName) -outputEncoding ([System.Text.Encoding]::UTF8.HeaderName)

# Now parse the json or whatever like
$json = ConvertFrom-Json -InputObject $fixedResponse
$json

#>