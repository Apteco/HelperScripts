
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
$systems = Invoke-Apteco -key "GetPeopleStageSystems" -additional @{dataViewName=$dataview}

# Choose system 
# TODO [ ] is viewName the correct one?
if ( $systems.totalCount -gt 1 ) {
    $system = ( $systems.list | Out-GridView -PassThru ).systemName
} elseif ( $systems.totalCount -eq 0 ) {
    "No systems"
    exit 0
} else {
    $system = $systems.list[0].systemName
}


exit 0


################################################
#
# LOAD PEOPLESTAGE INFORMATION
#
################################################

# Get PeopleStage system
$peopleStage = Invoke-Apteco -key "GetPeopleStageSystem" -additional @{systemName=$system} -query @{}

# Load all campaigns
$campaigns = [System.Collections.ArrayList]@()
$pageSize = 100
$offset = 0
$totalCampaignsCount = 0
Do {

    # Do the call so in case it creates an error, jump to the next page url
    $res = Invoke-Apteco -key "GetElementStatusForDescendants" -additional @{systemName=$system;elementId=$peopleStage.diagramId} -query @{offset=$offset;count=$pageSize;orderBy="-LastRan";filter="Type eq 'Campaign'"}

    If ( $totalCampaignsCount -eq 0 ) {
        $totalCampaignsCount = $res.totalCount
    }

    # Prepare for the next call
    #$Script:endpoints += $res.list
    $offset += $pageSize

    $campaigns.AddRange( $res.list )

} Until ( $offset -ge $totalCampaignsCount ) 

# Enrich campaigns
$campaigns | ForEach {
    $campaign = $_
    $path = $campaign.path[-1].description
    #$campaign.path
    For ( $i = ($campaign.path.count - 2); $i -ge 0 ; $i-- ) {
        $path += " >> $( $campaign.path[$i].description )"
    }
    $campaign | Add-Member -MemberType NoteProperty -Name "PathString" -Value $path
}

# Output campaigns
$campaignsSelection = $campaigns | Out-GridView -PassThru
#$campaigns | Export-Csv -Path ".\campaigns.csv" -Encoding Default -Delimiter "`t" -NoTypeInformation


exit 0

$campaignsSelection | ForEach {

    $campaign = $_

    "Deleting campaign '$( $campaign.description )' with id '$( $campaign.id )'"

    # Checkout campaign
    # CreateElementCheckInOutJob	PeopleStage	POST	{dataViewName}/PeopleStage/{systemName}/Elements/{elementId}/CheckInOutJobs	False	False	False	{}	{}	{}	
    # ElementCheckInOutJob	PeopleStage	GET	{dataViewName}/PeopleStage/{systemName}/Elements/{elementId}/CheckInOutJobs/{jobId}	False	False	False	{}	{}	{}	
    $body = ConvertTo-Json -InputObject  @{"action"="CheckOut"}
    $checkoutJob = Invoke-Apteco -key "CreateElementCheckInOutJob" -additional @{systemName=$system;elementId=$campaign.id} -query @{} -body $body

    Do {
        Start-Sleep -Seconds 5
        $checkoutJobStatus = Invoke-Apteco -key "ElementCheckInOutJob" -additional @{systemName=$system;elementId=$campaign.id;jobId=$checkoutJob.id} -query @{}
        "Checkout: $( ConvertTo-Json $checkoutjobstatus -compress )"
    } Until ( $checkoutJobStatus.isComplete -eq $true -or $checkoutJobStatus.isCancelled -eq $true )


    # Delete campaign
    # CreateDeleteElementJob	PeopleStage	POST	{dataViewName}/PeopleStage/{systemName}/Elements/{elementId}/DeleteElementJobs	False	True	True	{}	{}	{}	
    # DeleteElementJob	PeopleStage	GET	{dataViewName}/PeopleStage/{systemName}/Elements/{elementId}/DeleteElementJobs/{jobId}	False	True	True	{}	{}	{}	

    If ( $checkoutJobStatus.isComplete -eq $true -and $checkoutJobStatus.checkOutDetail.isCheckedOutToMe -eq $true ) {

        $deleteJob = Invoke-Apteco -key "CreateDeleteElementJob" -additional @{systemName=$system;elementId=$campaign.id} -query @{} -body ""

        Do {
            Start-Sleep -Seconds 5
            $deleteJobStatus = Invoke-Apteco -key "DeleteElementJob" -additional @{systemName=$system;elementId=$campaign.id;jobId=$deleteJob.id} -query @{}
            "Delete: $( ConvertTo-Json $deleteJobStatus -compress )"
        } Until ( $deleteJobStatus.isComplete -eq $true )
    
        "Campaign '$( $campaign.description )' with id '$( $campaign.id )' is deleted"

    }

}




<#

POST https://demo.apteco.io/OrbitAPI/Handel/PeopleStage/Handel/Elements/c8fef33e-2f3f-487c-a139-0d59e002aa2f/CheckInOutJobs
201



{"checkOutDetail":null,"id":1403065,"isComplete":false,"isCancelled":false,"queuePosition":null,"progress":null,"serverMessages":null}

GET /OrbitAPI/Handel/PeopleStage/Handel/Elements/c8fef33e-2f3f-487c-a139-0d59e002aa2f/CheckInOutJobs/1403065

https://demo.apteco.io/OrbitAPI/Handel/PeopleStage/Handel/Elements/c8fef33e-2f3f-487c-a139-0d59e002aa2f/CheckInOutJobs/1403065





POST /OrbitAPI/Handel/PeopleStage/Handel/Elements/c8fef33e-2f3f-487c-a139-0d59e002aa2f/DeleteElementJobs
NO BODY

{"elementId":"c8fef33e-2f3f-487c-a139-0d59e002aa2f","id":1403066,"isComplete":false,"isCancelled":false,"queuePosition":null,"progress":null,"serverMessages":null}

/OrbitAPI/Handel/PeopleStage/Handel/Elements/c8fef33e-2f3f-487c-a139-0d59e002aa2f/DeleteElementJobs/1403066

until isComplete = true

{"elementId":"c8fef33e-2f3f-487c-a139-0d59e002aa2f","id":1403066,"isComplete":true,"isCancelled":false,"queuePosition":null,"progress":null,"serverMessages":null}

#>