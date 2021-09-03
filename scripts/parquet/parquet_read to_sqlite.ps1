################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

$params = [hashtable]@{
    "scriptPath" = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\parquet"
}

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
    }
}


################################################
#
# NOTES
#
################################################

<#


# Example is based on: https://github.com/G-Research/ParquetSharp/blob/master/csharp.test/TestParquetFileReader.cs

TODO [ ] Add more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "PARQUETLOAD"
$processId = [guid]::NewGuid()

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{
    "logfile" = "$( $scriptPath )\parquet.log"
    "sqliteDll" =  "C:\Program Files\Apteco\FastStats Designer\sqlite-netFx46-binary-x64-2015-1.0.113.0\System.Data.SQLite.dll"
    "sqliteDb" = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\parquet\example.db" #"C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\parquet\$( $processId ).sqlite"
}

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

#-----------------------------------------------
# LOAD ALL POWERSHELL CODE
#-----------------------------------------------

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# LOAD MORE LIBS (DLL,EXE)
#-----------------------------------------------
<#
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}
#>


#-----------------------------------------------
# LOAD PARQUET DLLs
#-----------------------------------------------

<#
!!!
IT IS IMPORTANT TO PUT THE PARQUETSHARP.DLL AND PARQUETSHARPNATIVE.DLL INTO ONE FOLDER AND LOAD THE FIRST ONE
!!!
#>

Get-ChildItem -Path ".\bin" -Filter "*.dll" | where { @("ParquetSharpNative.dll") -notcontains $_.Name } | ForEach {

    $f = $_
    Add-Type -Path $f.FullName -Verbose

}


#-----------------------------------------------
# DATATYPE MAPPING BETWEEN PARQUET -> SQLITE
#-----------------------------------------------

Function Parquet-MapDataType {

    param (
        [Parameter(Mandatory=$true)][string]$logicaltype, 
        [Parameter(Mandatory=$true)][string]$physicaltype
        )    

    $datatype = ""
    Switch ( $logicaltype ) {
        "String" {
            $datatype = "TEXT"
        }
        "None" {
            Switch ( $physicaltype ) {
                "Int96" {
                    $datatype = "TEXT"
                }
                "Int32" {
                    $datatype = "INTEGER"
                }
                "Double" {
                    $datatype = "NUMERIC"
                }
                Default {
                    $datatype = "TEXT"
                }
            }
        }
        Default {
            $datatype = "TEXT"
        }
    }
    # return
    $datatype
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param )= ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# MORE CHECKS
#-----------------------------------------------

