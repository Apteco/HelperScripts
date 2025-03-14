
#-----------------------------------------------
# LOAD SCRIPTS AND MODULES
#-----------------------------------------------

$psScripts | ForEach {
    $scriptName = $_
    try {
        "Loading scripts"
        "    $( $scriptName )"
        Get-Command -Name $scriptName | % { . $_.Source }
    } catch {
        Write-Error -Message "Dependency '$( $scriptName )' not present"
    }
}

$psModules | ForEach {
    # [ ] TODO implement this!
}


#-----------------------------------------------
# LOAD FUNCTIONS
#-----------------------------------------------

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "    $( $_.FullName )"
}

Add-Type -AssemblyName System.Data


#-----------------------------------------------
# LOAD BINARIES
#-----------------------------------------------

<#
If ( $configMode -and -not $settings) {

    # Don't load yet, when in config mode and settings object not yet available

} else {
    
    # Load all exe files in subfolder
    $libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
    $libExecutables | ForEach {
        "... $( $_.FullName )"
    
    }

    # Load dll files in subfolder
    $libDlls = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
    $libDlls | ForEach {
        "Loading $( $_.FullName )"
        [Reflection.Assembly]::LoadFile($_.FullName) 
    }

}
#>


#-----------------------------------------------
# LOAD ASSEMBLIES
#-----------------------------------------------

#Add-Type -AssemblyName System.Security
