$action = {
        
        #-----------------------------------------------
        # LOG INCOMING EVENT AND WAIT UNTIL FILE IS FINISHED
        #-----------------------------------------------

        # This is the triggered event and the file
        $e = $event
        $filePath = $e.SourceEventArgs.FullPath
        
        # Write a message to the console and log it in the logfile
        ( $e.TimeGenerated,$e.SourceEventArgs.ChangeType,$e.SourceEventArgs.FullPath ) -join ", " | Write-Host
        Write-Log -message "Event '$( $e.SourceEventArgs.ChangeType )' on '$( $e.TimeGenerated )' to copy from '$( $filePath )'"

        # Wait for file writing to the end
        Wait-Action -Condition { Is-FileLocked -file $filePath -inverseReturn } -Timeout $settings.waitForExportFinishedTimeout -RetryInterval 1 #-ArgumentList @{"file" = $filePath}

        # Log
        Write-Log -message "File not locked anymore and ready to copy"


        #-----------------------------------------------
        # CHECK, FILTER, TRANSFORM AND INSERT DATA
        #-----------------------------------------------

        $eventData = Get-Content -Path $filePath -Encoding utf8 -Raw | ConvertFrom-Json -Depth 99

        Switch ( $eventData.event."evt-tp" ) {

            "mo_message_received" {

                Write-Log "Event relevant"

                #-----------------------------------------------
                # PART 1: WRITE TO CACHE DATABASE
                #-----------------------------------------------

                # Create object to import
                $eventValues = $eventData.event."fld-val-list"
                $obj = [PSCustomObject]@{
                    "from"       = $eventValues.from_address
                    "body"       = $eventValues.message_body           
                    "to"         = $eventValues.to_address
                    "senderid"   = $eventValues.sender_id_id
                    "timestamp"  = $eventData.event.timestamp
                    "eventid"    = $eventData."event-id"
                }

                # Insert data into database
                $locArr = [System.Collections.ArrayList]@(
                    $obj
                )
                Write-Host -Object ( $locArr | ConvertTo-Json -Depth 99 -Compress )
                Insert-Data -data $locArr


                #-----------------------------------------------
                # PART 2: GENERATE RESPONSE AND UPDATE CACHE DATABASE
                #-----------------------------------------------

                # Load data from cache database
                #$updatedData = sqlite-Load-Data -sqlCommand "Select * from ""$( $tablename )"" where eventid = '$( $obj.eventid )'" -connection $sqliteConnection

                # Trigger response attribution - could also be an external program and run async
                Write-Log -message "Checking text"
                Switch -wildcard ( $obj.body ) {

                    # {$_ -is [String]}
                    "Hello*" {
                        #Write-Log -message "Hello"

                        $upd = [PSCustomObject]@{
                            "eventid"    = $obj.eventid
                            "response_text" = "Hi"
                            "response_media" = ""
                        }

                        Break # Continue|Break
                    }

                    { $_ -like "Pics*" -or $_ -like "Pictures*" } {
                        #Write-Log -message "Hello"

                        $upd = [PSCustomObject]@{
                            "eventid"    = $obj.eventid
                            "response_text" = "Look at this"
                            "response_media" = "https://images.unsplash.com/photo-1519333566728-dded96ad28a2?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640;https://images.unsplash.com/photo-1542356670-0366c7cd7ebc?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640"
                        }

                        Break # Continue|Break
                    }

                    "*name*" {
                        #Write-Log -message "Hello"

                        $upd = [PSCustomObject]@{
                            "eventid"    = $obj.eventid
                            "response_text" = "Hi, I'm Dory"
                            "response_media" = ""
                        }

                        Break # Continue|Break
                    }

                    default {
                        #Write-Log -message "Default"

                        $upd = [PSCustomObject]@{
                            "eventid"    = $obj.eventid
                            "response_text" = "Sorry, don't understand"
                            "response_media" = ""
                        }
                    }

                }

                # Update the entry
                Write-Log -message "Response '$( $upd | ConvertTo-Json -Depth 99 -Compress )'"
                $locArr2 = [System.Collections.ArrayList]@(
                    $upd
                )
                Update-Data -data $locArr2


                #-----------------------------------------------
                # PART 3: SEND RESPONSE BACK
                #-----------------------------------------------

                # send responses back to user - could also be an external program and run async
                $updatedData = sqlite-Load-Data -sqlCommand "Select * from ""$( $tablename )"" where eventid = '$( $obj.eventid )'" -connection $sqliteConnection
                #Write-Host ( $updatedData | ConvertTo-Json -Compress )
                $responseText = $updatedData.response_text

                # Parse media - should be separated by ;
                If ( $updatedData.response_media -like "?*" ) {
                    $responseMedia = [System.Collections.ArrayList]@( $updatedData.response_media -split ";" )
                } else {
                    $responseMedia = [System.Collections.ArrayList]@()
                }

                # Log message
                Write-Log "Sending back text '$( $responseText )' and media '$( $responseMedia )'"

                # Send with whatapp business api through syniverse
                $paramsPost = [Hashtable]@{
                    Uri = "$( $settings.base )scg-external-api/api/v1/messaging/messages"
                    Method = "Post"
                    Headers = $headers
                    Verbose = $true
                    ContentType = $contentType
                    Body = [PSCustomObject]@{
                        "from" = "$( $settings.sendMethod ):$( $settings.senderId )"
                        "to" = "wa:$( $updatedData.from )" #@447743054533" #@($mobile)
                        "media_urls" = $responseMedia #@(
                            #"https://images.unsplash.com/photo-1519333566728-dded96ad28a2?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640"
                            #"https://images.unsplash.com/photo-1542356670-0366c7cd7ebc?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640"
                        #) # restrictions are listed here: https://sdcsupport.syniverse.com/hc/en-us/articles/360049544374-Sending-a-WhatsApp-Business-API-Message
                        "body"=$responseText #$smsTextTranslations.Item($mobileCountry)
                        #"consent_requirement"="NONE"
                    } | ConvertTo-Json -Depth 99 -Compress
                }                

                # Proxy settings, when needed
                if ( $settings.useDefaultCredentials ) {
                    $paramsPost.Add("UseDefaultCredentials", $true)
                }
                if ( $settings.ProxyUseDefaultCredentials ) {
                    $paramsPost.Add("ProxyUseDefaultCredentials", $true)
                }
                if ( $settings.proxyUrl ) {
                    $paramsPost.Add("Proxy", $settings.proxyUrl)
                }

                #Write-Host $paramsPost
                #Write-Host $paramsPost.body

                # Do API call
                try {
            
                    $res = Invoke-RestMethod @paramsPost
                    #$res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose -ContentType $contentType # -UseDefaultCredentials -ProxyUseDefaultCredentials -Proxy $settings.proxyUrl
            
                    Write-Log -message "Whatsapp result: $( $res | ConvertTo-Json -Depth 99 -Compress )"

                } catch {
            
                    $e = ParseErrorForResponseBody -err $_
                    Write-Log -message $e -severity ([LogSeverity]::ERROR)
                    [void]$errors.add( $e )
            
                }

            }

            Default {
                Write-Log "Event not relevant"
            }

        }
        
        # Trigger another script as an example
        #.\powershell.exe -file "D:\ttt.ps1" -fileToUpload $e.SourceEventArgs.FullPath -scriptPath "D:\Scripts\Upload\"
        
    }