Since CleverReach changed the expiry date of the tokens from three years to 30 days, we have implemented a way of automatic token creation and exchange.

There are two ways of using it:
1. On the app server in a specific place called by a Windows Scheduled Task in a regular rhythm
1. During the Data Build called as a preload or postload action where the file will be automatically deployed to the app server

# Prerequisites

Open the script `cleverreach__00__create_settings.ps1` and have a look at the following parts

If you want to receive notifications about a refreshed or failed token, put this to `$true` or `$false`

```PowerShell
    "sendMailOnCheck" = $true
    "sendMailOnSuccess" = $true
    "sendMailOnFailure" = $true
```

Change the default receiver email address for receiving those notifications

```PowerShell
    "notificationReceiver" = "admin@example.com"
```

If the notifications should be send, make sure to configure the mail settings

```PowerShell
    "mail" = @{
        smptServer = "smtp.example.com"
        port = 587
        from = "admin@example.com"
        username = "admin@example.com"
        password = $smtpPassEncrypted
    }
```

Then you execute that settings creation script. It does not need administrator rights.

NOTE: The script will ask you about the path to store the token. It needs to be accessible to the app server or needs to be put in the system folder so Designer can put the file into the deployment


# Method 1 - Regular Task (Default)

* Change the script as described above
* Execute the script `cleverreach__00__create_settings.ps1` first and you will be asked a few things and your smtp password - if you don't want to use the email notifications just leave it blank or enter some random string
* This will save a `settings.json` file and a token file like `cr.token` in the same folder (as default setting)
* The script will ask you to create a scheduled task automatically that will check and exchange (if needed) the token on a daily schedule. It should look like here in the screenshots<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/102686228-8257ae80-41e6-11eb-81c0-ff27a4cf45bb.png)<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/102686233-8c79ad00-41e6-11eb-9e73-825127985a39.png)<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/102686241-99969c00-41e6-11eb-814e-720cc5d100e0.png)

# Method 2 - Designer Action

* Change the script as described above
* Execute the script `cleverreach__00__create_settings.ps1` first and you will be asked a few things and your smtp password - if you don't want to use the email notifications just leave it blank or enter some random string
* This will save a `settings.json` file and a token file like `cr.token` in the same folder (as default setting). But for this method please make sure to change the path to the system folder like `D:\Apteco\Build\Holidays\cr.token` so it will be automatically deployed to the server
* In Designer create a preload or postload action like this:<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/102684853-68b16980-41dc-11eb-9e77-e26e1ded749a.png)
* The log is configured to send the log entries to a separate text file AND the Designer log (you can see an example here that the token exchange failed):<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/102686210-550b0080-41e6-11eb-935b-3f3a3651ba62.png)



# Configure PeopleStage to read token

## Channel Editor

Add the new parameter `Access Token Path` and change it to the local path where the token is saved

![grafik](https://user-images.githubusercontent.com/14135678/104179067-93719500-540b-11eb-92db-f3b8d8cdd9ec.png)

This setting is now possible from Orbit Campaign Channel Editor, too (2021-10-27).

## Response Gatherer

Add the new parameter `ACCESSTOKENPATH` and change it to the local path where the token is saved

![grafik](https://user-images.githubusercontent.com/14135678/104179240-d3387c80-540b-11eb-9ab4-f963fac445e0.png)


# Troubleshooting

```
Send-MailMessage : Das Remotezertifikat ist laut Validierungsverfahren ungültig
The remote certificate is invalid according to the validation procedure.
```

When generating the settings.json file, set `deactivateServerCertificateValidation` to `$true` (Default `$false`)

```
Unable to relay recipient in non-accepted domain
```

Check your mailserver, looks like the (external) recipient is not allowed by the current settings