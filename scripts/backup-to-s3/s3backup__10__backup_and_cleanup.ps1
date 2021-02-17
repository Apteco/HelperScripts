################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
    }
}

################################################
#
# NOTES
#
################################################

<#

resource: https://devops.profitbricks.com/api/s3/
https://gist.github.com/chrismdp/6c6b6c825b07f680e710
https://gist.github.com/tabolario/93f24c6feefe353e14bd
https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html
http://czak.pl/2015/09/15/s3-rest-api-with-curl.html

# TODO [ ] implement multipart upload if needed
# TODO [ ] implement server side encryption if needed
# TODO [ ] implement MD5 checksum

https://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html
To ensure that data is not corrupted traversing the network, use the Content-MD5 header. When you use this header,
Amazon S3 checks the object against the provided MD5 value and, if they do not match, returns an error. Additionally,
you can calculate the MD5 while putting an object to Amazon S3 and compare the returned ETag to the calculated MD5 value. 
find out content type https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Function-to-6429566c

#>



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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
#$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "S3BACKUP"
$timestamp = [datetime]::Now


if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Assemblies
Add-Type -AssemblyName System.Web

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}


# Import Bits to download all files in once
#Import-Module BitsTransfer


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
# PREPARE 7Z ARCHIVES
#
################################################


$7z = $libExecutables | where { $_.Name -eq "7za.exe"  }
$archive = Join-Path -Path $settings.uploadFolder -ChildPath "$( $timestamp.ToString("yyyyMMddHHmmss") ).7z"

# For more information see https://thedeveloperblog.com/7-zip-examples
$arguments = @(
    "a"                                                                         # add to archive
    "-p$( Get-SecureToPlaintext $settings.'7z'.encryptionPassword )"        # use encryption password
    "-spf"                                                                      # use fully qualified file paths
    "-mx3"                                                                      # Compression level (1 fastest -> 9 slowest)
    #"-bt"                                                                       # show execution time statistics
    "-r"                                                                        # Recurse subdirectories
    "-mhe"                                                                      # Encrypt headers, so the filenames won't be readable without the password
    """$( $archive )"""                                                        # the 7z ending automatically uses AES256 for encryption
)

# Put folders and files into archive
$settings.objectsToBackup | ForEach {

    $path = $_

    Write-Log -message "Adding '$( $path )' to the archive '$( $archive )'"


    $arg = $arguments + @( """$( $path )""" )
    Start-Process -NoNewWindow -FilePath $7z.FullName -ArgumentList $arg -Wait

}



################################################
#
# UPLOAD TO S3
#
################################################


#-----------------------------------------------
# PREPARATION
#-----------------------------------------------

$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.s3.secretKey ) -AsPlainText -Force
$cred = [pscredential]::new( $settings.s3.accessKey, $stringSecure )
$s3 = [S3]::new( $cred, $settings.s3.baseUrl, $settings.s3.region, $settings.s3.service )


#-----------------------------------------------
# CHOOSE BUCKET
#-----------------------------------------------

$bucket = $s3.getBuckets() | where { $_.name -eq $settings.s3.bucket } | select -first 1


#-----------------------------------------------
# UPLOAD THE ARCHIVE
#-----------------------------------------------

$t = Measure-Command {
    $bucket.upload( $archive )
}

Write-Log -message "Uploaded '$( $archive )' to the bucket '$( $bucket.name )'"
Write-Log -message "The upload needed $( $t.TotalMinutes.toString("#.##") ) minutes in total"


################################################
#
# CLEANUP AT S3
#
################################################


#-----------------------------------------------
# DEFINE THE TIMEFRAME TO REMOVE
#-----------------------------------------------

$removeEarlierThan = [Datetime]::Today.AddDays( $settings.maxAgeOfArchives * -1 )


#-----------------------------------------------
# REMOVE ITEMS
#-----------------------------------------------

$bucket.getObjects() | where { $_.lastModified -lt $removeEarlierThan } | ForEach {
    $s3object = $_
    $s3object.remove()
    Write-Log -message "Removed the object '$( $s3object.key )' in bucket '$( $bucket.name )'"
}


################################################
#
# CLEANUP LOCALLY
#
################################################


Get-ChildItem -Path $settings.uploadFolder -File | where { $_.LastWriteTime -lt $removeEarlierThan } | ForEach {
    $f = Get-Item -Path $_
    Write-Log -message "Removed the archive '$( $f.FullName )'"
    Remove-Item -Path $f.FullName
}