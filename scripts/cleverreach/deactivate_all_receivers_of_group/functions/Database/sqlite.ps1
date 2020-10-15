<#
 .SYNOPSIS
  Reads a sqlite database via sqlite3.exe command line tool

 .DESCRIPTION
  Uses the sqlite3.exe command line interface ( https://sqlite.org/cli.html ) to ask a sqlite database for a query. The advantage is no dependency on a dll file and complicated construction of objects in powershell.
  This script is easy and lightweight and is not recommended to use for big data volumes because it parses the console output.
  Important hint: Line breaks in the cells are read correctly.

 .PARAMETER  query
  The query you want to ask a sqlite database like listing all tables with "SELECT name FROM sqlite_master WHERE type='table'"

 .PARAMETER  sqliteDb
  A path to a sqlite database like "C:\temp\database.sqlite"

 .PARAMETER  sqliteExe
  The path to a sqlite3.exe file like "C:\lib\sqlite-tools-win32-x86-3320200\sqlite3.exe"

 .NOTES
 Name: sqlite.ps1
 Author: Florian von Bracht
 DateCreated: 2020-06-10
 DateUpdated: 2020-06-16
 Site: https://github.com/gitfvb/

 .LINK
 Site: https://github.com/gitfvb/AptecoHelperScripts/blob/master/functions/Database/sqlite.ps1

 .EXAMPLE
   # Shows the current unix timestamp
   Read-Sqlite -query "SELECT name FROM sqlite_master WHERE type='table'" -sqliteDb "C:\temp\database.sqlite" -sqliteExe "C:\lib\sqlite-tools-win32-x86-3320200\sqlite3.exe"

#>

Function Read-Sqlite {

    param(
         [Parameter(Mandatory=$true)][String] $query
        ,[Parameter(Mandatory=$true)][String] $sqliteDb
        ,[Parameter(Mandatory=$true)][String] $sqliteExe
        ,[Parameter(Mandatory=$false)][bool] $convertCsv = $true
    )

    # Settings for format sqlite output
    $separator = "`t"
    $newline = "###"

    # Call an external program first so the console encoding command works in ISE, too. Good explanation here: https://social.technet.microsoft.com/Forums/scriptcenter/en-US/b92b15c8-6854-4d3e-8a35-51b4b56276ba/powershell-ise-vs-consoleoutputencoding?forum=ITCG
    ping | Out-Null

    # Change the console output to UTF8
    $originalConsoleCodePage = [Console]::OutputEncoding.CodePage
    [Console]::OutputEncoding = [text.encoding]::utf8

    # Query the database
    $results = (( ".headers on", $query | & $sqliteExe -separator $separator -newline $newline $sqliteDb.Replace("\", "/") ) -join "`r" ) -replace $newline,"`r`n" 
    
    # Additional step, normally the result is in a table format, but also requesting information is possible, then $convertCsv should be $false
    if ( $convertCsv ) {
        $results = $results | ConvertFrom-Csv -Delimiter $separator 
    }
    
    # Change the console output to the default
    [Console]::OutputEncoding = [text.encoding]::GetEncoding($originalConsoleCodePage)

    # Return the results
    return $results

}






Function ImportCsv-ToSqlite {

    param(
         [Parameter(Mandatory=$true)][String] $sourceCsv
        ,[Parameter(Mandatory=$true)][String] $destinationTable
        ,[Parameter(Mandatory=$true)][String] $sqliteDb
        ,[Parameter(Mandatory=$true)][String] $sqliteExe
        #,[Parameter(Mandatory=$false)][String] $separator = "`t"
    )


    # import into the database
    #    ".mode csv",".separator \t",".import marketing_jobs.csv jobs" | .\sqlite3.exe jobs2.sqlite
    $results = ".mode csv",".separator \t",".import '$( $sourceCsv.Replace("\", "/") )' '$( $destinationTable )'" | & $sqliteExe $sqliteDb.Replace("\", "/")

    # Return the results
    return $results

}
