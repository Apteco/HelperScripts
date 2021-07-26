
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
}
$query = @{
    offset=0
    count=50
}
$files = Invoke-Apteco -key "GetFiles" -additional $params -query $query

# List the result
$files.list | ft

# Choose a selection file
$chooseFile = $files.list | where { $_.type -in @("Selection") } | Out-GridView -PassThru
#$chooseFile = $files.list | where { $_.name -eq "ActiveCustomers.xml" }
$chooseFile = $files.list | where { $_.type -in @("Cube") } | Out-GridView -PassThru


#-----------------------------------------------
# LOAD RAW CONTENT OF A SELECTION (CAN BE XML,CSV,...)
#-----------------------------------------------

$chosenFileContent = Invoke-Apteco -key "GetFile" -additional @{dataViewName=$dataview;systemName=$system;filePath=$chooseFile.path}
$chosenFileContent


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
# EXECUTE QUERY VIA FILE
#-----------------------------------------------

$body = @{
    "path" = $chooseFile.path
  }
$bodyJson = $body | ConvertTo-Json -Depth 8
$chosenFileExecution = Invoke-Apteco -key "CountQueryFromFileSync" -additional @{dataViewName=$dataview;systemName=$system} -body $bodyJson

# Output result to console
$chosenFileExecution | convertto-json -depth 8

#-----------------------------------------------
# TRANSFORM XML INTO HASHTABLE/JSON FORMAT
#-----------------------------------------------
<#
$treeSource = [xml]$chosenFileContent.Substring(3) 
$treeSourceHt = Convert-XMLtoPSObject -XML $treeSource -attributesPrefix ""
#>