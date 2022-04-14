
################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true
$configMode = $true


################################################
#
# NOTES
#
################################################

<#

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

#>


################################################
#
# SCRIPT ROOT
#
################################################

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "MONITORCREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
#. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"


################################################
#
# START
#
################################################


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if( Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR SESSIONFILE
#-----------------------------------------------

# Default file
$sessionFileDefault = "$( $scriptPath )\session.json"

# Ask for another path
$sessionFile = Read-Host -Prompt "Where do you want the session file to be saved? Just press Enter for this default [$( $sessionFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $sessionFile -eq "" -or $null -eq $sessionFile) {
    $sessionFile = $sessionFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $sessionFile -IsValid ) {
    Write-Host "SettingsFile '$( $sessionFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $sessionFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\monitor.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# LOAD LOGGING MODULE NOW
#-----------------------------------------------

$settings = @{
    logfile = $logfile
    appendDateToLogfile = $true
}

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


#-----------------------------------------------
# LOG THE NEW SETTINGS CREATION
#-----------------------------------------------

Write-Log -message "Creating a new settings file" -severity ( [Logseverity]::WARNING )


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# AKS FOR SMTP CREDENTIALS
#-----------------------------------------------

# Entering the username and password
# $base = Read-Host "Please enter account sessionId"
$username = Read-Host "Please enter the username for SMTP. Leave empty, if there is no username"

# If prompt is empty, just use default path
if ( $username -eq "" -or $null -eq $username) {
    $username = ""
}


$password = Read-Host -AsSecureString "Please enter the password for SMTP. Leave empty if there is no password"
# If prompt is empty, just use default path
if ( $password -eq "" -or $null -eq $password) {
    $passwordEncrypted = ""
} else {
    $passwordEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$password).GetNetworkCredential().Password)

}


#-----------------------------------------------
# SETTINGS OBJECT
#-----------------------------------------------

