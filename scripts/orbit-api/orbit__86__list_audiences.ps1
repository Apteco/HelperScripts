
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
#$chooseRoot = $systemRoot.list | where { $_.name -eq "Private" }

