#Usage example:
# .\trigger-import-and-build.ps1 -UserLogin "admin" -Password "password" -DataSourceIds @(1,2,3) -SystemDefinitionId 1 -LoginBaseUrl "http://localhost:60080" -ApiBaseUrl "https://localhost:7236" -DataViewName "holidays"

param (
    [Parameter(Mandatory=$true)]
    [string]$UserLogin,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [int[]]$DataSourceIds,
    
    [Parameter(Mandatory=$true)]
    [int]$SystemDefinitionId,
    
    [Parameter(Mandatory=$false)]
    [string]$LoginBaseUrl = "http://localhost:60080",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiBaseUrl = "https://localhost:7236",
    
    [Parameter(Mandatory=$false)]
    [string]$DataViewName = "holidays"
)

# Login function
function Connect-DataView {
    param (
        [string]$UserLogin,
        [string]$Password,
        [string]$DataViewName,
        [string]$LoginBaseUrl,
        [string]$ClientType = "ClientType"
    )

    # Build the login URL with the data view name
    $loginUrl = "$LoginBaseUrl/$DataViewName/Sessions/SimpleLogin"

    # Build the form-encoded body
    $formData = "UserLogin=$UserLogin&Password=$Password&ClientType=$ClientType"

    # Set headers
    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    # Make the POST request
    try {
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Headers $headers -Body $formData
        
        # Extract the access token
        $accessToken = $response.accessToken
        Write-Host "Access Token: $accessToken"
        
        # Return the access token and built headers
        $authHeaders = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $accessToken"
        }
        
        return $authHeaders
    }
    catch {
        Write-Host "Error occurred during login: $_"
        return $null
    }
}

# Import data function
function Import-Data {
    param (
        [hashtable]$Headers,
        [int]$DataSourceId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [string]$ImportType = "Replace"
    )

    # Build the data import URL with the data view name
    $dataImportUrl = "$ApiBaseUrl/$DataViewName/DataImports"

    # Define the body for the request
    $body = @{
        "dataSourceId" = $DataSourceId
        "importType"   = $ImportType
    } | ConvertTo-Json

    try {
        # Make the POST request
        $response = Invoke-RestMethod -Uri $dataImportUrl -Method Post -Headers $Headers -Body $body
        $dataImportId = [int]$response
        Write-Host "Data Import ID: $dataImportId for DataSourceId: $DataSourceId"
        
        # Wait for the data import to complete
        Wait-ForImportCompletion -Headers $Headers -DataImportId $dataImportId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl
        
        return $dataImportId
    }
    catch {
        Write-Host "Error occurred during data import for DataSourceId $DataSourceId $_"
        return $null
    }
}

