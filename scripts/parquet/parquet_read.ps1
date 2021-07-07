
# Example is based on: https://github.com/G-Research/ParquetSharp/blob/master/csharp.test/TestParquetFileReader.cs


<#
!!!
IT IS IMPORTANT TO PUT THE PARQUETSHARP.DLL AND PARQUETSHARPNATIVE.DLL INTO ONE FOLDER AND LOAD THE FIRST ONE
!!!
#>

$dlls = Get-ChildItem -Path ".\bin" -Filter "*.dll" | where { @("ParquetSharpNative.dll") -notcontains $_.Name }

$dlls | ForEach {

    $f = $_
    Add-Type -Path $f.FullName -Verbose

}



<#
# Possibly some checks for the future to make sure we are in Windows and having a 64bit shell
# Check the current OS
[System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
# Check if 64 bit
[Environment]::Is64BitProcess
#>

$reader = [ParquetSharp.ParquetFileReader]::new("example\example.parquet")
#$reader = [ParquetSharp.ParquetFileReader]::new("C:\Users\Florian\Downloads\area1.parquet")



# Output meta data like
<#

CreatedBy         : parquet-mr version 1.8.1 (build 4aba4dae7bb0d4edbcf7923ae1339f28fd3f7fcf)
KeyValueMetadata  : {}
NumColumns        : 13
NumRows           : 1000
NumRowGroups      : 1
NumSchemaElements : 14
Schema            : ParquetSharp.SchemaDescriptor
Size              : 1125
Version           : PARQUET_1_0
WriterVersion     : parquet-mr version 1.8.1

#>
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

"Reading $( $chosenSchema.Count ) schemas now"

# Go through the schema items aka. row groups
$chosenSchema | ForEach {

    $schemaMeta = $_
    "Reading $( $schemaMeta.Name )"
    $rowGroupReader = $reader.RowGroup($schemaMeta.Index)

    # Prepare reading the data in batches
    $rowsCount = $rowGroupReader.MetaData.NumRows
    $batchSize = 450
    $batches = [math]::Ceiling($rowsCount / $batchSize)
    $colNames = [System.Collections.ArrayList]@()
    $colMemory = [Hashtable]@{}

    For ( $i = 0 ; $i -lt 4 ; $i++ ) { # batches
        # In the last batch call with the exact number of remaining rows
        if ( $i -eq $batches - 1 ) {
            $batchSize = $rowsCount % ( $i * $batchSize)
        }

        $colValues = [System.Collections.ArrayList]@()


        For ( $c = 0 ; $c -lt $meta.NumColumns ; $c++ ) { # ++$c or $c++ ? #$meta.NumColumns

            $v = [System.Collections.ArrayList]@()

            
            # Return the column description
            <#
            
            ColumnOrder        : Undefined
            LogicalType        : String
            MaxDefinitionLevel : 1
            MaxRepetitionLevel : 0
            Name               : first_name
            Path               : first_name
            SchemaNode         : ParquetSharp.Schema.PrimitiveNode
            PhysicalType       : ByteArray
            SortOrder          : Unsigned
            TypeLength         : 0
            TypePrecision      : 0
            TypeScale          : 0
            
            #>

            # Only saves column names and pointers in the first batch
            If ($i -eq 0) {
                $columnReader = $rowGroupReader.Column( $c )
                $columnDescriptor = $columnReader.ColumnDescriptor
                "Column $( $c ) - $( $columnDescriptor.Name )"
                [void]$colNames.Add( $columnDescriptor.Name )
                #$colMemory | Add-Member -MemberType NoteProperty -Name $c -Value $columnReader.LogicalReader()
                $colMemory.Add( $c, $columnReader.LogicalReader() ) # Remember the current pointers for later continuation
            }

            # Return the metadata of a column chunk
            <#
            
            Compression           : Uncompressed
            CryptoMetadata        :
            Encodings             : {BitPacked, PlainDictionary, Rle}
            FileOffset            : 17317
            IsStatsSet            : False
            NumValues             : 1000
            TotalCompressedSize   : 2988
            TotalUncompressedSize : 2988
            Statistics            :
            Type                  : ByteArray
            
            #>

            # Read the data in batches
            # Call always the next n rows   
            [void]$v.AddRange( $colMemory[$c].ReadAll($batchSize) )
            [void]$colValues.Add($v)

        }

        # Convert to table / or put into database after one batch
        $table = [System.Collections.ArrayList]@()
        For ( $y = 0 ; $y -lt $batchSize ; $y++ ) {
            $row = [PSCustomObject]@{}
            For ( $x = 0 ; $x -lt $meta.NumColumns ; $x++ ) {
                $row | Add-Member -MemberType NoteProperty -Name $colNames[$x] -Value $colValues[$x][$y]
            }
            [void]$table.Add($row)
        }
        $table | Out-GridView

    }

}

<#
Important note: https://github.com/G-Research/ParquetSharp/issues/72
#>


<#
Next step
Read e.g. 10k rows for all columns and then do next round and skip x rows
#>