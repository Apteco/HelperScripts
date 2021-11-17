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
                    "inserted"   = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fffzzz")
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

                # Load data from datastore for personalisation
                $mobileNo =  $obj.from -replace "\D+"
                #$datastoreQuery = "Select value from ""datastore"" where key = '$( $mobileNo )'"
                $datastoreQuery = "SELECT value FROM (	SELECT value, RANK() OVER ( PARTITION BY KEY ORDER BY ROWID DESC ) AS rank, rowid FROM ""datastore"" WHERE KEY = '$( $mobileNo )' ) WHERE rank = 1"
                Write-Log -message "Trying to load personalised data from datastore with query '$( $datastoreQuery )'"

                $personalisation = sqlite-Load-Data -sqlCommand $datastoreQuery -connection $datastoreConnection
                #Write-Host "loaded $( $personalisation.value )"
                if ( $personalisation.value.count -gt 0 ) {
                    $ds = ConvertFrom-Json -InputObject $personalisation.value -Depth 99 -AsHashtable
                } else {
                    $ds = [Hashtable]@{}
                }
                Write-Log -message "Loaded following personalisation from datastore: $( $ds | ConvertTo-Json -Depth 99 -Compress )"


                # Load conversation data from cache database
                $conversationQuery = "Select * from ""$( $tablename )"" where eventid != '$( $obj.eventid )' AND ( ""from"" = '$( $obj.from )' OR ""to"" = '$( $mobileNo )' ) order by timestamp desc"
                Write-Log -message "Using the query: $( $conversationQuery )"
                $conversationData = sqlite-Load-Data -sqlCommand $conversationQuery -connection $sqliteConnection
                Write-Log -message "Loaded $( $conversationData.count ) rows"
                If ( $conversationData.count -gt 0 ) {
                    $conversationTags = $conversationData.response_tags -split ";" 
                }

                #Write-Log -message "Loaded following conversation from datastore: $( $conversationData | ConvertTo-Json -Depth 99 -Compress )"

                # Define regular expression for first email address in a text
                $reEmail="[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?"

                # Look for email in personalisation data store
                If ( $ds."Email Address" ) {

                    $email = $ds."Email Address"

                } <#else {

                    # Look for email in the current body
                    $matches = [regex]::Match($obj.body, $reEmail, "IgnoreCase")

                    # Try to find an email address in the conversation - regular expression inspired by stackoverflow
                    if ( $matches.count -eq 0 ) {
                        $conversationData | ForEach {
                            $msg = $_
                            #$msg='<p class=FillText><a name="InternetMail_P3"></a>First.Last@company-name.com</p>florian.von.bracht@apteco.de'
                            $matches = [regex]::Match($msg, $reEmail, "IgnoreCase")
                            $email = $matches.Value
                        }
                    }

                    # Set the email
                    if ( $matches.count -ne 0 ) {
                        $email = $matches.Value
                    } else {
                        $email = $null
                    }

                }#>

                Write-Log -message "Loaded email: $( $email )"

                # Look for language in personalisation data store
                If ( $ds.Language ) {
                    $language = $ds.Language # de|en
                } <#else {

                    # Look for email in the current body
                    $matches = [regex]::Match($obj.body, $reEmail, "IgnoreCase")
                    Switch -wildcard ( $obj.body ) {
                        { $_ -like "*german*" } {
                            $language = "de"
                        }
                        default {

                        }
                    }

                    # Try to find an email address in the conversation - regular expression inspired by stackoverflow
                    if ( $matches.count -eq 0 ) {
                        $conversationData | ForEach {
                            $msg = $_
                            #$msg='<p class=FillText><a name="InternetMail_P3"></a>First.Last@company-name.com</p>florian.von.bracht@apteco.de'
                            $matches = [regex]::Match($msg, $reEmail, "IgnoreCase")
                            $email = $matches.Value
                        }
                    }

                    # Set the email
                    if ( $matches.count -ne 0 ) {
                        $email = $matches.Value
                    } else {
                        $email = $null
                    }

                }#>

                Write-Log -message "Loaded language: $( $language )"
                
                # Trigger response attribution - could also be an external program and run async
                Write-Log -message "Checking email as identifier"

                $responseTextArr = [System.Collections.ArrayList]@()
                $responseMediaArr = [System.Collections.ArrayList]@()
                $responseTags = [System.Collections.ArrayList]@()

                # Add a question if we don't know the email yet
                # TODO [ ] Also look for email in personalisation store
                <#
                if ( $email -eq $null ) {
                    #[void]$responseTextArr.Add("Would you like to tell us your email?")
                    #[void]$responseTags.Add("AskEmail")
                } else {
                    If ( $conversationData.count -eq 0 ) {
                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Ich habe die E-Mail '$( $email )' identifiziert. Das passt hoffentlich.`r`n")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("I recognised the email '$( $email )' as an identifier. I hope that is fine.`r`n")  # English as default
                            }
                        }
                        [void]$responseTags.Add("ConfirmEmail")
                    }
                }
                #>

                

                Write-Log -message "Checking body text"

                # Add more text to the conversation
                Switch -wildcard ( $obj.body ) {

                    #---
                    # STARTERS & DEBUG
                    #---

                    # {$_ -is [String]}
                    #"Hello*" {
                    { $_ -like "Hello*" -or $_ -like "Hi*" -or $_ -like "Hallo*"} {
                        #Write-Log -message "Hello"
                        

                        If ( $ds."First Name" ) {
                            Switch ( $language ) {
                                "de" {
                                    $str = "Hi $( $ds."First Name" )"  # German
                                    Break
                                }
                                Default {
                                    $str = "Hi $( $ds."First Name" )"  # English as default
                                }
                            }
                        } else {
                            Switch ( $language ) {
                                "de" {
                                    $str = "Hi"
                                    Break
                                }
                                Default {
                                    $str = "Hi"
                                }
                            }
                        }

                        [void]$responseTextArr.Add($str)
                        $str = ""

                        [void]$responseTags.Add("intro")

                        #Continue # Continue|Break
                    }

                    <#
                    { $_ -like "wassup" } {
                        #Write-Log -message "Hello"

                        [void]$responseTextArr.Add("wassup yooo")
                        [void]$responseMediaArr.Add("https://i.giphy.com/media/ntM5BQShtEwY8/giphy-downsized.gif")

                        #Continue # Continue|Break
                    }
                    #>
                   
                    { $_ -like "joke*" -or $_ -like "scherz*" } {
                        #Write-Log -message "Hello"

                        $joke = Invoke-RestMethod -Uri https://api.icndb.com/jokes/random
                        
                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Hier ist ein Scherz von der internet chuck norris database https://icndb.com:`r`n`r`n$( [System.Web.HttpUtility]::HtmlDecode($joke.value.joke) )")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Here is a joke of the internet chuck norris database https://icndb.com:`r`n`r`n$( [System.Web.HttpUtility]::HtmlDecode($joke.value.joke) )")  # English as default
                            }
                        }
                        #[void]$responseMediaArr.Add("https://images.unsplash.com/photo-1519333566728-dded96ad28a2?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640;https://images.unsplash.com/photo-1542356670-0366c7cd7ebc?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640")
                        [void]$responseTags.Add("joke")
                        #Continue # Continue|Break
                    }

                    { $_ -like "Pics*" -or $_ -like "Pictures*" -or $_ -like "Bilder*" -or $_ -like "Fotos*" } {
                        #Write-Log -message "Hello"

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Schau dir das an")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Look at this")  # English as default
                            }
                        }
                        [void]$responseMediaArr.Add("https://images.unsplash.com/photo-1519333566728-dded96ad28a2?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640;https://images.unsplash.com/photo-1542356670-0366c7cd7ebc?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640")
                        [void]$responseTags.Add("Debug")
                        #Continue # Continue|Break
                    }

                    "*name*" {
                        #Write-Log -message "Hello"

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Mein Name ist Dorie")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("My name is Dory")  # English as default
                            }
                        }
                        [void]$responseTags.Add("name")
                        #Continue # Continue|Break
                    }

                    { $_ -like "stop" -or $_ -like "unsubscribe" } {
                        #Write-Log -message "Hello"

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Danke für dein Anliegen. Wir melden dich jetzt von unserer Whatsapp-Kommunikation ab.")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Thanks for your request. We are unsubscribing you now at our WhatsApp communication.")  # English as default
                            }
                        }
                        [void]$responseTags.Add("stop")
                        Break
                    }

                    { $_ -like "*slides*" -or $_ -like "*folien*" } {
                        #Write-Log -message "Hello"

                        $slidesLink = "https://www.apteco.de/sites/default/files/2021-11/Apteco%20Live%20Online%202021%20-%20WABA%20Breakout%20Session_0.pdf"

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Danke für das Interesse. Hier sind die Folien: $( $slidesLink )")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Thanks for your request. Here are the slides: $( $slidesLink )")  # English as default
                            }
                        }
                        [void]$responseTags.Add("slides")
                        #Continue # Continue|Break
                    }


                    #---
                    # ANSWERS
                    #---

                    { $_ -like "*yes*" -or $_ -like "*ja*" } {
                        #Write-Log -message "Hello"

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Danke. Schau dir mal dieses Angebot an: https://mpages.cm.syniverse.eu/c/7mgm78")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Thanks. Look at this offer: https://mpages.cm.syniverse.eu/c/7mgm78")  # English as default
                            }
                        }
                        #[void]$responseMediaArr.Add("https://images.unsplash.com/photo-1519333566728-dded96ad28a2?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640;https://images.unsplash.com/photo-1542356670-0366c7cd7ebc?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=640")
                        [void]$responseTags.Add("wallet")
                        #Continue # Continue|Break
                    }


                    #---
                    # QUESTIONS
                    #---

                    { ( $_ -like "*hotel*" -and $_ -like "*offer*" ) -or ( $_ -like "*hotel*" -and $_ -like "*angebot*" ) } {

                        # https://cdn.contentful.com/spaces/0z8yac9o7usr/environments/master/assets/VwlXZXsHKK5QiPV15S5pS?access_token=919f154c8d255590d14c60f4f3e9183657baa41945566530f06621f619082fc0
                        # https://images.ctfassets.net/0z8yac9o7usr/VwlXZXsHKK5QiPV15S5pS/15c24626f01796dd6e3b7eb518604e0f/Accommodationresized800.png

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Wie wärs mit diesem Angebot? Besteht Interesse an einem Gutschein für deinen Ausflug? Dann anworte bitte mit: ja")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("How about that offer? Are you interested in receiving a discount voucher for your break away? Then please answer with: yes")  # English as default
                            }
                        }

                        [void]$responseMediaArr.Add("https://images.ctfassets.net/0z8yac9o7usr/VwlXZXsHKK5QiPV15S5pS/15c24626f01796dd6e3b7eb518604e0f/Accommodationresized800.png?fm=jpg&w=800&fit=fill&f=center")
                        [void]$responseTags.Add("OfferQuestion")

                        Break #Continue # Continue|Break
                    }

                    { ( $_ -like "*insurance*" -and $_ -like "*offer*" ) -or ( $_ -like "*versicherung*" -and $_ -like "*angebot*" ) } {

                        # https://cdn.contentful.com/spaces/0z8yac9o7usr/environments/master/assets/3TeCxV9OgsylAxaSDqXwnb?access_token=919f154c8d255590d14c60f4f3e9183657baa41945566530f06621f619082fc0
                        # https://images.ctfassets.net/0z8yac9o7usr/3TeCxV9OgsylAxaSDqXwnb/cc41dbbefd1637933f3fb20619f37a4a/travel_insurance_resized800.png

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Wie wärs mit diesem Angebot? Besteht Interesse an einem Gutschein für deinen Ausflug? Dann anworte bitte mit: ja")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("How about that offer? Are you interested in receiving a discount voucher for your break away? Then please answer with: yes")  # English as default
                            }
                        }
                        [void]$responseMediaArr.Add("https://images.ctfassets.net/0z8yac9o7usr/3TeCxV9OgsylAxaSDqXwnb/cc41dbbefd1637933f3fb20619f37a4a/travel_insurance_resized800.png?fm=jpg&w=800&fit=fill&f=center")
                        [void]$responseTags.Add("OfferQuestion")

                        Break #Continue # Continue|Break
                    }

                    { ( $_ -like "*activity*" -and $_ -like "*offer*" ) -or ( $_ -like "*aktiv*" -and $_ -like "*angebot*" ) } {

                        # https://cdn.contentful.com/spaces/0z8yac9o7usr/environments/master/assets/1xX6532qSEiaFEtVlQjkUe?access_token=919f154c8d255590d14c60f4f3e9183657baa41945566530f06621f619082fc0
                        # https://images.ctfassets.net/0z8yac9o7usr/1xX6532qSEiaFEtVlQjkUe/1e51af12fb95cfb6099eeaddb56c442b/Adventureresized800.png

                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Wie wärs mit diesem Angebot? Besteht Interesse an einem Gutschein für deinen Ausflug? Dann anworte bitte mit: ja")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("How about that offer? Are you interested in receiving a discount voucher for your break away? Then please answer with: yes")  # English as default
                            }
                        }
                        [void]$responseMediaArr.Add("https://images.ctfassets.net/0z8yac9o7usr/1xX6532qSEiaFEtVlQjkUe/1e51af12fb95cfb6099eeaddb56c442b/Adventureresized800.png?fm=jpg&w=800&fit=fill&f=center")
                        [void]$responseTags.Add("OfferQuestion")

                        Break #Continue # Continue|Break
                    }
                    
                    #---
                    # DEFAULT
                    #---

                    default {
                        #Write-Log -message "Default"


                        Switch ( $language ) {
                            "de" {
                                [void]$responseTextArr.Add("Sorry, ich verstehe es nicht. Bitte nochmal... Um Angebote zu erhalten, tippe folgende Stichwörter ein:`r`nhotel angebote`r`nversicherung angebote`r`naktiv angebote")  # German
                                Break
                            }
                            Default {
                                [void]$responseTextArr.Add("Sorry, don't understand. Please go again... If you want to receive offers, just type in one of these options:`r`nhotel offer`r`ninsurance offer`r`nactivity offer")  # English as default
                            }
                        }
                        [void]$responseTags.Add("NotUnderstand")
                        
                    }

                }

                # Message to send
                $upd = [PSCustomObject]@{
                    "eventid"    = $obj.eventid
                    "response_text" = $responseTextArr -join "`r`n"
                    "response_media" = $responseMediaArr -join ";"
                    "response_tags" = $responseTags -join ";"
                    "response_calculated" = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fffzzz")
                }

                # replace links with track function to create personalised shortened urls
                $regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"
                $responseTextLinks = [Regex]::Matches($upd.response_text, $regexForLinks) | Select -ExpandProperty Value
                $responseTextLinks | ForEach {
                    $textLink = $_
                    # the #track function in syniverse automatically creates a trackable short link in the SMS
                    $upd.response_text = $upd.response_text -replace [regex]::Escape($textLink), "#track(""$( $textLink )"")"
                }

                # Update the entry
                Write-Log -message "Response '$( $upd | ConvertTo-Json -Depth 99 -Compress )'"
                $locArr2 = [System.Collections.ArrayList]@(
                    $upd
                )
                Write-Host $sqliteUpdateCommand | gm
                Update-Data -command $sqliteUpdateCommand -data $locArr2


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

                # TODO [ ] stop communication if response tags contains "stop"

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

                    # Write to log
                    Write-Log -message "Whatsapp result: $( $res | ConvertTo-Json -Depth 99 -Compress )"

                    # Update the entry
                    $locArr3 = [System.Collections.ArrayList]@(
                        [PSCustomObject]@{
                            "eventid"    = $obj.eventid
                            "syniverse_response_id"    = $res.id
                            "syniverse_response_timestamp" = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fffzzz")
                        }
                    )
                    Update-Data -command $sqliteUpdateCommandTwo -data $locArr3


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