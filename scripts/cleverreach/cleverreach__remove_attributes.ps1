﻿################################################
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
    logfile = "$( $scriptPath )\cleverreach_attributes_remove.log"
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


################################################
#
# DOWNLOAD ATTRIBUTES METADATA
#
################################################

$attributesUrl = "$( $settings.base )attributes.json?group_id=0"
$globalAttributes = Invoke-RestMethod -Method Get -Uri $attributesUrl -Headers $header

$localAttributes = @()
$groups | ForEach {
    $group = $_
    Write-Host $group.name
    $attributesUrl = "$( $settings.base )attributes.json?group_id=$( $group.id )"
    $localAttributes += Invoke-RestMethod -Method Get -Uri $attributesUrl -Headers $header
}



Write-Log -message "Found '$( $localAttributes.Count )' local attributes and $( $globalAttributes.count ) global"


#$localAttributes + $globalAttributes | export-csv -path ".\attributes.csv" -Delimiter "`t" -Encoding UTF8 -NoTypeInformation

#-----------------------------------------------
# ASK FOR ATTRIBUTES TO DO SOMETHING
#-----------------------------------------------

$attributesSelection = $localAttributes + $globalAttributes |  Out-GridView -PassThru #| select * -ExcludeProperty body_html,body_text |
# $mailings.draft | select * -ExcludeProperty body_html,body_text | export-csv -path ".\mailings.csv" -Delimiter "`t" -Encoding UTF8 -NoTypeInformation

exit 0
################################################
#
# REMOVING ATTRIBUTES
#
################################################

Write-Log -message "Removing selected attributes"

$results = @()
$attributesSelection | ForEach {
    $attribute = $_
    Write-Log -message "Removing attribute $( $attribute.id ) - $( $attribute.name )"
    $attributeUrl = "$( $settings.base )attributes.json/$( $attribute.id )"
    $results += Invoke-RestMethod -Method Delete -Uri $attributeUrl -Headers $header
}


#-----------------------------------------------
# WAIT FOR PRESS
#-----------------------------------------------


read-host “Press ENTER to continue...”