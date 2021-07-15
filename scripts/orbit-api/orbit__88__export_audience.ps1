
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
# MISC ABOUT THE SYSTEM
#
################################################

#-----------------------------------------------
# SET DATAVIEW AND SYSTEM
#-----------------------------------------------

# Set DataView
$dataview = $settings.login.dataView

# Get Systems
$systems = Invoke-Apteco -key "GetFastStatsSystems" -additional @{dataViewName=$dataview}

# Choose system 
# TODO [ ] is viewName the correct one?
if ( $systems.totalCount -gt 1 ) {
    $system = ( $systems.list | Out-GridView -PassThru ).viewName
} elseif ( $systems.totalCount -eq 0 ) {
    "No systems"
    exit 0
} else {
    $system = $systems.list[0].viewName
}


#-----------------------------------------------
# GET AUDIENCES
#-----------------------------------------------

# Get all audiences, admins can use GetAllAudiences for all independent from the user
$params = @{
    "key" = "GetUserAudiences"
    "additional" = @{
        "dataViewName"=$dataview
        "systemName"=$system
        "username"=$settings.login.user
    }
    "query" = @{
        "orderBy" = "-createdOn"
        "offset" = "0"
        "count" = "10"
        "includeDeleted" = "onlyNotDeleted"
        "filter" = "(status neq 'Archived')"
    }
}
$userAudiences = Invoke-Apteco @params
$userAudiences.list | ft

# Choose a specific folder
$chooseAudience = $userAudiences.list | Out-GridView -PassThru


#-----------------------------------------------
# EXPORT AUDIENCES
#-----------------------------------------------

$body = @{
    "maximumNumberOfRowsToBrowse" = 10
    "returnBrowseRows" = $true
    "filename" = "hello.csv"
    "output" = @{
      "format" = "CSV"
      "delimiter" = ";"
      "alphaEncloser" = ""
      "numericEncloser" = ""
      "authorisationCode" = ""
      "exportExtraName" = ""
    }
    "columns" = @(
        @{
          "id" = "0"
          "variableName" = "HaKunden"
          "columnHeader" = "KundenId"
          "detail" = "Description" # Code|Description
        }
        @{
          "id" = "1"
          "variableName" = "HaVornam"
          "columnHeader" = "Vorname"
          "detail" = "Description" # Code|Description
        }
    )
    "generateUrnFile" = $true
  }

$params = @{
    "key" = "ExportAudienceLatestUpdateSync"
    "additional" = @{
        "dataViewName"=$dataview
        "systemName"=$system
        "audienceId"=$chooseAudience.id
    }
    "contentType" = "application/json-patch+json"
    "verboseCall" = $true
    "body" = $body | ConvertTo-Json -Depth 20
}
$audienceExport = Invoke-Apteco @params


#-----------------------------------------------
# COPY THE AUDIENCES EXPORT/URN FILE
#-----------------------------------------------

$params = @{
    "key" = "CopyFile"
    "additional" = @{
        "dataViewName"=$dataview
        "systemName"=$system
        "toFilePath"="20210715\urn-file.urn"
    }
    "query" = @{
        "fromFilePath" = $audienceExport.urnFilePath
        "targetBaseDirectory" = "Private"
    }
    "contentType" = "application/json-patch+json"
    "verboseCall" = $true
}
$copyFile = Invoke-Apteco @params