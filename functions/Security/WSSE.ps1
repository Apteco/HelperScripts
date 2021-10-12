<#
example for header
X-WSSE: UsernameToken
Username="customer001",
PasswordDigest="ZmI2ZmQ0MDIxYmQwNjcxNDkxY2RjNDNiMWExNjFkZA==",
Nonce="d36e316282959a9ed4c89851497a717f",
Created="2014-03-20T12:51:45Z"
source: https://dev.emarsys.com/v2/before-you-start/authentication
api endpoints: https://trunk-int.s.emarsys.com/api-demo/#tab-customer
other urls
https://dev.emarsys.com/v2/emarsys-developer-hub/what-is-the-emarsys-api
#>
function Create-WSSE-Token {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$false)][pscredential]$cred                                   # securestring containing username as user and secret as password
        ,[Parameter(Mandatory=$false)][Switch]$noMilliseconds = $false 
        #,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://api.emarsys.net/api/v2/"  # default url to use
        #,[Parameter(Mandatory=$false)][String]$method = "Get"
        #,[Parameter(Mandatory=$false)][String]$outFile = ""
        #,[Parameter(Mandatory=$false)][System.Object]$body = $null
    )

    begin {
        
        # Extract credentials
        $secret = $cred.GetNetworkCredential().Password
        $username = $cred.UserName

        # Create nonce
        $randomStringAsHex = Get-RandomString -length 16 | Format-Hex
        $nonce = Get-StringfromByte -byteArray $randomStringAsHex.Bytes
        
        # Format date
        if ( $noMilliseconds ) {
            $utcString = [datetime]::UtcNow.ToString("s")
            $date = $utcString + "Z" #2021-10-01T15:32:23Z
        } else {
            $date = [datetime]::UtcNow.ToString("o")         #2021-10-01T15:33:11.0564473Z
        }
         
    }

    process {

        # Create password digest
        $stringToSign = $nonce + $date + $secret
        #$sha1 = Get-StringHash -inputString $stringToSign -hashName "SHA1"
        #$passwordDigest = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($sha1))
        $sha1 = Get-StringHash -inputString $stringToSign -hashName "SHA1" -returnBytes
        $passwordDigest = [System.Convert]::ToBase64String($sha1)
        
        # Combine Escher XWSSE header
        <#
        $xwsseArr = [System.Collections.ArrayList]@()
        [void]$xwsseArr.Add("UsernameToken Username=""$( $username )""")
        [void]$xwsseArr.Add("PasswordDigest=""$( $passwordDigest )""")
        [void]$xwsseArr.Add("Nonce=""$( $nonce )""")
        [void]$xwsseArr.Add("Created=""$( $date )""")
        #>

        $xwsseObj = @{
            "Username" = $username
            "PasswordDigest" = $passwordDigest
            "Nonce" = $nonce
            "Created" = $date
        }

        # Setup content type
        #$contentType = "application/json;charset=utf-8"
        #$xwsseArr.Add("Content-type=""$( $contentType )""") # take this out possibly
        
        # Join Escher XWSSE together
        #$xwsse = $xwsseArr -join ", " 

    }
    
    end {

        $xwsseObj

    }
}

#$wsse = Create-WSSE-Token -cred $cred -noMilliseconds
#$wsse
#CId2KIOFic3OK0D47/x33rX5PgE=

<#
Passwort                                abc123
Nonce-Wert                              0123456789abcdef
Zeitstempel                             2013-08-15T23:12:01Z
Base64-encodierter Passwort-Digest      CId2KIOFic3OK0D47/x33rX5PgE=
#>