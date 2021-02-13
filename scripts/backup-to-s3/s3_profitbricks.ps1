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
$modulename = "S3"
$timestamp = [datetime]::Now


# [ ] implement settings file and encrypted keys
$settings = @{
   
    accessKey = "accesskey" # ENTER YOUR ACCESS KEY
    secretKey = "secretkey" # ENTER YOUR SECRET KEY
    region = "s3-de-central"
    service = "s3"
    baseUrl = "https://s3-de-central.profitbricks.com/"
    
    changeTLS = $true
    logfile = "$( $scriptPath )\s3.log"


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
    $settings.sqliteDb = "$( $settings.sqliteDb ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

Add-Type -AssemblyName System.Web

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

<#
# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}
#>

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
# MORE FUNCTIONS
#
################################################


function Invoke-S3 {

    [CmdletBinding()]
    param (

         [Parameter(Mandatory=$false)][string]$bucket = ""
        ,[Parameter(Mandatory=$false)][String]$verb = "GET"
        ,[Parameter(Mandatory=$false)][string]$objectKey = ""                                       # the key/path to the file in the bucket
        ,[Parameter(Mandatory=$false)][string]$localfile = ""                                       # the local file to upload or download destination
        ,[Parameter(Mandatory=$false)][string]$contentType = "text/plain"                           # default content type
        ,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://s3-de-central.profitbricks.com/"  # default url to use
        ,[Parameter(Mandatory=$false)][Switch]$storeEncrypted = $false                              # TODO [ ] implement this flag
        ,[Parameter(Mandatory=$false)][Switch]$keepFolderStructure = $true                          # keep the folder when downloading files
        ,[Parameter(Mandatory=$false)][Switch]$overwriteLocalfile = $false                          # should the local file overridden if already existing?
    )

    begin {

        #-----------------------------------------------
        # PREPARE
        #-----------------------------------------------

        # date operations
        $currentDate = Get-Date
        $date = $currentDate.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
        $dateStamp = $currentDate.ToUniversalTime().ToString("yyyyMMdd")

        # setup scope
        $scope = "$( $dateStamp )/$( $settings.region )/$( $settings.service )/aws4_request"

        # Sanitize strings
        $verbUpper = $verb.ToUpper()
        $escapedObjectKey = [uri]::EscapeDataString($objectKey) -replace "%2F","/"

        # add bucket and dot if it is used
        [System.Uri]$endpoint = "$( $uri.Scheme )://$( $bucket )$( if ($bucket -ne '') { '.' } )$( $uri.Host )/$( $escapedObjectKey )"

        # file hash for upload, otherwise hash of empty string
        if ( $verbUpper -eq "PUT" -and $localfile -ne "") {           
            # work out hash value
            $contentHash = (( Get-FileHash $f.FullName -Algorithm "SHA256" ).Hash ).ToLower()
        } else {
            $contentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }

        

    }

    process {
        
        #-----------------------------------------------
        # CANONICAL REQUEST
        #-----------------------------------------------

        #$canonicalRequestPlain = "$( $verbUpper )`n/$( $escapedObjectKey )`n`ncontent-type:$( $contentType )`nhost:$( $endpoint.Host )`nx-amz-content-sha256:$( $contentHash )`nx-amz-date:$( $date )`n`ncontent-type;host;x-amz-content-sha256;x-amz-date`n$( $contentHash )"
        $canonicalRequestPlain = @"
$( $verbUpper )
/$( $escapedObjectKey )

content-type:$( $contentType )
host:$( $endpoint.Host )
x-amz-content-sha256:$( $contentHash )
x-amz-date:$( $date )

content-type;host;x-amz-content-sha256;x-amz-date
$( $contentHash )
"@
        $canonicalRequestHash = Get-StringHash -inputString $canonicalRequestPlain -hashName "SHA256"


        #-----------------------------------------------
        # STRING TO SIGN
        #-----------------------------------------------
        
        $stringToSign = "AWS4-HMAC-SHA256`n$( $date )`n$( $scope )`n$( $canonicalRequestHash )"


        #-----------------------------------------------
        # SIGNATURE KEY
        #-----------------------------------------------

        $secret = "AWS4$( $settings.secretKey )"
        $kDate = Get-StringHash -inputString $dateStamp -hashName "HMACSHA256" -key $secret
        $kRegion = Get-StringHash -inputString $settings.region -hashName "HMACSHA256" -key $kDate -keyIsHex
        $kService = Get-StringHash -inputString $settings.service -hashName "HMACSHA256" -key $kRegion -keyIsHex
        $sign = Get-StringHash -inputString "aws4_request" -hashName "HMACSHA256" -key $kService -keyIsHex


        #-----------------------------------------------
        # SIGNATURE
        #-----------------------------------------------

        # Combines "String to sign" with the "Signature Key"
        $signatureHash = Get-StringHash -inputString $stringToSign -hashName "HMACSHA256" -key $sign -keyIsHex
        

        #-----------------------------------------------
        # HEADERS
        #-----------------------------------------------

        $headers = @{
            "Host" = $endpoint.Host
            "Content-Type" = $contentType
            "x-amz-content-sha256" = $contentHash
            "x-amz-date" = $date
            "Authorization" = "AWS4-HMAC-SHA256 Credential=$($settings.accessKey)/$($scope),SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,Signature=$( $signatureHash )"
        }


        #-----------------------------------------------
        # PREPARE LOCAL STRUCTURE
        #-----------------------------------------------


        if ( $localfile -ne "" ) {

            $path = "."  # TODO [ ] maybe change to another root folder

            # Create folder structure if wished
            if ( $keepFolderStructure ) {

                $pathParts = $objectKey -split "/" 
                $pathParts | select -SkipLast 1 | ForEach {
                    $part = $_
                    $path = Join-Path $path -ChildPath $part #-Resolve
                }
                #$resolvedPath = Resolve-Path -Path $path -
                if ( $pathparts.count -gt 1 -and !(Test-Path -Path $path) ) {
                    New-Item -Path $path -ItemType Directory
                }
                $localFilepath = Join-Path -Path $path -ChildPath $pathParts[-1] 
    
            } else {
    
                $pathParts = $objectKey -split "/" 
                $pathToResolve = Join-Path -Path $path -ChildPath $pathParts[-1] 
                $localFilepath = Resolve-Path -Path $pathToResolve
    
            }

            # Remove file if already exists
            if ( $overwriteLocalfile ) {
                Remove-Item -Path $localFilepath -Force
            }


        }
        

        #-----------------------------------------------
        # CALL API
        #-----------------------------------------------

        # Default Call
        $callParams = @{
            uri = $endpoint
            method = $verbUpper
            headers = $headers
            verbose = $true
        }

        # Choose if file should be uploaded or downloaded
        if ( $localfile -ne "" ) {
            if ( $verbUpper -eq "PUT" ) {
                $callParams += @{
                    InFile = $localFilepath
                }
            } else {
                $callParams += @{
                    OutFile = $localFilepath
                }
            }
        }



        $result = Invoke-RestMethod @callParams
        

    }
    
    end {
        
        #-----------------------------------------------
        # RETURN RESULT
        #-----------------------------------------------

        $result

    }

}


################################################
#
# TEST CALLS
#
################################################



# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols


#-----------------------------------------------
# LISTS BUCKETS
#-----------------------------------------------

$buckets = Invoke-S3 -uri $settings.baseUrl
$chooseBucket = $buckets.ListAllMyBucketsResult.Buckets.Bucket | Out-GridView -PassThru | select -First 1


#-----------------------------------------------
# LIST FILES OF BUCKETS
#-----------------------------------------------

$bucket = Invoke-S3 -uri $settings.baseUrl -bucket $chooseBucket.name
$chooseFiles = $bucket.ListBucketResult.contents | Out-GridView -PassThru

exit 0

#-----------------------------------------------
# DOWNLOAD FILES TO LOCAL
#-----------------------------------------------

$chooseFiles | ForEach {

    $f = $_
    $f.Key
    $filename = ( $f.Key -split "/" )[-1]
    $contentType = [System.Web.MimeMapping]::GetMimeMapping($filename)
    $destination = ".\$( $filename )"

    Invoke-S3 -uri $settings.baseUrl -bucket $chooseBucket.name -objectKey $f.Key -localfile $destination -contentType $contentType -keepFolderStructure

}

exit 0

#-----------------------------------------------
# REMOVE FILES
#-----------------------------------------------

$chooseFiles | ForEach {

    $f = $_   
    Invoke-S3 -uri $settings.baseUrl -bucket $chooseBucket.name -objectKey $f.Key -verb "DELETE"

}

exit 0

#-----------------------------------------------
# UPLOAD FILES
#-----------------------------------------------


$fileToUpload = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\backup-to-s3\_archive\sergey-sokolov-yxJavcfExYs-unsplash.jpg"
Set-Location -Path $scriptPath # Needed for the relativ part in the next step
$objectkey = ( Resolve-Path -Path $fileToUpload -Relative ) -replace "\.\\","" -replace "\\","/"

Invoke-S3 -uri $settings.baseUrl -bucket $chooseBucket.name -objectKey $objectkey -localfile $fileToUpload -verb "PUT"



