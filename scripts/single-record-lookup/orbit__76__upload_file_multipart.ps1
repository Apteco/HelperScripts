
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
# PREPARATION AND SESSION CREATION
#
################################################

. ".\orbit__60__preparation_for_examples.ps1"


################################################
#
# UPLOAD TEMPORARY FILE
#
################################################

<#
Some links for multipart upload

hint from https://stackoverflow.com/questions/36268925/powershell-invoke-restmethod-multipart-form-data
other: https://stackoverflow.com/questions/51739874/multipart-form-script-works-perfectly-in-powershell-but-not-in-powershell-core
with .NET classes https://get-powershellblog.blogspot.com/2017/09/multipartform-data-support-for-invoke.html
#>

#-----------------------------------------------
# CHOOSE FILE
#-----------------------------------------------

#$fileItem = Get-Item -Path "$( $params.Path )"
$fileItem = Get-Item -Path ".\danielle-macinnes-IuLgi9PWETU-unsplash.jpg"
$fileId = "$( $fileItem.name -replace $fileItem.Extension )__$( [System.Guid]::NewGuid().ToString() )$( $fileItem.Extension )"

Write-Log -message "Uploading file '$( $params.Path )'"
Write-Log -message "Using file id '$( $fileId )'"



#-----------------------------------------------
# PREPARE CHUNKS
#-----------------------------------------------

# TODO [ ] put no of parts or buffersize in settings
$noParts = $settings.multipart.noParts
$partPrefix = $settings.multipart.partPrefix
$secondsToWait = $settings.multipart.secondsToWait

# Log
Write-Log -message "Using file part prefix '$( $partPrefix )'"

# create chunks
Write-Log -message "Splitting into '$( $noParts )' files"
$buffer = $fileItem.Length / $noParts
Write-Log -message "Bytes per file '$( $buffer )'"
$chunks = Split-File-To-Chunks -inFile $fileItem.FullName -outPrefix $partPrefix -bufSize $buffer

# Prepare API call
#$endpoint = Get-Endpoint -key "UpsertTemporaryFilePart"


#-----------------------------------------------
# UPLOAD CHUNKS
#-----------------------------------------------

Write-Log -message "Uploading part by part, parallel upload not implemented yet"
$final = $false
$tempUpload = @()
for ( $i = 0; $i -lt $chunks.Length ; $i++ ) {

    # Choose part
    $partFile = $chunks[$i]
    if ( $i+1 -eq $chunks.Length ) { $final = $true }

    # Prepare part
    $multipart = Prepare-MultipartUpload -path $partFile -part $true
    #$uri = Resolve-Url -endpoint $endpoint -additional @{"id"=$fileId; "partNumber"=$i} -query @{"finalPart"="$( $final )".ToLower()}

    # Execute API call
    #$tempUpload += Invoke-RestMethod -Uri $uri -Method $endpoint.method -ContentType $multipart.contentType -Headers $headers -Body $multipart.body -Verbose
    Write-Log -message "Uploading part no $( $i )"
    $tempUpload += Invoke-Apteco -key "UpsertTemporaryFilePart" -additional @{"id"=$fileId; "partNumber"=$i} -query @{"finalPart"="$( $final )".ToLower()} -contentType $multipart.contentType -Body $multipart.body 

}        

# Wait a moment for the file to be processed
Write-Log -message "Upload done... Waiting for '$( $secondsToWait )' seconds"
Start-Sleep -Seconds $secondsToWait

# Remove part files
Write-Log -message "Removing part files"
$chunks | ForEach { Remove-Item $_ } 


#-----------------------------------------------
# CHECK UPLOAD RESULT
#-----------------------------------------------

$tempUpload

If ( $tempUpload[-1].temporaryFileCreated ) {
    Write-Log -message "Upload of $( $tempUpload[-1].partNumber + 1 ) parts successful"
} else {
    Write-Log -message "Upload not successful"
}


#-----------------------------------------------
# DOWNLOAD IN ONE PART
#-----------------------------------------------

# Where to save the file
$dlLocation = "$( $fileItem.DirectoryName )\$( $fileId )"

# Download file directly
#$endpoint = Get-Endpoint -key "GetTemporaryFile"
#$uri = Resolve-Url -endpoint $endpoint -additional @{"id"=$fileId}
#Invoke-RestMethod -Uri $uri -Method $endpoint.method -Headers $headers -Verbose -ContentType "application/octet-stream" -OutFile $dlLocation

Invoke-Apteco -key "GetTemporaryFile" -additional @{"id"=$fileId} -contentType "application/octet-stream" -outFile $dlLocation


