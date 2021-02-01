BACKUP DATABASE [WS_Reisen] 
TO DISK = N'D:\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Backup\WS_Reisen_Database.bak' WITH NOFORMAT, NOINIT,  
NAME = N'WS_Reisen-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
GO


BACKUP LOG [WS_Reisen] 
TO DISK = N'D:\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Backup\WS_Reisen_Log.TRN' WITH NOFORMAT, NOINIT,  
NAME = N'WS_Reisen-TRN Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
GO


-- Set recovery model from full to simple
USE [master]
GO
ALTER DATABASE [WS_Reisen] SET RECOVERY SIMPLE WITH NO_WAIT
GO

-- Create a checkpoint
USE [WS_Reisen] ;
checkpoint;

-- Then free up space
USE [WS_Reisen]
GO
DBCC SHRINKFILE (N'WS_Reisen_log' , 0, TRUNCATEONLY)
GO