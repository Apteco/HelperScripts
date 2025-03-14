
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
$modulename = "CRCREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

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
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\cr.log"

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
# ASK FOR TOKENFILE
#-----------------------------------------------

# Default file
$tokenFileDefault = "$( $scriptPath )\cr.token"

# Ask for another path
$tokenFile = Read-Host -Prompt "Where do you want the token file to be saved? Just press Enter for this default [$( $tokenFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $tokenFile -eq "" -or $null -eq $tokenFile) {
    $tokenFile = $tokenFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $tokenFile -IsValid ) {
    Write-Host "SettingsFile '$( $tokenFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $tokenFile )' contains invalid characters"
}


#-----------------------------------------------
# LOAD LOGGING MODULE NOW
#-----------------------------------------------

$settings = @{
    "logfile" = $logfile
}

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


#-----------------------------------------------
# LOG THE NEW SETTINGS CREATION
#-----------------------------------------------

Write-Log -message "Creating a new settings file" -severity ( [Logseverity]::WARNING )


################################################
#
# OBTAIN CLEVERREACH TOKEN
#
################################################

#-----------------------------------------------
# CONFIRM FOR NEXT STEPS
#-----------------------------------------------

# Confirm you want to proceed
$proceed = $Host.UI.PromptForChoice("New Token", "This will create a NEW token. Previous tokens will be invalid immediatly. Please confirm you are sure to proceed?", @('&Yes'; '&No'), 1)

# Leave if answer is not yes
If ( $proceed -eq 0 ) {
    Write-Log -message "Asked for confirmation of new token creation. Answer was 'yes'"
} else {
    Write-Log -message "Asked for confirmation of new token creation. Answer was 'No'"
    Write-Log -message "Leaving the script now"
    exit 0
}


#-----------------------------------------------
# SETTINGS FOR THE TOKEN CREATION
#-----------------------------------------------

$customProtocol = "apttoken$( Get-RandomString -length 6 -noSpecialChars )"
$clientId = "ssCNo32SNf"    # Certified CleverReach App for Apteco
$authUrl = [uri]"https://rest.cleverreach.com/oauth/authorize.php"
$tokenUrl = [uri]"https://rest.cleverreach.com/oauth/token.php"
$callbackFile = "$( $env:TEMP )\crcallback.txt" # This path is also used in the callback.ps1 script

# Ask APTECO to enter the client secret
Write-Log -message "Asking Apteco about the CleverReach App client secret"
$clientSecret = Read-Host -AsSecureString "Please ask Apteco to enter the client secret"
$clientCred = New-Object PSCredential $clientId,$clientSecret
$clientSecret = ""


#-----------------------------------------------
# PREPARE REGISTRY
#-----------------------------------------------

# current path - will get back to this at the end
$currentLocation = Get-Location

# Switch to registry - choose the current user to not need admin rights
$root = "Registry::HKEY_CURRENT_USER\Software\Classes" # User registry - needs no elevated rights
# $root = "Registry::HKEY_CLASSES_ROOT" # Global registry - needs admin rights
Write-Log -message "Putting new registry entries into '$( $root )' with custom protocol '$( $customProtocol )'"
Set-Location -Path $root

# Remove the registry entries, if already existing
If ( Test-Path -path $customProtocol ) {
    Write-Log -message "Custom protocol folder was already existing. Removing it now."
    Remove-Item -Path $customProtocol -Force
}

# Create the base entries now
New-Item -Path $customProtocol
New-ItemProperty -Path $customProtocol -Name "(Default)" -PropertyType String -Value "URL:$( $customProtocol )"
New-ItemProperty -Path $customProtocol -Name "URL Protocol" -PropertyType String -Value ""

# Create more keys and properties for sub items
Set-Location -Path ".\$( $customProtocol )"
New-Item -Path ".\DefaultIcon"
New-Item -Path ".\shell\open\command" -force # Creates the items recursively
New-ItemProperty -Path ".\shell\open\command" -Name "(Default)" -PropertyType String -Value """powershell.exe"" -File ""$( $scriptPath )\bin\callback.ps1"" ""%1"""  

# Go back to original path
Set-Location -path $currentLocation.Path

Write-Log -message "Created the registry entries"


#-----------------------------------------------
# CLEVERREACH OAUTHv2 PROCESS - STEP 1
#-----------------------------------------------

# Prepare redirect URI
$redirectUri = "$( $customProtocol )://localhost" # The www.apteco.de is only there for cleverreach, otherwise the url would be invalid and not accepted

