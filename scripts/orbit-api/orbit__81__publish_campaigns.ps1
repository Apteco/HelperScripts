
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


################################################
#
# LOAD PEOPLESTAGE INFORMATION
#
################################################

# Get PeopleStage system
$peopleStage = Invoke-Apteco -key "GetPeopleStageSystem" -additional @{systemName=$system} -query @{}

# Show last ran 100 campaigns
$campaigns = Invoke-Apteco -key "GetElementStatusForDescendants" -additional @{systemName=$system;elementId=$peopleStage.diagramId} -query @{offset=0;count=100;orderBy="-LastRan";filter="Type eq 'Campaign'"}
$chosenCampaigns = $campaigns.list | Out-GridView -PassThru


$chosenCampaigns | ForEach {

    $campaign = $_

    $campaignDetails = Invoke-Apteco -key "GetElement" -additional @{systemName=$system;elementId=$campaign.id}
    $campaignChildren = Invoke-Apteco -key "GetElementChildren" -additional @{systemName=$system;elementId=$campaign.id}

    $publishJob = Invoke-Apteco -key "CreateElementPublishJob" -additional @{systemName=$system;elementId=$campaign.id}


    #$actionJobStatus.

    <#
    
    {
        "elementId": "string",
        "id": 0,
        "isComplete": true,
        "isCancelled": true,
        "queuePosition": 0,
        "progress": 0
    }
    
    #>

}
exit 0
$publishJobStatus = Invoke-Apteco -key "ElementPublishJob" -additional @{systemName=$system;elementId=$campaign.id;jobId=$publishJob.id}
$publishJobStatus