################################################
#
# INPUT
#
################################################


Param (
)

################################################
#
# PATH
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
# TODO
#
################################################

<#

- [ ] 

#>

################################################
#
# FUNCTIONS
#
################################################

# load functions from external file
. ".\00__functions.ps1"


################################################
#
# SETTINGS
#
################################################

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$logfile = $settings.logfile



# log
#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`t--------------------------------" >> $logfile
#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tUsing: $( $fileItem.FullName )" >> $logfile



################################################
#
# PREPARATION / ASSEMBLIES
#
################################################





################################################
#
# LOAD AND TRANSFORM FILE
#
################################################

$file = "C:\Users\Florian\Desktop\20191001\bing_geocode_with_datatable\20191018105500_success_translation.txt"

$csv = import-csv $file -Delimiter "`t" -Encoding UTF8

$dataTable = $csv | ConvertTo-DataTable

#$dataTable.Columns | Out-GridView