# STEP 1: Prepare the first call to let the user log into cleverreach
# SOURCE: https://powershellmagazine.com/2019/06/14/pstip-a-better-way-to-generate-http-query-strings-in-powershell/
$nvCollection  = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
$nvCollection.Add('response_type','code')
$nvCollection.Add('client_id',$clientId)
$nvCollection.Add('grant',"basic")
$nvCollection.Add('redirect_uri', $redirectUri) # a dummy url like apteco.de is needed

# Create the url
$uriRequest = [System.UriBuilder]$authUrl
$uriRequest.Query = $nvCollection.ToString()

# Remove callback file if it exists
If ( Test-Path -Path $callbackFile ) {
    "Removing callback file '$( $callbackFile )'"
    Remove-Item $callbackFile -Force
}

# Open the default browser with the generated url
Write-Log -message "Opening the browser now to allow the CleverReach Apteco APP access to the account"
Write-Log -message "Please finish the process in your browser now"
Write-Log -message "NOTE:"
Write-Log -message "  APTECO WILL NOT GET ACCESS TO YOUR DATA THROUGH THE APP!"
Write-Log -message "  ONLY THIS LOCAL GENERATED TOKEN CAN BE USED FOR ACCESS!"
Start-Process $uriRequest.Uri.OriginalString

# Wait
Write-Log -message "Waiting for the callback file '$( $callbackFile )'"
Do {
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 500
} Until ( Test-Path -Path $callbackFile )

Write-Log -message "Callback file found '$( $callbackFile )'"

# Read and parse callback file
$callback = Get-Content -Path $callbackFile -Encoding utf8
$callbackUri = [uri]$callback
$callbackUriSegments = [System.Web.HttpUtility]::ParseQueryString($callbackUri.Query)
$code = $callbackUriSegments["code"]

# Remove callback file
Write-Log -message "Removing callback file now"
Remove-Item $callbackFile -Force


#-----------------------------------------------
# CLEVERREACH OAUTHv2 PROCESS - STEP 2
#-----------------------------------------------

# Prepare the second call to exchange the code quickly for a token
$postParams = [Hashtable]@{
    Method = "Post"
    Uri = $tokenUrl
    Body = [Hashtable]@{
        "client_id" = $clientCred.UserName
        "client_secret" = $clientCred.GetNetworkCredential().Password
        "redirect_uri" = $redirectUri
        "grant_type" = "authorization_code"
        "code" = $code
    }
    Verbose = $true
}
$response = Invoke-RestMethod @postParams

Write-Log -message "Got a token with scope '$( $response.scope )'"

# Trying an API call
try {

    $headers = @{
        "Authorization" = "Bearer $( $response.access_token )"
    }
    $ttl = Invoke-RestMethod -Uri "https://rest.cleverreach.com/v3/debug/ttl.json" -Method Get -ContentType "application/json; charset=utf-8" -Headers $headers
    
    Write-Log -message "Used token for API call successfully. Token expires at '$( $ttl.date.toString() )'"
    
} catch {
    
    Write-Log -message "API call was not successful. Aborting the whole script now!" -severity ( [Logseverity]::WARNING )
    throw $_.Exception

}

# Clear the variables straight away
$clientCred = $null


#-----------------------------------------------
# HOUSEKEEPING OF REGISTRY
#-----------------------------------------------

Write-Log -message "Removing temporary registry entries"

# Switch to root path of registry
Set-Location -Path $root

# Remove item now
Remove-Item $customProtocol -Recurse

# Go back to original path
Set-Location -path $currentLocation.Path


################################################
#
# SETTINGS
#
################################################

$login = @{
    "accesstoken" = Get-PlaintextToSecure $response.access_token
    "refreshtoken" = Get-PlaintextToSecure $response.refresh_token
    "refreshTokenAutomatically" = $true
    "refreshTtl" = 604800 # seconds; refresh one week before expiration
}


#-----------------------------------------------
# MAIL SETTINGS
#-----------------------------------------------

