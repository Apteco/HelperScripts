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

$chosenSchema | ForEach {

    $schemaMeta = $_

    "Reading $( $schemaMeta.Name )"

    $rowGroupReader = $reader.RowGroup($schemaMeta.Index)

    $v = [System.Collections.ArrayList]@()
    For ( $c = 2 ; $c -lt 3 ; $c++ ) { # ++$c or $c++ ? #$meta.NumColumns

        $columnReader = $rowGroupReader.Column($c)
        
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

        $columnDescriptor = $columnReader.ColumnDescriptor

        "Column $( $c ) - $( $columnDescriptor.Name )"

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

        # Prepare reading the data in batches
        $colChunkMetaData = $rowGroupReader.MetaData.GetColumnChunkMetaData($c)
        $rowsCount = $colChunkMetaData.NumValues
        $batchSize = 101
        $batches = [math]::Ceiling($rowsCount / $batchSize)
        #$columnReader.Skip(10000) # skip x rows
        #$columnReader.LogicalReader().BufferLength
        #$columnReader.LogicalReader().LogicalType
        #$columnReader.LogicalReader().HasNext
        $logicalReader = $columnReader.LogicalReader()

        # Read the data in batches
        For ( $i = 0 ; $i -lt $batches ; $i++ ) {
            # In the last batch call with the exact number of remaining rows
            if ( $i -eq $batches - 1 ) {
                $batchSize = $rowsCount % ( $i * $batchSize)
            }
            # Call always the next n rows
            $v.AddRange($logicalReader.ReadAll($batchSize))
        }

        <#
        Do {
            $v.AddRange($logicalReader.ReadAll(100))
            "Hello"
            #$columnReader.LogicalReader().HasNext
        } until ( $logicalReader.HasNext -eq $false )
        #>
    }

}


<#
Next step
Read e.g. 10k rows for all columns and then do next round and skip x rows
#>