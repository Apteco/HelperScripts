Function Check-Path {

    param(
        [Parameter(Mandatory=$false)][string]$Path
    )

    $b = $false

    try {
        $b = Test-Path -Path $Path
    } catch [System.Exception] {
        #$errText = $_.Exception
        #$errText | Write-Output
        #"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile        
        #$b = $false
    }

    return $b

}