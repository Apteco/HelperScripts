
################################################
#
# ZIP HANDLING
#
################################################

<#
source: https://github.com/DzRepo/Powershell/blob/master/gzip.ps1
#>
Function DeGZip-File{
    Param(
        [Parameter(Mandatory=$true)][string]$infile,
        [Parameter(Mandatory=$true)][string]$outfile,
        [Parameter(Mandatory=$false)][bool]$deleteFileAfterUnzip = $false       
        )

    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
        }

    $gzipStream.Close()
    $output.Close()
    $input.Close()

    if ( $deleteFileAfterUnzip ) {
        Remove-Item -Path $infile
    }

}

