
Set-ExecutionPolicy Unrestricted

Register-PackageSource -Name MyNuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet

find-package Winscp -ProviderName NuGet -RequiredVersion 5.21.7 -IncludeDependencies | Install-Package -Scope CurrentUser #-Destination . -Force

$pkg = Get-Item (Get-Package winscp).Source

$target = Join-Path $pkg.Directory /lib/net40/WinSCPnet.dll


[System.Reflection.Assembly]::LoadFrom($target)


# Define clear text string for username and password
[string]$userName = 'user'
[string]$userPassword = 'password'

# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force

[pscredential]$credObject = [System.Management.Automation.PSCredential]::new($userName, $secStringPassword)

# https://www.powershellgallery.com/packages/WinSCP/5.7.4.1/Content/Functions%5CNew-WinSCPSession.ps1
$sess = New-WinSCPSession -Credential $credObject -HostName "fpt.server.de" -Protocol ( [WinSCP.Protocol]::Sftp )



