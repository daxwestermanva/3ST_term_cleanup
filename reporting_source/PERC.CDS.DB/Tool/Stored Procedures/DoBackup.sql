
CREATE PROCEDURE [Tool].[DoBackup] 
-------------------------------------------------------------------------------------------------------------------------------------------
--	Last Updated:
	-- 2018/05/22 - Jason Bacani - Clean up; Removed default value for @destDBname AND REPLACED WITH null; should not have a default database at all
	-- 2022-01-12 - RAS	- Added "Test" as an exclusion so that backups will not be created if the calling database is NOT production.
	
-- EXEC [Tool].[DoBackup] 'InpatDetail','PRF_HRS','OMHSP_PERC_SbxB'
-------------------------------------------------------------------------------------------------------------------------------------------
(
	 @TName VARCHAR(200)
	,@SName VARCHAR(50)
	,@destDBname VARCHAR(50) = NULL
	,@suffix VARCHAR(25) = NULL
) 
AS
BEGIN

	--INLINE TESTING WITH PARAMETERS
	--DECLARE @TName VARCHAR(200)='Lithium_Writeback', @SName VARCHAR(50)='LSV'),@destDBname VARCHAR(50)='OMHSP_PERC_SbxB'
IF	(SELECT DISTINCT TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES) like '%Test' 
	or (SELECT DISTINCT TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES) like '%Dev'
	or (SELECT DISTINCT TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES) like '%Sbx'
BEGIN
--PRINT 'No!'
RETURN
END
	DECLARE @RCount INT = 0
	--DECLARE @suffix VARCHAR(10)='_BK'
	IF @suffix IS NULL 
	BEGIN
		SET @suffix='_BK'
	END

	IF EXISTS
	(
		SELECT * FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_SCHEMA = @SName AND TABLE_NAME = @TName
	)
	BEGIN

		DROP TABLE IF EXISTS #RecCount
		CREATE TABLE #RecCount (RCount INT)
		INSERT INTO #RecCount(RCount)

		EXEC('SELECT COUNT(*) AS RCount FROM ' + @SName + '.' + @TName)
		SELECT @RCount = RCount FROM #RecCount
		IF @RCount > 0
		BEGIN
			IF @destDBname IS NULL
			BEGIN
				EXEC('DROP TABLE IF EXISTS '+  @SName + '.' + @TName + @suffix)
				EXEC('SELECT * INTO ' + @SName + '.' + @TName + @suffix + ' FROM ' + @SName + '.' + @TName)
				EXEC('ALTER TABLE ' + @SName + '.' + @TName + @suffix + ' REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)')
			END
			ELSE
			BEGIN
				EXEC('DROP TABLE IF EXISTS '+ @destDBname + '.' + @SName + '.' + @TName + @suffix)
				EXEC('SELECT * INTO ' + @destDBname + '.'+ @SName + '.' + @TName + @suffix + ' FROM ' + @SName + '.' + @TName)
				EXEC('ALTER TABLE '+@destDBname + '.' + @SName + '.' + @TName + @suffix + ' REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)')
			END
		END

	END

END