# Example is based on: https://github.com/G-Research/ParquetSharp/blob/master/csharp.test/TestParquetFileReader.cs

#using namespace System.Collections.Generic

<#
!!!
IT IS IMPORTANT TO PUT THE PARQUETSHARP.DLL AND PARQUETSHARPNATIVE.DLL INTO ONE FOLDER AND LOAD THE FIRST ONE
!!!
#>

$dlls = @( Get-ChildItem -Path ".\bin" -Filter "*.dll" | where { @("ParquetSharpNative.dll") -notcontains $_.Name } ).fullname 

$dlls | ForEach {

    #$f = $_
    "Adding '$( $_ )'"
    Add-Type -Path $_ -Verbose

}

<#
https://blog.adamfurmanek.pl/2016/03/19/executing-c-code-using-powershell-script/

$loadLibrary = @'
[DllImport("kernel32", SetLastError=true, CharSet = CharSet.Ansi)]
public static extern IntPtr LoadLibrary([MarshalAs(UnmanagedType.LPStr)]string lpFileName);
'@
$Kernel32 = Add-Type -MemberDefinition $loadLibrary -Name 'Kernel32' -Namespace 'Win32' -PassThru
$Kernel32::LoadLibrary("NativeLibrary.dll") | out-null
#>


$CSharpCode = @"
using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using ParquetSharp;
using ParquetSharp.IO;
using ParquetSharp.RowOriented;


namespace HelloWorld
{
    public class Program
    {
        public static void Main(){
            var helloString1 = "Hello";
            var helloString2 = "World!";
            Console.WriteLine(String.Concat(helloString1, ' ', helloString2));
            var reader = new ParquetFileReader("C:/Users/Florian/Documents/GitHub/AptecoHelperScripts/scripts/parquet/example.parquet");
            var fileMetaData = reader.FileMetaData;
            Console.WriteLine("File meta data:");
            Console.WriteLine("- created by: '{0}'", fileMetaData.CreatedBy);
            Console.WriteLine("- num columns: {0}", fileMetaData.NumColumns);
            Console.WriteLine("- num rows: {0}", fileMetaData.NumRows);
            Console.WriteLine("- num row groups: {0}", fileMetaData.NumRowGroups);
        }

        public static ParquetRowReader<int> MainTwo() {
            var helloString1 = "Hello";
            var helloString2 = "Nice!";
            Console.WriteLine(String.Concat(helloString1, ' ', helloString2));
            var reader = ParquetFile.CreateRowReader<int>("C:/Users/Florian/Documents/GitHub/AptecoHelperScripts/scripts/parquet/example.parquet");
            //Console.WriteLine(reader.ReadRows(0));
            return reader;
        }
    }
}
"@

Add-Type -TypeDefinition $CSharpCode -Language CSharp -ReferencedAssemblies $dlls
$reader = [HelloWorld.Program]::MainTwo()

$reader.ReadRows(0)

exit 0
# using var reader = ParquetFile.CreateRowReader<(String)>("example\example.parquet");


<#
# Possibly some checks for the future to make sure we are in Windows and having a 64bit shell
# Check the current OS
[System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
# Check if 64 bit
[Environment]::Is64BitProcess
#>

$p = [System.Tuple]::Create("first_name","last_name")
$t = [System.Tuple]::Create([String])

$splat = @{TTuple=$p;path="example\example.parquet"}
#$tuple = New-Object "tuple[String,String]" "first_name", "last_name" 
$tuple = [ValueTuple[String, String]]::new("first_name", "last_name")
[ParquetSharp.RowOriented.ParquetFile]::CreateRowReader($tuple, [String]"example\example.parquet")


exit 0


$x = @{ [System.ValueTuple]::Create(1, $false) = 5 }
$x[[System.ValueTuple]::Create(1, $false)]

$test = [Dictionary[[ValueTuple[int, bool]], int]]::new()
[TTuple]
$buffer = [ParquetSharp.IO.ResizableBuffer]::new()
$inputStream = [ParquetSharp.IO.BufferReader]::new($buffer)
$rowReader = [ParquetSharp.RowOriented.ParquetFile]::CreateRowReader($test, "example\example.parquet")

$p = [System.Tuple]::Create("Flintstone","Rubble")
[ParquetSharp.RowOriented.ParquetFile]::CreateRowReader($p,"example\example.parquet")
[ParquetSharp.RowOriented.ParquetFile[ValueTuple[int, bool]]]::CreateRowReader("example\example.parquet")
$t = New-Object -TypeName ParquetSharp.RowOriented.ParquetFile -Property @{TTuple=$p;path="example\example.parquet"}
exit 0
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


[ParquetSharp.RowOriented.ParquetRowReader]::new("example\example.parquet")
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
    $batchSize = 101
    $batches = [math]::Ceiling($rowsCount / $batchSize)
    $colValues = [System.Collections.ArrayList]@()
    $colNames = [System.Collections.ArrayList]@()
    #$colMemory = [Hashtable]@{}

    For ( $i = 0 ; $i -lt 2 ; $i++ ) { # batches
        # In the last batch call with the exact number of remaining rows
        if ( $i -eq $batches - 1 ) {
            $batchSize = $rowsCount % ( $i * $batchSize)
        }


        For ( $c = 0 ; $c -lt $meta.NumColumns ; $c++ ) { # ++$c or $c++ ? #$meta.NumColumns

            $v = [System.Collections.ArrayList]@()

            $columnReader = $rowGroupReader.Column( $c )
            
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

            # Only saves column names and pointers in the first batch
            If ($i -eq 0) {
                [void]$colNames.Add( $columnDescriptor.Name )
                #$colMemory.Add( $c, $rowGroupReader.Column($c).LogicalReader() ) # Remember the current pointers for later continuation
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

            #$colChunkMetaData = $rowGroupReader.MetaData.GetColumnChunkMetaData($c)
            [void]$columnReader.Skip( $i * $batchSize ) # skip x rows
            #$columnReader.LogicalReader().BufferLength
            #$columnReader.LogicalReader().LogicalType
            #$columnReader.LogicalReader().HasNext
            $logicalReader = $columnReader.LogicalReader()

            # Read the data in batches
            # Call always the next n rows            
            #[void]$v.AddRange( $colMemory.$c.ReadAll($batchSize) )
            [void]$v.AddRange($columnReader.LogicalReader().ReadAll($batchSize))
            $logicalReader.ReadBatch()

            <#
            Do {
                $v.AddRange($logicalReader.ReadAll(100))
                "Hello"
                #$columnReader.LogicalReader().HasNext
            } until ( $logicalReader.HasNext -eq $false )
            #>

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
Next step
Read e.g. 10k rows for all columns and then do next round and skip x rows
#>





<#
More notes

$test = [Dictionary[[ValueTuple[int, bool]], int]]::new()
[TTuple]
$buffer = [ParquetSharp.IO.ResizableBuffer]::new()
$inputStream = [ParquetSharp.IO.BufferReader]::new($buffer)
$rowReader = [ParquetSharp.RowOriented.ParquetFile]::CreateRowReader($test, "example\example.parquet")

$p = [System.Tuple]::Create("Flintstone","Rubble")
[ParquetSharp.RowOriented.ParquetFile]::CreateRowReader($p,"example\example.parquet")
[ParquetSharp.RowOriented.ParquetFile[ValueTuple[int, bool]]]::CreateRowReader("example\example.parquet")
$t = New-Object -TypeName ParquetSharp.RowOriented.ParquetFile -Property @{TTuple=$p;path="example\example.parquet"}
exit 0


[ParquetSharp.RowOriented.ParquetRowReader]::new("example\example.parquet")


#>