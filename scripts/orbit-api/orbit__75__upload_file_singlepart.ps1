
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

#-----------------------------------------------
# CHOOSE FILE
#-----------------------------------------------

#$fileItem = Get-Item -Path "$( $params.Path )"
$fileItem = Get-Item -Path ".\danielle-macinnes-IuLgi9PWETU-unsplash.jpg"
$fileId = "$( $fileItem.name -replace $fileItem.Extension )__$( [System.Guid]::NewGuid().ToString() )$( $fileItem.Extension )"

Write-Log -message "Uploading file '$( $params.Path )'"
Write-Log -message "Using file id '$( $fileId )'"


#-----------------------------------------------
# UPLOAD IN ONE PART
#-----------------------------------------------

# Prepare multipart
$multipart = Prepare-MultipartUpload -path $fileItem.FullName

# Prepare API call
#$endpoint = Get-Endpoint -key "UpsertTemporaryFile"
#$uri = Resolve-Url -endpoint $endpoint -additional @{"id"=$fileId}

# Execute API call
#$tempUpload = Invoke-RestMethod -Uri $uri -Method $endpoint.method -ContentType $multipart.contentType -Headers $headers -Body $multipart.body -Verbose
$tempUpload = Invoke-Apteco -key "UpsertTemporaryFile" -additional @{"id"=$fileId} -contentType $multipart.contentType -Body $multipart.body 

# Result of upload
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

