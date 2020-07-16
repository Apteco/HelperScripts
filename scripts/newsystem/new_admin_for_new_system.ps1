
################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false




################################################
#
# NOTES
#
################################################



<#

#>



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

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$processId = [guid]::NewGuid()
$modulename = "add_admin_for_new_system"
$timestamp = [datetime]::Now

$settings = @{

    # settings for database
    instances = @( "F9517BC" )
    globalDatabase = "WS_Global"
    variablesToReplace = @{
        "SYSNAME" = Read-Host -Prompt 'name of the new system'
    }


    # General
    logfile = "$( $scriptPath )\newsystems.log"

}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################





################################################
#
# EXECUTE SQL SCRIPTS
#
################################################

$settings.instances | ForEach {
    
    $instance = $_
    $instance

    Write-Log "using instance '$( $instance )'"

    Get-ChildItem -Path ".\sql\*" -Include @( "*.sql" ) | Sort { $_.Name } | ForEach {

        $file = $_

        $file.FullName

        $query = Get-Content -Path "$( $file.FullName )" -Encoding UTF8
        $settings.variablesToReplace.Keys | ForEach {
            $key = $_
            $query = $query -replace "#$( $key )#", "$( $settings.variablesToReplace[$key] )"
        }
        $query
        $result = Invoke-SqlServer -query $query -instance $instance -executeNonQuery
        Write-Log "Executed '$( $file.Name )' with the result of '$( $result )' records"

    }

}



