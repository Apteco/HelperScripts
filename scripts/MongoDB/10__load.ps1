
################################################
#
# NOTES
#
################################################

<#

TODO [ ] input settings file from PeopleStage
#>


################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# FUNCTIONS
#
################################################


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
# SETTINGS
#
################################################


#-----------------------------------------------
# READ SETTINGS
#-----------------------------------------------

$script:moduleName = "JOIN-EXTRACT"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Define dependencies
    . ".\bin\dependencies.ps1"

    # Load network settings
    #. ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Host -message "Got exception during start phase" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Type: '$( $_.Exception.GetType().Name )'" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Message: '$( $_.Exception.Message )'" #-severity ( [LogSeverity]::ERROR )
    Write-Host -message "  Stacktrace: '$( $_.ScriptStackTrace )'" #-severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}

exit 0

#Install-Module Mdbc
Import-Module Mdbc

$url = "mongodb+srv://user:pass@cluster0.aw9ejax.mongodb.net/tes"
$db = "local"
$collection = "test"

$mConn = Connect-Mdbc -ConnectionString $url -DatabaseName $db -CollectionName $collection

# create a new db, if not existing
$testDb = Get-MdbcDatabase -Name "sample_restaurants" -Client $mConn

# Add a collection to the database
#$testCollection = Add-MdbcCollection -Name "TestCollection" -Database $testDb 

$testCollection = Get-MdbcCollection -Name "restaurants" -Database $testDb

# Nice performance. E.g. loading 10k records in 2 seconds from MongoDB Cloud Atlas

$t = Measure-Command {
    $restaurants = Get-MdbcData -First 10000 -As PS -Collection $testCollection
}

# Add data - currently not authorized
@{_id = 1; value = 42}, @{_id = 2; value = 3.14} | Add-MdbcData -Collection $testCollection
$testCollection.Settings
# Get Data
Get-MdbcData -As PS | Format-Table

exit 0









$localDb = Get-MdbcDatabase -Name local

Connect-Mdbc . test test -NewCollection
@{_id = 1; value = 42}, @{_id = 2; value = 3.14} | Add-MdbcData
Get-MdbcData -As PS | Format-Table

exit 0
