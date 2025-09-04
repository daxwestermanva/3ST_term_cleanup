/********************************************************************************************************************
DESCRIPTION: Publishes data from an intermediate table to a permanent table e.g. for reporting purposes. This 
		     procedure is highly optimized loading and uses a staging table to improve load performance. The 
			 staging table is scripted as an exact copy of the published table, including clustered and nonclustered 
			 indexes. Loading the staging table uses minimal logging by inserting the data into a heap WITH (TABLOCK)
			 and creating the indexes on the staging table afterwards. The alternative is to create indexes in staging
			 prior to loading it, which takes roughly twice as much time. After the staging table is ready, it is 
			 switched with the published table using partition switching (fast, metadata only operation).

			 The source data typically is a temporary table, but could use physical tables as well. The source table
			 must include all columns required by the published table, and must have consistent spelling.

			 If this procedure is executed by any non ETL service account, it will avoid any DDL statement and instead
			 perform a simple TRUNCATE/INSERT, which isn't as fast but avoids any DDL trigger issue with production.
TEST:
	EXEC [Maintenance].[PublishTable] '[Present].[Medications]', '#Medications'

UPDATE:
	2019-02-12	- Matt Wollner	- Added Logging
	2019-02-13	- Jason Bacani	- Incorporated [Log].[PublishTable]
	2022-01-19	- Rebecca Stephens	- Replaced UDF Dflt.String_Agg with system function STRING_AGG.	
									- Added "collate" hint to data_compression_desc field in index section due to 
									- collation conflict error when switching to string_agg system function
	2022-05-12	- Alyssa Noesen	- added CAST([field] AS VARCHAR(MAX)) to STRING_AGG functions to prevent exceeding byte limit
	2022-05-15	- Rebecca Stephens	- Added condition to run same as "unattended mode" for Dev and Test environments. The 
									attended mode option, which does NOT create a staging table and then use SWITCH,
									is only necessary for manual runs in production, which is locked.

********************************************************************************************************************/
CREATE PROCEDURE [Maintenance].[PublishTable]
	@PublishTable VARCHAR(128)		-- The target table to update to
	,@SourceTable VARCHAR(128)		-- The source data to update from
	,@ValidateNoRows BIT = 1		-- Requires the source data to contain at least 1 record
	,@EchoSQL BIT = 0				-- Prints all dynamic SQL statements for debugging purposes
