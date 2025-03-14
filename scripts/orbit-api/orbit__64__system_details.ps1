
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
# SYSTEM DETAILS
#-----------------------------------------------

# Details about the system
$systemDetails = Invoke-Apteco -key "GetFastStatsSystem" -additional @{dataViewName=$dataview;systemName=$system}
$systemDetails | fl


#-----------------------------------------------
# TABLES
#-----------------------------------------------

$tables = Invoke-Apteco -key "GetTables" -additional @{dataViewName=$dataview;systemName=$system}
$tables.list | ft
#$tables.list | Out-GridView


#-----------------------------------------------
# VARIABLES
#-----------------------------------------------

$variables = Invoke-Apteco -key "GetVariables" -additional @{dataViewName=$dataview;systemName=$system;count=500}
$variables.list | ft
#$variables.list | Out-GridView


#-----------------------------------------------
# FOLDERS
#-----------------------------------------------

# Root System Folder
$folders = Invoke-Apteco -key "GetRootFolder" -additional @{dataViewName=$dataview;systemName=$system}
$folders.list.folder | ft
#$folders.list.folder | Out-GridView


# Content of a System Folder
$folderContent = Invoke-Apteco -key "GetFolder" -additional @{dataViewName=$dataview;systemName=$system;path=$folders.list.folder.name[0]}
$folderContent.list.variable | ft
#$folderContent.list.variable | Out-GridView


#-----------------------------------------------
# GET ALL AT ONCE
#-----------------------------------------------

$all = Invoke-Apteco -key "GetAllFastStatsSystemItems" -additional @{"dataViewName"=$dataview;"systemName"=$system} -query @{count=100000;includeVarCodeCounts="false"}
