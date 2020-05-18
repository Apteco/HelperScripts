# current unixtimestamp with the optional milliseconds
Function Get-Unixtime {
    
    param(
        [Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
    )

    $multiplier = 1

    if ( $inMilliseconds ) {
        $multiplier = 1000
    }

    [long]$unixtime = [double]::Parse((Get-Date(Get-Date).ToUniversalTime() -UFormat %s)) * $multiplier

   return $unixtime 

}