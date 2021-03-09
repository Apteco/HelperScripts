<#

Requires the loaded log function from https://github.com/Apteco/HelperScripts/tree/master/functions/Log

Example for creating an initialsessionstate

    # Reference: https://devblogs.microsoft.com/scripting/powertip-add-custom-function-to-runspace-pool/                
    # and https://docs.microsoft.com/de-de/powershell/scripting/developer/hosting/creating-an-initialsessionstate?view=powershell-7.1
    $iss = [initialsessionstate]::CreateDefault()

    # create a sessionstate function entry
    $definition = Get-Content Function:\Get-StringHash -ErrorAction Stop                
    $sessionStateFunction = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(‘Get-StringHash’, $definition)
    $iss.Commands.Add($sessionStateFunction)

    # create a sessionstate variable entry
    $var1 = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new("extractAddressFields",$settings.extractDefinitions[0].addressFields,"Defines address variables to extract")
    $iss.Variables.Add($var1)

Example of calling this function

    # Arguments for Filesplitting
    $params = @{
        inputPath = $currentExtract.Filename
        inputDelimiter = "`t"
        outputDelimiter = "`t"
        writeCount = 150000
        batchSize = 150000
        chunkSize = 5000
        header = $true
        writeHeader = $true
        outputColumns = $columnsToExtract
        #outputDoubleQuotes = $false
        outputFolder = $settings.processingFolder
        additionalColumns = $additionalColumns

    }

    # Split the file and remember the ID
    Split-File @params


#>

