
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
$modulename = "sqlserver_housekeeping"
$timestamp = [datetime]::Now

$settings = @{

    # DB shrinking
    instances = @( "777D0B7" )
    dbExclude = @( "master","model","msdb","tempdb" )
    ownerExclude = @( "sa" )
    
    # General
    logfile = "$( $scriptPath )\housekeeping.log"

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

Add-Type -AssemblyName System.Data


# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
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
# EXECUTE SQL SCRIPTS
#
################################################


#-----------------------------------------------
# LOAD SCRIPTS IN SQL FOLDER
#-----------------------------------------------

$sqlScripts = [System.Collections.ArrayList]@()
$settings.instances | Select -First 1 | ForEach {
    
    $instance = $_
    
    Get-ChildItem -Path ".\sql\*" -Include @( "*.sql" ) | Sort { $_.Name } | ForEach {

        $file = $_
        $file.FullName
        $query = Get-Content -Path "$( $file.FullName )" -Encoding UTF8 -Raw
        
        [void]$sqlScripts.Add([PSCustomObject]@{
            Name = $file.BaseName
            Path = $file.FullName
            Query = $query
        })

        #$result = Invoke-SqlServer -query $query -instance $instance -executeNonQuery
        #Write-Log "Executed '$( $file.Name )' with the result of '$( $result )' records"

    }
    
}


#-----------------------------------------------
# RECREATE USER PER INSTANCE AND DATABASE
#-----------------------------------------------

$settings.instances | ForEach {
    
    $instance = $_
    $instance

    Write-Log "Checking instance '$( $instance )'"

    #-----------------------------------------------
    # RECREATE USER PER INSTANCE (ASK FOR IT)
    #-----------------------------------------------

    $decision = $Host.UI.PromptForChoice("Confirmation", "Do you want to recreate the faststats service user for the whole instance?", @('&Yes'; '&No'), 1)

    If ( $decision -eq "0" ) {

        # Means yes and proceed

        $script = $sqlScripts | where { $_.Name -eq "recreate_user_instance" }
        Write-Log "Executing script '$( $script.Path )' on instance $( $instance )"
        Invoke-Sqlcmd -InputFile $script.Path -ServerInstance $instance #-Database $db.Name

    } else {
        
        # Proceed

    }

    #-----------------------------------------------
    # RECREATE USER PER DATABASE (ASK FOR IT)
    #-----------------------------------------------

    ( Get-SqlDatabase -ServerInstance $instance | where { $_.Owner -notin $settings.ownerExclude -or $_.Name -notin $settings.dbExclude } ) | Out-GridView -PassThru | ForEach {

        $db = $_

        Write-Log "Checking database '$( $db.Name )'"

        # Look for all objects with an alternate schema
        $changeSchema = [System.Collections.ArrayList]@()
        $db.Tables | where { $_.Schema -notin @("dbo","sys","INFORMATION_SCHEMA") } | ForEach {
            [void]$changeSchema.Add($_)
        }
        $db.Views | where { $_.Schema -notin @("dbo","sys","INFORMATION_SCHEMA") } | ForEach {
            [void]$changeSchema.Add($_)
        }
        $db.UserDefinedFunctions | where { $_.Schema -notin @("dbo","sys","INFORMATION_SCHEMA") } | ForEach {
            [void]$changeSchema.Add($_)
        }

        # Transfer all objects with an alternate schema to dbo
        $changeSchema | ForEach {
            $obj = $_
            Write-Log "Changing schema from '$( $obj.Schema ).$( $obj.Name )' to 'dbo'"
            $c = Invoke-SqlServer -query "ALTER SCHEMA dbo TRANSFER $( $obj.Schema ).$( $obj.Name );" -database $db.Name -instance $instance -executeNonQuery
        }

        # Now execute the db script to recreate the user and schema
        $script = $sqlScripts | where { $_.Name -eq "recreate_user_db" }
        Write-Log "Executing script '$( $script.Path )' on database $( $db.name )"
        Invoke-Sqlcmd -InputFile $script.Path -ServerInstance $instance -Database $db.Name
        #Invoke-SqlServer -query $script -database $db.Name -instance $instance -executeNonQuery

        # Transfer all objects with an alternate schema from dbo back to the origin
        $changeSchema | ForEach {
            $obj = $_ 
            Write-Log "Changing schema from 'dbo.$( $obj.Name )' to '$( $obj.Schema )'"
            $c = Invoke-SqlServer -query "ALTER SCHEMA $( $obj.Schema ) TRANSFER dbo.$( $obj.Name );" -database $db.Name -instance $instance -executeNonQuery
        }

    }

}



################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');