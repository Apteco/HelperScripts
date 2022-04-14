This script is used to check a lot of things on a regular base and to inform about some stats and other information and send a daily summary. This monitor and email notification includes

- Custom checks e.g. if a file is zero size or locked -> This can be extended via `/bin/define_checks.ps1` and the files, folders to check are entered in `./bin/load_settings.ps1`
- Installed .NET runtimes
- SSL Certificates (with expiration dates)
- Drive Space (used and free)
- Windows Services
- Orbit Updater settings
- Installed Orbit versions vs. the repository versions
- Current CPU and RAM usage
- Computer information like OS version, uptime etc.

The custom checks can also trigger other actions. In this case the monitor just informs the users about those problems, but an automatic delete/restart etc. could be implemented.

- To implement this monitor, please download these files, open `mntr__00__create_settings.ps1` and check through all settings, they are commented inline
- When you are happy with the settings, execute the script with PowerShell and answer the questions you get during the execution
- Don't be afraid to execute the settions creation multiple times. Older settings files won't get overwritten and this script is able to run with multiple settings files
- This script is automatically creating a Windows Scheduled Task to run the monitor every 5 minutes and to send a summary at 11pm every day
- The logfiles will be created from scratch every day and automatically cleaned up after 14 days