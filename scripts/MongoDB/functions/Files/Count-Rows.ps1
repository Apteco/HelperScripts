
<#

Use it like

Count-Rows -Path "C:\Users\Florian\Downloads\Data\People.csv"

#>
Function Count-Rows {

    param(
        [Parameter(Mandatory=$false)][string]$Path
    )

    $c = [long]0
    <#
    Get-Content -Path $Path -ReadCount 1000 | ForEach {
        $c += $_.Count
    }
    #>

    $reader = New-Object System.IO.StreamReader($Path, [System.Text.Encoding]::UTF8)
    #[void]$reader.ReadLine() # Skip first line.

    # Go through all lines
    while ($reader.Peek() -ge 0) {
        [void]$reader.ReadLine()
        $c += 1
    }

    $reader.Close()

    # Return
    return $c

}