<#
# Possibly some checks for the future to make sure we are in Windows and having a 64bit shell
# Check the current OS
[System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
# Check if 64 bit
[Environment]::Is64BitProcess
#>
[System.Environment]::SetEnvironmentVariable("SQLITEDB",$settings.sqliteDb)

################################################
#
# PREPARE DATABASE
#
################################################

#-----------------------------------------------
# PREPARE CONNECTION
#-----------------------------------------------

# Journal Mode = MEMORY can cause data loss as everything is written into memory instead of the disk
# Page size is 4096 as default
# Cache size is -2000 as default
$additionalParameters = "Journal Mode=MEMORY;Cache Size=-4000;Page Size=4096;"

Write-Log -message "Loading cache assembly from '$( $settings.sqliteDll )'"

sqlite-Load-Assemblies -dllFile $settings.sqliteDll

Write-Log -message "Establishing connection to cache database '$( $settings.sqliteDB )'"

$retries = 10
$retrycount = 0
$secondsDelay = 2
$completed = $false

while (-not $completed) {
    try {
        #$sqliteConnection = sqlite-Open-Connection -sqliteFile ":memory:" -new
        $sqliteConnection = sqlite-Open-Connection -sqliteFile "$( $settings.sqliteDB )" -new -additionalParameters $additionalParameters
        Write-Log -message "Connection succeeded."
        $completed = $true
    } catch [System.Management.Automation.MethodInvocationException] {
        if ($retrycount -ge $retries) {
            Write-Log -message "Connection failed the maximum number of $( $retries ) times." -severity ([LogSeverity]::ERROR)
            throw $_
            exit 0
        } else {
            Write-Log -message "Connection failed $( $retrycount ) times. Retrying in $( $secondsDelay ) seconds." -severity ([LogSeverity]::WARNING)
            Start-Sleep -Seconds $secondsDelay
            $retrycount++
        }
    }
}


# Setting some pragmas for the connection
$sqlitePragmaCommand = $sqliteConnection.CreateCommand()

# With an unplanned event this can cause data loss, but in this case the database is not persistent, so good to go
# Good explanation here: https://stackoverflow.com/questions/1711631/improve-insert-per-second-performance-of-sqlite
$sqlitePragmaCommand.CommandText = "PRAGMA synchronous = OFF"
[void]$sqlitePragmaCommand.ExecuteNonQuery()
Write-Log -message "Setting the pragma '$( $sqlitePragmaCommand.CommandText )'"


################################################
#
# READ PARQUET
#
################################################

#-----------------------------------------------
# INSTANTIATE PARQUET READER
#-----------------------------------------------

#$reader = [ParquetSharp.ParquetFileReader]::new("C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\parquet\example.parquet")
$reader = [ParquetSharp.ParquetFileReader]::new("C:\Users\Florian\Downloads\area1.parquet")


#-----------------------------------------------
# READ AND PARSE PARQUET METADATA
#-----------------------------------------------

$meta = $reader.FileMetaData
$meta

# Find out the schemas with index and name which delivers more information than $reader.FileMetaData.Schema
$schemas = [System.Collections.ArrayList]@()
For ( $g = 0 ; $g -lt $meta.NumRowGroups ; $g++ ) {

    "Reading metadata for numrowgroup $( $g )"

    $schemaMeta = $reader.RowGroup($g).MetaData | select @{name="Index";expression={ $g  }}, @{name="Name";expression={ $_.schema.name }}, *
    [void]$schemas.add( $schemaMeta )

}

# Choose a schema
$chosenSchema = $schemas #| Out-GridView -PassThru


#-----------------------------------------------
# LOOP THROUGH PARQUET DATA
#-----------------------------------------------

"Reading $( $chosenSchema.Count ) schemas now"

# Go through the schema items aka. row groups
$chosenSchema | ForEach {

    # Get current schema
    $schemaMeta = $_
    "Reading $( $schemaMeta.Name )"
    $rowGroupReader = $reader.RowGroup($schemaMeta.Index)

    # Prepare reading the data in batches
    $rowsCount = $rowGroupReader.MetaData.NumRows
    $batchSize = 200000
    $batches = [math]::Ceiling($rowsCount / $batchSize)
    $colMeta = [System.Collections.ArrayList]@()
    $colNames = [System.Collections.ArrayList]@()
    $colMemory = [Hashtable]@{}
    $sqliteCreateFields = [System.Collections.ArrayList]@()
    $sqliteInsertCommand = $sqliteConnection.CreateCommand()


    #-----------------------------------------------
    # PREPARE POINTERS AND DATABASE
    #-----------------------------------------------

    # Only saves column names and pointers collection in the first batch
    For ( $c = 0 ; $c -lt $meta.NumColumns ; $c++ ) { # ++$c or $c++ ? #$meta.NumColumns

        $columnReader = $rowGroupReader.Column( $c )
        $columnDescriptor = $columnReader.ColumnDescriptor
        [void]$colMeta.Add( $columnDescriptor )
        $columnName = $columnDescriptor.Name
        "Column $( $c ) - $( $columnName )"
        
        [void]$colNames.Add( $columnName )
        #$colMemory | Add-Member -MemberType NoteProperty -Name $c -Value $columnReader.LogicalReader()
        $colMemory.Add( $c, $columnReader.LogicalReader() ) # Remember the current pointers for later continuation

        #Write-Log -message "Creating table for inxmail data, if it does not exist"

        # Create database input parameters for INSERT statement
        $sqliteParameterObject = $sqliteInsertCommand.CreateParameter()
        $sqliteParameterObject.ParameterName = ":$( $columnName )"
        [void]$sqliteInsertCommand.Parameters.Add($sqliteParameterObject)
        #$sqliteParams.Add( $c, $sqliteParameterObject )

        # Build create statement
        $sqliteDataType = Parquet-MapDataType -logicaltype $columnDescriptor.LogicalType -physicaltype $columnDescriptor.PhysicalType
        [void]$sqliteCreateFields.Add( """$( $columnName )"" $( $sqliteDataType )" )


    }
    
    # Create temporary table in database
    $sqliteCommand = $sqliteConnection.CreateCommand()
    $sqliteCommand.CommandText = @"
    CREATE TABLE IF NOT EXISTS "$( $schemaMeta.Name )" (
        $( $sqliteCreateFields -join ",`n" )
    );
"@

    [void]$sqliteCommand.ExecuteNonQuery()

    # Prepare the INSERT statement
    $sqliteInsertCommand.CommandText = "INSERT INTO ""$( $schemaMeta.Name )"" (""$( $colNames -join '" ,"' )"") VALUES ($( $sqliteInsertCommand.Parameters.ParameterName -join ', ' ))"


    #Write-Log -message "Preparing for inserting data"


    #-----------------------------------------------
    # GO THROUGH IN BATCHES
    #-----------------------------------------------

    $totalSeconds = 0
    For ( $i = 0 ; $i -lt $batches ; $i++ ) { # batches

        # Create database transaction
        $sqliteTransaction = $sqliteConnection.BeginTransaction()

        # In the last batch call with the exact number of remaining rows
        # If this is also the first call, put the current iterator to 1 (otherwise modulus will divide by zero)
        if ( $i -eq $batches - 1 ) {
            if ($i -eq 0 ) {
                $j = 1
            } else {
                $j = $i
            }
            $batchSize = $rowsCount % ( $j * $batchSize)
        }

        $colValues = [System.Collections.ArrayList]@()

        #-----------------------------------------------
        # GO THROUGH COLUMNS AND HOLD IN-MEMORY
        #-----------------------------------------------

        $t = Measure-Command {
            For ( $c = 0 ; $c -lt $meta.NumColumns ; $c++ ) { # ++$c or $c++ ? #$meta.NumColumns

                # Temporary storage for values
                $v = [System.Collections.ArrayList]@()

                # Read the data in batches
                # Call always the next n rows   
                [void]$v.AddRange( $colMemory[$c].ReadAll($batchSize) )
                [void]$colValues.Add($v)

            }
        }

        Write-Log -message "Read the batch of $( $batchSize ) rows and $( $meta.NumColumns ) columns in $( $t.TotalSeconds ) seconds"

                
        #-----------------------------------------------
        # INSERT DATA AND COMMIT
        #-----------------------------------------------

        #Write-Log -message "Inserting $( $batchSize ) rows"

        # Inserting the data with 1m records and 2 columns took 77 seconds
        $t = Measure-Command {

            try {

                # Insert the data
                For ( $y = 0 ; $y -lt $batchSize ; $y++ ) {                
                    For ( $x = 0 ; $x -lt $meta.NumColumns ; $x++ ) {
                        $sqliteInsertCommand.Parameters[$x].Value = $colValues[$x][$y]
                    }
                    [void]$sqliteInsertCommand.ExecuteNonQuery()
                    $sqliteInsertCommand.Reset()
                }

            } catch {

                throw $_

            } finally {


                # Commit the transaction
                $sqliteTransaction.Commit()

            }

        }

        Write-Log -message "Inserted $( $batchSize ) rows in $( $t.TotalSeconds ) seconds and will commit now"
        $totalSeconds += $t.TotalSeconds

    }

    # Read the data
    $count = sqlite-Load-Data -sqlCommand "Select count(*) as c from $( $schemaMeta.Name )" -connection $sqliteConnection
    Write-Log -message "Written the data in $( $totalSeconds ) seconds, inserted '$( $count.c )' rows"

}

<#
Important note: https://github.com/G-Research/ParquetSharp/issues/72
#>


<#
Next step
Read e.g. 10k rows for all columns and then do next round and skip x rows
#>


################################################
#
# WRAP UP
#
################################################

#-----------------------------------------------
# DISPOSE PARQUET CONNECTION
#-----------------------------------------------

$reader.Dispose()


#-----------------------------------------------
# CHECK RESULT
#-----------------------------------------------


# Close the connection if it is not in-memory
if ( $settings.sqliteDb -like "*:memory:*"  ) { 
    Write-Log -message "Closing connection to cache"
    $sqliteConnection.Dispose()
} else {
    Write-Log -message "Keeping the database open"
}
