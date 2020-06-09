<#

NOTES

Source: https://github.com/gitfvb/AptecoHelperScripts/blob/master/functions/Time/Get-Unixtime.ps1

#>

# current unixtimestamp with the optional milliseconds
Function Get-Unixtime {
    
    param(
         [Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
        ,[Parameter(Mandatory=$false)][DateTime] $timestamp = ( Get-Date )
    )

    $multiplier = 1

    if ( $inMilliseconds ) {
        $multiplier = 1000
    }

    [long]$unixtime = [double]::Parse((Get-Date ($timestamp).ToUniversalTime() -UFormat %s)) * $multiplier

   return $unixtime 

}