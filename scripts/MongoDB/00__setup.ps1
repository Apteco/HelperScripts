
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
# FUNCTIONS
#
################################################

<#

Example to use

$stringArray = @("Frankfurt","Aachen","Braunschweig")
$choice = Prompt-Choice -title "City" -message "Which city would you prefer?" -choices $stringArray
$choiceMatchedWithArray = $stringArray[$choice -1]

#>
Function Prompt-Choice {

    param(
         [Parameter(Mandatory=$true)][string]$title
        ,[Parameter(Mandatory=$true)][string]$message
        ,[Parameter(Mandatory=$true)][string[]]$choices
        ,[Parameter(Mandatory=$false)][int]$defaultChoice = 0
    )

    $i = 1
    $choicesConverted = [System.Collections.ArrayList]@()
    $choices | ForEach {
        $choice = $_
        [void]$choicesConverted.add((New-Object System.Management.Automation.Host.ChoiceDescription "&$( $i ) - $( $choice )" )) # putting a string afterwards shows it as a help message
        $i += 1
    }
    $options = [System.Management.Automation.Host.ChoiceDescription[]]$choicesConverted
    $result = $host.ui.PromptForChoice($title, $message, $options, $defaultChoice) 

    return $result +1 # add one for index

}


################################################
#
# START
#
################################################

#-----------------------------------------------
# READ SETTINGS
#-----------------------------------------------

$script:moduleName = "JOIN-EXTRACT-SETTINGS"

# Load dependencies
. ".\bin\dependencies.ps1"

#-----------------------------------------------
# CHECK EXECUTION POLICY
#-----------------------------------------------

<#

If you get

    .\load.ps1 : File C:\Users\WDAGUtilityAccount\scripts\load.ps1 cannot be loaded because running scripts is disabled on this system. For more information, see
    about_Execution_Policies at https:/go.microsoft.com/fwlink/?LinkID=135170.
    At line:1 char:1
    + .\load.ps1
    + ~~~~~~~~~~
        + CategoryInfo          : SecurityError: (:) [], PSSecurityException
        + FullyQualifiedErrorId : UnauthorizedAccess

Then change your Execution Policy to something like

#>

# Set-ExecutionPolicy -ExecutionPolicy Unrestricted   

#-----------------------------------------------
# INSTALLATION POWERSHELL 7 (PWSH)
#-----------------------------------------------

<#
Please make sure to have PowerShell 7 installed
$PSVersionTable

Invoke-Expression "& { $( Invoke-RestMethod https://aka.ms/install-powershell.ps1 )  } -UseMSI"

#>

If ( $PSVersionTable.PSVersion.Major -lt 7 ) {
    Write-Warning -Message "Your PowerShell version is less than 7, please check if you use pwsh.exe as command or if you have installed it."
    Write-Warning -Message 'Installation can be done with'
    Write-Warning -Message 'Invoke-Expression "& { $( Invoke-RestMethod https://aka.ms/install-powershell.ps1 )  } -UseMSI"'
    Write-Warning -Message 'Please restart this process from PowerShell 7 again.'

    Exit 0
}


#-----------------------------------------------
# ADD NUGET
#-----------------------------------------------

<#

# Add nuget first or make sure it is set

Register-PackageSource -Name Nuget -Location "https://www.nuget.org/api/v2" –ProviderName Nuget

# Make nuget trusted
Set-PackageSource -Name NuGet -Trusted

#>

# Get-PSRepository

#Install-Package Microsoft.Data.Sqlite.Core -RequiredVersion 7.0.0-rc.2.22472.11

$packageSourceName = "NuGet" # otherwise you could create a local repository and put all dependencies in there. You can find more infos here: https://github.com/Apteco/HelperScripts/tree/master/functions/Log#installation-via-local-repository
$packageSourceLocation = "https://www.nuget.org/api/v2"
$packageSourceProviderName = "NuGet"

# See if Nuget needs to get registered
$sources = Get-PackageSource -ProviderName $packageSourceProviderName
If ( $sources.count -ge 1 ) {
    Write-Output -InputObject "You have at minimum 1 $( $packageSourceProviderName ) repository. Good!"
} elseif ( $sources.count -eq 0 ) {
    Write-Warning -Message "You don't have $( $packageSourceProviderName ) as a PackageSource, do you want to register it now?"
    $registerNugetDecision = $Host.UI.PromptForChoice("", "Register $( $packageSourceProviderName ) as repository?", @('&Yes'; '&No'), 1)
    If ( $registerNugetDecision -eq "0" ) {
        # Means yes and proceed
        Register-PackageSource -Name $packageSourceName -Location $packageSourceLocation -ProviderName $packageSourceProviderName
    } else {
        # Means no and leave
        Write-Warning -Message "Then we will leave here"
        exit 0
    }
}

# TODO [ ] ask if you want to trust the new repository

$sources = Get-PackageSource -ProviderName $packageSourceProviderName
If ( $sources.count -gt 1 ) {

    $packageSources = $sources.Name
    $packageSourceChoice = Prompt-Choice -title "PackageSource" -message "Which $( $packageSourceProviderName ) repository do you want to use?" -choices $packageSources
    $packageSource = $packageSources[$packageSourceChoice -1]

} elseif ( $sources.count -eq 1 ) {
    
    $packageSource = $sources[0]

} else {
    
    Write-Warning -Message "There is no $( $packageSourceProviderName ) repository available"

}

# Do you want to trust that source?
If ( $packageSource.IsTrusted -eq $false ) {
    Write-Warning -Message "Your source is not trusted. Do you want to trust it now?"
    $trustChoice = Prompt-Choice -title "Trust Package Source" -message "Do you want to trust $( $packageSource.Name )?" -choices @("Yes", "No")
    If ( $trustChoice -eq 1 ) {
        Set-PackageSource -Name NuGet -Trusted
    }
}




# Install single packages
# Install-Package -Name SQLitePCLRaw.core -Scope CurrentUser -Source NuGet -Verbose -SkipDependencies -Destination ".\lib" -RequiredVersion 2.0.6
 exit 0
#-----------------------------------------------
# CHECK ALL DEPENDENCIES FOR INSTALLATION AND UPDATE
#-----------------------------------------------

# TODO [] Add psgallery possibly, too

# SCRIPTS
$installedScripts = Get-InstalledScript
$psScripts | ForEach {
    
    # TODO [ ] possibly add dependencies on version number
    $psScript = $_
    $psScriptDependencies = Find-Script -Name $psScript -IncludeDependencies
    $psScriptDependencies | where { $_.Name -notin $installedScripts.Name } | Install-Script -Scope AllUsers -Verbose

}

# MODULES
$installedModules = Get-InstalledModule
$psModules | ForEach {
    
    # TODO [ ] possibly add dependencies on version number
    $psModule = $_
    $psModuleDependencies = Find-Module -Name $psScript -IncludeDependencies
    $psModuleDependencies | where { $_.Name -notin $installedScripts.Name } | Install-Module -Scope AllUsers -Verbose

}

# PACKAGES
$localPackages = Get-package -Destination .\lib
$globalPackages = Get-package 
$installedPackages = $localPackages + $globalPackages
$psPackages | ForEach {

    $psPackage = $_
    $pkg = Find-Package $psPackage -IncludeDependencies -Verbose
    $pkg | where { $_.Name -notin $installedPackages.Name } | Select Name, Version -Unique | ForEach {
        Install-Package -Name $_.Name -Scope CurrentUser -Source NuGet -Verbose -RequiredVersion $_.Version -SkipDependencies -Destination ".\lib"
    }

}

exit 0
