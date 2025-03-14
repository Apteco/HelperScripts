
<#
"Hello World" | Get-PlaintextToSecure | Get-SecureToPlaintext

WARNUNG: No keyfile present at '.\aes.key'. Creating it now
Hello World






"Hello World" | Get-PlaintextToSecure
76492d1116743f0423413b16050a5345MgB8AHIATAAyADEAcwBiAGsATwBJAEgANQBFAEUAbwBsAHUANABWAE8AaQBtAEEAPQA9AHwAMQBmADMANAA0ADAAMAA2AGYANABmAGQAOQBmAGYAYwA4AGMAYQA0ADkAOQBjADcAZQA4ADEANgAxAGIANAAxADMANgBlADMANQAwADEAYgBiADEAZABkAGQAMgAzADAAMgA5AGQANQBmADgAMABkAGUANABmAGEANAAwAGMAMwA=


Save this text into a variable like

$t = "Hello World" | Get-PlaintextToSecure

And decrypt it with 

$t | Get-SecureToPlaintext
Hello World

Please don't try to move the keyfile or the encrypted string to another machine. It uses a combination of AES encryption and SecureString, where the last one is dependent on the current machine or account.
You can only decrypt the text on the same machine/account where you have encrypted it.

#>

Function Get-PlaintextToSecure {

    [cmdletbinding()]

    param(
         [Parameter(Mandatory=$true,ValueFromPipeline)][String]$String
        ,[Parameter(Mandatory=$false)][String]$KeyfilePath = ".\aes.key"
    )
    
    Begin {

        $return = ""

        # If the scriptPath variable is not present, use the current location
        #If ( $null -eq $scriptPath ) {
        #    Write-Warning -Message "Variable `$scriptPath is not defined. Automatically using current location."
        #    $private:scriptPath = ( Get-Location ).path
        #}

        # Keyfile to search for
        #$keyfile = Join-Path -Path $scriptPath -ChildPath $KeyfilePath

        # Checking existance of keyfile
        If ( (Test-Path -Path $KeyfilePath) -eq $false ) {
            Write-Warning -Message "No keyfile present at '$( $KeyfilePath )'. Creating it now"
            If ( (Test-Path -Path $KeyfilePath -IsValid) -eq $true ) {
                Create-KeyFile -Path $KeyfilePath -ByteLength 32
            } else {
                Write-Warning -InputObject "Path is invalid. Please check '$( $KeyfilePath )'"
            }

        }

    }

    Process {

        If ( (Test-Path -Path $KeyfilePath) -eq $true ) {

            # generate salt
            $salt = Get-Content -Path $KeyfilePath -Encoding UTF8

            # convert
            $stringSecure = ConvertTo-secureString -String $String -asplaintext -force
            $return = ConvertFrom-SecureString $stringSecure -Key $salt

        }

    }

    End {

        # return
        return $return
        
    }

}

Function Get-SecureToPlaintext {

    [cmdletbinding()]
    
    param(
         [Parameter(Mandatory=$true,ValueFromPipeline)][String]$String
        ,[Parameter(Mandatory=$false)][String]$KeyfilePath = ".\aes.key"
    )

    $return = ""

    # Checking existance of keyfile
    If ( (Test-Path -Path $KeyfilePath) -eq $false ) {

        Write-Warning -Message "No keyfile present at '$( $KeyfilePath )'!"

    # File exists
    } else {

        # generate salt
        $salt = Get-Content -Path $KeyfilePath -Encoding UTF8

        #convert
        Try {
            $stringSecure = ConvertTo-SecureString -String $String -Key $salt
            $return = (New-Object PSCredential "dummy",$stringSecure).GetNetworkCredential().Password
        } Catch {
            Write-Error "Decryption failed, maybe the keyfile was exchanged or you copied the files to another machine?"
        }

    }

    #return
    return $return

}


Function Create-KeyFile {
    
    param(
         [Parameter(Mandatory=$true)][string]$Path
        ,[Parameter(Mandatory=$false)][int]$ByteLength = 32
        ,[Parameter(Mandatory=$false)][Switch]$Force
    )
    
    $writeFile = $false

    # Evaluate if the file should be created
    if ( (Test-Path -Path $Path) -eq $true ) {

        If ( $Force -eq $true ) {
            $writeFile = $true
            Write-Warning "The keyfile at '$( $Path )' already exists. It will be removed now"
            Remove-Item -Path $Path
        } else {
            Write-Warning "The keyfile at '$( $Path )' already exists. Please use -Force to overwrite the file."
        }
        
    } else {

        # File does not exist -> create it
        $writeFile = $true

    }

    If ( $writeFile -eq $true) {

        # Checking the path validity
        If ( (Test-Path -Path $Path -IsValid) -eq $true ) {

            Write-Output -InputObject "Path is valid. Creating a new keyfile at '$( $Path )'"

            $Key = New-Object Byte[] $ByteLength   # You can use 16, 24, or 32 for AES
            [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
            $Key | Set-Content -Encoding UTF8 -Path $Path

        } else {

            Write-Warning -InputObject "Path is invalid. Please check '$( $Path )'"
            
        }

    }
    
}









<#
Password encryption for Apteco Orbit
#>
Function Crypt-Password {

    param(
        [String]$password
    )

    $cryptedPassword = @()
    $password.ToCharArray() | %{[int][char]$_} | ForEach {    
        If ($_ % 2 -eq 0) {
            $cryptedPassword += [char]( $_ + 1 )
        } else {
            $cryptedPassword += [char]( $_ - 1 )
        } 
    }

    $cryptedPassword -join ""

}