
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
# CHOOSE FILEROOT
#-----------------------------------------------

# Get System root (private, public, cascade)
$systemRoot = Invoke-Apteco -key "GetRootFiles" -additional @{dataViewName=$dataview;systemName=$system}
$systemRoot.list | ft

# Choose a specific folder
$chooseRoot = $systemRoot.list | Out-GridView -PassThru
#$chooseRoot = $systemRoot.list | where { $_.name -eq "Private" }


#-----------------------------------------------
# LOAD FILES FROM A FOLDER
#-----------------------------------------------

# The parameters can also be defined in a separate object instead of the calling line
$params = @{
    dataViewName=$dataview
    systemName=$system
    directoryPath=$chooseRoot.path
    offset=10
    count=30
}
$files = Invoke-Apteco -key "GetFiles" -additional $params

# List the result
$files.list | ft

# Choose a file
$chooseFile = $files.list | where { $_.type -in @("Selection") } | Out-GridView -PassThru
#$chooseFile = $files.list | where { $_.name -eq "ActiveCustomers.xml" }


#-----------------------------------------------
# LOAD QUERY DEFINITION IN JSON (INSTEAD OF LOADING RAW XML)
#-----------------------------------------------

$body = @{
    "path" = $chooseFile.path
}
$bodyJson = $body | ConvertTo-Json -Depth 8
$chosenFileQuery = Invoke-Apteco -key "GetQueryFromFileSync" -additional @{dataViewName=$dataview;systemName=$system} -body $bodyJson

# Output as json on console
$chosenFileQuery.query | ConvertTo-Json -depth 20



################################################
#
# EXPORT A SELECTION AS URN FILE
#
################################################

$filename = "$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).csv"

$exportBody = @{
  "baseQuery"= $chosenFileQuery.query
  "resolveTableName"="Customers"
  "maximumNumberOfRowsToBrowse" = 10
  "returnBrowseRows" = $true
  "pathToExportTo" = "Private/$( $filename )"
  #"urnFilePath" = "Private/$( $filename ).urn"
  #"urnPathToExportTo" = "Private/$( $filename ).urn"
  "output" = @{
    "format" = "CSV" # CSV|URN|XLSX
    "delimiter" = ";"
    "alphaEncloser" = """"
    "numericEncloser" = ""
    "authorisationCode" = ""
    "exportExtraName" = ""
    #"outputUrnWithExport" = $true
    #"urnPath"="Private/$( $filename ).urn"
  }
  "columns" = @(
    @{
      "id" = "0"
      "variableName" = "CuEntity"
      "columnHeader" = "URN-ID"
      "detail" = "Description" # Code|Description
    },
    @{
      "id" = "1"
      "variableName" = "CuFirstn"
      "columnHeader" = "Firstname"
      "detail" = "Description" # Code|Description
    },
    @{
      "id" = "2"
      "variableName" = "CuLastna"
      "columnHeader" = "Lastname"
      "detail" = "Description" # Code|Description
    }
  )
  "limits" = @{
    "sampling" = "All"
    "stopAtLimit" = $true
    "total" = 0
    "type" = "None"
    "startAt" = 0
    "percent" = 0
    "fraction" = @{
      "numerator" = 0
      "denominator" = 0
    }
  }
  #"generateUrnFile" = $true
}

$exportBodyJson = $exportBody | ConvertTo-Json -Depth 20
$exportQuery = Invoke-Apteco -key "ExportSync" -additional @{dataViewName=$dataview;systemName=$system;returnDefinition="true"} -body $exportBodyJson
$exportQuery | ConvertTo-Json


# Download file
# use content-type application/octet-stream for download file
$chosenFileContent = Invoke-Apteco -key "GetFile" -additional @{dataViewName=$dataview;systemName=$system;filePath="Private/$( $filename )"}
$chosenFileContent
