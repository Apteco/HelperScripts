################################################
#
# INPUT
#
################################################

# TODO [x] allow this script to be called with a path
# NOTE: Calling this script from tasks or other programs, do it like 
#       powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\monitor\mntr__10__monitor.ps1" -params "@{settingsfile='.\settings.json'}"


Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false


################################################
#
# NOTES
#
################################################


<#

TODO

- [x] Check certificate expiration
- [ ] Check orbit api call (also authenticated calls)
- [x] Check current nuget version
- [ ] allow proxy calls (copy from Agnitas Code)

#>



################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
#if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
#} else {
#    $scriptPath = "$( $params.scriptPath )" 
#}
Set-Location -Path $scriptPath


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    #scriptPath= "C:\faststats\scripts\emarsys\response_gathering"
        settingsFile = ".\settings.json"
    }
}

################################################
#
# SETTINGS
#
################################################

$script:moduleName = "APTECO-MONITOR"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    #. ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

    # Load all checks
    . ".\bin\define_checks.ps1"


} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}


################################################
#
# PROGRAM
#
################################################


try {


    ################################################
    #
    # TRY
    #
    ################################################

    Write-Log -message "Starting to execute all checks"

    $warningEntries = [System.Collections.ArrayList]@()
    $systemInformation = [System.Collections.ArrayList]@()


    #-----------------------------------------------
    # CHECK SIZE AND DATE OF SPECIFIC FILES AND FOLDERS
    #-----------------------------------------------

    Write-Log -message "Checking files and folders"

    # TODO [ ] Create enum with specific events that should trigger that warning entry
    # TODO [ ] Implement all of these events
    # TODO [ ] add "actions" if some events are happening
    # TODO [ ] show all messages since last sending, not only from today

    $filesToCheck | ForEach {

        $checkItem = $_

        # Log
        Write-log -message "Checking object '$( $checkItem.Name )' at path '$( $checkItem.Path )'"

        # Check if path is valid
        $validPath = Test-Path -IsValid -Path "$( $checkItem.Path )" -Verbose
        If ( $validPath -eq $true ) {
                        
            Write-log -message "Path is valid"

            $existingPath = Test-Path -Path "$( $checkItem.Path )" -Verbose
            If ( $existingPath -eq $true ) {

                Write-log -message "Path is existing"
                
                # Check type of path
                $item = Get-Item -Path "$( $checkItem.Path )"

                # Go through the defined events
                $checkItem.warningEvents | ForEach {

                    $warningEvent = $_.toString()

                    Write-Log -message "Checking event '$( $warningEvent )'"

                    Invoke-Command -ScriptBlock $eventChecks.Item($warningEvent) -ArgumentList @( $item.FullName )
                    
                }
               
            } else {

                Write-log -message "Path is not existing" -severity ([LogSeverity]::WARNING)
                [void]$warningEntries.Add("$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - NOT EXISTING: Path of object '$( $checkItem.Name )' at path '$( $checkItem.Path )'")
    
            }

        } else {
            
            Write-log -message "Path is not valid" -severity ([LogSeverity]::WARNING)
            [void]$warningEntries.Add("$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - NOT VALID: Path of object '$( $checkItem.Name )' at path '$( $checkItem.Path )'")

        }

    }


    #-----------------------------------------------
    # CHECK FREE SPACE
    #-----------------------------------------------

    # Warning entries

    # Get all local drives that are currently used (used space greater than 0) and format the numbers and output as list
    If ( $settings.checkSpace -eq $true ) {
        
        Get-PSDrive -PSProvider FileSystem | where { $_.Used -gt 0 } | ForEach {

            $psDrive = $_

            # Calculate the amount of space used
            $usedPercentage = $psDrive.Used / ( $psDrive.free + $psDrive.Used )

            # Create a warning
            if ( $usedPercentage -gt $settings.thresholdCritical ) {
                # Create a critical warning
                [void]$warningEntries.Add("$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - CRITICAL: More than $( $checkItem.Name )% used at path '$( $psDrive.Name )'")
            } elseif ( $usedPercentage -gt $settings.thresholdWarning ) {
                [void]$warningEntries.Add("$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - WARNING: More than $( $usedPercentage )% used at path '$( $psDrive.Name )'")
            }
        
            #$psDrive | Select Root, @{name="Used (GB)";expression={ ($_.Used/1GB).ToString(".00") }}, @{name="Free (GB)";expression={ ($_.Free/1GB).ToString(".00") }}  | fl

        }

    }
    
    If ( $settings.attachDriveOverview -eq $true ) {
        #$drivesOverview = Get-PSDrive -PSProvider FileSystem | Format-Table -AutoSize | Out-String
        #[void]$systemInformation.Add( "`n`n$( $drivesOverview )`n`n" )
        $t = Get-PSDrive -PSProvider FileSystem | Select Root, Description, @{name="Used (GB)";expression={ ($_.Used/1GB).ToString(".00") }}, @{name="Free (GB)";expression={ ($_.Free/1GB).ToString(".00") }} | ConvertTo-Html -Fragment -as Table  | Out-String  
        $str = $t.replace("`r","").replace("`n","")
        [void]$systemInformation.add( "`n`n<h2>Drive space</h2>`n$( $str )" ) #| Format-List | Out-String
    }



    # Send mail if threshold is reached
    #If ()

    # Send regular mail that this process is still active
    #If ()


    #-----------------------------------------------
    # CHECK SERVICES
    #-----------------------------------------------

    If ( $settings.checkServicesStatus -eq $true ) {

        $serviceTable = Get-Service | where { $_.Name -like $settings.servicePrefix -or $_.Name -like $settings.orbitServicePrefix } | Select $settings.serviceAttributes
        $services = $serviceTable | ConvertTo-Html -Fragment -as Table | Out-String  #| Format-Table -AutoSize | Out-String  # TODO [ ] add this to the email
        
        $str = $services.replace("`r","").replace("`n","")
        [void]$systemInformation.add( "`n`n<h2>Windows services</h2>`n$( $str )" ) #| Format-List | Out-String

    }

    
    #-----------------------------------------------
    # CHECK WINDOWS UPDATES
    #-----------------------------------------------

    # No good option found yet


    #-----------------------------------------------
    # CHECK HTTPS CERTIFICATE EXPIRATION DATES
    #-----------------------------------------------

    # Since MS does not work with ServicePoints in .NET Core, it is better to use the approach like
    # https://docs.microsoft.com/de-de/dotnet/api/system.net.http.httpclienthandler.servercertificatecustomvalidationcallback?view=net-6.0
    # or
    # https://serverfault.com/questions/984953/net-httpwebrequest-difference-between-powershell-and-powershell-core


    if ( $settings.checkCertificates -eq $true ) {

        $certs = [System.Collections.ArrayList]@()

        $settings.certificateURLsToCheck | ForEach {

            $uri = $_

            $Req = [System.Net.Sockets.TcpClient]::new($uri, '443')
            $Stream = [System.Net.Security.SslStream]::new($Req.GetStream())
            $Stream.AuthenticateAsClient($uri)
            $cert = $Stream.RemoteCertificate | Select @{name="uri";expression={ $uri }}, Thumbprint, Issuer, Subject, @{name="Expiration";expression={$Stream.RemoteCertificate.GetExpirationDateString()}}
            [void]$certs.add( $cert )

            $expiresIn = New-TimeSpan -Start ([datetime]::Now) -end $cert.Expiration
            If ( $expiresIn.TotalDays -le $settings.warningIfCertificateExpiresInNDays ) {
                [void]$warningEntries.Add("$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - CERTIFICATE $( $uri ): Expires in '$( $expiresIn.TotalDays )' days")
            }


        }

        $str = ($certs | ConvertTo-Html -Fragment -as List | Out-String  ).replace("`r","").replace("`n","")
        [void]$systemInformation.add( "`n`n<h2>SSL Certificates</h2>`n$( $str )" ) #| Format-List | Out-String

    }

    #-----------------------------------------------
    # CHECK SOME THINGS IN THE DATABASE(S)
    #-----------------------------------------------

    # TODO [ ] implement this -> see AptecoCustomChannels for MSSQL (native), SQLITE and Postgres (Klicktipp)

    #-----------------------------------------------
    # CHECK ORBIT UPDATER SETTINGS
    #-----------------------------------------------

    If ( $settings.checkOrbitAutomaticUpdate -eq $true ) {

        $orbitUpdaterSettingsRaw = Get-Content -Path $settings.orbitUpdaterConfig -encoding utf8 -Raw
        $orbitUpdaterSettings = [xml]$orbitUpdaterSettingsRaw
    
        $orbitUpdaterList = [PSCustomObject]@{}
        $orbitUpdaterSettings.configuration.appSettings.add | where { $_.key -like "Update*" } | ForEach {
            $orbitUpdaterList | Add-Member -MemberType NoteProperty -Name $_.key -Value $_.value
        }
        
        $str = ($orbitUpdaterList | ConvertTo-Html -Fragment -as List | Out-String ).replace("`r","").replace("`n","")
        [void]$systemInformation.Add( "`n`n<h2>Orbit Updater Settings</h2>`n$( $str )" )

    }


    #-----------------------------------------------
    # CHECK ORBIT VERSIONS AND NUGET
    #-----------------------------------------------

    # via Orbit API, read the json file
    # TODO [x] implement this

    If ( $settings.checkOrbitVersions -eq $true ) {

        # Check API
        $orbitApiVersion = Invoke-RestMethod -Uri "$( $settings.orbitApiUrl )/about/version" -Method Get -ContentType "application/json"
        $orbitApiVersion.version

        # Check UI - The answer contains a BOM and PowerShell does not interprete this right, so we are writing this into a temporary file first and then read it again
        $orbitUIVersionRaw = Invoke-RestMethod -Uri "$( $settings.orbitUiUrl )/en/assets/version.json" -Method Get
        $orbitUIVersionRawEncoded = Convert-StringEncoding -string $orbitUIVersionRaw -inputEncoding ([System.Text.Encoding]::Default.HeaderName) -outputEncoding ([System.Text.Encoding]::UTF8.HeaderName)
        $tmpFile = New-TemporaryFile
        [System.IO.File]::WriteAllLines($tmpFile.FullName, $orbitUIVersionRawEncoded)
        $orbitUIVersion = Get-Content -Path $tmpFile.FullName -Encoding utf8 | ConvertFrom-Json
        Remove-Item -Path $tmpFile.FullName -Force


        # Check NuGet repository
        $nugetVersions = Find-Package -Source $settings.nugetRepository
        
        # Put together
        [void]$systemInformation.Add( "`n`n<h2>Orbit Versions</h2>" )
        [void]$systemInformation.add( "`nOrbitAPI: $( $orbitApiVersion.version )" )
        [void]$systemInformation.add( "OrbitUI: $( $orbitUIVersion.version )" )
        [void]$systemInformation.add( "`nNuget:`n$( $nugetVersions | ForEach { "$( $_.Name ): $( $_.Version )" } | Out-String )`n`n" )

    }

    
    #-----------------------------------------------
    # CHECK OTHER APTECO VERSIONS AND .NET
    #-----------------------------------------------
    # TODO [x] implement this

    If ( $settings.checkDotNet -eq $true ) {

        $netRuntimes = dotnet --info #--list-runtimes

        [void]$systemInformation.add( "`n<h2>.NET runtimes</h2>`n$( $netRuntimes | Out-String )`n" )

    }


    #-----------------------------------------------
    # CHECK MAYBE TOKENS LIKE CLEVERREACH
    #-----------------------------------------------
    # TODO [ ] implement this


    #-----------------------------------------------
    # CHECK THE FASTSTATS DESIGNER BUILD TIME
    #-----------------------------------------------

    # TODO [ ] implement this -> used from an earlier gist
    <#
    $allStats = [System.Collections.ArrayList]@()

    #cd "C:\FastStats\Build\piwik\log"
    $c = Get-Content -Path "C:\FastStats\Build\jobs\log\Build Statistics Log.txt" -Delimiter "`r`n`r`n" -Encoding UTF8

    $c | Select -First 100 | ForEach {

        $stats = New-Object -TypeName PSCustomObject

        $_ -split "`r`n" | ForEach {
            
            $line = $_
            
            $pattern = $logStrings[0]
            Switch -Regex ( $_ ) {
                            
                # Begins with a specific text, then 0..n chars (except tab), then tab, then a string until the end

                '^Build Statistics Report for[^\t]*\t(.*)$' { 
                    $stats | Add-Member -MemberType NoteProperty -Name "SystemName" -Value $matches[1]
                    break
                }

                '^Build started at[^\t]*\t(.*)$' { 
                    $stats | Add-Member -MemberType NoteProperty -Name "BuildStartDate" -Value $matches[1]
                    break
                }

                '^Extract finished at[^\t]*\t(.*)$' { 
                    $values = $matches[1] -split "`t"
                    $stats | Add-Member -MemberType NoteProperty -Name "ExtractFinishedDate" -Value $values[0]
                    $stats | Add-Member -MemberType NoteProperty -Name "ExtractFinishedDurationSeconds" -Value $values[1]
                    break
                }

                '^Auto detect finished at[^\t]*\t(.*)$' { 
                    $values = $matches[1] -split "`t"
                    $stats | Add-Member -MemberType NoteProperty -Name "AutoFinishedDate" -Value $values[0]
                    $stats | Add-Member -MemberType NoteProperty -Name "AutoFinishedDurationSeconds" -Value $values[1]
                    break
                }

                '^Sort finished at[^\t]*\t(.*)$' { 
                    $values = $matches[1] -split "`t"
                    $stats | Add-Member -MemberType NoteProperty -Name "SortFinishedDate" -Value $values[0]
                    $stats | Add-Member -MemberType NoteProperty -Name "SortFinishedDurationSeconds" -Value $values[1]
                    break
                }

                '^Load finished at[^\t]*\t(.*)$' { 
                    $values = $matches[1] -split "`t"
                    $stats | Add-Member -MemberType NoteProperty -Name "LoadFinishedDate" -Value $values[0]
                    $stats | Add-Member -MemberType NoteProperty -Name "LoadFinishedDurationSeconds" -Value $values[1]
                    break
                }

                '^Post load actions finished at[^\t]*\t(.*)$' { 
                    $values = $matches[1] -split "`t"
                    $stats | Add-Member -MemberType NoteProperty -Name "PostloadFinishedDate" -Value $values[0]
                    $stats | Add-Member -MemberType NoteProperty -Name "PostloadFinishedDurationSeconds" -Value $values[1]
                    break
                }

                '^Base system size[^\t]*\t(.*)$' { 
                    $stats | Add-Member -MemberType NoteProperty -Name "BaseSystemSizeMb" -Value $matches[1]
                    break
                }

                '^Virtual system size[^\t]*\t(.*)$' { 
                    $stats | Add-Member -MemberType NoteProperty -Name "VirtualSystemSizeMb" -Value $matches[1]
                    break
                }


            }
            
            
        
        }

        # add more columns for duration
        $duration = New-TimeSpan -Start ( [DateTime]::Parse($stats.BuildStartDate) ) -End ( [DateTime]::Parse($stats.LoadFinishedDate) )
        $stats | Add-Member -MemberType NoteProperty -Name "BuildTimeMinutes" -Value $duration.Minutes
        $stats | Add-Member -MemberType NoteProperty -Name "BuildTimePretty" -Value $duration

        # output pre- and postload duration
        $postloadDuration = New-TimeSpan -Seconds $stats.PostloadFinishedDurationSeconds
        $stats | Add-Member -MemberType NoteProperty -Name "PostLoadMinutes" -Value $postloadDuration.Minutes
        $stats | Add-Member -MemberType NoteProperty -Name "PostLoadPretty" -Value $postloadDuration

        [void]$allStats.Add($stats)

    }

    $allStats | Out-GridView
    #>

    #-----------------------------------------------
    # CURRENT RESOURCES CPU 
    #-----------------------------------------------

    # TODO [x] Find out current ram and cpu usage
    # TODO [ ] put more into settings
    # Get-CimInstance win32_processor | select * # fetch a lot of information about the processor

    If ( $settings.measureCPU -eq $true ) {
        $sleepTime = 500   # Milliseconds
        $timeout = 10       # Seconds
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $cpuLoad = [System.Collections.ArrayList]@()
        Do {
            Start-Sleep -Milliseconds $sleepTime
            [void]$cpuLoad.add(( Get-CimInstance win32_processor | measure -property "LoadPercentage" -Average).Average )
        } Until ( $stopwatch.Elapsed.TotalSeconds -ge $timeout )
        $stopwatch.Stop()
        $cpuMetrics = $cpuLoad | measure -Average -Maximum

        $metrics = [PSCustomObject]@{
            "CPU avg" = "$( [math]::Round($cpuMetrics.Average,1) ) %"
            "CPU max" = "$( [math]::Round($cpuMetrics.Maximum,1) ) %"
            "Measures" = "$( $cpuLoad.Count ) measures over $( $timeout ) seconds"
        }

        <#
        [void]$systemInformation.Add("CPU avg: $( [math]::Round($cpuMetrics.Average,1) ) %")
        [void]$systemInformation.Add("CPU max: $( [math]::Round($cpuMetrics.Maximum,1) ) %")
        [void]$systemInformation.Add("Resources measures: $( $cpuLoad.Count ) measures over $( $timeout ) seconds")
        #>
        $str = ($metrics | ConvertTo-Html -Fragment -as List | Out-String ).replace("`r","").replace("`n","")
        [void]$systemInformation.Add( "`n<h2>CPU</h2>`n$( $str )`n" )


    }


    #-----------------------------------------------
    # CURRENT RESOURCES RAM 
    #-----------------------------------------------

    # TODO [ ] put more into settings
    # Get-CimInstance win32_processor | select * # fetch a lot of information about the processor

    If ( $settings.measureRAM -eq $true ) {
        $sleepTime = 500   # Milliseconds
        $timeout = 10       # Seconds
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $freeRAM = [System.Collections.ArrayList]@()
        Do {
            Start-Sleep -Milliseconds $sleepTime
            [void]$freeRAM.add(( Get-CimInstance Win32_OperatingSystem | measure -property "FreePhysicalMemory" -Average).Average )
        } Until ( $stopwatch.Elapsed.TotalSeconds -ge $timeout )
        $stopwatch.Stop()
        $ramMetrics = $freeRAM | measure -Average -Maximum

        $os = Get-CimInstance Win32_OperatingSystem
        $metrics = [PSCustomObject]@{
            "RAM total size" = "$( [math]::Round($os.TotalVisibleMemorySize / [math]::pow(2,20),2) ) GB"
            "RAM free avg percentage" = "$( [math]::Round(($ramMetrics.Average/$os.TotalVisibleMemorySize)*100,2) ) %"
            "RAM free avg" = "$( [math]::Round($ramMetrics.Average / [math]::pow(2,20),2) ) GB"
            "RAM free max" = "$( [math]::Round($ramMetrics.Maximum / [math]::pow(2,20),2) ) GB"
            "Measures" = "$( $freeRAM.Count ) measures over $( $timeout ) seconds"
        }

        $str = ($metrics | ConvertTo-Html -Fragment -as List | Out-String ).replace("`r","").replace("`n","")
        [void]$systemInformation.Add( "`n<h2>RAM</h2>`n$( $str )`n" )


        <#
        [void]$systemInformation.Add("RAM total size: $( [math]::Round($os.TotalVisibleMemorySize / [math]::pow(2,20),2) ) GB")
        [void]$systemInformation.Add("RAM free avg percentage: $( [math]::Round(($ramMetrics.Average/$os.TotalVisibleMemorySize)*100,2) ) %")
        [void]$systemInformation.Add("RAM free avg: $( [math]::Round($ramMetrics.Average / [math]::pow(2,20),2) ) GB")
        [void]$systemInformation.Add("RAM free max: $( [math]::Round($ramMetrics.Maximum / [math]::pow(2,20),2) ) GB")
        [void]$systemInformation.Add("Resources measures: $( $freeRAM.Count ) measures over $( $timeout ) seconds")
        #>
    }


    #-----------------------------------------------
    # MERGE SYSTEM INFORMATION
    #-----------------------------------------------

    # Ask for the system information
    If ( @( $settings.attachComputerInfo ).Count -gt 0 ) {

        $computerInfo = Get-ComputerInfo | Select $settings.attachComputerInfo

        <#
        $settings.attachComputerInfo | ForEach {
            $attr = $_
            [void]$systemInformation.Add( "$( $attr ): $( [String]$computerInfo.$attr )" )
        }
        #>
        $str = ($computerInfo | ConvertTo-Html -Fragment -as List | Out-String ).replace("`r","").replace("`n","")
        [void]$systemInformation.Add( "`n<h2>ComputerInfo</h2>`n$( $str )`n" )
        
    }

    # Merge everything to one string
    $systemInformationString = ""
    If ( $systemInformation.Count -gt 0 ) {
        $systemInformationString = "`n`n------------`n`n<h1>System information:</h1>`n$( $systemInformation -join "`n" )"
    }


    #-----------------------------------------------
    # CHECK IF THIS IS A SUMMARY MAIL OR REGULAR CHECK MAIL
    #-----------------------------------------------

    # Check daily keepalive
    $sendDaily = $false
    If ( $settings.dailyKeepAlive -eq $true ) {

        $todayKeepAlive = [datetime]::Parse($settings.dailyKeepAliveTime) #($settings.dailyKeepAliveTime)

        $todayKeepAliveTimespan = New-TimeSpan -Start $todayKeepAlive -End $timestamp

        # Check if it already passed 
        If ( $todayKeepAliveTimespan.TotalMinutes -gt 0 ) {

            # Check we haven't already sent this
            If ( $lastSession -ne $null ) {
                # Check if lastsession was before the wished time slot
                #$lastSessionDateTime = Get-DateTimeFromUnixtime -unixtime $lastSession.lastSession -convertToLocalTimezone
                $lastSessionToKeepAliveTimespan = New-TimeSpan -Start $todayKeepAlive -End $lastSessionTime
                If ( $lastSessionToKeepAliveTimespan.TotalMinutes -le 0 ) {
                    # Send it
                    $sendDaily = $true
                }
            } else {
                # Send, because there is no last session and we already passed the wished time slot
                $sendDaily = $true
            }

        }

    }


    #-----------------------------------------------
    # SEND EMAIL STRAIGHT AWAY
    #-----------------------------------------------

    # TODO [ ] change XYZ to something else like systemname
    # TODO [ ] put subject and body text into settings

    $emailSent = $false

    If ( $sendDaily -eq $false ) {

        If ( $warningEntries.Count -gt 0 ) {

            $bodyContent = "<h1>Please check those warnings</h1>`n`n$( $warningEntries -join "`n" )$( $systemInformationString )</span>" -replace "`n","<br/>"
            $bodyHTML = "$( $mailStyle )<span style='font-family:courier, courier new, serif;font-size:12pt;font-style:none;'>$( $bodyContent )</span>"
            #$bodyHTML | Set-content "c:\temp\abc.html"

            # combine all parameters
            $mailParams = [Hashtable]@{
                SmtpServer = $settings.smtpSettings.host
                From = $settings.smtpSettings.from
                To = @( $settings.smtpSettings.to )
                Port = $settings.smtpSettings.port
                Subject = "$( $settings.subjectprefix )Please check these $( $warningEntries.Count ) warnings"
                Body = $bodyHTML #"<span style='font-family:courier, courier new, serif;font-size:12pt;font-style:none;'>Please check those warnings`n`n$( $warningEntries -join "`n" )$( $systemInformationString )</span>"
                BodyAsHtml = $true
            }

            # Add credentials if set
            If ( $settings.smtpSettings.username.length -gt 0 -and $settings.smtpSettings.password.length -gt 0 ) {
                $cred =  [PSCredential]::new($settings.smtpSettings.username, ( ConvertTo-SecureString ( Get-SecureToPlaintext -String $settings.smtpSettings.password ) -AsPlainText -Force ))
                $mailParams.Add("credential",$cred)
            #} elseif ( $settings.smtpSettings.username.length -gt 0 ) {
            #    $cred =  [PSCredential]::new($settings.smtpSettings.username, ( ConvertTo-SecureString "" -AsPlainText -Force ))
            #    $mailParams.Add("credential",$cred)
            } else {
                # Do nothing
            }
            
            # Log
            Write-Log -message "Sending direct email"

            # call the sending with splatting
            Send-MailMessage @mailParams
    
            # Set this to true now
            $emailSent = $true
    
        }

    }

    
    #-----------------------------------------------
    # MERGE WARNINGS WITH OTHER MESSAGES FROM TODAY
    #-----------------------------------------------

    # Add entries since last summary
    $warningsToday = [System.Collections.ArrayList]@()    
    If ( $lastSession -ne $null ) {
        If ( @( $lastSession.messagesToday ).Count -gt 0 ) {
        
            #If ($timespanSinceLastSession.TotalMinutes -gt $timespanSinceMidnight.TotalMinutes) {
                # "This was yesterday" - do nothing with messages from yesterday
            #} else {
                # "This is today" - only add messages from today
                [void]$warningsToday.AddRange($lastSession.messagesToday)
            #}

        }
    }   

    # Add current entries
    [void]$warningsToday.AddRange($warningEntries)

    # LOG
    If ( $warningEntries.Count -gt 0 ) {
        Write-Log -message "Collected $( $warningEntries.Count ) warnings" -severity ( [Logseverity]::WARNING )
    } else {
        Write-Log -message "No warnings found" -severity ( [Logseverity]::INFO )
    }
    

    #-----------------------------------------------
    # SEND DAILY SUMMARY MAIL
    #-----------------------------------------------
    
    If ( $sendDaily -eq $true ) {
   
        # TODO [ ] Now it only sends the warnings of today, but maybe think about sending the warnings since the last warning summary mail
        $bodyContent = "Please check those warnings`n`n$( $warningsToday -join "`n" )$( $systemInformationString )</span>" -replace "`n","<br/>"
        $bodyHTML = "$( $mailStyle )<span style='font-family:courier, courier new, serif;font-size:12pt;font-style:none;'>$( $bodyContent )</span>"

        # combine all parameters
        $mailParams = [Hashtable]@{
            SmtpServer = $settings.smtpSettings.host
            From = $settings.smtpSettings.from
            To = @( $settings.smtpSettings.to )
            Port = $settings.smtpSettings.port
            Subject = "$( $settings.subjectprefix )Please check $( $warningsToday.Count ) warnings of today"
            Body = $bodyHTML #"<span style='font-family:courier, courier new, serif;font-size:12pt;font-style:none;'>Please check those warnings`n`n$( $warningEntries -join "`n" )$( $systemInformationString )</span>"
            BodyAsHtml = $true
        }

        # Add credentials if set
        If ( $settings.smtpSettings.username.length -gt 0 -and $settings.smtpSettings.password.length -gt 0 ) {
            $cred =  [PSCredential]::new($settings.smtpSettings.username, ( ConvertTo-SecureString ( Get-SecureToPlaintext -String $settings.smtpSettings.password ) -AsPlainText -Force ))
            $mailParams.Add("credential",$cred)
        #} elseif ( $settings.smtpSettings.username.length -gt 0 ) {
        #    $cred =  [PSCredential]::new($settings.smtpSettings.username, ( ConvertTo-SecureString "" -AsPlainText -Force ))
        #    $mailParams.Add("credential",$cred)
        } else {
            # Do nothing
        }

        # Log
        Write-Log -message "Sending summary email"

        # call the sending with splatting
        Send-MailMessage @mailParams

        # Clear the messages if a summary was sent
        $warningsToday.Clear()

        # Set this to true now
        $emailSent = $true    
        
        # When we are already at this daily point, do some regular log cleanup
        If ( $settings.appendDateToLogfile -eq $true ) {
            $logfileDir = [System.IO.Path]::GetDirectoryName($logfile)
            $filter = "$( [System.IO.Path]::GetFileNameWithoutExtension($settings.logfile) )*$( [System.IO.Path]::GetExtension($settings.logfile) )*"
            Get-ChildItem -Path $logfileDir -Filter $filter | ForEach {
                $logItem = $_
                $logItemAge = New-TimeSpan -Start $logItem.LastWriteTime -End ( [datetime]::Today )
                If ( $logItemAge.TotalDays -gt $settings.retainXdaysOfLogfiles ) {
                    Write-Log "Removing logfile '$( $logItem.FullName )' because it is older than $( $settings.retainXdaysOfLogfiles ) days"
                    Remove-Item -Path $logItem.FullName -Force
                }
            }
        }

    }

    If ( $emailSent -eq $true ) {
        $emailTimestamp = Get-Unixtime
    } elseif ( $lastSession -ne $null ) {
        $emailTimestamp = $lastSession.emailTimestamp
    } else {
        $emailTimestamp = $null
    }
    

} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

} finally {

    # TODO [ ] put mailsend into finally?

    #-----------------------------------------------
    # CREATE SUCCESS WITH LAST LOAD
    #-----------------------------------------------

    # Remove, if file already exists
    If ( Test-Path -Path $sessionFile ) {
        Remove-Item -Path $sessionFile
    }

    Write-Log -message "Creating session file at '$( $sessionFile )'"
    
    # Create the session file
    $currentSessionJson = [PSCustomObject]@{
        lastSession = Get-Unixtime
        lastMailSent = $emailSent
        emailTimestamp = $emailTimestamp
        messagesToday = @( $warningsToday )        
    } | ConvertTo-Json -Depth 99 # -compress
    
    # save current session to file
    $currentSessionJson | Set-Content -path $sessionFile -Encoding UTF8

    $process.ExitCode

}



