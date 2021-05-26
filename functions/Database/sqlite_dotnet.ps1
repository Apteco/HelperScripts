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



<#

# Open up connection
sqlite-Load-Assemblies -dllFile "C:\Program Files\Apteco\FastStats Designer\SQLite\System.Data.SQLite.dll"
$sqliteConnection = sqlite-Open-Connection -sqliteFile ":memory:" -new

# Create temporary table
$sqliteCommand = $sqliteConnection.CreateCommand()
$sqliteCommand.CommandText = @"
CREATE TABLE "Data" (
	"key"	TEXT,
	"value"	TEXT
);
"@
$sqliteCommand.ExecuteNonQuery()

# Prepare data insertion
# https://docs.microsoft.com/de-de/dotnet/standard/data/sqlite/bulk-insert
$sqliteTransaction = $sqliteConnection.BeginTransaction()
$sqliteCommand = $sqliteConnection.CreateCommand()
$sqliteCommand.CommandText = "INSERT INTO data (key, value) VALUES (:key, :value)"

# Prepare data parameters
$sqliteParameterKey = $sqliteCommand.CreateParameter()
$sqliteParameterKey.ParameterName = ":key"
$sqliteCommand.Parameters.Add($sqliteParameterKey)

$sqliteParameterValue = $sqliteCommand.CreateParameter()
$sqliteParameterValue.ParameterName = ":value"
$sqliteCommand.Parameters.Add($sqliteParameterValue)

# Inserting the data with 1m records and 2 columns took 77 seconds
$t = Measure-Command {
    # Insert the data
    For ( $i = 0 ; $i -lt 1000000 ; $i++ ) {
        $sqliteParameterKey.Value = $i
        $sqliteParameterValue.Value = Get-Random
        [void]$sqliteCommand.ExecuteNonQuery()
    }
}

"Inserted the data in $( $t.TotalSeconds ) seconds"

# Commit the transaction
$sqliteTransaction.Commit()

# Read the data
$t = Measure-Command {
    sqlite-Load-Data -sqlCommand "Select count(*) from data" -connection $sqliteConnection | ft
}

"Queried the data in $( $t.TotalSeconds ) seconds"


# Close the connection
$sqliteConnection.Dispose()


  
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
       ,[Parameter(Mandatory=$false)][switch]$readonly = $false     # switch if it should open read only
       ,[Parameter(Mandatory=$false)][switch]$new = $false     # switch if it should open read only
    )

    #Data Source=:memory:;Version=3;New=True;
    $connString = "Data Source=""$( $sqliteFile )"";Version=3;New=$( $new );Read Only=$( $readonly );"

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
    [void]$dataAdapter.fill($data)

    $data.tables.rows

}
