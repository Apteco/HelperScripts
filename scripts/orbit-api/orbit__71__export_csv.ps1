
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
exit 0
#-----------------------------------------------
# Filter Query
#-----------------------------------------------

$filterquery = @"
{
    "selection":  {
                      "ancestorCounts":  false,
                      "recordSet":  null,
                      "rule":  null,
                      "rfv":  null,
                      "nPer":  {
                                   "recency":  {
                                                   "variableName":  "peGeschl",
                                                   "sequence":  "2\t1\t!",
                                                   "direction":  "First",
                                                   "value":  1,
                                                   "distinct":  false
                                               },
                                   "groupingTableName":  "Haushalte",
                                   "transactionalTableName":  "Personen"
                               },
                      "topN":  null,
                      "limits":  null,
                      "tableName":  "Personen",
                      "name":  "NPTSelection"
                  },
    "todayAt":  null
}
"@ | ConvertFrom-Json


#-----------------------------------------------
# LOAD QUERY DEFINITION IN JSON (INSTEAD OF LOADING RAW XML)
#-----------------------------------------------

$body = @{
    "path" = $chooseFile.path
}
$bodyJson = $body | ConvertTo-Json -Depth 8
$chosenFileQuery = Invoke-Apteco -key "GetQueryFromFileSync" -additional @{dataViewName=$dataview;systemName=$system} -body $bodyJson

# Output as json on console
$chosenFileQuery.query | ConvertTo-Json -depth 99
#$chosenFileQuery.query | ConvertTo-Json -depth 99 | set-content -path "tui.json" -Encoding UTF8



################################################
#
# EXPORT A SELECTION AS URN FILE
#
################################################

$filename = "$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).csv"

$exportBody = @{
  "baseQuery"= $chosenFileQuery.query
  #"filterQuery"= $filterquery
  #"isDefaultResolveTableName" = $false
  "resolveTableName"="Companies"
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
      "variableName" = "co2OI7LV"
      "columnHeader" = "HaushaltURN"
      "detail" = "Description" # Code|Description
    } <#,
    @{
      "id" = "1"
      "variableName" = "PePURN"
      "columnHeader" = "PersonURN"
      "detail" = "Description" # Code|Description
    },
    @{
      "id" = "2"
      "variableName" = "peGeschl"
      "columnHeader" = "Geschlecht"
      "detail" = "Description" # Code|Description
<<<<<<< Updated upstream
=======
<<<<<<< Updated upstream
    },
    <#@{
      "id" = "3"
      #"variableName" = "Cu257JZ9"
      "columnHeader" = "Arr"
      "detail" = "Description" # Code|Description
      #"unclassifiedFormat" = "Spaces" # FromDesign|Spaces
      "type" = "Expression"
      #"arrayIndex" = 0
      "expression"='DescOf([cu257JZ9])'
    },#>
    @{
      "id" = "4"
      "variableName" = "Cu257KSU"
      "columnHeader" = "ArrText"
      "detail" = "Description" # Code|Description
      #"unclassifiedFormat" = "Space" # FromDesign|Spaces
    },
    @{
      "id" = "5"
      "variableName" = "CuPrefix"
      "columnHeader" = "Prefix"
      "detail" = "Description" # Code|Description
      "unclassifiedFormat" = "Empty" # FromDesign|Spaces
=======
<<<<<<< Updated upstream
>>>>>>> Stashed changes
>>>>>>> Stashed changes
    }
=======
    },
    @{
      "id" = "3"
      #"variableName" = "Cu257JZ9"
      "columnHeader" = "Arr"
      "detail" = "Description" # Code|Description
      #"unclassifiedFormat" = "Spaces" # FromDesign|Spaces
      "type" = "Expression"
      #"arrayIndex" = 0
      "expression"='DescOf([cu257JZ9])'
    },
    @{
      "id" = "4"
      "variableName" = "PeVornam"
      "columnHeader" = "Vorname"
      "detail" = "Description" # Code|Description
      #"unclassifiedFormat" = "Space" # FromDesign|Spaces
    },
    @{
      "id" = "5"
      "variableName" = "PeNachna"
      "columnHeader" = "Nachname"
      "detail" = "Description" # Code|Description
      "unclassifiedFormat" = "Empty" # FromDesign|Spaces
    }#>
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
  #"generateUrnFile" = $true