# Wait for import to complete
function Wait-ForImportCompletion {
    param (
        [hashtable]$Headers,
        [int]$DataImportId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [int]$CheckIntervalSeconds = 5
    )

    while ($true) {
        # Define the endpoint to check the status of the data import
        $statusUrl = "$ApiBaseUrl/$DataViewName/DataImports/$DataImportId/Status"

        try {
            # Make the GET request to check the status
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $Headers
            Write-Host "Import Status Response: $statusResponse"

            # Check if the status is 'Done'
            if ($statusResponse.state -eq "Done") {
                Write-Host "Import completed successfully."
                break
            }
        }
        catch {
            Write-Host "Error occurred while checking import status: $_"
        }

        # Wait before checking again
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Trigger system build function
function Start-SystemBuild {
    param (
        [hashtable]$Headers,
        [int]$SystemDefinitionId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [bool]$AutoDeploy = $true
    )

    # Build the system build URL with the data view name
    $buildUrl = "$ApiBaseUrl/$DataViewName/SystemBuilds"

    $body = @{
        "systemDefinitionId" = $SystemDefinitionId
        "settings" = @{
            "autoDeploy" = $AutoDeploy
        }
    } | ConvertTo-Json

    try {
        # Make the POST request
        $response = Invoke-RestMethod -Uri $buildUrl -Method Post -Headers $Headers -Body $body
        $systemBuildId = $response.id
        Write-Host "System Build ID: $systemBuildId"
        
        # Wait for the system build to complete
        Wait-ForBuildCompletion -Headers $Headers -SystemBuildId $systemBuildId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl
        
        # Get deployment ID
        $systemDeploymentId = Get-DeploymentId -Headers $Headers -SystemBuildId $systemBuildId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl
        
        # Wait for deployment to complete
        Wait-ForDeploymentCompletion -Headers $Headers -SystemDeploymentId $systemDeploymentId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl
        
        return $systemBuildId
    }
    catch {
        Write-Host "Error occurred during system build: $_"
        return $null
    }
}

# Wait for build to complete
function Wait-ForBuildCompletion {
    param (
        [hashtable]$Headers,
        [int]$SystemBuildId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [int]$CheckIntervalSeconds = 5
    )

    while ($true) {
        # Define the endpoint to check the status of the system build
        $statusUrl = "$ApiBaseUrl/$DataViewName/SystemBuilds/$SystemBuildId/Status"

        try {
            # Make the GET request to check the status
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $Headers
            Write-Host "Build Status Response: $statusResponse"

            # Check if the status is 'Done'
            if ($statusResponse.state -eq "Done") {
                Write-Host "Build completed successfully."
                break
            }
        }
        catch {
            Write-Host "Error occurred while checking build status: $_"
        }

        # Wait before checking again
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Get deployment ID
function Get-DeploymentId {
    param (
        [hashtable]$Headers,
        [int]$SystemBuildId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [int]$CheckIntervalSeconds = 5
    )

    while ($true) {
        # Using string formatting to ensure proper URL construction
        $statusUrl = "$ApiBaseUrl/$DataViewName/SystemBuilds/{0}?includeLatestDeploymentId=true" -f $SystemBuildId

        try {
            # Make the GET request to check the status
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $Headers
            Write-Host "Build Response: $statusResponse"

            if ($statusResponse.systemDeploymentId) {
                $systemDeploymentId = $statusResponse.systemDeploymentId
                Write-Host "System Deployment ID: $systemDeploymentId"
                return $systemDeploymentId
            }
        }
        catch {
            Write-Host "Error occurred while waiting for deployment ID: $_"
        }

        # Wait before checking again
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Wait for deployment to complete
function Wait-ForDeploymentCompletion {
    param (
        [hashtable]$Headers,
        [int]$SystemDeploymentId,
        [string]$DataViewName,
        [string]$ApiBaseUrl,
        [int]$CheckIntervalSeconds = 5
    )

    while ($true) {
        # Define the endpoint to check the status of the deployment
        $statusUrl = "$ApiBaseUrl/$DataViewName/SystemDeployments/$SystemDeploymentId/Status"

        try {
            # Make the GET request to check the status
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $Headers
            Write-Host "Deployment Status Response: $statusResponse"

            # Check if the status is 'Done'
            if ($statusResponse.state -eq "Done") {
                Write-Host "Deployment completed successfully."
                break
            }
        }
        catch {
            Write-Host "Error occurred while checking deployment status: $_"
        }

        # Wait before checking again
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Main execution

Write-Host "Starting workflow with the following parameters:"
Write-Host "UserLogin: $UserLogin"
Write-Host "DataSourceIds: $($DataSourceIds -join ', ')"
Write-Host "SystemDefinitionId: $SystemDefinitionId"
Write-Host "DataViewName: $DataViewName"
Write-Host "LoginBaseUrl: $LoginBaseUrl"
Write-Host "ApiBaseUrl: $ApiBaseUrl"

# Step 1: Login and get authentication headers
$headers = Connect-DataView -UserLogin $UserLogin -Password $Password -DataViewName $DataViewName -LoginBaseUrl $LoginBaseUrl

if ($null -eq $headers) {
    Write-Host "Login failed. Exiting workflow."
    exit 1
}

# Step 2: Import data - either sequentially or in parallel
$allImportsSuccessful = $true

# Import data sequentially
Write-Host "Starting sequential data import for all data sources..."
foreach ($dataSourceId in $DataSourceIds) {
    Write-Host "Processing DataSourceId: $dataSourceId"
    $dataImportId = Import-Data -Headers $headers -DataSourceId $dataSourceId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl
    
    if ($null -eq $dataImportId) {
        Write-Host "Data import failed for DataSourceId: $dataSourceId. Continuing with next data source."
        $allImportsSuccessful = $false
    }
}

if (-not $allImportsSuccessful) {
    Write-Host "One or more data imports failed. Continuing with system build..."
}

# Step 3: Start system build and deployment
$systemBuildId = Start-SystemBuild -Headers $headers -SystemDefinitionId $SystemDefinitionId -DataViewName $DataViewName -ApiBaseUrl $ApiBaseUrl

if ($null -eq $systemBuildId) {
    Write-Host "System build failed. Exiting workflow."
    exit 1
}

Write-Host "Workflow completed successfully!"
exit 0