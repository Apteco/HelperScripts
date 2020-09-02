
<#

Is-FileLocked -file 'c:\IExist.txt'

#>

function Is-FileLocked {
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $file
        
        ,[Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch] $inverseReturn = $false
    )

    try {

        $locked = $false
        
        Write-Log "Checking '$( $file.FullName )'"
        
        # If the file is currently locked by another thread or does not exist, then this will throw the exception
        [System.IO.FileStream] $stream = $file.Open( [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None )                

       

    } catch [System.IO.IOException] {
        
        $locked = $true

    } catch {

    # This part runs always, even if an error occured: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-7    
    } finally {

        $stream.Close()
        

    }

    if ( $inverseReturn ) {
        $locked = -not $locked
    }
    return $locked

}


<#

In combination:
$filePath = 'c:\IExist.txt'
# Wait for 60 seconds, retry every second, check if file is NOT locked
Wait-Action -Condition { !( Is-FileLocked -file $filePath ) } -Timeout 60 -$RetryInterval 1
"Done!"

#>

