<#
Reads the credentials from the settings object which is defined like this

$smtpPass = Read-Host -AsSecureString "Please enter the SMTP password"
$smtpPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$smtpPass).GetNetworkCredential().Password)
$settings = @{
    ...
    "mail" = @{
        smptServer = "smtp.example.com"
        port = 587
        from = "admin@example.com"
        username = "admin@example.com"
        password = $smtpPassEncrypted
    }
    ...
}
# Parameter/Arguments splatting is well explained here https://kpatnayakuni.com/2019/01/21/powershell-how-to-use-splatting-to-pass-parameters-to-commands/
# https://adamtheautomator.com/powershell-splatting-what-is-it-and-how-does-it-work/#Combining_Traditional_Parameters_and_Splatting

# Can be called like

# Method 1 with named arguments
Send-Mail -to "florian.von.bracht@apteco.de" -subject "[TRIGGERDIALOG] Test" -body "Hello World"

# Method 2 with splatted arguments
$splattedArguments = @{
    "to" = "florian.von.bracht@apteco.de"
    "subject" = "[TRIGGERDIALOG] Test"
    "body" = "Hello World"
}
Send-Mail @splattedArguments # note the @ instead of $

#>
Function Send-Mail {

    [CmdLetBinding()] #[CmdLetBinding(SupportsShouldProcess)]

    param(

        #[parameter(mandatory=$true,parametersetname="Path")]
        #[parameter(mandatory=$true,parametersetname="Name")]
        [parameter(mandatory=$true)][string]$to,
        [parameter(mandatory=$true)][string]$subject,
        [parameter(mandatory=$true)][string]$body

    )

    begin {

        # build the credentials object from the settings
        $cred = New-Object System.Management.Automation.PSCredential $settings.mail.username, ( Get-SecureToPlaintext $settings.mail.password | ConvertTo-SecureString -asplaintext -force  )

    }

    process {
    
        # send the mail

        $mailParams = @{
            To = $to
            Subject = $subject
            Body = $body
            SmtpServer = $settings.mail.smtpServer 
            From = $settings.mail.from 
            UseSsl = $true
            Port = $settings.mail.port
            Credential = $cred
            encoding = ([System.Text.Encoding]::UTF8)
            verbose = $true
        }

        Send-MailMessage @mailParams 

        <# 
        Send-MailMessage -To $to `
                         -Subject $subject `
                         -Body $body `
                         -SmtpServer $settings.mail.smtpServer `
                         -From $settings.mail.from `
                         -UseSsl -Port $settings.mail.port -Credential $cred -encoding ([System.Text.Encoding]::UTF8) -Verbose
        #>

    }

    end {

        #return
        $true

    }
}

