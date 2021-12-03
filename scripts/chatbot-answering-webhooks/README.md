# Which sqlite dlls to use?

- Downloaded this one: https://www.nuget.org/packages/Stub.System.Data.SQLite.Core.NetStandard/
- Used following files

```
.\stub.system.data.sqlite.core.netstandard.1.0.115.5\lib\netstandard2.1\System.Data.SQLite.xml
.\stub.system.data.sqlite.core.netstandard.1.0.115.5\lib\netstandard2.1\System.Data.SQLite.dll
.\stub.system.data.sqlite.core.netstandard.1.0.115.5\lib\netstandard2.1\System.Data.SQLite.dll.altconfig
.\stub.system.data.sqlite.core.netstandard.1.0.115.5\runtimes\linux-x64\native\SQLite.Interop.dll
```

- And put them into the same folder and executed `[Reflection.Assembly]::LoadFile($dllFile)` only for full path of `System.Data.SQLite.dll`

# Difference between dot-sourcing and direct calling

If the event should be able to access the surrounding environment with functions, variables etc. you need to call the script like `. ./filewatcher__register.ps1`

Otherwise when calling it like `./filewatcher__register` the task can only access itself and the messagedata

# Call the script

```bash
`xxx@localhost:~/# pwsh 10__register_watchdog_and_process.ps1`
```

Execute it as a background job

```bash
pwsh 10__register_watchdog_and_process.ps1 >> /dev/null 2>&1 &
```

List running jobs in background with `jobs`

Bring the job to the foreground with `fg 1` (replace the job id from the squared brackets) and then you can end it with CTRL+C

After re-logging in to the server, you can see the running processes with `sudo ps aux` or `top`. Search for PID and kill the process with somethin like `sudo kill 105706`. If the job stays in state `T` or `Tl`, then try the command `sudo kill -9 105706` with the correct processid

# Notes

This is how the personalisation store does look like technically: ![grafik](https://user-images.githubusercontent.com/14135678/142027818-ffe32063-4dcc-4638-8329-907e7e2846e1.png)