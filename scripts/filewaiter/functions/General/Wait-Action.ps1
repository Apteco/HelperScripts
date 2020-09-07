
<#
https://mcpmag.com/articles/2018/03/16/wait-action-function-powershell.aspx?m=1

Use like

$scriptblock={Test-Path -Path 'c:\IExist.txt' -PathType Leaf};
Wait-Action -Condition $scriptblock -Timeout 60 -$RetryInterval 1;

-or-

Wait-Action -Condition {Test-Path -Path 'c:\IExist.txt' -PathType Leaf} -Timeout 60 -$RetryInterval 1;

Timeout in seconds

#>



function Wait-Action {
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Condition,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$Timeout,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object[]]$ArgumentList,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$RetryInterval = 5
    )
    try {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (($timer.Elapsed.TotalSeconds -lt $Timeout) -and (-not (& $Condition $ArgumentList))) {
            Start-Sleep -Seconds $RetryInterval
            $totalSecs = [math]::Round($timer.Elapsed.TotalSeconds, 0)
            Write-Verbose -Message "Still waiting for action to complete after [$totalSecs] seconds..."
        }
        $timer.Stop()
        if ($timer.Elapsed.TotalSeconds -gt $Timeout) {
            throw 'Action did not complete before timeout period.'
        } else {
            Write-Verbose -Message 'Action completed before timeout period.'
        }
    } catch {
        Write-Error -Message $_.Exception.Message
    }
}



