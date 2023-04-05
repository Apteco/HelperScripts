
# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @( 
        [System.Net.SecurityProtocolType]::Tls
        [System.Net.SecurityProtocolType]::Tls11 
        [System.Net.SecurityProtocolType]::Tls12
        [System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    #[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"
}

<#
# Setup default credentials for proxy communication per default
$proxyUrl = $null
if ( $settings.proxy.proxyUrl ) {
    $proxyUrl = $settings.proxy.proxyUrl
    $useDefaultCredentials = $true

    if ( $settings.proxy.proxyUseDefaultCredentials ) {
        $proxyUseDefaultCredentials = $true
        [System.Net.WebRequest]::DefaultWebProxy.Credentials=[System.Net.CredentialCache]::DefaultCredentials
    } else {
        $proxyUseDefaultCredentials = $false
        $proxyCredentials = New-Object PSCredential $settings.proxy.credentials.username,( Get-SecureToPlaintext -String $settings.proxy.credentials.password )
    }

}

function Check-Proxy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][Hashtable]$invokeParams
    )
    
    begin {
        
    }
    
    process {
        if ( $script:proxyUrl ) {
            $invokeParams.Add("Proxy", $script:proxyUrl)
            $invokeParams.Add("UseDefaultCredentials", $script:useDefaultCredentials)
            if ( $script:proxyUseDefaultCredentials ) {
                $invokeParams.Add("ProxyUseDefaultCredentials", $true)
            } else {
                $invokeParams.Add("ProxyCredential", $script:proxyCredentials)         
            }
        }
    }
    
    end {
        
    }
}
#>

<#
# Add proxy settings
if ( $proxyUrl ) {
    $paramsPost.Add("Proxy", $proxyUrl)
    $paramsPost.Add("UseDefaultCredentials", $useDefaultCredentials)
    if ( $proxyUseDefaultCredentials ) {
        $paramsPost.Add("ProxyUseDefaultCredentials", $true)
    } else {
        $paramsPost.Add("ProxyCredential", $proxyCredentials)         
    }
}
#>