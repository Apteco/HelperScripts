


#-----------------------------------------------
# NOTES
#-----------------------------------------------

<#

This script works when executed in single parts.... if the certificate is expired, it needs to create a new one and this need a temporary dns txt entry where the key is generated through this script. When it is created succesfully, all the other steps work fine here


#>


#-----------------------------------------------
# DEBUG
#-----------------------------------------------


# debug switch
$debug = $false


#-----------------------------------------------
# MODULES
#-----------------------------------------------

Import-Module WriteLog
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Import-Module Posh-ACME


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

$logfile = "D:\Log\cert_renewal.log"
Set-Logfile -Path $logfile
Write-Log "-----------------------------------------------"
Write-Log -Message "Debug mode is: $( $debug )"


# settings
$dns = "crm.apteco.io"
$destCertPath = "Cert:\LocalMachine\My" #"Cert:\LocalMachine\Remote Desktop" #"Cert:\LocalMachine\WebHosting" # https://serverfault.com/questions/710293/wmic-error-when-setting-remote-desktop-self-signed-certificate
$email = "admin@crm.apteco.io"
$renewalBeforeExpiration = 14 # days

# dns settings - IONOS API
$ionosAPIBase = "https://api.hosting.ionos.com/"
$ionosHeaders = [Hashtable]@{
    "X-API-Key" = "xapikey"
}
$contentType = "application/json"
$ionosDnsZone = "apteco.io"
$ionosDnsZoneSuffix = "crm.apteco.io"


#-----------------------------------------------
# CHECK CURRENT CERTIFICATE OR CREATE NEW ONE
#-----------------------------------------------

# Create a new one if in debug mode
if ( $debug ) {
    
    Write-Log -Message "Creating a complete new certificate"

    # Create new certificate
    # For the new creation it would be helpful that the script can set the dns txt entry itself (and remove it), but this API is still in beta on IONOS side
    # This is created to: %LOCALAPPDATA%\Posh-ACME
    $cert = New-PACertificate $dns -AcceptTOS -Contact $email

    # TODO [ ] This cannot be automated yet, so create the txt record with the lines below and then proceed with the line above

    # DNS Record creation
    # https://developer.hosting.ionos.de/docs/dns
    $dnsZones = Invoke-RestMethod -Method Get -Uri "$( $ionosAPIBase )dns/v1/zones" -Headers $ionosHeaders -Verbose -ContentType $contentType
    $dnsZone = $dnsZones | where { $_.name -eq $ionosDnsZone } 

    # Times out a lot
    #$dnsRecords = Invoke-RestMethod -Method Get -Uri "$( $ionosAPIBase )dns/v1/zones/$( $dnsZone.id )?suffix=$( $ionosDnsZoneSuffix )&recordType=TXT" -Headers $ionosHeaders -Verbose -ContentType $contentType

    [array]$dnsRecordBody = [Array]@(
        [PSCustomObject]@{
            name = "testdomain.ionos.de"
            type = "TXT"
            content = "1.2.3.4" #$key
            ttl = 3600
            prio = 0
            disabled = $false

        }
    ) 
    $dnsRecordBodyJson = ConvertTo-Json -Depth 99 -InputObject $dnsRecordBody
    $createdRecord = Invoke-RestMethod -Method Post -Uri "$( $ionosAPIBase )dns/v1/zones/$( $dnsZone.id )/records" -Headers $ionosHeaders -Verbose -ContentType $contentType -Body $dnsRecordBodyJson


    $deleteRecord = Invoke-RestMethod -Method Delete -Uri "$( $ionosAPIBase )dns/v1/zones/$( $dnsZone.id )/records/$( $createdRecord.id )" -Headers $ionosHeaders -Verbose -ContentType $contentType

} else {   
 
    # Details for last certificate
    Write-Log -Message "Getting last certificate"
    $cert = Get-PACertificate | select -first 1 # #| where { $_.Thumbprint -eq "EBECC8ADB9A2EB194D02B31967601DE8331A5D95" }#$cert.Thumbprint }
    #Submit-Renewal

}

# Age of last certificate
$ts = New-TimeSpan -End $cert.NotAfter -Start ([datetime]::Today)
Write-Log -Message "Certificate expires in $( [int]$ts.TotalDays ) days"

# Create a new certificate if less than n days
If ( $ts.TotalDays -lt $renewalBeforeExpiration ) {
    Write-Log -Message "Renewal of certificate, because less than $( $renewalBeforeExpiration ) days left"
    $cert = Submit-Renewal -Force -NoSkipManualDns
} 


#-----------------------------------------------
# IMPORT CERTIFICATE - IF NEEDED
#-----------------------------------------------

If ( $debug -eq $true -or $ts.TotalDays -lt $renewalBeforeExpiration ) {
    
    # Import the certificate
    Write-Log -Message "Importing the certificate"
    Set-Location -Path $destCertPath
    $cer = Import-PfxCertificate -Password $cert.PfxPass -FilePath $cert.PfxFullChain #$cert.PfxFile 

    # Read the private key
    Write-Log -Message "Reading private key"
    $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cer)
    # Check the cert folder after import
    #$SslCertificate = Get-ChildItem -Path $destCertPath | where { $_.NotBefore -lt [datetime]::now -and $_.NotAfter -gt [datetime]::now -and $_.Subject -match $dns } | Sort $_.NotAfter -descending | Select -First 1

    # Change back to file system
    Set-Location -Path $env:USERPROFILE

    # Using certificate for remote connections
    Write-Log -Message "Setting the certificate for remote desktop connections"
    $TSGS = Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace "root\cimv2\terminalservices"
    Set-WmiInstance -Path $TSGS -Arguments @{SSLCertificateSHA1Hash=$cert.Thumbprint.ToString()}

    # Give access to the private key file for NETWORK SERVICE
    Write-Log -Message "Giving access to private key for NETWORK SERVICE"
    $filename = $rsaCert.key.uniquename
    $path = "$( $env:ALLUSERSPROFILE )\Microsoft\Crypto\Keys\$( $filename )"
    icacls $path /grant "NT Authority\NETWORK SERVICE:F"

    # Restart services
    Write-Log -Message "Restarting remote services"
    ReStart-Service -Force -Name SessionEnv
    Restart-Service -Force -Name TermService

}

Write-Log -Message "All done!"
exit 0
# copy the certificate from "Web Hosting\Certificates" to "Personal\Certificates" and then execute this command with changed "<FINGERPRINT>"
# note: the SHA1 fingerprint should be without spaces and with capital letters
#wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash=EBECC8ADB9A2EB194D02B31967601DE8331A5D95
#wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash=$cert.Thumbprint


#wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash=84485E19C85D1F607865D49A924A73301EE9D529
#Stop-Service -Name SessionEnv
#ReStart-Service -Force -Name SessionEnv
#Restart-Service -Force -Name TermService
