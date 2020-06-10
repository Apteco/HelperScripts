Function Read-Sqlite {

    param(
         [Parameter(Mandatory=$true)] $query
        ,[Parameter(Mandatory=$true)] $sqliteDb
        ,[Parameter(Mandatory=$true)] $sqliteExe
    )

    $separator = "`t"
    $newline = "###"

    [Console]::OutputEncoding = [text.encoding]::utf8
    $results = (( ".headers on", $query | & $sqliteExe -separator $separator -newline $newline $sqliteDb.Replace("\", "/") ) -join "`r" ) -replace $newline,"`r`n" | ConvertFrom-Csv -Delimiter $separator
    [Console]::OutputEncoding = [text.encoding]::Default

    return $results

}