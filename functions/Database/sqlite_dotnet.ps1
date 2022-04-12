<#

# NOTES

* Information about connection string: https://www.connectionstrings.com/sqlite/

# LINKS

* Inspiration: https://www.pipperr.de/dokuwiki/doku.php?id=windows:powershell_oracle_db_abfragen 
* https://docs.microsoft.com/de-de/dotnet/framework/data/adonet/retrieving-and-modifying-data

# EXAMPLE

sqlite-Load-Assemblies -dllFile "C:\Program Files\Apteco\FastStats Designer\System.Data.SQLite.dll"
sqlite-Load-DataTable -sqlCommand "Select * from households limit 100"

#>

Function sqlite-Load-DataTable {

    param(   
        [Parameter(Mandatory=$true)][String]$sqlFile        # sql file
       ,[Parameter(Mandatory=$true)][String]$sqlCommand     # command
       #,[Parameter(Mandatory=$false)][switch]$readonly = $true     # switch if it should open read only
    )


    #$sqlCommand = "Select * from households limit 100"

    try {

        $conn = sqlite-Open-Connection -sqliteFile ".\test.sqlite" -readonly $true
        $data = sqlite-Load-Data -sqlCommand $sqlCommand -connection $conn
        
        <#
        $conn = New-Object -TypeName System.Data.SQLite.SQLiteConnection
        $conn.ConnectionString = $connString
        $conn.Open()
        

        $cmd = New-Object -TypeName System.Data.SQLite.SQLiteCommand
        $cmd.CommandText = $sqlCommand
        $cmd.Connection = $conn
        


        $dataAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter
        $dataAdapter.SelectCommand = $cmd

        $data = New-Object -TypeName System.Data.DataSet
        $dataAdapter.fill($data)
        $data.tables.rows | Out-GridView
#>
    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile

    } finally {
        
        #$dataAdapter.Dispose()
        #$cmd.Dispose()
        $conn.Dispose()
        
    }

}

# [ ] load dll path through a setting
Function sqlite-Load-Assemblies {

    param(   
        [Parameter(Mandatory=$true)][String]$dllFile
    )

    #$assemblyFile = "C:\Program Files\Apteco\FastStats Designer\System.Data.SQLite.dll" # download precompiled binaries for .net or "System.Data.SQLite"
    [Reflection.Assembly]::LoadFile($dllFile)

}



Function sqlite-Open-Connection {

    param(   
        [Parameter(Mandatory=$true)][String]$sqliteFile
       ,[Parameter(Mandatory=$false)][switch]$readonly = $true     # switch if it should open read only
    )


    $connString = "Data Source=""$( $sqliteFile )"";Version=3;"

    $conn = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $conn.ConnectionString = $connString
    $conn.Open()

    return $conn

}

Function sqlite-Load-Data {

    param(   
        [Parameter(Mandatory=$true)][String]$sqlCommand                               # connection string
       ,[Parameter(Mandatory=$true)][System.Data.SQLite.SQLiteConnection]$connection  # switch if it should open read only
    )

    $cmd = New-Object -TypeName System.Data.SQLite.SQLiteCommand
    $cmd.CommandText = $sqlCommand
    $cmd.Connection = $connection

    $dataAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter
    $dataAdapter.SelectCommand = $cmd

    $data = New-Object -TypeName System.Data.DataSet
    $dataAdapter.fill($data)
    $data.tables.rows

    return $data

}

# TODO [ ] Test this new function

# Source: https://stackoverflow.com/questions/11383775/memory-stream-as-db
# So e.g. you can process data in-memory and then backup an in-memory-database as file
# Make sure both source and connection are already existing
Function sqlite-Backup-Database {

    param(   
        [Parameter(Mandatory=$true)][System.Data.SQLite.SQLiteConnection]$sourceConnection          # 
       ,[Parameter(Mandatory=$true)][System.Data.SQLite.SQLiteConnection]$destinationConnection     # 
       ,[Parameter(Mandatory=$false)][switch]$closeDestinationAfterBackup = $false                  # 
    )

    # Test if the connection is already open
    <#
    If (  ) {

    } else {
        $connection.Open()
    }
    #>

    $sourceConnection.BackupDatabase($destinationConnection, "main", "main",-1, null, 0)

    If ( $closeDestinationAfterBackup ) {
        $destinationConnection.Close()
    }
    
}
