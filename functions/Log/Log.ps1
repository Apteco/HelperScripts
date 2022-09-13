<#PSScriptInfo

.VERSION 0.9.01

.GUID eeb42bfc-facd-4f60-8108-9eed67a115e9

.AUTHOR florian.von.bracht@apteco.de

.COMPANYNAME Apteco GmbH

.COPYRIGHT 2022 Apteco GmbH. All rights reserved.

.TAGS PSEdition_Desktop PSEdition_Core Windows Apteco

.LICENSEURI https://gist.github.com/gitfvb/58930387ee8677b5ccef93ffc115d836

.PROJECTURI https://github.com/Apteco/HelperScripts/tree/master/functions/Log

.ICONURI https://www.apteco.de/sites/default/files/favicon_3.ico

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Initial release of logging module through psgallery

.PRIVATEDATA

#>

<#

.DESCRIPTION
Apteco Customs - PowerShell logging script

The logfile getting written looks like

20210217134552	a6f3eda5-1b50-4841-861e-010174784e8c	INFO	Hello World
20210217134617	a6f3eda5-1b50-4841-861e-010174784e8c	ERROR	Hello World

separated by tabs.

Make sure, the variables $logfile and $processId are present before calling this. Otherwise they will be created automatically.
The variables could be filled like

$logfile = ".\test.log"
$processId = [guid]::NewGuid()

The process id is good for parallel calls/processes so you know they belong together

#>
Param()


<#
Source: https://blogs.endjin.com/2014/07/how-to-retry-commands-in-powershell/
#>
Function Invoke-CommandRetry {

<#
.SYNOPSIS
    Retrying a specific command multiple times until it fails. This can be used e.g. to
    try to write in a file if multiple write commands can occur at the same time.

.DESCRIPTION
    This function is a helper for the logging script function. It retries a specific command,
    e.g. you have concurrent calls to write to the logfile. In this case this function
    can try the write command multiple times until it fails.

.PARAMETER Command
    The command to be executed like Write-Output or Set-Content

.PARAMETER Args
    The arguments for the command defined in a hashtable because it uses splatting

.PARAMETER Retries
    Optional parameter (default 10) for retries of this command

.PARAMETER MillisecondsDelay
    Optional parameter (default random between 0 and 3000) to define the milliseconds to wait before the next try

.EXAMPLE
    Invoke-CommandRetry -command "Write-Output" -args @{"InputObject"="Hello World"}

.EXAMPLE
    $randomDelay = Get-Random -Maximum 3000
    $outArgs = @{
        FilePath = $logfile
        InputObject = $logstring
        Encoding = "utf8"
        Append = $true
        NoClobber = $true
    }
    Invoke-CommandRetry -Command 'Out-File' -Args $outArgs -retries 10 -MillisecondsDelay $randomDelay

.INPUTS
    String, HashTable

.OUTPUTS
    Boolean

.NOTES
    Author:  florian.von.bracht@apteco.de

#>

    param (
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][hashtable]$Args,
        [Parameter(Mandatory=$false)][int]$Retries = 10,
        [Parameter(Mandatory=$false)][int]$MillisecondsDelay = ( Get-Random -Maximum 3000 )
    )

    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are
    # treated as terminating errors, and will be caught by the catch block.
    $Args.ErrorAction = "Stop"

    $retrycount = 0
    $completed = $false

    while (-not $completed) {
        try {
            & $Command @Args
            Write-Verbose ("Command [{0}] succeeded." -f $Command)
            $completed = $true
        } catch {
            if ($retrycount -ge $Retries) {
                Write-Verbose -Message ("Command [{0}] failed the maximum number of {1} times." -f $Command, $retrycount) -Verbose
                throw
            } else {
                Write-Verbose -Message ("Command [{0}] failed. Retrying in {1} seconds." -f $Command, $secondsDelay) -Verbose
                Start-Sleep -Milliseconds $MillisecondsDelay
                $retrycount++
            }
        }
    }

    # Return
    $completed

}


# Severity Enumeration used by the log function
Enum LogSeverity {
    INFO      = 0
    VERBOSE   = 5
    WARNING   = 10
    ERROR     = 20
}


