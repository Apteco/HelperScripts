

# Make sure you 

* Installed `Apteco FastStats Email Response Gatherer`
* Used `C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseConfig.exe` to create an FERGE configuration file
* Put that xml file somewhere on the disk and allow it to be read
* Put this script and subfolders somewhere on your disk and allow it be read and executed

Then you need to change the settings in `.\bin\load_settings.ps1`

# Note

To capture all log entries rename the integrations folder in something like `c:\program files\apteco\faststats email response gatherer x64\xintegrations`
otherwise ferge will start a subprocess which cannot be captured.


# Automated Run

Optionally you can create a scheduled task to trigger this script. In the scheduled task create an action with program `powershell.exe` and argument like `-file "D:\Apteco\scripts\response_gathering\ferge__10__getresponses.ps1"`