################################################
#
# INPUT
#
################################################


Param (

)

################################################
#
# PATH
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
# TODO
#
################################################

<#

- [x] put settings in json file and create settings script with file dialogue
- [ ] put all properties of bing columns in a separate json file or in settings file
- [ ] check how not used columns can be cut out first
- [x] rewrite file at end with correct customer IDs
- [ ] ask for credentials automatically if needed
- [ ] split file in batches with 200k records for bing batch
- [ ] create more log output in extra logfile
- [ ] create hash value dynamically
- [ ] put files in guid directory rather than with a timestamp

#>



################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"
$moduleName = "GEOCODE"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.connection.changeTLSEncryption ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles


################################################
#
# FUNCTIONS
#
################################################

# Only needed for hashing
if ( $settings.encryption.hashId ) {

    Add-Type -AssemblyName System.Security, System.Text.Encoding
    
}

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

<#
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
#>

################################################
#
# SETUP
#
################################################

# settings for the API
$bingMapskey = Get-SecureToPlaintext $settings.login.token

# settings for the file to read
$file = $settings.inputfile.path
$delimiter = $settings.inputfile.delimiter

# mappings to the api format
$mapping = $settings.inputfile.mapping

# fixed values not contained in the file
$fixedValue = $settings.inputfile.fixedValues

# timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

# hashing of ID
$hashId = $settings.encryption.hashId
$hashMethod = $settings.encryption.hashMethod
$salt = -join ((65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_}) # use a fixed value like "abc" or this "-join ((65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})" for a random string

# ask for credentials if e.g. a proxy is used (normally without the prefixed domain)
#$cred = Get-Credential
#$proxyUrl = "http://proxy:8080"

# rewriting
$rewriting = $settings.rewrite.active
$rewriteMethod = $settings.rewrite.method

# export settings
$exportId = [guid]::NewGuid()
$exportFolder = New-Item -Name $exportId -ItemType "directory" # create folder for export
$exportFilePrefix = "$( $exportFolder.FullName )\$( $input.Name )"

# filenames
$translationFile = "$( $exportFolder.FullName )\$( $settings.exportfiles.translationFile )"
$translationSuccess = "$( $exportFolder.FullName )\$( $settings.exportfiles.translationSuccess )"
$translationFailed = "$( $exportFolder.FullName )\$( $settings.exportfiles.translationFailed )"
$successFile = "$( $exportFolder.FullName )\$( $settings.exportfiles.successFile )"
$failedFile = "$( $exportFolder.FullName )\$( $settings.exportfiles.failedFile )"




################################################
#
# LOAD AND TRANSFORM FILE
#
################################################

# [ ] Check, if all headers were used

$headerRow = ( Get-Content $file -First 1 -Encoding UTF8).Split( $delimiter ).replace('"',"")

$mappedHeader = @()
$headerRow | ForEach {
    $mappedHeader += $mapping.$_
}

$csv = Get-Content -Path $file -Encoding UTF8 | Select -Skip 1 | ConvertFrom-Csv -Delimiter $delimiter -Header $mappedHeader
if ( $hashId ) {
    
    $translation = $csv | Select @{name=$hashMethod;expression={ Get-StringHash -inputString $_.Id -hashName $hashMethod -salt $salt -uppercase $true }}, *
    $csv = $translation | Select @{name="Id";expression={ $_.$hashMethod }}, * -ExcludeProperty Id, $hashMethod
    
    # write out translation of ID and Hash
    $translation | Select Id, $hashMethod | Export-Csv -Path $translationFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

}




$fixedValue.Keys | ForEach {
   
    $key = $_
    $value = $fixedValue.$_
   
    $csv = $csv | Select *, @{ name="$( $key )";expression={ $value }}

}


<#

https://msdn.microsoft.com/en-us/library/ff701737.aspx

# examples for input
https://msdn.microsoft.com/en-us/library/jj735475.aspx

#>


# properties from https://msdn.microsoft.com/en-us/library/jj735477.aspx
$properties = "Id
GeocodeRequest/Culture
GeocodeRequest/Query
GeocodeRequest/Address/AddressLine
GeocodeRequest/Address/AdminDistrict
GeocodeRequest/Address/CountryRegion 
GeocodeRequest/Address/AdminDistrict2
GeocodeRequest/Address/FormattedAddress
GeocodeRequest/Address/Locality
GeocodeRequest/Address/PostalCode
GeocodeRequest/Address/PostalTown
GeocodeRequest/ConfidenceFilter/MinimumConfidence
ReverseGeocodeRequest/IncludeEntityTypes
ReverseGeocodeRequest/Location/Latitude
ReverseGeocodeRequest/Location/Longitude
GeocodeResponse/Address/AddressLine
GeocodeResponse/Address/AdminDistrict
GeocodeResponse/Address/CountryRegion
GeocodeResponse/Address/AdminDistrict2
GeocodeResponse/Address/FormattedAddress
GeocodeResponse/Address/Locality
GeocodeResponse/Address/PostalCode
GeocodeResponse/Address/PostalTown
GeocodeResponse/Address/Neighborhood
GeocodeResponse/Address/Landmark
GeocodeResponse/Confidence
GeocodeResponse/Name
GeocodeResponse/EntityType
GeocodeResponse/MatchCodes
GeocodeResponse/Point/Latitude
GeocodeResponse/Point/Longitude
GeocodeResponse/BoundingBox/SouthLatitude
GeocodeResponse/BoundingBox/WestLongitude
GeocodeResponse/BoundingBox/NorthLatitude
GeocodeResponse/BoundingBox/EastLongitude
GeocodeResponse/QueryParseValues
GeocodeResponse/GeocodePoints
StatusCode
FaultReason
TraceId"