Function Write-Log {

<#
.SYNOPSIS
    Writing log messages into a logfile and additionally to the console output.
    The messages are also redirected to the Apteco software, if used in a custom channel

.DESCRIPTION
    The logfile getting written looks like

    20210217134552	a6f3eda5-1b50-4841-861e-010174784e8c	INFO	Hello World
    20210217134617	a6f3eda5-1b50-4841-861e-010174784e8c	ERROR	Hello World

    separated by tabs.

    Make sure, the variables $logfile and $processId are present before calling this. Otherwise they will be created automatically.
    The variables could be filled like

    $logfile = ".\test.log"
    $processId = [guid]::NewGuid()

    The process id is good for parallel calls so you know they belong together

.PARAMETER Message
    The message the script should log into a file and additionally to the console

.PARAMETER WriteToHostToo
    Boolean flag (default=true) to let the function put the message additionally to the console

.PARAMETER Severity
    Uses the enum [LogSeverity] (default=[LogSeverity]::VERBOSE) to choose the loglevel.
    The logfile will contain that loglevel and depending on error or warning, it will be shown in the console

.EXAMPLE
    Write-Log -message "Hello World"

.EXAMPLE
    Write-Log -message "Hello World" -severity ([LogSeverity]::ERROR)

.EXAMPLE
    "Hello World" | Write-Log

.EXAMPLE
    Write-Log -message "Hello World" -WriteToHostToo $false

.INPUTS
    String

.OUTPUTS
    $null

.NOTES
    Author:  florian.von.bracht@apteco.de

#>

    [cmdletbinding()]
    param(
          [Parameter(Mandatory=$true,ValueFromPipeline)][String]$Message
         ,[Parameter(Mandatory=$false)][Boolean]$WriteToHostToo = $true
         ,[Parameter(Mandatory=$false)][LogSeverity]$Severity = [LogSeverity]::VERBOSE
    )

    Process {

        # If the variable is not present, it will create a temporary file
        If ( $null -eq $logfile ) {
            $f = New-TemporaryFile
            $Script:logfile = $f.FullName
            Write-Warning -Message "There is no variable '`$logfile' present on 'Script' scope. Created one at '$( $Script:logfile )'"
        }

        # Testing the path
        If ( ( Test-Path -Path $logfile -IsValid ) -eq $false ) {
            Write-Error -Message "Invalid variable '`$logfile'. The path '$( $logfile )' is invalid."
        }

        # If a process id (to identify this session by a guid) it will be set automatically here
        If ( $null -eq $processId ) {
            $Script:processId = [guid]::NewGuid().ToString()
            Write-Warning -Message "There is no variable '`$processId' present on 'Script' scope. Created one with '$( $Script:processId )'"
        }

        # Create an array first for all the parts of the log message
        $logarray = @(
            [datetime]::Now.ToString("yyyyMMddHHmmss")
            $Script:processId
            $Severity.ToString()
            $Message
        )

        # Put the array together
        $logstring = $logarray -join "`t"

        # Save the string to the logfile
        #$logstring | Out-File -FilePath $logfile -Encoding utf8 -Append -NoClobber
        #Out-File -InputObject = $logstring
        $randomDelay = Get-Random -Maximum 3000
        $outArgs = @{
            FilePath = $script:logfile
            InputObject = $logstring
            Encoding = "utf8"
            Append = $true
            NoClobber = $true
        }
        Invoke-CommandRetry -Command 'Out-File' -Args $outArgs -retries 10 -MillisecondsDelay $randomDelay | Out-Null

        # Put the string to host, too
        If ( $WriteToHostToo -eq $true ) {
            # Write-Host $message # Updating to the newer streams Information, Verbose, Error and Warning
            Switch ( $Severity ) {
                ( [LogSeverity]::VERBOSE ) {
                    #Write-Verbose $message $message -Verbose # To always show the logmessage without verbose flag, execute    $VerbosePreference = "Continue"
                    Write-Output -InputObject $Message
                }
                ( [LogSeverity]::INFO ) {
                    Write-Information -MessageData $Message -InformationAction Continue
                }
                ( [LogSeverity]::WARNING ) {
                    Write-Warning -Message $Message
                }
                ( [LogSeverity]::ERROR ) {
                    Write-Error -Message $Message -CategoryActivity "ERROR"
                }
                Default {
                    #Write-Verbose -Message $message -Verbose
                    Write-Output -InputObject $Message
                }
            }
        }

        # Return
        $null

    }

}


