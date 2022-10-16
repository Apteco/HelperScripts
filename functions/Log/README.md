
# Apteco Customs - PowerShell logging script

Execute commands like

```PowerShell
Write-Log -message "Hello World"
Write-Log -message "Hello World" -severity ([LogSeverity]::ERROR)
"Hello World" | Write-Log
```

Then the logfile getting written looks like

```
20220217134552	a6f3eda5-1b50-4841-861e-010174784e8c	INFO	This is a general information
20220217134617	a6f3eda5-1b50-4841-861e-010174784e8c	ERROR	Note! This is an error
20220217134618	a6f3eda5-1b50-4841-861e-010174784e8c	VERBOSE	This is the verbose/debug information
20220217134619	a6f3eda5-1b50-4841-861e-010174784e8c	WARNING	And please look at this warning

```

separated by tabs.


Make sure, the variables `$logfile` and `$processId` are present before calling this. Otherwise they will be created automatically and you are notified about the location and the current process id.

The variables could be filled like

```PowerShell
$logfile = ".\test.log"
$processId = [guid]::NewGuid()
```

The process id is good for parallel calls/processes so you know they belong together.


# Installation

You can just download the whole repository here and pick this script or your can use PSGallery through PowerShell commands directly.

## PSGallery

### Installation via Install-Script

For installation execute this for all users scope

```PowerShell
Find-Script -Repository "PSGallery" -Name "WriteLogfile" -IncludeDependencies | Install-Script -Verbose
```

You can then find the script via `Set-Location "$( $env:USERPROFILE )\Documents\WindowsPowerShell\Scripts"`

or this for the current users scope (this includes all dependencies as addition to `Install-Script WriteLogfile`)

```PowerShell
Find-Script -Repository "PSGallery" -Name "WriteLogfile" -IncludeDependencies | Install-Script -Scope CurrentUser -Verbose
```

The last option installs the script in a folder like `Set-Location "$( $env:USERPROFILE )\Documents\WindowsPowerShell\Scripts"` but you can also have a look via

```PowerShell
Get-InstalledScript WriteLogFile
```

or

```PowerShell
Get-Command WriteLogFile
```

If you want to find more [Apteco scripts in PSGallery](https://www.powershellgallery.com/packages?q=Tags%3A%22Apteco%22), please search with

```PowerShell
Find-Script -Repository "PSGallery" -Tag "Apteco"
```

### Installation via local Repository

If your machine does not have an online connection you can use another machine to save the script from PSGallery website as a local file via your browser. You should have download a file with an `.nupkg` extension. Please don't forget to download all dependencies, too. You could simply unzip the file(s) and put the script somewhere you need it OR do it in an updatable manner and create a local repository if you don't have it already with

```PowerShell
Set-Location "$( $env:USERPROFILE )\Downloads"
New-Item -Name "PSRepo" -ItemType Directory
Register-PSRepository -Name "LocalRepo" -SourceLocation "$( $env:USERPROFILE )\Downloads\PSRepo"
Get-PSRepository
```

Then put your downloaded `.nupkg` file into the new created `PSRepo` folder and you should see the script via 

```PowerShell
Find-Script -Repository LocalRepo
```

Then install the script like 

```PowerShell
Find-Script -Repository LocalRepo -Name WriteLogfile -IncludeDependencies | Install-Script -Scope CurrentUser -Verbose
```

That way you can exchange the `.nupkg` files and update them manually from time to time.

#### Troubleshooting

##### Unable to download from URI

`WARNING: Unable to download from URI...`

If you are confronted with this message (because of missing internet connection)

![grafik](https://user-images.githubusercontent.com/14135678/193812253-3e2ca672-8d36-4f55-9659-f45ea38ec3f2.png)

Make sure to install the nuget provider in order to create a local repository for nuget packages.

So have a look at the url that is embedded in that message, in our case https://go.microsoft.com/fwlink/?LinkID=627338&clcid=0x409 and copy that to a browser with internet access.
This should forward you automatically to another url https://onegetcdn.azureedge.net/providers/providers.masterList.feed.swidtag where you can copy 

![grafik](https://user-images.githubusercontent.com/14135678/193815009-8e2200a1-0945-441a-ba29-c8eb430bb2a4.png)

the url https://onegetcdn.azureedge.net/providers/nuget-2.8.5.208.package.swidtag from it and then you are redirected this file

![grafik](https://user-images.githubusercontent.com/14135678/193815153-a7c7b2be-d6e4-43f6-b358-a27d6c205b66.png)

where you get the final link https://onegetcdn.azureedge.net/providers/Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll for the dll file to download.

Make sure you unblock the dll file

![grafik](https://user-images.githubusercontent.com/14135678/193817768-8a08f553-9490-4e18-ab28-bec849b6865f.png)

and then load it to your machine without internet connection and put it into one of your folders mentioned in the first screenshot like `C:\Program Files\PackageManagement\ProviderAssemblies` or `%LOCALAPPDATA%\PackageManagement\ProviderAssemblies` 

Then proceed with the other steps...

#### Using the IE proxy settings

Good reference here: https://copdips.com/2018/05/setting-up-powershell-gallery-and-nuget-gallery-for-powershell.html

Execute this command first to use the local IE proxy settings

```PowerShell
(New-Object -TypeName System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
```
and maybe add these command to your profile to execute it with every new PowerShell process. You can find your profiles here:

```PowerShell
$PROFILE | gm | ? membertype -eq noteproperty
```

### Uninstall

If you don't want to use the script anymore, just remove it with 

```PowerShell
Uninstall-Script -Name WriteLogfile
```



## Github

[Download the whole repository](https://github.com/Apteco/HelperScripts/archive/refs/heads/master.zip) and pick the `log.ps1` file and put it wherever you want in your project.

To load the script, dot source it like

```PowerShell
. .\log.ps1
```

or

```PowerShell
. .\functions\log.ps1
```

or wherever you organise your scripts. If you put it in a folder that is automatically loaded through the `PATH` Environment variable you can find the script in a list via 

```PowerShell
Get-Command -CommandType ExternalScript
```

or dot source (load) it directly

```PowerShell
Get-Command -Name "WriteLogfile" | % { . $_.Source }
```

See Usage for more information about loading this script.


# Usage

As the script contains multiple functions you should dot source (load, but not execute) it when you want to use it in your current session/scope. To load the code of this script, just execute this command

```PowerShell
Get-Command -Name "WriteLogfile" | % { . $_.Source }
```

If you want to load multiple scripts, you can define the names in a string array like

```PowerShell
Get-Command -Name "WriteLogfile","HelloWorld" | % { . $_.Source }
```

You should be able to use the script directly with a command like `Write-Log "Hello World"`, but please have a look at more hints at the top of this documentation.

## Example 1

```PowerShell
Write-Log -message "Hello World"
```

Uses the `$logfile` and `$processId` variables and redirects the message to your console and creates a line in your logfile like

```
20220217134552	a6f3eda5-1b50-4841-861e-010174784e8c	INFO	Hello World
```

## Example 2

```PowerShell
Write-Log -message "Note! This is an error" -severity ([LogSeverity]::ERROR)
```

outputs red characters at the console and creates a line in your logfile like

```
20220217134617	a6f3eda5-1b50-4841-861e-010174784e8c	ERROR	Note! This is an error
```

## Example 3

```PowerShell
"Hello World" | Write-Log
```

Works like the previous examples but also works with the pipeline

# Best Practise

Normally I use a settings at the beginning of the script to allow debugging without writing into a production log like:

```PowerShell

# debug switch
$debug = $true

# settings
$logfile = ".\script.log"

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}

```