$smtpPass = Read-Host -AsSecureString "Please enter the SMTP password"
$smtpPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$smtpPass).GetNetworkCredential().Password)
$mailSettings = @{
    smptServer = "smtp.example.com"
    port = 587
    from = "admin@example.com"
    username = "admin@example.com"
    password = $smtpPassEncrypted
    deactivateServerCertificateValidation = $true # $true|$false
    useSsl = $true  # $true|$false
    useCredentials = $true # $true|$false -> sometimes you have mailservers without user/pass 
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{
    
    # general
    "base" = "https://rest.cleverreach.com/v3/"
    "connectionTestUrl" = "https://rest.cleverreach.com/v3/debug/validate.json"
    "providername" = "CleverReach"
    "logfile" = $logfile
    "contentType" = "application/json; charset=utf-8"
    
    # Token specific
    "tokenfile" = "$( $scriptPath )\cr.token"
    "sendMailOnCheck" = $true
    "sendMailOnSuccess" = $true
    "sendMailOnFailure" = $true
    "notificationReceiver" = "admin@example.com"

    # Windows scheduled task settings
    "taskDefaultName" = "Apteco CleverReach Token Refresher"
    "powershellExePath" = "powershell.exe" # e.g. use pwsh.exe for PowerShell7
    "dailyTaskSchedule" = 6   # runs every day at 6 local time in the morning

    # Mail settings for notification
    "mail" = $mailSettings

    # authentication
    "login" = $login
    
    # network
    "changeTLS" = $true
    
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
# EXPORT THE TOKEN
#
################################################

# save token to file
Write-Log -message "Saving token to '$( $settings.tokenfile )'"
Get-SecureToPlaintext -String $settings.login.accesstoken | Set-Content -path "$( $settings.tokenfile )" -Encoding UTF8 -Force


################################################
#
# CREATE WINDOWS TASK
#
################################################

 # Confirm you want a scheduled task
 $createTask = $Host.UI.PromptForChoice("Confirmation", "Do you want to create a scheduled task for the check and refreshment?", @('&Yes'; '&No'), 0)

 If ( $createTask -eq "0" ) {

    # Means yes and proceed
    Write-Log -message "Creating a scheduled task to check the token daily"

    # Default file
    $taskNameDefault = $settings.taskDefaultName

    # Replace task?
    $replaceTask = $Host.UI.PromptForChoice("Replace Task", "Do you want to replace the existing task if it exists?", @('&Yes'; '&No'), 0)

    If ( $replaceTask -eq 0 ) {
        
        # Check if the task already exists
        $matchingTasks = Get-ScheduledTask | where { $_.TaskName -eq $taskName }

        If ( $matchingTasks.count -ge 1 ) {
            Write-Log -message "Removing the previous scheduled task for recreation"
            # To replace the task, remove it without confirmation
            Unregister-ScheduledTask -TaskName $taskNameDefault -Confirm:$false
        }
        
        # Set the task name to default
        $taskName = $taskNameDefault

    } else {

        # Ask for task name or use default value
        $taskName  = Read-Host -Prompt "Which name should the task have? [$( $taskNameDefault )]"
        if ( $taskName -eq "" -or $null -eq $taskName) {
            $taskName = $taskNameDefault
        }

    }

    Write-Log -message "Using name '$( $taskName )' for the task"


    # TODO [ ] Find a reliable method for credentials testing
    # TODO [ ] Check if a user has BatchJobrights ##[System.Security.Principal.WindowsIdentity]::GrantUserLogonAsBatchJob

    # Enter username and password
    $taskCred = Get-Credential

    # Parameters for scheduled task
    $taskParams = [Hashtable]@{
        TaskPath = "\Apteco\"
        TaskName = $taskname
        Description = "Refreshes the token for CleverReach because it is only valid for 30 days"
        Action = New-ScheduledTaskAction -Execute "$( $settings.powershellExePath )" -Argument "-ExecutionPolicy Bypass -File ""$( $scriptPath )\cleverreach__05__check_token.ps1"""
        #Principal = New-ScheduledTaskPrincipal -UserId $taskCred.Name -LogonType "ServiceAccount" # Using this one is always interactive mode and NOT running in the background
        Trigger = New-ScheduledTaskTrigger -at ([Datetime]::Today.AddDays(1).AddHours($settings.dailyTaskSchedule)) -Daily # Starting tomorrow at six in the morning
        Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 3) -MultipleInstances "Parallel" # Max runtime of 3 minutes
        User = $taskCred.UserName
        Password = $taskCred.GetNetworkCredential().Password
        #AsJob = $true
    }

    # Create the scheduled task
    try {
        Write-Log -message "Creating the scheduled task now"
        $newTask = Register-ScheduledTask @taskParams #T1 -InputObject $task
    } catch {
        Write-Log -message "Creation of task failed or is not completed, please check your scheduled tasks and try again"
        throw $_.Exception
    }

    # Check the scheduled task
    $task = $newTask #Get-ScheduledTask | where { $_.TaskName -eq $taskName }
    $taskInfo = $task | Get-ScheduledTaskInfo
    Write-Host "Task with name '$( $task.TaskName )' in '$( $task.TaskPath )' was created"
    Write-Host "Next run '$( $taskInfo.NextRunTime.ToLocalTime().ToString() )' local time"
    # The task will only be created if valid. Make sure it was created successfully

 } 

Write-Log -message "Done with settings creation"


################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

exit 0
