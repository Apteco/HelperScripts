

function Test-Credential {
    [CmdletBinding()]
    param (
        [Parameter( 
            Mandatory = $false
            ,ValueFromPipeLine = $true
            #,ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $Credentials
        ,[Parameter(Mandatory=$false)][Switch]$NonInteractive = $false
         
    )
    
    begin {

        # Some settings
        $waitInterval = 200
        $waitForState = @("Completed","Failed")
        $maxRetries = 3
        $success = $false
        $initialUsername = $env:Username

        # The action script to check the credentials
        $scriptBlock = {
            $tmpFile = New-TemporaryFile
            Remove-Item $tmpFile
        }

        # Leave script if the non interactive mode is active and no credentials provided
        If ($NonInteractive -eq $true -and $Credentials -eq $null) {
            #Write-Host 
            throw [Exception] "Please make sure to provide -Credentials when in NonInteractive mode"
        }

    }
    
    process {
        
        $retries = 0
        Do {

            # At the first try, request the whole string
            If ( $retries -eq 0 -and $Credentials -eq $null) {
                $cred = Get-Credential -UserName $initialUsername
            } elseif ( $retries -eq 0 -and $Credentials -ne $null ) {
                $cred = $Credentials
            } elseIf ( $retries -gt 0 -and $NonInteractive -eq $false ) {
                # After the first try, only request the password
                $cred = Get-Credential -UserName $cred.UserName
            }

            # Start the job
            $job = Start-Job -ScriptBlock $scriptBlock -Credential $cred

            # Wait until job is completed or failed
            Do {
                Start-Sleep -Milliseconds $waitInterval -Verbose
                #"Waiting $( $job.State )"
            } Until ( $waitForState -contains $job.State )

            # Set success if job was completed successfully
            If ( $job.State -eq "Completed" ) {
                $success = $true
            }

            # Next try
            $retries += 1

        # Check if we have a success or if we are in noninteractive mode or if the retries are reached    
        } Until ( ( $retries -eq $maxRetries -or $NonInteractive -eq $true ) -or $success -eq $true )


    }
    
    end {

        return $success

    }

}

<#

# Interactive mode -> this one requests your user and password, uses the current user as default
Test-Credential

# Define User and password beforehand
$c = Get-Credential
Test-Credential -Credentials $c

OR 

$c = Get-Credential
Test-Credential -Credentials $c  -NonInteractive

# OR

Get-Credential | Test-Credential

#>