$settings = [Ordered]@{

    # Log file settings
    logfile = $settings.logfile                     # Logfile to use
    appendDateToLogfile = $true                     # in this case a date will be appended to the logfile name
    retainXdaysOfLogfiles = 14                      # For how long do you want to retain the logfiles

    # General settings
    powershellExePath = "powershell.exe"            # Define other powershell path, e.g if you want to use pwsh for powershell7
    sessionFile = $sessionFile                      # File to save the last session

    # Network settings
    #"changeTLS" = $true
    #"proxy" = $proxy # Proxy settings, if needed - will be automatically used
    
    # check space for drives
    attachDriveOverview = $true                     # $true|$false attaches a list of drives with free and used gb
    checkSpace = $true                              # $true|$false checks if the free space is already used up
    thresholdWarning = 0.8                          # Threshold when a warning for used space should be generated
    thresholdCritical = 0.9                         # Threshold when a critical warning for used space should be generated
    #onlyOutputWarnings = $false                     # TODO [ ] implement this one to only show log messages when something is wrong

    # more settings
    dailyKeepAlive = $true                          # $true|$false if you want to receive a keep alive via email every day, even if there are no warnings to send
    dailyKeepAliveTime = "23:00:00"                 # daily time to send the daily summary
    
    # Attributes of Get-ComputerInfo to attach to the mail, execute this command to find out more
    attachComputerInfo = @(
        "WindowsProductName"
        "CsName"
        "CsNumberOfLogicalProcessors"
        "CsProcessors"
        "OsName"
        "OsUptime"
    )

    # Measure CPU and RAM over a specific period
    measureCPU = $true                              # $true|$false if you want to measure CPU over 10 seconds and to see the average use
    measureRAM = $true                              # $true|$false if you want to measure RAM over 10 seconds and to see the average use

    # Services
    checkServicesStatus = $true                     # $true|false if you want to check the current service status
    servicePrefix = "fs_*"                          # Prefix for the FastStats services
    orbitServicePrefix = "FastStats*"               # Prefix for the Orbit Updater services
    serviceAttributes = @(                          # Services attributes to attach in the email, find out more with  Get-Service -Name "A*" | Select *, "UserName", "StartupType"
        "Status"
        "Name"
        "DisplayName"
    ) 

    # certificates
    checkCertificates = $true                       # $true|false if you want to check SSL certificates
    certificateURLsToCheck = @(                     # Array with hostnames to check the certificates
        "demo.apteco.io"
    ) 
    warningIfCertificateExpiresInNDays = 14         # Number of days when the warnings should be generated

    # Check the Orbit Update settings
    checkOrbitAutomaticUpdate = $true               # $true|false if you want to check if the automatic update of orbit is activated
    orbitUpdaterConfig = "C:\Program Files (x86)\Apteco\FastStats Orbit Updater\Updater.exe.config" # The path to the updater config file
    
    # OrbitUrls version check
    checkOrbitVersions = $true                      # $true|false if you want to check the orbit versions
    orbitApiUrl = "https://demo.apteco.io/OrbitAPI" # The Orbit API url of your Orbit installation
    orbitUiUrl = "https://demo.apteco.io/Orbit"     # The Orbit UI url of your Orbit installation
    nugetRepository = "https://orbit.apteco.com/FastStatsOrbitUpdateServer/nuget"   # Normally no need to change as this is the public repository

    # .NET
    checkDotNet = $true                             # $true|false if you want to check .NET

    # email/smtp settings
    subjectprefix = "[DEMO] "                       # Prefix to use for the email subject
    smtpSettings = [Hashtable]@{
        username = $username                        # Will be asked interactive when running this script
        password = $passwordEncrypted               # Will be asked interactive when running this script
        host = "smtp.ionos.de"                      # SMTP server name
        from = "orbit@demo.apteco.io"               # SMTP username
        port = 587                                  # SMTP Port
        to = @(                                     # receivers for notification mails
            "florian.von.bracht@apteco.de"
        )
    }

    
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# rename settings file if it already exists
If ( Test-Path -Path $settingsFile ) {
    $backupPath = "$( $settingsFile ).$( $timestamp.ToString("yyyyMMddHHmmss") )"
    Write-Log -message "Moving previous settings file to $( $backupPath )" -severity ( [Logseverity]::WARNING )
    Move-Item -Path $settingsFile -Destination $backupPath
} else {
    Write-Log -message "There was no settings file existing yet"
}

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $settingsFile -Encoding UTF8


################################################
#
# RELOAD EVERYTHING
#
################################################

#-----------------------------------------------
# RELOAD SETTINGS
#-----------------------------------------------

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the preparation file to prepare the connections
. ".\bin\preparation.ps1"


################################################
#
# CREATE WINDOWS TASK
#
################################################

# Confirm you read the licence details
$createTask = $Host.UI.PromptForChoice("Confirmation", "Do you want to create a scheduled task?", @('&Yes'; '&No'), 0)

If ( $createTask -eq "0" ) {

    # Means yes and proceed
    
    #-----------------------------------------------
    # REPLACE / REMOVE EXISTING VPN TASKS
    #-----------------------------------------------
    
    # Default task settings
    $taskPath = "Apteco"
    $taskNameDefault = "Apteco Monitor"
    $taskDescription = "Monitors or checks some things"
    #$executionUser = "$( $env:USERDOMAIN )\$( $env:USERNAME )" # "LOCALSERVICE"
    $execFile = Get-Item -Path ".\mntr__10__monitor.ps1"

    Write-Log -message "Creating a scheduled task with name '$( $taskNameDefault )' and Path '$( $taskPath )'"

    # Replace task if it already exists
    $existingTask = @( Get-ScheduledTask | where { $_.TaskName -like "$( $taskNameDefault )*" } )
    if ( $existingTask.Count -gt 0 ) {

        # Replace task?
        $replaceTask = $Host.UI.PromptForChoice("Replace Task", "Do you want to remove the existing tasks, they will get replaced?", @('&Yes'; '&No'), 0)

        If ( $replaceTask -eq 0 ) {

            # To replace the tasks, remove them
            $existingTask | ForEach {
                $exTask = $_
                Write-Log -message "Removing task first with '$( $exTask.TaskName )' to get it replaced"
                Unregister-ScheduledTask -TaskName $exTask.TaskName -Confirm:$false
            }

        }

    } 

    # Just use the default name instead of asking
    # Ask for task name or use default value
    #$taskName  = Read-Host -Prompt "Which name should the task have? [$( $taskNameDefault )]"
    #if ( $taskName -eq "" -or $null -eq $taskName) {
        $taskName = $taskNameDefault
    #}

    #-----------------------------------------------
    # GET VALID CREDENTIALS
    #-----------------------------------------------

    Write-Log -message "Your current username is '$( $env:USERNAME )'"
    Write-Log -message "Your current domain is '$( $env:USERDOMAIN )'"

    $taskCred = Get-Credential
    $credValid = Test-Credential -Credentials $taskCred

    if ( $credValid -eq $true ) {
        Write-Log -message "The credentials you have provided are valid"
    } else {
        Write-Log -message "The credentials you have provided are not valid" -severity ([Logseverity]::ERROR)
        throw [System.IO.InvalidDataException] "The credentials you have provided are not valid"
    }


    #-----------------------------------------------
    # SET TRIGGERS - SEE EVENT LOG FOR THESE EVENTS
    #-----------------------------------------------

    # Set the triggers
    $triggers = @()
    
    # TODO [x] add a repeating every 5 minutes for 24 hours!
    # https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger?view=windowsserver2022-ps

    # You need a workaround to get a daily time based trigger with recurrring schedule
    # https://www.reddit.com/r/PowerShell/comments/8vjpzq/registerscheduledtask_using_daily_and_repetition/
    $tempTrigger = New-ScheduledTaskTrigger -Once -at "00:00" -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 1)
    $trigger = New-ScheduledTaskTrigger -Daily -At ([Datetime]::Parse("06:00")  ) #"07:00" 
    $trigger.Repetition = $tempTrigger.Repetition
    $triggers += $trigger

    # create TaskEventTrigger, use your own value in Subscription
    #$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
    #$trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly

    # Filter to subscribe to "connected" event
    <#
    $trigger.Subscription = @"
<QueryList>
    <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
        <Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]</Select>
    </Query>
