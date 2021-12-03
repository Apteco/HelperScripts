

IF EXISTS (SELECT * FROM sys.schemas WHERE name = N'faststats_schema')
BEGIN
	PRINT 'Dropping faststats_schema schema'
	EXEC sys.sp_executesql N'DROP SCHEMA faststats_schema'
	PRINT 'Done'
END
GO

IF EXISTS (SELECT * FROM sys.schemas WHERE name = N'faststats_service')
BEGIN
	PRINT 'Dropping faststats_service schema'
	EXEC sys.sp_executesql N'DROP SCHEMA faststats_service'
	PRINT 'Done'
END
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'faststats_service')
BEGIN
	PRINT 'Dropping faststats_service user'
	EXEC sys.sp_executesql N'DROP USER faststats_service'
	PRINT 'Done'
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'faststats_service')
BEGIN
	PRINT 'Creating faststats_service user'
	EXEC sys.sp_executesql N'CREATE USER [faststats_service] FOR LOGIN [faststats_service] WITH DEFAULT_SCHEMA=[faststats_schema]'
	PRINT 'Done'
END
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'faststats_schema')
BEGIN
	PRINT 'Creating faststats_schema schema'
	EXEC sys.sp_executesql N'CREATE SCHEMA [faststats_schema] AUTHORIZATION [faststats_service]'
	PRINT 'Done'
END
GO

EXEC sys.sp_addrolemember N'db_datareader', N'faststats_service'
EXEC sys.sp_addrolemember N'db_datawriter', N'faststats_service'
EXEC sys.sp_executesql N'GRANT CONNECT TO [faststats_service]'
GO

PRINT 'Done'
GO