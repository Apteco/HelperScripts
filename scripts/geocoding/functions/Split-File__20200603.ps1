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
    if ( $outputPath -ne "") {
        $checkPath = Check-Path -Path $outputPath
        # only use that output path if it exists, otherwise use the current directory
        if ( $checkPath ) {
            $currentPath = Get-Location
            Set-Location -Path $outputPath
        }
    }
    $exportId = [guid]::NewGuid()
    $exportFolder = New-Item -Name $exportId -ItemType "directory" # create folder for export
    $exportFilePrefix = "$( $exportFolder.FullName )\$( $input.Name )"
    $append = $true
    $outputEncoding = [System.Text.Encoding]::UTF8.CodePage

    # add extension to file prefix dependent on number of export files
    if ( $writeCount -ne -1 ) {
        $exportFilePrefix = "$( $exportFilePrefix ).part"
    }

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

            $chunks = @()
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
                    $chunks += ,( @($headerRow) + @($currentLines[$start..$end]) )
                } else {
                    $chunks += ,@($currentLines[$start..$end])
                }
                
            }

            # log
            Write-Log -message "chunks $( $chunks.Count )"
            for($i = 0; $i -lt $chunks.Count ; $i++) {
                Write-Log -message "chunk $( $i ) size: $( $chunks[$i].Count - [int]$header )" # subtract one line if a header is included
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

                # read input, convert to output
                $inputlines =  $chunk | ConvertFrom-Csv -Delimiter $inputDelimiter
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

            $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $throttleLimit)
            $RunspacePool.Open()
            $Jobs = @()

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
                
                $arguments = @{            
                    chunk = $chunk
                    header = $headerChunk
                    inputDelimiter = $inputDelimiter
                    outputDelimiter = $outputDelimiter
                    outputColumns = $outputColumns
                    outputDoubleQuotes = $outputDoubleQuotes
                }
                
                $Job = [powershell]::Create().AddScript($scriptBlock).AddArgument($arguments)
                $Job.RunspacePool = $RunspacePool
                $Jobs += New-Object PSObject -Property @{
                    RunNum = $_
                    Pipe = $Job
                    Result = $Job.BeginInvoke()
                }
                
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
            $rows = @()
            ForEach ($Job in $Jobs) {
                $res = $Job.Pipe.EndInvoke($Job.Result)
                
                # put header always in first place ( could be in another position regarding parallelisation )
                if ( $res.header ) {
                    $headerRowParsed = $res.lines
                    #$rows = $rows + $res.lines  
                } else {
                    $rows += $res.lines  
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

    $reader.Close()

    # switch back to current path
    if ( $outputPath -ne "") {
        Set-Location -Path $currentPath
    }

    return $exportId.Guid

}