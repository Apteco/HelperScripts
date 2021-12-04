# Description

After doing a backup from the apteco databases in MS SQLServer and importing that backup to another SQLServer the faststats_service user won't work out of the box. So this script will make sure it will recreate the user and schema in this database

Before using this process, make sure you tried the following on each restored database

```SQL
EXEC sp_change_users_login 'Report'
-- If an entry appears, execute this one
EXEC sp_change_users_login 'Auto_Fix', 'faststats_service'.
```


# Steps

* To use this script, download the whole repository and make sure you are on the sqlserver hosting machine
* Make sure to unzip the repository with 7zip or show properties of the zip file and trust this file (right bottom corner)
* Now use this folder
* Edit the `recreate_schema_and_users.ps1` and change the line with `instances = @( "777D0B7" )` to your sqlserver instance name. This could also need a `\SQLEXPRESS` at the end
* By default this script is using the current logged in user of the powershell process, so either start the powershell with a domain user with access to sqlserver or change the connection string in the line starting with `$connectionString = `. For more information see: https://www.connectionstrings.com/sql-server/