################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# NOTES
#
################################################




################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
#$settingsFilename = "settings.json"
#$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "cleverreach_deactivate"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json



# TODO  [ ] unify settings in json file
$settings = @{

    base = "https://rest.cleverreach.com/v3/"
    changeTLS = $true
    #loadArchivedRecords = $true
    pageLimitGet = 100 # Max amount of records to download with one API call
    logfile = "$( $scriptPath )\cleverreach_deactivate.log"
    token = "<token>"
    
   # details to load from cleverreach per receiver
    cleverreachDetails = @{
        events = $false
        orders = $false
        tags = $false
    }
    

}

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Create the binary value for loading the cleverreach details for each receiver
$cleverreachDetailsBinaryValues = @{
    events = 1
    orders = 2
    tags = 4
}
$cleverReachDetailsBinary = 0
$cleverreachDetailsBinaryValues.Keys | ForEach {
    if ( $settings.cleverreachDetails[$_] -eq $true ) {
        $cleverReachDetailsBinary += $cleverreachDetailsBinaryValues[$_]
    }
}

# Log
$logfile = $settings.logfile

<#
# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
    $settings.sqliteDb = "$( $settings.sqliteDb ).debug"
}
#>

################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}



################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################


# Create general settings
#$keyfilename = $settings.aesFile
$auth = "Bearer $( $settings.token )"
$header = @{ "Authorization" = $auth }
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
#$successFile = $settings.buildNowFile


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################

[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
$currentTimestampDateTime = Get-DateTimeFromUnixtime -unixtime $currentTimestamp -inMilliseconds -convertToLocalTimezone


Write-Log -message "Current timestamp: $( $currentTimestamp )"


################################################
#
# CHECK CONNECTION AND LOGIN
#
################################################

$ping = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/ping.json" -Headers $header -Verbose

$validAUth = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/validate.json" -Headers $header -Verbose


# Exit if no limit is delivered
if ( $ping -and $validAuth ) {
    
    Write-Log -message "Connection succeeded. Quote of CleverReach: $( $ping )"

} else {
    
    Write-Log -message "No connection available -> exit"
    throw [System.IO.InvalidDataException] "No connection and/or valid authentication available"
    
}


################################################
#
# DEBUG AND ACCOUNT INFORMATION
#
################################################

$ttl = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/ttl.json" -Headers $header -Verbose
$whoAmI = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/whoami.json" -Headers $header -Verbose

Write-Log -message "Token valid until '$( $ttl.date  )'"
Write-Log -message "Using login via '$( $whoAmI.login_domain )'"



################################################
#
# DOWNLOAD GROUP METADATA
#
################################################

Write-Log -message "Downloading all groups/lists"

#-----------------------------------------------
# DOWNLOAD GROUP METADATA
#-----------------------------------------------

$groupsUrl = "$( $settings.base )groups.json"
$groups = Invoke-RestMethod -Method Get -Uri $groupsUrl -Headers $header

Write-Log -message "Found '$( $groups.Count )' groups"

#-----------------------------------------------
# ASK FOR GROUPS TO DO SOMETHING
#-----------------------------------------------

$groupsSelection = $groups |  Out-GridView -PassThru


################################################
#
# DOWNLOAD ALL GROUPS RECEIVERS
#
################################################

# Download all data and one call per group

# write all single groups and additional attributes
$detailLevel = $cleverReachDetailsBinary # Detail depth (bitwise combinable) (0: none, 1: events, 2: orders, 4: tags).
#$attributes = Invoke-RestMethod -Method Get -Uri "$( $settings.base )attributes.json" -Headers $header -Verbose # load global attributes first
#$contacts = @()

$groupsSelection | ForEach {
    
    $groupId = $_.id
    $page = 0
    Write-Log -message "Downloading group id $( $groupId )"
    
    # Downloading attributes
    #$attributes += Invoke-RestMethod -Method Get -Uri "$( $groupsUrl )/$( $groupId )/attributes" -Headers $header -Verbose # add local attributes
    $upload = @()
    do {

        $url = "$( $groupsUrl )/$( $groupId )/receivers?pagesize=$( $settings.pageLimitGet )&page=$( $page )&detail=$( $detailLevel )&type=active" # active|inactive
        $result = Invoke-RestMethod -Method Get -Uri $url -Headers $header -Verbose

        #$contacts += $result
        
        #Write-Log -message "Loaded $( $result.count ) 'contacts' in total"


        if ( $result.Count -gt 0 ) {

            #-----------------------------------------------
            # CREATE UPSERT OBJECT
            #-----------------------------------------------


            $uploadObject = @()
            For ($i = 0 ; $i -lt $result.count ; $i++ ) {

                $uploadEntry = [PSCustomObject]@{
                    email = $result[$i].email
                    deactivated = 1
                }

                $uploadObject += $uploadEntry

            }


            #-----------------------------------------------
            # UPSERT DATA INTO GROUP
            #-----------------------------------------------

            $object = "groups"
            $endpoint = "$( $groupsUrl )/$( $groupId )/receivers/upsertplus"
            $bodyJson = $uploadObject | ConvertTo-Json
            $contentType = "application/json;charset=utf-8"

            $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 

            Write-Log -message "Deactivated $( $upload.count ) 'contacts' in total"

        }

        #$page += 1

    } while ( $result.Count -eq $settings.pageLimitGet )
    
    Write-Log -message "Done with deactivating $( $upload.count ) 'contacts' in group '$( $groupId )'"

}


#-----------------------------------------------
# WAIT FOR PRESS
#-----------------------------------------------


read-host “Press ENTER to continue...”