# format result tab-delimited without type information and remove quotes
$inputList = $csv | Select $properties.Split("`n").Trim() | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % {$_ -replace '"',""}
$body = @( "Bing Spatial Data Services, 2.0" ) + $inputList


################################################
#
# CALL GEOCODING
#
################################################

$input = "tab" # xml|csv|tab|pipe
$output = "json" # json|xml
$contentType = "text/plain; charset=utf-8" # text/plain|application/xml|application/octet-stream

$url = "https://spatial.virtualearth.net/REST/v1/dataflows/geocode?input=$( $input )&output=$( $output )&key=$( $bingMapskey )"

try {
    $res = Invoke-RestMethod -Uri $url -ContentType $contentType -Verbose -Body ( $body -join "`r`n" ) -Method Post # -ProxyUseDefaultCredentials $true # -Proxy $proxyUrl -ProxyCredential $cred
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
}


################################################
#
# CHECK STATUS & DOWNLOAD RESULT
#
################################################

if ( $res.statusCode -eq [System.Net.HttpStatusCode]::Created.value__ ) {
    
    # Get the resources for the job
    $jobId = $res.resourceSets.resources.id
    $jobUrl = $res.resourceSets.resources.links.url
    $output = "json" # json|xml

    # Check current status of job
    Do {
        $status = Invoke-RestMethod -Method Get -Uri "$( $jobUrl )?output=$( $output )&key=$( $bingMapsKey )" -Verbose
        Start-Sleep -s 30
    } Until ( $status.resourceSets.resources.status -eq "Completed" )

    # Get URLs for results
    $succeededUrl = ( $status.resourceSets.resources.links | where { $_.name -eq "succeeded" } ).url
    $failedUrl = ( $status.resourceSets.resources.links | where { $_.name -eq "failed" } ).url
    
    # Download available results
    if ( $succeededUrl.Length -gt 0 ) {
        $downloadSuccessFile = "$( $exportFolder.FullName )\success.txt"
        Invoke-RestMethod -Method Get -Uri "$( $succeededUrl )?key=$( $bingMapsKey )" -Verbose -OutFile $downloadSuccessFile # -ProxyUseDefaultCredentials $true # -Proxy $proxyUrl -ProxyCredential $cred
        if ( $rewriting ) {
            Switch ( $rewriteMethod ) {
                "full" { 
                <#
                Write-Log -message "Start to create a new file"

                $t = Measure-Command {
                    $fileItem = Get-Item -Path $file
                    $exportId = Split-File -inputPath $fileItem.FullName `
                                        -header $true `
                                        -writeHeader $true `
                                        -inputDelimiter "`t" `
                                        -outputDelimiter "`t" `
                                        -outputColumns $listAttributes `
                                        -writeCount $maxWriteCount `
                                        -outputDoubleQuotes $false `
                                        -outputPath $uploadsFolder
                }

                Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"
                #>
                    rewriteFileInOnce -inputPath $downloadSuccessFile -outputPath $successFile -skipFirstLines 1
                    
                }
                "stream" {
                    rewriteFileAsStream -inputPath $downloadSuccessFile -outputPath $successFile -inputEncoding ([System.Text.Encoding]::UTF8.CodePage) -outputEncoding ([System.Text.Encoding]::UTF8.CodePage) -skipFirstLines 1                
                }
            }
        }
    }
    if ( $failedUrl.Length -gt 0 ) {
        $downloadFailedFile = "$( $exportFolder.FullName )\failed.txt"
        Invoke-RestMethod -Method Get -Uri "$( $failedUrl )?key=$( $bingMapsKey )" -Verbose -OutFile $downloadFailedFile # -ProxyUseDefaultCredentials $true # -Proxy $proxyUrl -ProxyCredential $cred
        if ( $rewriting ) {           
            Switch ( $rewriteMethod ) {
                "full" { 
                    rewriteFileInOnce -inputPath $downloadFailedFile -outputPath $failedFile -skipFirstLines 1
                }
                "stream" {
                    rewriteFileAsStream -inputPath $downloadFailedFile -outputPath $failedFile -inputEncoding ([System.Text.Encoding]::UTF8.CodePage) -outputEncoding ([System.Text.Encoding]::UTF8.CodePage) -skipFirstLines 1                
                }
            }
        }
    }
    
}


################################################
#
# REWRITE FILES WITH URN
#
################################################

# create a hashtable of id and hash
$hashTable = @{}
$translation | ForEach {
    $hashTable[$_.$hashMethod] = $_.Id
}

# TODO [ ] implement faster rewriting methods here

# Translate send back files
if ( $hashId -and $rewriting ) {
    
    If (Check-Path -Path $successFile ) {
        $csvSuccess = Import-Csv -Path $successFile -Encoding UTF8 -Delimiter $delimiter
        $csvTranslatedSuccess = $csvSuccess | Select @{name="Id";expression={ $hashTable[$_.Id] }}, * -ExcludeProperty Id
        $csvTranslatedSuccess | Export-Csv -Path $translationSuccess -Encoding UTF8 -Delimiter "`t" -NoTypeInformation
    }

    If (Check-Path -Path $failedFile ) {
        $csvFailed = Import-Csv -Path $successFile -Encoding UTF8 -Delimiter $delimiter
        $csvTranslatedFailed = $csvFailed | Select @{name="Id";expression={ $hashTable[$_.Id] }}, * -ExcludeProperty Id
        $csvTranslatedFailed | Export-Csv -Path $translationFailed -Encoding UTF8 -Delimiter "`t" -NoTypeInformation
    }

}
