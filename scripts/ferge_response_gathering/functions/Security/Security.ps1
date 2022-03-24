Function Get-PlaintextToSecure {

    param(
         [Parameter(Mandatory=$true)][String]$String
    )
    
    # generate salt
    Create-KeyFile -keyfilename "$( $scriptPath )\aes.key" -byteLength 32
    $salt = Get-Content -Path "$( $scriptPath )\aes.key" -Encoding UTF8

    # convert
    $stringSecure = ConvertTo-secureString -String $String -asplaintext -force
    $return = ConvertFrom-SecureString $stringSecure -Key $salt

    # return
    $return

}

Function Get-SecureToPlaintext {

    param(
         [Parameter(Mandatory=$true)][String]$String
    )

    # generate salt
    $salt = Get-Content -Path "$( $scriptPath )\aes.key" -Encoding UTF8

    #convert 
    $stringSecure = ConvertTo-SecureString -String $String -Key $salt
    $return = (New-Object PSCredential "dummy",$stringSecure).GetNetworkCredential().Password

    #return
    $return

}

Function Create-KeyFile {
    
    param(
         [Parameter(Mandatory=$false)][string]$keyfilename = "$( $scriptPath )\aes.key"
        ,[Parameter(Mandatory=$false)][int]$byteLength = 32
    )

    #$keyfile = ".\$( $keyfilename )"
    
    # file does not exist -> create one
    if ( (Test-Path -Path $keyfilename) -eq $false ) {
        $Key = New-Object Byte[] $byteLength   # You can use 16, 24, or 32 for AES
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
        $Key | Set-Content -Encoding UTF8 -Path $keyfilename
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