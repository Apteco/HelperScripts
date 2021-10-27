<#
 .SYNOPSIS
  Shows a unix timestamp as a datetime object

 .DESCRIPTION
  Unixtime is always UTC

 .PARAMETER  unixtime
  A unix timestamp as integer

 .PARAMETER  inMilliseconds
  Use this [switch] if the timestamp is in milliseconds

 .PARAMETER  convertToLocalTimezone
  Convert the DateTime into the local timezone, otherwise the return value will be UTC
  
 .NOTES
  Name: Get-DateTimeFromUnixtime.ps1
  Author: Florian von Bracht
  DateCreated: yyyy-mm-dd
  DateUpdated: 2020-06-10
  Site: https://github.com/gitfvb/

 .LINK
  Site: https://github.com/gitfvb/AptecoHelperScripts/blob/master/functions/Time/Get-DateTimeFromUnixtime.ps1

 .EXAMPLE
   # Converts a unix timestamp as integer into a System.DateTime object as UTC
   Get-DateTimeFromUnixtime -unixtime 1591775090

 .EXAMPLE
   # Converts a unix timestamp as integer into a System.DateTime object with the local timezone
   Get-DateTimeFromUnixtime -unixtime 1591775090 -convertToLocalTimezone

 .EXAMPLE
   # Converts a unix timestamp with milliseconds as integer into a System.DateTime object
   Get-DateTimeFromUnixtime -unixtime 1591775146091 -inMilliseconds

 .EXAMPLE
   # Creates a DateTime from a Unixtimestamp and outputs as ISO 8601 format
   ( Get-DateTimeFromUnixtime -unixtime $lastSession.timestamp ).ToString("yyyy-MM-ddTHH:mm:ssK")

#>


Function Get-DateTimeFromUnixtime {
    
    param(
         [Parameter(Mandatory=$true)][uint64] $unixtime
        ,[Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
        ,[Parameter(Mandatory=$false)][switch] $convertToLocalTimezone = $false
    )

    if ( $inMilliseconds ) {
        $divisor = 1000
    } else {
        $divisor = 1
    }

    $timestamp = (Get-Date -Date "1970/01/01").AddSeconds($unixtime/$divisor)
    $timestamp = [System.TimeZoneInfo]::ConvertTimeFromUtc($timestamp,[System.TimeZoneInfo]::Utc) # Load the date with the utc timezone first

    if ( $convertToLocalTimezone ) {
        $timestamp = [System.TimeZoneInfo]::ConvertTimeFromUtc($timestamp,[System.TimeZoneInfo]::Local)
    }

    return $timestamp
    
}