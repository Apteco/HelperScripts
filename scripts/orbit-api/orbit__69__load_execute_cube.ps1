
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
# DEFINE QUERY TO USE
#-----------------------------------------------

$bodyCountHt = @{
    selection = @{
        ancestorCounts = $false
        recordset = $null
        rule = $null
        rfv = $null
        nPer = $null
        topN = $null
        limits = $null
        tableName = "Kunden"
        name = "Meine Query"
    }
    todayAt = $null
}
$params = @{
    key = "CountQuerySync"
    additional = @{
        dataViewName=$dataview
        systemName=$system
    }
    body = ConvertTo-Json -InputObject $bodyCountHt -Depth 20
    query = @{
        returnDefinition = "false"
    }
    contentType = "application/json-patch+json"
}
$count = Invoke-Apteco @params 

"Counted $( $count.counts.countValue ) records for table $( $count.counts.tableName )"


#-----------------------------------------------
# DEFINE CUBE/TREE TO USE
#-----------------------------------------------

$bodyHt = @{
    baseQuery = @{
        selection = $bodyCountHt.selection
    }
    resolveTableName = "Kunden"
    storage = "Full"
    leftJoin = $true
    dimensions = @(
        @{
            id = "21766f80-6914-4bcd-beab-23e9a61c801a"
            query = $null

            # Example selector variabe
            #variableName = "HaMarket"
            #type = "Selector"

            # Example numeric banding variable
            variableName = "ku1OWWL9"
            type = "NumericBand"
            banding = @{
                type = "Custom"
                customValues = "<=0`t>0 - <=10`t>10 - <=20`t>20 - <=30`t>30 - <=40`t>40 - <=50`t>50 - <=60`t>60 - <=70`t>70 - <=80`t>80 - <=90"
            }

            function = "None"
            noneCell = $true
            omitUnclassified = $true
            filterQuery = $null
            expression = $null
        }
    )
    measures = @(
        @{
            id = "DefaultCountStatistics"
            resolveTableName = "Kunden"
            function = "Count"
            #variableName = ""
            sort = "None"
        }
    )
    subTotals = "All"
}

$params = @{
    key = "CalculateCubeSync"
    additional = @{
        dataViewName=$dataview
        systemName=$system
    }
    body = ConvertTo-Json -InputObject $bodyHt -Depth 20
    query = @{
        returnDefinition = "false"
    }
    contentType = "application/json-patch+json"
}

$cube = Invoke-Apteco @params



