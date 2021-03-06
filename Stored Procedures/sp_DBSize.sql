USE master
GO

IF OBJECT_ID(N'dbo.sp_DBSize', 'P') IS NULL
	EXECUTE ('CREATE PROCEDURE sp_DBSize AS SELECT 1');
GO

ALTER PROCEDURE dbo.sp_DBSize @database_name SYSNAME = NULL
AS
DECLARE @DB SYSNAME
	,@cmd NVARCHAR(4000)

CREATE TABLE #DBsize (
	dbname VARCHAR(100)
	,filename VARCHAR(100)
	,currentsizemb INT
	,freespacemb INT
	,percentfree INT
	,type_desc VARCHAR(100)
	,[dbid] INT
	)

SELECT TOP 1 @DB = NAME
FROM master..sysdatabases
WHERE dbid > 4
	AND Databasepropertyex(NAME, 'status') = 'online'
	AND (@database_name IS NULL OR NAME = @database_name)
ORDER BY NAME

WHILE @@ROWCOUNT = 1
BEGIN
	SET @cmd = N'USE [' + @DB + ']                  
      INSERT INTO #tableSize      
      SELECT DB_NAME () AS DbName,      
    name AS FileName,      
    size/128.0 AS CurrentSizeMB,      
    size/128.0 - CAST (FILEPROPERTY( name, ''SpaceUsed'') AS INT )/128.0 AS FreeSpaceMB,      
    convert(int,(size/128.0 - CAST (FILEPROPERTY( name, ''SpaceUsed'') AS INT )/128.0 )*100/(size/128.0)) as PercentFree,
    type_desc,db_id()
   FROM sys .database_files      
   ORDER BY type_desc DESC;              '

	EXEC Sp_executesql @cmd

	SELECT TOP 1 @DB = NAME
	FROM master..sysdatabases
	WHERE dbid > 4
		AND NAME > @DB
		AND (@database_name IS NULL OR NAME = @database_name)
		AND Databasepropertyex(NAME, 'status') = 'online'
	ORDER BY NAME
END

SELECT sys.NAME AS nome
	,tb.filename
	,tb.currentsizemb
	,tb.freespacemb
	,tb.percentfree
	,tb.type_desc
	,sy.physical_name
	,growth_MB = CASE is_percent_growth
		WHEN 1
			THEN STR(growth)
		WHEN 0
			THEN LTRIM(STR(growth * 8.0 / 1024, 10, 1))
		END
	,growth_type = CASE is_percent_growth
		WHEN 1
			THEN 'Percent growth'
		WHEN 0
			THEN 'MB'
		END
	,CASE max_size
		WHEN - 1
			THEN 'unrestricted growth'
		ELSE 'restricted growth to ' + LTRIM(STR(max_size * 8.0 / 1024, 10, 1)) + ' MB'
		END AS 'restricted ?'
FROM #DBsize tb
INNER JOIN master..sysdatabases sys
	ON tb.dbid = sys.dbid
INNER JOIN sys.master_files sy
	ON sy.database_id = sys.dbid
		AND sy.NAME = tb.filename
ORDER BY left(sy.physical_name, 2) ASC
	,type_desc DESC
	,freespacemb DESC
DROP TABLE #DBsize