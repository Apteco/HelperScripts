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

<#
Checks if an path is free

Can be used like to wait for a path to be free

$outArgs = @{
    Path = "C:\temp\test.lock"
    fireExceptionIfUsed = $true
}

Retry-Command -Command 'Is-PathFree' -Args $outArgs -retries 10 -MillisecondsDelay 1000


#>
function Is-PathFree {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][string]$Path
        ,[Parameter(Mandatory=$false)][switch]$fireExceptionIfUsed = $false
    )
    
    # Check validity
    if ( ( Test-Path -Path $Path -IsValid ) -eq $false ) {
        throw [System.Management.Automation.ItemNotFoundException]
    }
    
    # Check if path is free
    $pathAlreadyUsed = Test-Path -Path $Path

    # Fire exception if not free
    if ( $fireExceptionIfUsed -and $pathAlreadyUsed) {
        throw [System.IO.InvalidDataException]
    }

    # Return the inverted value
    -not $pathAlreadyUsed
}

Is-PathFree -Path "C:\temp\test.lock" -fireExceptionIfUsed

exit 0