</QueryList>
"@
#>

<#
 @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[(Level=4 or Level=0) and (EventID=10000)]]</Select>
  </Query>
</QueryList>
"@
#>

    #$trigger.Enabled = $True 
    #$triggers += $trigger
        


    #-----------------------------------------------
    # CREATE SCHEDULED TASK
    #-----------------------------------------------

    # Parameters for scheduled task
    $registerTaskFailed = $false
    $taskParams = [Hashtable]@{
        TaskPath = $taskPath
        TaskName = $taskname
        Description = $taskDescription
        Action = New-ScheduledTaskAction -Execute "$( $settings.powershellExePath )" -Argument "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ""$( $execFile.FullName )"" -params ""@{settingsfile='$( $settingsFile )'}"""
        Trigger = $triggers
        Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 3) -MultipleInstances "IgnoreNew" -RunOnlyIfNetworkAvailable -Hidden #-RestartInterval 
        User = $taskCred.UserName                               # Only username will be interactive mode; username+password is non-interactive mode
        Password = $taskCred.GetNetworkCredential().Password    # Just input password to let this be executed independent from the current session
    }

    Write-Log "Register the task now"

    try {
        $newTask = Register-ScheduledTask @taskParams -ErrorAction Stop  #T1 -InputObject $task
        $task = $newTask #Get-ScheduledTask | where { $_.TaskName -eq $taskName }
        $taskInfo = $task | Get-ScheduledTaskInfo
    } catch [Microsoft.Management.Infrastructure.CimException] { #[Microsoft.Management.Infrastructure.CimException]
        Write-Log -message "Registering the task failed." -severity ([Logseverity]::ERROR)
        Write-Log -message "Task Scheduler cannot create the task. The user account is unknown, the password is incorrect, or the user account does not have permission to create this task." -severity ([Logseverity]::ERROR)
        $registerTaskFailed = $true
        #throw $_.Exception
    }

    # If the task creation failed we can try an admin user to create the task
    If ( $registerTaskFailed -eq $true) {
        
        $tryAgaign = $Host.UI.PromptForChoice("Confirmation", "Do you want to try again to register that task?", @('&Yes'; '&No'), 0)

        If ( $tryAgaign -eq "0" ) {
            
            Write-Log -message "Trying to recreate the task with another user"

            # Please enter credentials for task creation
            Write-Host "Please enter other credentials with admin role to register task"
            $createTaskCred = Get-Credential
            $createTaskCredValid = Test-Credential -Credentials $createTaskCred

            if ( $createTaskCredValid -eq $true ) {
                Write-Log -message "The credentials you have provided are valid"
            } else {
                Write-Log -message "The credentials you have provided are not valid" -severity ([Logseverity]::ERROR)
                throw [System.IO.InvalidDataException] "The credentials you have provided are not valid"
            }
            
            # Create a hashtable for the arguments
            $ht = [Hashtable]@{
                taskParams=$taskparams
            }

            # Scriptblock to execute
            $registerTaskScriptBlock = [scriptblock]{
                $a = $args.taskParams
                $existingTask = @( Get-ScheduledTask | where { $_.TaskName -eq "$( $a.TaskName )" } )
                If ($existingTask.Count -gt 0 ) {
                    Unregister-ScheduledTask -TaskName $a.TaskName -Confirm:$false
                }
                $newTask = Register-ScheduledTask @a
                $return = [Hashtable]@{
                    task = $newTask
                    taskInfo = $newTask | Get-ScheduledTaskInfo
                }
                return $return
            }
            
            # Start a job with other credentials to create that task
            $registerTaskJob = Start-Job -ScriptBlock $registerTaskScriptBlock -Credential $createTaskCred -ArgumentList $ht

            # Wait until job is completed or failed
            Do {
                Start-Sleep -Milliseconds 200 -Verbose
                #"Waiting $( $job.State )"
            } Until ( @("Completed","Failed") -contains $registerTaskJob.State )


            # Put the results into separate variables
            $registerTaskJobResult = Receive-Job -Id $registerTaskJob.id -Keep
            $task = $registerTaskJobResult.task
            $taskInfo = $registerTaskJobResult.taskInfo

        }
    }


    #-----------------------------------------------
    # GET INFO ABOUT NEW TASK
    #-----------------------------------------------

    Write-Log -message "Task with name '$( $task.TaskName )' in '$( $task.TaskPath )' was created"
    Write-Log -message "  Next run date is '$( $taskInfo.NextRunTime )'"
    # The task will only be created if valid. Make sure it was created successfully

}


################################################
#
# WAIT FOR KEY
#
################################################

Write-Log -message "Settings creation finished :-)"

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');