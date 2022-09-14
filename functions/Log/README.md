
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

You can just download the whole repository here and pick this script or your can use PSGallery through PowerShell commands directly like

this for all users scope

```PowerShell
Install-Script -Name WriteLogfile
```

or this for the current users scope

```PowerShell
Install-Script -Name WriteLogfile -Scope CurrentUser
```

The last option installs the script in a folder like `C:\Users\Florian\Documents\WindowsPowerShell\Scripts` but you can also have a look via

```PowerShell
Get-InstalledScript WriteLogFile
```

If you want to find more [Apteco scripts in PSGallery](https://www.powershellgallery.com/packages?q=Tags%3A%22Apteco%22), please search with

```PowerShell
Find-Script -Repository "PSGallery" -Tag "Apteco"
```

# Usage

The script should be loaded automatically when you opening your PowerShell session. If your `PATH` variable was changed during the installation of your first script from PSGallery, please restart your machine to enforce the reload of the `PATH` environment variable.

You should be able to use the script directly like, but please have a look at more hints at the top of this documentation.

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

