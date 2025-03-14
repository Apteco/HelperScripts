
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
        "count" = "100"
        "includeDeleted" = "onlyNotDeleted"
        "filter" = "(status neq 'Archived')"
    }
}
$userAudiences = Invoke-Apteco @params
$userAudiences.list | ft

# Choose a specific folder
$chooseAudience = $userAudiences.list | Out-GridView -PassThru


#-----------------------------------------------
# GET EXPORT FORMATS
#-----------------------------------------------

#$lastExportTemplate = Invoke-Apteco -key "GetLastExportedAudienceExportTemplate" -additional @{"dataViewName"=$dataview;"audienceId"=$chooseAudience.id;"systemName"=$system}

$exportTemplates = Invoke-Apteco -key "GetUserAudienceExportTemplates" -additional @{"dataViewName"=$dataview;"username"=$settings.login.user}
$chooseExportTemplate = $exportTemplates.list | Out-GridView -PassThru



#$Script:endpoints | out-gridview -PassThru





#-----------------------------------------------
# EXPORT AUDIENCE
#-----------------------------------------------

$body = @{
    "maximumNumberOfRowsToBrowse" = 10000
    "returnBrowseRows" = $true
    #"filename" = "20230308_01.csv"
    <#
    "output" = @{
      "format" = "CSV"
      "delimiter" = ";"
      "alphaEncloser" = ""
      "numericEncloser" = ""
      "authorisationCode" = ""
      "exportExtraName" = ""
    }
    #>
    "columns" = @(
        $chooseExportTemplate.exportTemplateDefinition.exportTemplateColumns | select * -ExcludeProperty columnType
    )
    "generateUrnFile" = $false
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
    "body" = ConvertTo-Json -InputObject $body -Depth 99
}


$audienceExport = Invoke-Apteco @params
exit 0


#-----------------------------------------------
# PARSE EXPORT
#-----------------------------------------------

$maxColumns = $audienceExport.columns.Count
$parsedRows = [System.Collections.ArrayList]@()
$audienceExport.rows | ForEach {
    
    $row = $_
    $pscustom = [PSCustomObject]@{}
    $parsedCodes = $row.codes -split "`t",$maxColumns
    $parsedDescriptions = $row.descriptions -split "`t",$maxColumns
    
    For ($i = 0; $i -lt $maxColumns; $i++) {
        $col = $audienceExport.columns[$i]
        if ( $col.detail -eq "Code" ) {
            $pscustom | Add-Member -MemberType NoteProperty -Name $col.columnHeader -Value $parsedCodes[$i]
        } else {
            $pscustom | Add-Member -MemberType NoteProperty -Name $col.columnHeader -Value $parsedDescriptions[$i]
        }
    }
    [void]$parsedRows.Add($pscustom)
}

#($audienceExport.rows | select -first 100 ).descriptions | ConvertFrom-Csv -Delimiter "`t" -Header $audienceExport.columns.columnHeader | Out-GridView
