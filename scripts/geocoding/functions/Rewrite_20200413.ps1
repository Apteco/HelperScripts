


# this is a really fast way to rewrite a file
function rewriteFileAsStream() {

    param(
        [Parameter(Mandatory=$true)][string]$inputPath,
        [Parameter(Mandatory=$true)][int]$inputEncoding,
        [Parameter(Mandatory=$true)][string]$outputPath,
        [Parameter(Mandatory=$true)][int]$outputEncoding,
        [Parameter(Mandatory=$false)][int]$skipFirstLines

    )

    $input = Get-Item -Path $inputPath

    $reader = New-Object System.IO.StreamReader($input.FullName, [System.Text.Encoding]::GetEncoding($inputEncoding))
    
    $tmpFile = "$( $input.FullName ).$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).tmp"
    $append = $false # the true means to "append", false means replace
    $writer = New-Object System.IO.StreamWriter($tmpFile, $append, [System.Text.Encoding]::GetEncoding($outputEncoding)) 

    for ($i = 0; $i -lt $skipFirstLines; $i++) {
        $reader.ReadLine() > $null # Skip first line.
    }

    while ($reader.Peek() -ge 0) {
        $writer.writeline($reader.ReadLine())
    }

    $reader.Close()
    $writer.Close()

    Remove-Item -Path $outputPath -Recurse
    Move-Item -Path $tmpFile -Destination $outputPath

}

# alternative to the function "rewriteFileAsStream" where the .NET classes are maybe not allowed, uses UTF8 here as a standard
function rewriteFileInOnce() {

    param(
        [Parameter(Mandatory=$true)][string]$inputPath,
        [Parameter(Mandatory=$true)][string]$outputPath,
        [Parameter(Mandatory=$false)][int]$skipFirstLines

    )

    $input = Get-Item -Path $inputPath
    $output = Get-Item -Path $outputPath
    $tmpFile = "$( $input.FullName ).$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).tmp"

    # Encoding listed here: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content?view=powershell-5.1
    Get-Content -Path $input.FullName -Encoding UTF8 | Select -Skip $skipFirstLines | Set-Content -Path $tmpFile -Encoding UTF8

    Remove-Item -Path $output.FullName -Recurse
    Move-Item -Path $tmpFile -Destination $output.FullName

}


