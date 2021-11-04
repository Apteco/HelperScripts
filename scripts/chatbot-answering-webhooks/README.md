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

`xxx@localhost:~/# pwsh 10__register_watchdog_and_process.ps1`