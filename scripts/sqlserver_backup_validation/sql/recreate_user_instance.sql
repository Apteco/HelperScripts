-- Find out current sessions
--SELECT session_id FROM sys.dm_exec_sessions WHERE login_name = N'faststats_service'
--KILL 51  --51 is session_id here, you may get different id


IF EXISTS (SELECT * FROM sys.server_principals WHERE name = N'faststats_service')
	BEGIN
		PRINT 'Dropping faststats_service login'
		EXEC sys.sp_executesql N'DROP LOGIN faststats_service'
		PRINT 'Done'
	END	
GO

-- SQL Server 2005
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'faststats_service')
BEGIN
	PRINT 'Creating faststats_service login with password fa5t5tat5!'
	EXEC sys.sp_executesql N'CREATE LOGIN [faststats_service] WITH PASSWORD=N''fa5t5tat5!'', DEFAULT_DATABASE=[FS_Config], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON'
	PRINT 'Done'
END	
GO

BEGIN TRY
  PRINT 'Adding bulkadmin role for faststats_service...'
  EXEC sys.sp_executesql N'GRANT ADMINISTER BULK OPERATIONS TO faststats_service'
END TRY
BEGIN CATCH
  PRINT 'Failed to add bulkadmin role for faststats_service - continuing anyway...'
END CATCH
GO