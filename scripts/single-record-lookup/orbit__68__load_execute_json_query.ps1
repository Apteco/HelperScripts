
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


#-----------------------------------------------
# EXECUTE QUERY VIA JSON OBJECT
#-----------------------------------------------

# Put the query into the body
$body = $chosenFileQuery.query

# Change a value
$body.selection.rule.clause.logic.operands.criteria.where({$_.variableName -eq "CuEmail"}).valueRules.listRule.list = "Florian" #"apteco"

# Do the call
$bodyJson = $body | ConvertTo-Json -Depth 20
$countQuery = Invoke-Apteco -key "CountQuerySync" -additional @{dataViewName=$dataview;systemName=$system} -body $bodyJson

# Show the results
$countQuery | convertto-json -depth 20

exit 0


################################################
#
# ANOTHER EXAMPLE
#
################################################

# Example json query with an expression as json
$j = @"
{
  "selection": {
      "ancestorCounts": false,
      "rule": {
          "clause": {
              "criteria": {
                  "include": true,
                  "logic": "OR",
                  "ignoreCase": false,
                  "textMatchType": "Is",
                  "valueRules": [
                      {
                          "listRule": {
                              "bandingType": "None",
                              "list": ">=5",
                              "variableName": null
                          },
                          "name": "Distanz von >=5"
                      }
                  ],
                  "expressionRule": {
                      "tableName": "Customers",
                      "queries": [],
                      "desc": "Distanz",
                      "displayText": "GeoDist(\n\t47,424298;9,386160;\n\t47,415401;9,261395;\n\t\"k\"\n)",
                      "serverText": "GeoDist(\n\t47.424298,9.386160,\n\t47.415401,9.261395,\n\t\"k\"\n)",
                      "queryDescriptions": [],
                      "outputType": "Double",
                      "stringSize": 20
                  },
                  "tableName": "Customers",
                  "name": "Distanz von >=5"
              }
          }
      },
      "tableName": "Customers",
      "name": "Dist"
  }
}
"@