=======
<<<<<<< Updated upstream
=======
<<<<<<< Updated upstream
  #"generateUrnFile" = $true
=======
>>>>>>> Stashed changes
}

$query = @{
  "returnDefinition" = "true"
<<<<<<< Updated upstream
}

$browseBodyJson = $browseBody | ConvertTo-Json -Depth 20
$browseQuery = Invoke-Apteco -key "ExportSync" -additional @{dataViewName=$dataview;systemName=$system;returnDefinition="true"} -body $browseBodyJson -query $query
$browseQuery | ConvertTo-Json -Depth 20

$browseQuery.rows.descriptions | ConvertFrom-Csv -Delimiter "`t" -Header $browseQuery.export.columns.columnHeader 

exit 0
################################################
#
# EXPORT A SELECTION AS CSV AND/OR URN FILE
#
################################################

$filename = "$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).csv"

$exportBody = $browseBody + @{
  "pathToExportTo" = "Private/$( $filename )"
  "pathToExportUrnFileTo" = "Private/$( $filename ).urn"
  "output" = @{
    "format" = "CSV" # CSV|URN|XLSX
    "delimiter" = ";"
    "alphaEncloser" = """"
    "numericEncloser" = ""
    "authorisationCode" = ""
    "exportExtraName" = ""
  }
=======
>>>>>>> Stashed changes
>>>>>>> Stashed changes
}

$browseBodyJson = $browseBody | ConvertTo-Json -Depth 99
#$browseBodyJson = $browseBody | ConvertTo-Json -Depth 99 | Set-Content ".\ttt2.json"

$browseQuery = Invoke-Apteco -key "ExportSync" -additional @{dataViewName=$dataview;systemName=$system;returnDefinition="true"} -body $browseBodyJson -query $query
$browseQuery | ConvertTo-Json -Depth 20

$browseQuery.rows.descriptions | ConvertFrom-Csv -Delimiter "`t" -Header $browseQuery.export.columns.columnHeader 

exit 0
################################################
#
# EXPORT A SELECTION AS CSV AND/OR URN FILE
#
################################################

$filename = "$( [datetime]::Now.ToString("yyyyMMddHHmmss") ).csv"




$exportBody = $browseBody + @{
  "pathToExportTo" = "Public/$( $filename )"
  "pathToExportUrnFileTo" = $null #"Public/$( $filename ).urn"
  "output" = @{
    "format" = "CSV" # CSV|URN|XLSX
    "delimiter" = ","
    "alphaEncloser" = ""
    "numericEncloser" = ""
    "authorisationCode" = ""
    "exportExtraName" = "RemoveQuotes"
  }
>>>>>>> Stashed changes
}

$exportBodyJson = $exportBody | ConvertTo-Json -Depth 99
#$exportBody | ConvertTo-Json -Depth 99 | Set-Content -Path .\tri.json -Encoding UTF8
$exportQuery = Invoke-Apteco -key "ExportSync" -additional @{dataViewName=$dataview;systemName=$system;returnDefinition="true"} -body $exportBodyJson
<<<<<<< Updated upstream
$exportQuery | ConvertTo-Json
=======
<<<<<<< Updated upstream
$exportQuery | ConvertTo-Json -Depth 20
=======
<<<<<<< Updated upstream
$exportQuery | ConvertTo-Json
=======



$exportQuery | ConvertTo-Json -Depth 99
>>>>>>> Stashed changes
>>>>>>> Stashed changes
>>>>>>> Stashed changes


# Download file
# use content-type application/octet-stream for download file
$chosenFileContent = Invoke-Apteco -key "GetFile" -additional @{dataViewName=$dataview;systemName=$system;filePath="Private/$( $filename )"}
$chosenFileContent