Function Split-File {

    [CmdletBinding()]
    
    param(
         [Parameter(Mandatory=$true)][string]$inputPath                     # file to split
        ,[Parameter(Mandatory=$true)][string]$inputDelimiter                # delimiter for input
        ,[Parameter(Mandatory=$true)][string]$outputDelimiter               # delimiter for output
        ,[Parameter(Mandatory=$false)][int]$writeCount = -1                 # think of -1 for one file or x > 0 for n records per file; NOTE: The writer cannot write more than the batchsize
        ,[Parameter(Mandatory=$false)][int]$batchSize = 200000              # read n records at once
        ,[Parameter(Mandatory=$false)][int]$chunkSize = 5000                # parse n records at once
        ,[Parameter(Mandatory=$false)][int]$throttleLimit = 20              # max nr of threads to work in parallel for parsing
        ,[Parameter(Mandatory=$false)][bool]$header = $true                 # file has a header?
        ,[Parameter(Mandatory=$false)][bool]$writeHeader = $true            # output the header
        ,[Parameter(Mandatory=$false)][string[]]$outputColumns = @()        # columns to output
        ,[Parameter(Mandatory=$false)][switch]$outputDoubleQuotes = $true   # output double quotes -> $true is better performance because it needs to be removed by an regex
        ,[Parameter(Mandatory=$false)][String]$outputFolder = "."           # output root folder 
        ,[Parameter(Mandatory=$false)][System.Collections.ArrayList]$additionalColumns = [System.Collections.ArrayList]@()      # more columns to define via @( @{name="colA";expression={ $_.num + 1 }}, @{name="colB";expression={ 2 + 1 }} )
        ,[Parameter(Mandatory=$false)][initialsessionstate]$initialsessionstate = [initialsessionstate]::CreateDefault()        # allows you to add functions and variables to each runspace pool so they can be shared
    )

    begin {
        
        # TODO [ ] test files without header
        # TODO [ ] put encodings in parameter

        # NOTE: Because the writing is in the same loop as reading a batch, $writecount cannot be larger than $batchsize

        # settings
        $now = [datetime]::Now.ToString("yyyyMMddHHmmss")
        #$tmpFile = "$( $input.FullName ).$( $now ).part"

        # counter initialisation
        $batchCount = 0 #The number of records currently processed for SQL bulk copy
        $recordCount = 0 #The total number of records processed. Could be used for logging purposes.
        $intLineReadCounter = 0 #The number of lines read thus far
        $fileCounter = 0

        # import settings
        $inputEncoding = [System.Text.Encoding]::UTF8.CodePage

        # open file to read
        $input = Get-Item -path $inputPath    
        $reader = New-Object System.IO.StreamReader($input.FullName, [System.Text.Encoding]::GetEncoding($inputEncoding))

        # export settings
        $exportId = [guid]::NewGuid()
        $exportFolder = New-Item -Path $outputFolder -Name $exportId.Guid -ItemType "directory" # create folder for export
        $exportFilePrefix = "$( $exportFolder.FullName )\$( $input.Name )"
        $append = $true
        $outputEncoding = [System.Text.Encoding]::UTF8.CodePage

        # add extension to file prefix dependent on number of export files
        if ( $writeCount -ne -1 ) {
            $exportFilePrefix = "$( $exportFilePrefix ).part"
        }

        # setup output columns
        $additionalColumns | ForEach {
            $addColumn = $_
            $outputColumns += $addColumn.Name
        }
    
    }
    
    process {
        



        # read header if needed
        if ( $header ) {
            $headerRow = $reader.ReadLine()
        }


        # measure how much time is consumed
        #Measure-Command {
            
            # read lines until they are available
            while ($reader.Peek() -ge 0) {
                        
                #--------------------------------------------------------------
                # read n lines
                #--------------------------------------------------------------
                
                # create empty array with max of batchsize
                $currentLines = [string[]]::new($batchSize)

                # read n lines into the empty array
                # until batchsize or max no of records reached
                do 
                {
                    $currentLines[$intLineReadCounter] = $reader.ReadLine()
                    $intLineReadCounter += 1
                    $recordCount += 1
                } until ($intLineReadCounter -eq $batchSize -or $reader.Peek() -eq -1)
                #$intLineReadCounter
                $batchCount += 1

                Write-Log -message "batchcount $( $batchCount )"
                Write-Log -message "recordCount $( $recordCount )"
                Write-Log -message "intLineReadCounter $( $intLineReadCounter )"


                #--------------------------------------------------------------
                # parse lines sequentially
                #--------------------------------------------------------------
                
                <#
                $currentLines | ForEach {
                    $line = $_                                      # Read line
                    #$line = [Regex]::Replace($line,'"', "")         # Remove quotes            
                    $items = $line.Split(";")  

                }
                #>

                #--------------------------------------------------------------
                # define line blocks (chunks) to be  parsed in parallel
                #--------------------------------------------------------------

                $chunks = [System.Collections.ArrayList]@()
                $maxChunks = [Math]::Ceiling($intLineReadCounter/$chunkSize)            
                $end = 0

                Write-Log -message "maxChunks $( $maxChunks )"

                for($i = 0; $i -lt $maxChunks ; $i++) {
                    $start = $i * $chunkSize 
                    $end = $start+$chunkSize-1               
                    if ( $end -gt $intLineReadCounter ) {
                        $end = $intLineReadCounter-1
                    }
                    #"$( $start ) - $( $end )"
                    if ( $header ) {
                        [void]$chunks.Add( @($headerRow) + @($currentLines[$start..$end]) )
                    } else {
                        [void]$chunks.Add( @($currentLines[$start..$end]) )
                    }
                    
                }

                # log
                Write-Log -message "chunks $( $chunks.Count )"
                for($i = 0; $i -lt $chunks.Count ; $i++) {
                    Write-Log -message "chunk $( $i ) size: $( $chunks[$i].Count - [int]$header )"  # subtract one line if a header is included
                }
                #$chunks[0] | Out-File -FilePath "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") ).csv" -Encoding utf8 # write out some chunks to check

                #--------------------------------------------------------------
                # define scriptblock to parse line blocks in parallel
                #--------------------------------------------------------------

                $scriptBlock = {

                    Param (
                        $parameters
                    )

                    $chunk = $parameters.chunk
                    $header = $parameters.header # $true if the chunk is the header
                    $inputDelimiter = $parameters.inputDelimiter
                    $outputDelimiter = $parameters.outputDelimiter
                    $outputCols = $parameters.outputColumns
                    $outputDoubleQuotes = $parameters.outputDoubleQuotes
                    $additionalColumns = $parameters.additionalColumns

                    #Get-Item Function:\ | ForEach { $_.Name } | set-content -path "C:\Apteco\Build\20210308\postextract\$( [guid]::NewGuid() ).csv" -Encoding UTF8 


                    # read input, convert to output
                    $inputlines =  $chunk | ConvertFrom-Csv -Delimiter $inputDelimiter

                    # Enrich additional calculated columns          
                    #$additionalColumns | ConvertTo-Json -Depth 3 | Set-Content -Path "$( [guid]::NewGuid() ).json" -Encoding UTF8
                    $additionalColumns | ForEach {
                        $addCol = $_
                        $inputlines = $inputlines | select *, $addCol
                        #$inputlines | export-csv -Path "$( [guid]::NewGuid() ).csv" -Delimiter "`t" -Encoding UTF8 -NoTypeInformation
                    }
                    
                    # Output rows
                    $outputlines = $inputlines | Select $outputCols | ConvertTo-Csv -Delimiter $outputDelimiter -NoTypeInformation
                    
                    # remove double quotes, tributes to https://stackoverflow.com/questions/24074205/convertto-csv-output-without-quotes
                    if ( $outputDoubleQuotes -eq $false ) {
                        $outputlines = $outputlines | % { $_ -replace  `
                                "\G(?<start>^|$( $outputDelimiter ))((""(?<output>[^,""]*?)""(?=$( $outputDelimiter )|$))|(?<output>"".*?(?<!"")("""")*?""(?=$( $outputDelimiter )|$))|(?<output>))",'${start}${output}'} 
                                # '\G(?<start>^|,)(("(?<output>[^,"]*?)"(?=,|$))|(?<output>".*?(?<!")("")*?"(?=,|$))|(?<output>))','${start}${output}'} 
                    }

                    # result to return

                    if ($header) {
                        $returnLines = $outputlines | Select -SkipLast 1
                    } else {
                        $returnLines = $outputlines | Select -Skip 1
                    }                

                    $res = @{
                        lines = $returnLines
                        header = $header
                    }                
                    return $res

                }
                                

                #--------------------------------------------------------------
                # create and execute runspaces to parse in parallel
                #--------------------------------------------------------------

                Write-Log -message "Prepare runspace pool with throttle of $( $throttleLimit ) threads in parallel"

                # Create the runspacepool and add the session with variables and functions
                $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$throttleLimit,$initialsessionstate,$Host)
                #$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $throttleLimit)
                $RunspacePool.Open()
                $Jobs = [System.Collections.ArrayList]@()

                # insert header "chunk" at first place
                if ( $header -and $batchCount -eq 1 ) { 
                    
                    $headerChunk = ,@($headerRow,$headerRow)
                    $chunks = $headerChunk + $chunks
                    
                }             
                
                Write-Log -message "Starting runspace pool"

                $jobCount = 0
                $chunks | ForEach {
                    
                    $chunk = $_
                    
                    if ( $header -and $batchCount -eq 1 -and $jobCount -eq 0) {
                        $headerChunk = $true
                    } else {
                        $headerChunk = $false
                    }
                    
                    # rebuild additional columns so the expression ids are unique, otherwise it fails when an expression is used in parallel processes
                    $addCols = [System.Collections.ArrayList]@()
                    $additionalColumns | ForEach {
                        $addCol = $_
                        [void]$addCols.Add(@{
                            name = $addCol.name
                            expression = [scriptblock]::Create( $addCol.expression.toString() )
                        })
                    }

                    $arguments = @{            
                        chunk = $chunk
                        header = $headerChunk
                        inputDelimiter = $inputDelimiter
                        outputDelimiter = $outputDelimiter
                        outputColumns = $outputColumns
                        outputDoubleQuotes = $outputDoubleQuotes
                        additionalColumns = $addCols
                    }
                    
                    $Job = [powershell]::Create().AddScript($scriptBlock).AddArgument($arguments)
                    $Job.RunspacePool = $RunspacePool
                    [void]$Jobs.Add([PSCustomObject]@{
                        RunNum = $_
                        Pipe = $Job
                        Result = $Job.BeginInvoke()
                    })
                    
                    $jobcount += 1

                }

                Write-Log -message "Checking for results of $( $jobcount ) jobs"

                # check for results
                Write-Host "Waiting.." -NoNewline
                Do {
                    Write-Host "." -NoNewline
                    Start-Sleep -Milliseconds 500
                } While ( $Jobs.Result.IsCompleted -contains $false)
                Write-Host "All jobs completed!"
                
                # put together results
                $rows = [System.Collections.ArrayList]@()
                ForEach ($Job in $Jobs) {
                    $res = $Job.Pipe.EndInvoke($Job.Result)
                    
                    # put header always in first place ( could be in another position regarding parallelisation )
                    if ( $res.header ) {
                        $headerRowParsed = $res.lines
                        #$rows = $rows + $res.lines  
                    } else {
                        [void]$rows.AddRange($res.lines)  
                    }
                                
                }

                Write-Log -message "Got results back from $( $jobCount )"


                #--------------------------------------------------------------
                # write lines in file
                #--------------------------------------------------------------
                
                
                # open file if it should written in once
                if ( $writeCount -eq -1 ) {
                    Write-Log -message "Open file to write: $( $exportFilePrefix )"
                    $writer = New-Object System.IO.StreamWriter($exportFilePrefix, $append, [System.Text.Encoding]::GetEncoding($outputEncoding))
                    if ($writeHeader) {
                        Write-Log -message "Writing header"
                        $writer.WriteLine($headerRowParsed)
                    }
                }

                Write-Log -message "Writing $( $rows.count ) lines"

                # loop for writing lines
                $exportCount = 0          
                $rows | ForEach {         

                    # close/open streams to write
                    if ( ( $exportCount % $writeCount ) -eq 0 -and $writeCount -gt 0 ) {
                        if ( $null -ne $writer.BaseStream  ) {
                            Write-Log -message "Closing file $( $fileCounter ) after exported $( $exportCount )"
                            $writer.Close() # close file if stream is open
                            $fileCounter += 1
                        }
                        $f = "$( $exportFilePrefix )$( $fileCounter )"
                        Write-Log -message "Open file to write: $( $f )"
                        $writer = New-Object System.IO.StreamWriter($f, $append, [System.Text.Encoding]::GetEncoding($outputEncoding))
                        if ($writeHeader) {
                            Write-Log -message "Writing header"
                            $writer.WriteLine($headerRowParsed)
                        }
                    }

                    # write line
                    $writer.writeline($_)

                    # count the line
                    $exportCount += 1

                }

                # close last file
                Write-Log -message "Closing file $( $fileCounter ) after exported $( $exportCount )"
                $writer.Close()
                $fileCounter += 1


                #--------------------------------------------------------------
                # reset some values for the loop
                #--------------------------------------------------------------

                $intLineReadCounter = 0; #reset for next pass
                $currentLines.Clear()
                


            }
        #}
    }
    
    end {

        $reader.Close()

        # return value
        $exportId.Guid 

    }


}


<#

# Remember the current location and change to the export dir
$currentLocation = Get-Location
Set-Location $exportFolder

$splitJobs = [System.Collections.ArrayList]@()
Get-ChildItem -Path $exportFolder | Select -first 1 | ForEach {

    # Split file in parts
    $t = Measure-Command {
        $fileItem = $_
        $splitParams = @{
            inputPath = $fileItem.FullName
            header = $true
            writeHeader = $true
            inputDelimiter = ";"
            outputDelimiter = "`t"
            #outputColumns = $fields
            writeCount = 500 #$settings.rowsPerUpload # TODO [ ] change this back for productive use
            outputDoubleQuotes = $true
        }
        $exportId = Split-File @splitParams
        $splitJobs.Add($exportId)

    }

    Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"

}

# Set the location back
Set-Location $currentLocation
#>

<#

$params = @{
    inputPath = "C:\temp\produkt_klima_tag.csv"
    inputDelimiter = "`t"
    outputDelimiter = ","
    chunkSize = 20000
    outputDoubleQuotes = $true
    writeCount = 100000
}

Split-File @params

#>