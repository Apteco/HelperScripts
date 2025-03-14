
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else {
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
$systems = Invoke-Apteco -key "GetFastStatsSystems" -additional @{dataViewName = $dataview }

# Choose system 
# TODO [ ] is viewName the correct one?
if ( $systems.totalCount -gt 1 ) {
    $system = ( $systems.list | Out-GridView -PassThru ).viewName
}
elseif ( $systems.totalCount -eq 0 ) {
    "No systems"
    exit 0
}
else {
    $system = $systems.list[0].viewName
}


#-----------------------------------------------
# CHOOSE FILEROOT
#-----------------------------------------------

# Get System root (private, public, cascade)
$systemRoot = Invoke-Apteco -key "GetRootFiles" -additional @{dataViewName = $dataview; systemName = $system }
$systemRoot.list | ft

# Choose a specific folder
$chooseRoot = $systemRoot.list | Out-GridView -PassThru
#$chooseRoot = $systemRoot.list | where { $_.name -eq "Private" }


#-----------------------------------------------
# LOAD FILES FROM A FOLDER
#-----------------------------------------------

# The parameters can also be defined in a separate object instead of the calling line
$params = @{
    dataViewName  = $dataview
    systemName    = $system
    directoryPath = $chooseRoot.path
}

$query = @{
    offset = 0
    count  = 50
}

$files = Invoke-Apteco -key "GetFiles" -additional $params -query $query

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
    "selection": {
        "ancestorCounts": false,
        "recordSet": null,
        "rule": null,
        "rfv": null,
        "nPer": {
            "recency": {
                "variableName": "peGeschl",
                "sequence": "2\t1\t!",
                "direction": "First",
                "value": 1,
                "distinct": false
            },
            "groupingTableName": "Haushalte",
            "transactionalTableName": "Personen"
        },
        "topN": null,
        "limits": null,
        "tableName": "Personen",
        "name": "NPTSelection"
    },
    "todayAt": null
}
"@ | ConvertFrom-Json



#-----------------------------------------------
# LOAD QUERY DEFINITION IN JSON (INSTEAD OF LOADING RAW XML)
#-----------------------------------------------

$body = @{
    "path" = $chooseFile.path
}
$bodyJson = $body | ConvertTo-Json -Depth 8
$chosenFileQuery = Invoke-Apteco -key "GetQueryFromFileSync" -additional @{dataViewName = $dataview; systemName = $system } -body $bodyJson

# Output as json on console
#$chosenFileQuery.query | ConvertTo-Json -depth 99
#$chosenFileQuery.query | ConvertTo-Json -depth 99 | set-content -path "tui.json" -Encoding UTF8


################################################
#
# GET RESULT BACK WITHOUT EXPORT
#
################################################

$browseBody = @{
    "baseQuery"                   = $chosenFileQuery.query
    #"filterQuery"= $filterquery
    #"isDefaultResolveTableName" = $false
    "resolveTableName"            = "Company"
    "maximumNumberOfRowsToBrowse" = 10
    "returnBrowseRows"            = $true
    "columns"                     = @(
        @{
            "id"           = "0"
            "variableName" = "FiID"
            "columnHeader" = "FiID"
            "detail"       = "Description" # Code|Description
        },
        @{
            "id"           = "1"
            "variableName" = "FiFIRMA"
            "columnHeader" = "FiFIRMA"
            "detail"       = "Description" # Code|Description
        },
        @{
            "id"           = "2"
            "variableName" = "FiRECHTS"
            "columnHeader" = "FiRECHTS"
            "detail"       = "Description" # Code|Description
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
            "id"           = "4"
            "variableName" = "SIC3SUM"
            "columnHeader" = "SIC3SUM"
            "detail"       = "Description" # Code|Description
            #"unclassifiedFormat" = "Space" # FromDesign|Spaces
        },
        @{
            "id"                 = "5"
            "variableName"       = "FiSIC"
            "columnHeader"       = "FiSIC"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        },
        @{
            "id"                 = "6"
            "variableName"       = "KoContac"
            "columnHeader"       = "KoContac"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        },
        @{
            "id"                 = "7"
            "variableName"       = "KoJobFun"
            "columnHeader"       = "KoJobFun"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        },
        @{
            "id"                 = "8"
            "variableName"       = "KoVornam"
            "columnHeader"       = "KoVornam"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        },
        @{
            "id"                 = "9"
            "variableName"       = "KoNachna"
            "columnHeader"       = "KoNachna"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        },
        @{
            "id"                 = "10"
            "variableName"       = "KoE-Mail"
            "columnHeader"       = "KoE-Mail"
            "detail"             = "Description" # Code|Description
            "unclassifiedFormat" = "Empty" # FromDesign|Spaces
        }


    )
    "limits"                      = @{
        "sampling"    = "All"
        "stopAtLimit" = $true
        "total"       = 0
        "type"        = "None"
        "startAt"     = 0
        "percent"     = 0
        "fraction"    = @{
            "numerator"   = 0
            "denominator" = 0
        }
    }
}

$query = @{
    "returnDefinition" = "true"
}

$browseBodyJson = $browseBody | ConvertTo-Json -Depth 99
#$browseBodyJson = $browseBody | ConvertTo-Json -Depth 99 | Set-Content ".\ttt2.json"

$browseQuery = Invoke-Apteco -key "ExportSync" -additional @{dataViewName = $dataview; systemName = $system; returnDefinition = "true" } -body $browseBodyJson -query $query
#$browseQuery | ConvertTo-Json -Depth 20

$browseQuery.rows.descriptions | ConvertFrom-Csv -Delimiter "`t" -Header $browseQuery.export.columns.columnHeader 

