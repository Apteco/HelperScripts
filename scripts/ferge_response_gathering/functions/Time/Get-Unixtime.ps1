<#
 .SYNOPSIS
  Shows the current time as a unix timestamp

 .DESCRIPTION
  Unixtime is always UTC

 .PARAMETER  inMilliseconds
  Just use this to parameter [switch] if you want the timestamp with milliseconds

 .PARAMETER  timestamp
  Just input a [DateTime] object to calculate another timestamp

 .NOTES
 Name: Get-Unixtime.ps1
 Author: Florian von Bracht
 DateCreated: yyyy-mm-dd
 DateUpdated: 2020-06-10
 Site: https://github.com/gitfvb/

 .LINK
 Site: https://github.com/gitfvb/AptecoHelperScripts/blob/master/functions/Time/Get-Unixtime.ps1

 .EXAMPLE
   # Shows the current unix timestamp
   Get-Unixtime

 .EXAMPLE
   # Shows the current unix timestamp with Millseconds
   Get-Unixtime -inMilliseconds

 .EXAMPLE
   # Shows the unix timestamp from two days ago
   Get-Unixtime -inMilliseconds -timestamp ( Get-Date ).AddDays(-2)

#>

Function Get-Unixtime {
    
    param(
         [Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
        ,[Parameter(Mandatory=$false)][DateTime] $timestamp = ( Get-Date )
    )

    $multiplier = 1

    if ( $inMilliseconds ) {
        $multiplier = 1000
    }

    [uint64]$unixtime = [double]::Parse((Get-Date ($timestamp).ToUniversalTime() -UFormat %s)) * $multiplier

   return $unixtime 

}