AS
BEGIN

	--DECLARE @PublishTable VARCHAR(128)	= 'MillCDS.CCLEncounterAll'			-- The target table to update to
	--	,@SourceTable VARCHAR(128)		= '##StageMillCDSCCLEncounterAll'	-- The source data to update from
	--	,@ValidateNoRows BIT = 1		-- Requires the source data to contain at least 1 record
	--	,@EchoSQL BIT = 0				-- Prints all dynamic SQL statements for debugging purposes

	BEGIN TRY
		
		DECLARE @SQL NVARCHAR(MAX)
		DECLARE @Msg NVARCHAR(MAX)

		DECLARE @PublishSchemaName VARCHAR(128) = OBJECT_SCHEMA_NAME(OBJECT_ID(@PublishTable))
		DECLARE @PublishTableName VARCHAR(128) = OBJECT_NAME(OBJECT_ID(@PublishTable))
		DECLARE @StageTable VARCHAR(128) = '[' + @PublishSchemaName + '].[' + @PublishTableName + '_Stage]'
		
		-- Logging Begin
		EXEC [Log].[ExecutionBegin] @Name = 'Publish Table', @Description = 'Maintenance PublishTable Procedure'
		EXEC [Log].[Message] @Type = 'Information', @Name = 'Publish Table Name', @Message = @PublishTable
	
		-- Get list of all columns in target table.
		DECLARE @PublishColumnList VARCHAR(MAX)
		SELECT @PublishColumnList = STRING_AGG('[' + CAST([name] AS VARCHAR(MAX))+ ']', ',')
		FROM sys.columns
		WHERE object_id = OBJECT_ID(@PublishTable)

		---------------------------------------------------------------------------------------------------------
		-- Validate the publication prior to making any changes.
		---------------------------------------------------------------------------------------------------------
		IF @PublishTableName IS NULL
		BEGIN
			SET @Msg = 'Unable to publish table ' + @PublishTable + ', publish table not found.'
			;THROW 51000, @Msg, 1;
		END

		IF OBJECT_ID(@SourceTable) IS NULL AND OBJECT_ID('tempdb..' + @SourceTable) IS NULL
		BEGIN
			SET @Msg = 'Unable to publish table ' + @PublishTable + ', source table not found.'
			;THROW 51000, @Msg, 1;
		END

		IF IDENT_CURRENT('[' + @PublishSchemaName + '].[' + @PublishTableName + ']') IS NOT NULL
		BEGIN
			SET @Msg = 'Unable to publish table ' + @PublishTable + ', target table defines unsupported IDENTITY column.'
			;THROW 51000, @Msg, 1;
		END

		IF @ValidateNoRows = 1
		BEGIN
			SET @SQL = '
				IF (SELECT COUNT(*) FROM ' + @SourceTable + ') = 0
				BEGIN
					THROW 51000, ''Publish of table ' + @PublishTable + ' failed due to empty source table.'', 1;
				END'

			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL
		END

		---------------------------------------------------------------------------------------------------------
		-- Build the publish query.
		---------------------------------------------------------------------------------------------------------

		-- Determine if running in attended or unattended mode.
		IF USER_NAME() = 'VHAMASTER\OMHSP_PERC_ETL'
			OR DB_NAME() LIKE '%Dev'  -- 2022-05-15	RAS	Added to use this method in Dev.
			OR DB_NAME() LIKE '%Test' -- 2022-05-15	RAS	Added to use this method in Test.
		BEGIN

			-- If executed in unattended mode, attempt to create a staging table per the publish 
			-- table's design for optimal performance.

			-- Collect some basic information about the table.
			DECLARE @IsCCIX BIT = 0
			SELECT @IsCCIX = 1 FROM sys.indexes i WHERE object_id = OBJECT_ID(@PublishTable) AND [type] = 5
		
			-- Drop existing staging table (if exists).
			SET @SQL = N'DROP TABLE IF EXISTS ' + @StageTable
			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL
		

			-- Use existing table schema to script out publish table.
			SET @SQL = ''
			SELECT @SQL = COALESCE(@SQL + CHAR(13) + CHAR(10), '') + [Line]
			FROM
			(
				SELECT TOP 10000
					'[' + c.[name] + '] [' + t.[name] + '] '
					+ CASE 
						WHEN t.[name] LIKE '%CHAR%' AND c.[max_length] = -1	THEN '(MAX) '
						WHEN t.[name] LIKE 'NVARCHAR' 					THEN '(' + CAST((c.[max_length]/2) AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE '%CHAR%'						THEN '(' + CAST(c.[max_length] AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE '%CHAR%'						THEN '(' + CAST(c.[max_length] AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE 'DECIMAL'					THEN '(' + CAST(c.[precision] AS VARCHAR(100)) + ', ' + CAST(c.[scale] AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE '%BINARY%'					THEN '(' + CAST(c.[max_length] AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE '%DATETIME2%'				THEN '(' + CAST(c.[scale] AS VARCHAR(100)) + ') '
						WHEN t.[name] LIKE 'NUMERIC'					THEN '(' + CAST(c.[precision] AS VARCHAR(100)) + ', ' + CAST(c.[scale] AS VARCHAR(100)) + ') '
						ELSE ''
					END
					+ CASE
						WHEN c.[is_nullable] = 1						THEN 'NULL'
						WHEN c.[is_nullable] = 0						THEN 'NOT NULL'
					END 
					+ ',' [Line]
				FROM sys.objects o
				INNER JOIN sys.columns c ON o.object_id = c.object_id
				INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
				WHERE o.object_id = OBJECT_ID(@PublishTable)
				ORDER BY c.column_id ASC
			) q
		
			-- Create staging table.
			SET @SQL = 'CREATE TABLE ' + @StageTable + '( ' + @SQL + ')'
			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL
		
			-- If the table is a heap and is compressed, apply compression ahead of INSERT (confirmed faster by about 25%).
			SET @SQL = ''
			SELECT @SQL = 'ALTER TABLE ' + @StageTable + ' REBUILD WITH (DATA_COMPRESSION = ' + p.data_compression_desc + ')' 
			FROM sys.objects o
			INNER JOIN sys.indexes i ON o.object_id = i.object_id
			INNER JOIN sys.partitions p ON o.object_id = p.object_id
			WHERE 
				o.object_id = OBJECT_ID(@PublishTable)
				AND i.type_desc = 'HEAP'
				AND p.data_compression_desc IN ('PAGE', 'ROW')

			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL

			---------------------------------------------------------------------------------------------------------
			-- Stage data from source.
			---------------------------------------------------------------------------------------------------------
		
			-- Copy source data to Staging table
			SET @SQL = '
				INSERT INTO ' + @StageTable + ' WITH (TABLOCK) (' + @PublishColumnList + ')
				SELECT ' + @PublishColumnList + '
				FROM ' + @SourceTable

			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL

			---------------------------------------------------------------------------------------------------------
			-- Script out publish table indexes and apply to stage.
			---------------------------------------------------------------------------------------------------------
			;WITH Idx AS
			(
				SELECT TOP 100
					i.[name]
					,i.[type]
					,i.[is_primary_key]
					,i.[is_unique]
					,(
						SELECT p.data_compression_desc
						FROM sys.partitions p
						WHERE p.object_id = i.object_id AND p.index_id = i.index_id
					) data_compression_desc
					,(
						SELECT STRING_AGG('[' + CAST(c.[name] AS VARCHAR(MAX)) + ']' + ' ' + CASE WHEN is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END, ',') 
						FROM sys.index_columns ic
						INNER JOIN sys.columns c ON i.object_id = c.object_id AND ic.column_id = c.column_id AND ic.is_included_column = 0
						WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
					) ColumnList
					,(
						SELECT STRING_AGG('[' + CAST(c.[name] AS VARCHAR(MAX)) + ']', ',') 
						FROM sys.index_columns ic
						INNER JOIN sys.columns c ON i.object_id = c.object_id AND ic.column_id = c.column_id AND ic.is_included_column = 1
						WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
					) IncludedColumnList
				FROM sys.indexes i 
				WHERE i.object_id = OBJECT_ID(@PublishTable)
				ORDER BY i.[index_id] ASC
			)
			SELECT
				@SQL = STRING_AGG(
					CASE 
						WHEN i.type = 1 AND i.[is_unique] = 0 AND [is_primary_key] = 0 THEN
							'CREATE CLUSTERED INDEX [' + i.[name] + '] ON ' + @StageTable
						WHEN i.type = 1 AND i.[is_unique] = 1 AND [is_primary_key] = 0 THEN
							'CREATE UNIQUE CLUSTERED INDEX [' + i.[name] + '] ON ' + @StageTable
						WHEN i.type = 1 AND i.[is_unique] = 1 AND [is_primary_key] = 1 THEN
							'ALTER TABLE ' + @StageTable + ' ADD CONSTRAINT [' + i.[name] + '_Stage] PRIMARY KEY '
						WHEN i.[type] = 2 AND i.[is_unique] = 0 AND [is_primary_key] = 0 THEN
							'CREATE NONCLUSTERED INDEX [' + i.[name] + '] ON ' + @StageTable
						WHEN i.[type] = 2 AND i.[is_unique] = 1 AND [is_primary_key] = 0 THEN
							'CREATE UNIQUE NONCLUSTERED INDEX [' + i.[name] + '] ON ' + @StageTable
						WHEN i.[type] = 2 AND i.[is_unique] = 1 AND [is_primary_key] = 1 THEN
							'ALTER TABLE ' + @StageTable + ' ADD CONSTRAINT [' + i.[name] + '_Stage] PRIMARY KEY NONCLUSTERED'
						WHEN i.[type] = 5 THEN
							'CREATE CLUSTERED COLUMNSTORE INDEX [' + i.[name] + '] ON ' + @StageTable
						WHEN i.[type] = 6 THEN
							'CREATE NONCLUSTERED COLUMNSTORE INDEX [' + i.[name] + '] ON ' + @StageTable
						ELSE 'Error' 
					END
					+ CASE
						WHEN i.[type] = 5 THEN ''
						WHEN i.[type] = 6 THEN '(' + IncludedColumnList + ')'
						ELSE '(' + ColumnList + ')'
							 + CASE 
								WHEN LEN(IncludedColumnList) > 0 THEN ' INCLUDE (' + IncludedColumnList + ')' 
								ELSE '' 
							END
					END

					+ ' WITH ('
					--+ CASE WHEN @IsCCIX = 0 AND i.[type] <> 6 THEN 'ONLINE=ON,' ELSE '' END		-- can't use online option with columnstore indexes (commented since can't universally create indexes online and is slower)
					+ 'DATA_COMPRESSION=' + data_compression_desc collate SQL_Latin1_General_CP1_CI_AS -- RAS added 2022-01-19 
					+ ')'
					,CHAR(13) + CHAR(10)
				)
			FROM Idx i

			IF @EchoSQL = 1
				PRINT @SQL
			EXEC sp_executesql @SQL

			-- Publish by truncating target so it's empty, then use partition swapping to quickly move the data into
			-- the target. Switching minimizes the impact to any production report which might be referencing the table.
			SET @SQL = '
				BEGIN TRANSACTION
				TRUNCATE TABLE [' + @PublishSchemaName + '].[' + @PublishTableName + ']
				ALTER TABLE ' + @StageTable + ' SWITCH TO [' + @PublishSchemaName + '].[' + @PublishTableName + ']
				DROP TABLE IF EXISTS ' + @StageTable + '
				COMMIT TRANSACTION'

		END
		ELSE
		BEGIN
			-- If executed in attended mode (by a person), do not attempt to create a staging table since the
			-- database could be locked. Publish by truncating target then performing a simple BULK INSERT. Since
			-- this doesn't use partition switching, reports attempting to access the table during the publish
			-- will be blocked.

			SET @SQL = '
				BEGIN TRANSACTION
				TRUNCATE TABLE [' + @PublishSchemaName + '].[' + @PublishTableName + ']
				INSERT INTO [' + @PublishSchemaName + '].[' + @PublishTableName + '] (' + @PublishColumnList + ')
				SELECT ' + @PublishColumnList + '
				FROM ' + @SourceTable + '
				COMMIT TRANSACTION'
		END

		---------------------------------------------------------------------------------------------------------
		-- Publish
		---------------------------------------------------------------------------------------------------------	

		IF @EchoSQL = 1
			PRINT @SQL
		EXEC sp_executesql @SQL

		-- Logging End
		DECLARE @RowCount BIGINT, @CurrentUser VARCHAR(256)
		SELECT @CurrentUser = USER_NAME()
		SELECT @RowCount = rowcnt FROM sysindexes WHERE id = OBJECT_ID(@PublishTable) AND indid < 2

		EXEC [Log].[PublishTable]
			@SchemaName = @PublishSchemaName
			,@TableName = @PublishTableName 		
			,@SourceTableName = @SourceTable
			,@PublishedType = 'Replace'
			,@PublishedRowCount = @RowCount
			,@PublishedBy = @CurrentUser
		EXEC [Log].[Message] @Type = 'Information', @Name = 'Publish Row Count', @Message = @RowCount
		EXEC [Log].[ExecutionEnd] @Status = 'Completed'

	END TRY
	BEGIN CATCH
		-- Rollback any active transactions (i.e. when switching Stage to Publish).
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION
		
		-- Always echo back SQL which generated an error
		IF @EchoSQL = 0
			PRINT @SQL

		-- Make sure to clean up any temporary objects facilitating the load.
		SET @SQL = 'DROP TABLE IF EXISTS ' + @StageTable
		IF @EchoSQL = 1
			PRINT @SQL
		EXEC sp_executesql @SQL

		--Logging Error
		DECLARE  @ErrorMessage VARCHAR(MAX)
		SELECT @ErrorMessage = ERROR_MESSAGE() 

		EXEC [Log].[Message] @Type = 'Error', @Name ='Maintenance.PublishTable', @Message = @ErrorMessage
		EXEC [Log].[ExecutionEnd] @Status = 'Error'
		
		-- Rethrow as this is an error condition.
		;THROW
	END CATCH

END