
# some settings
$rabatteSubfolder = "rabatte"
$mssqlConnectionString = $settings.connectionString

# the enviroment variable fills from the designer user defined variables
$evrGUID = $processId.Guid -replace "-"

# SQL files and tables
$campaignsSqlFilename = ".\sql\100_load_campaign_run.sql"
$customersSqlFilename = ".\sql\110_insert_customers.sql"
$evrSqlFilename = ".\sql\120_insert_evr.sql"
$bulkDestination = "[server].[PeopleStage].[tblCampaigns]"

# Dropdown
$messagesDropdown = @(
    [pscustomobject]@{
        id = "0"
        name = "Rabatte zuordnen"
    }
    <#
    [pscustomobject]@{
        id = "1"
        name = "Bronze"
    }
    [pscustomobject]@{
        id = "2"
        name = "Silber"
    }
        [pscustomobject]@{
        id = "3"
        name = "Gold"
    }
    #>
)
