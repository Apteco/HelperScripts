# Install nuget packages

Those steps are valid for windows, but should be transferable to linux, too.

Make sure you have installed or downloaded the `nuget.exe` client and put it in your `PATH` environment or in that folder.

Then go into the lib subfolder and install `ParquetSharp` with dependencies like here and then make sure to put all needed files together

```PowerShell
cd .\lib\
.\nuget.exe install ParquetSharp
cd ..
New-Item -Name "bin" -ItemType Directory
Copy-Item -Path ".\lib\System.Buffers.4.5.1\lib\net461\System.Buffers.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\System.Memory.4.5.4\lib\net461\System.Memory.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\System.Numerics.Vectors.4.5.0\lib\net46\System.Numerics.Vectors.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\System.Runtime.CompilerServices.Unsafe.4.5.3\lib\net461\System.Runtime.CompilerServices.Unsafe.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\System.ValueTuple.4.5.0\lib\net461\System.ValueTuple.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\ParquetSharp.2.4.0\lib\net461\ParquetSharp.dll" -Destination ".\bin"
Copy-Item -Path ".\lib\ParquetSharp.2.4.0\runtimes\win-x64\native\ParquetSharpNative.dll" -Destination ".\bin"
```

It is important to have `ParquetSharp.dll` and `ParquetSharpNative.dll` in the same folder.

# Example usage

Try to use the script, more information to follow

Some example data can be downloaded here: http://www.synthcity.xyz/download.html

Just put it into your `example` subfolder

```PowerShell
New-Item -Name "example" -ItemType Directory
wget -Uri "https://rdr.ucl.ac.uk/s/5cc49e8bcc7497581b30" -OutFile ".\example\example.parquet"
```

Then you are good to go to dive into the both scripts:

* `parquet_read.ps1` allows you to read the data from parquet into memory and renders it in PowerShell Out-GridView per page
* `parquet_read_to_sqlite.ps1` reads the data in batches and puts it into a sqlite database which is a good temporary cache for following processes