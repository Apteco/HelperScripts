# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS -eq $true ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

<# 
Code to obtain certificate SHA256 hashes and also deactivate certificate checks, if wished

For PowerShell Core call URLs with invalid certificates like:

Invoke-RestMethod -Uri https://sachsenstation -SkipCertificateCheck

Got this code from: https://www.jeansnyman.com/posts/invoke-rest-method-self-signed-certificate-errors/

#>


if ( $settings.deactivateCertificateCheck -eq $true ) {

    # This is the way for PowerShell Core
    if ($PSEdition -ne 'Core'){

        Write-Host "Please add the flag -SkipCertificateCheck to your Invoke-RestMethod and Invoke-WebRequest calls"

    # This is the way for Windows PowerShell - only execute this time and call the APIs as usual
    } else {

        $certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
        Add-Type $certCallback
    
        [ServerCertificateValidationCallback]::Ignore()

    }

}

