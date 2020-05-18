
# Check-Path

Example of writing the log

```PowerShell 
Check-Path -Path "logfile.log"
```

# Split-File

```powershell 
Function Split-File {
    
    param(
         [Parameter(Mandatory=$true)][string]$inputPath # file to split
        ,[Parameter(Mandatory=$true)][string]$inputDelimiter # delimiter for input
        ,[Parameter(Mandatory=$true)][string]$outputDelimiter # delimiter for output
        ,[Parameter(Mandatory=$false)][int]$writeCount = -1 # think of -1 for one file or x > 0 for n records per file; NOTE: The writer cannot write more than the batchsize
        ,[Parameter(Mandatory=$false)][int]$batchSize = 200000 # read n records at once
        ,[Parameter(Mandatory=$false)][int]$chunkSize = 5000 # parse n records at once
        ,[Parameter(Mandatory=$false)][int]$throttleLimit = 20 # max nr of threads to work in parallel for parsing
        ,[Parameter(Mandatory=$false)][bool]$header = $true # file has a header?
        ,[Parameter(Mandatory=$false)][bool]$writeHeader = $true # output the header
        ,[Parameter(Mandatory=$false)][string[]]$outputColumns = @() # columns to output
        ,[Parameter(Mandatory=$false)][string[]]$outputDoubleQuotes = $false # output double quotes 
        ,[Parameter(Mandatory=$false)][string]$outputPath = ""
    )
```

