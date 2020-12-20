
<#

Requirements:
* This log needs the presence of two global variables
* Those variables do not need to be in this script, they can just be declared like
$logfile = "C:\logfile.txt"
$processId = [guid]::NewGuid()
* The process id is good for parallel calls so you know they belong together

Current Version = 202002052330

#>


<#
Source: https://blogs.endjin.com/2014/07/how-to-retry-commands-in-powershell/
#>
Function Retry-Command
{
    param (
        [Parameter(Mandatory=$true)][string]$command, 
        [Parameter(Mandatory=$true)][hashtable]$args, 
        [Parameter(Mandatory=$false)][int]$retries = 10, 
        [Parameter(Mandatory=$false)][int]$MillisecondsDelay = ( Get-Random -Maximum 3000 )
    )
    
    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are 
    # treated as terminating errors, and will be caught by the catch block.
    $args.ErrorAction = "Stop"
    
    $retrycount = 0
    $completed = $false

    while (-not $completed) {
        try {
            & $command @args
            Write-Verbose ("Command [{0}] succeeded." -f $command)
            $completed = $true
        } catch {
            if ($retrycount -ge $retries) {
                Write-Verbose ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount)
                throw
            } else {
                Write-Verbose ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay)
                Start-Sleep -Milliseconds $MillisecondsDelay
                $retrycount++
            }
        }
    }
}


Function Write-Log {

    param(
         [Parameter(Mandatory=$true)][String]$message
    )

    # Create an array first for all the parts of the log message
    $logarray = @(
        [datetime]::Now.ToString("yyyyMMddHHmmss")
        $processId
        $message
    )

    # Put the array together
    $logstring = $logarray -join "`t"

    # Save the string to the logfile
    #$logstring | Out-File -FilePath $logfile -Encoding utf8 -Append -NoClobber
    #Out-File -InputObject = $logstring
    $randomDelay = Get-Random -Maximum 3000
    $outArgs = @{
        FilePath = $logfile
        InputObject = $logstring
        Encoding = "utf8"
        Append = $true
        NoClobber = $true
    }
    Retry-Command -Command 'Out-File' -Args $outArgs -Verbose -retries 10 -MillisecondsDelay $randomDelay

}

