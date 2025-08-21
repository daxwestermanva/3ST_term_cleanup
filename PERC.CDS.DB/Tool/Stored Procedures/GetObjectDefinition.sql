
------------------------------------------	
-- AUTHOR:		HUGO ERICK SOLARES
-- CREATE DATE: 2016-07-19
-- DESCRIPTION:	Obtain Table DDL
------------------------------------------	
-- GetObjectDefinition Stored Procedure
--
-- Purpose: Script Any Table, Temp Table. Primarilly will be used 
-- for backing up table structures/definitions (DDL) in 
-- conjunction with table data		 
--			
------------------------------------------
------------------------------------------
-- USAGE: 
-- 	 exec GetObjectDefinition '[Dflt].[STAFF_FACILITY_COMBINED_STAFFING_14]' or
--   exec GetObjectDefinition 'bob.example' or
--   exec GetObjectDefinition 'Dflt.SQLError' or
--   exec GetObjectDefinition #temp
------------------------------------------
CREATE PROCEDURE [Tool].[GetObjectDefinition] @TBL VARCHAR(255), @SOLUTION VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @TBLNAME VARCHAR(200)
		,@SCHEMANAME VARCHAR(255)
		,@STRINGLEN INT
		,@TABLE_ID INT
		,@CONSTRAINTSQLS VARCHAR(MAX)
		,@CHECKCONSTSQLS VARCHAR(MAX)
		,@RULESCONSTSQLS VARCHAR(MAX)
		,@FKSQLS VARCHAR(MAX)
		,@TRIGGERSTATEMENT VARCHAR(MAX)
		,@EXTENDEDPROPERTIES VARCHAR(MAX)
		,@INDEXSQLS VARCHAR(MAX)
		,@MARKSYSTEMOBJECT VARCHAR(MAX)
		,@vbCrLf CHAR(2)
		,@ISSYSTEMOBJECT INT
		,@PROCNAME VARCHAR(256)
		,@input VARCHAR(MAX)
		,@ObjectTypeFound VARCHAR(255);
		DECLARE @FINALSQL VARCHAR(MAX);
		
		  

	------------------------------------------
	-- INITIALIZE
	------------------------------------------
	SET @input = ''

	-- Determine whether this proc is marked as a system 
	-- proc with sp_ms_marksystemobject,
	-- which will flip the is_ms_shipped bit in sys.objects
	-- This is for cross database work so you don’t need to 
	-- create / remove the script again and again in all 
	-- databases. The solution is the undocumented 
	-- stored procedure sp_ms_marksystemobject -HES
	SELECT @ISSYSTEMOBJECT = ISNULL(is_ms_shipped, 0)
		,@PROCNAME = ISNULL(NAME, 'GetObjectDefinition')
	FROM sys.objects
	WHERE OBJECT_ID = @@PROCID

	IF @ISSYSTEMOBJECT IS NULL
		SELECT @ISSYSTEMOBJECT = ISNULL(is_ms_shipped, 0)
			,@PROCNAME = ISNULL(NAME, 'GetObjectDefinition')
		FROM master.sys.objects
		WHERE OBJECT_ID = @@PROCID

	IF @ISSYSTEMOBJECT IS NULL
		SET @ISSYSTEMOBJECT = 0

	IF @PROCNAME IS NULL
		SET @PROCNAME = 'GetObjectDefinition'
	-- determine if tablename contains a schema
	SET @vbCrLf = CHAR(13) + CHAR(10)

	SELECT @SCHEMANAME = ISNULL(PARSENAME(@TBL, 2), 'dbo')
		,@TBLNAME = PARSENAME(@TBL, 1)

	SELECT @TBLNAME = [name]
		,@TABLE_ID = [OBJECT_ID]
	FROM sys.objects OBJS
	WHERE [TYPE] IN (
			'S'
			,'U'
			)
		AND [name] <> 'dtproperties'
		AND [name] = @TBLNAME
		AND [SCHEMA_ID] = SCHEMA_ID(@SCHEMANAME);



	------------------------------------------
	-- CHECK IF TABLENAME IS VALID
	------------------------------------------
	IF ISNULL(@TABLE_ID, 0) = 0
	BEGIN
		-- see if it is an object and not a table.
		SELECT @TBLNAME = [name]
			,@TABLE_ID = [OBJECT_ID]
			,@ObjectTypeFound = type_desc
		FROM sys.objects OBJS
		WHERE [TYPE] IN (
				'P'
				,'V'
				,'TR'
				,'AF'
				,'IF'
				,'FN'
				,'TF'
				,'SN'
				)
			AND [name] <> 'dtproperties'
			AND [name] = @TBLNAME
			AND [SCHEMA_ID] = SCHEMA_ID(@SCHEMANAME);
		
		IF ISNULL(@TABLE_ID, 0) <> 0
		BEGIN
			-- adding a drop statement.
			-- adding a sp_ms_marksystemobject if needed
			SELECT @MARKSYSTEMOBJECT = CASE 
					WHEN is_ms_shipped = 1
						THEN '    --MARK AS A SYSTEM OBJECT
	GO

		
		EXECUTE sp_ms_marksystemobject  ''' + quotename(@SCHEMANAME) + '.' + quotename(@TBLNAME) + ''' 

	'
					ELSE '
	GO
	'
					END
			FROM sys.objects OBJS
			WHERE object_id = @TABLE_ID

			-- adding a drop statement.
			IF @ObjectTypeFound = 'SYNONYM'
			BEGIN
				SELECT @FINALSQL = 'IF EXISTS(SELECT * FROM sys.synonyms WHERE name = ''' + NAME + 
				'''' + ' AND base_object_name <> ''' + base_object_name + ''')' + @vbCrLf + 
				'  DROP SYNONYM ' + quotename(NAME) + '' + @vbCrLf + 'GO' + @vbCrLf + 
				'IF NOT EXISTS(SELECT * FROM sys.synonyms WHERE name = ''' + NAME + ''')' + 
				@vbCrLf + 'CREATE SYNONYM ' + quotename(NAME) + ' FOR ' + base_object_name + ';'
				FROM sys.synonyms
				WHERE [name] = @TBLNAME
					AND [SCHEMA_ID] = SCHEMA_ID(@SCHEMANAME);
					
			END
			ELSE
			BEGIN
				SELECT @FINALSQL = 'IF OBJECT_ID(''' + QUOTENAME(@SCHEMANAME) + '.' + 
				QUOTENAME(@TBLNAME) + ''') IS NOT NULL ' + @vbcrlf + 'DROP ' + CASE 
						WHEN OBJS.[type] IN ('P')
							THEN ' PROCEDURE '
						WHEN OBJS.[type] IN ('V')
							THEN ' VIEW      '
						WHEN OBJS.[type] IN ('TR')
							THEN ' TRIGGER   '
						ELSE ' FUNCTION  '
						END + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ' + 
						@vbcrlf + 'GO' + @vbcrlf + def.DEFINITION + @MARKSYSTEMOBJECT
				FROM sys.objects OBJS
				INNER JOIN sys.sql_modules def ON OBJS.object_id = def.object_id
				WHERE OBJS.[type] IN (
						'P'
						,'V'
						,'TR'
						,'AF'
						,'IF'
						,'FN'
						,'TF'
						)
					AND OBJS.[name] <> 'dtproperties'
					AND OBJS.[name] = @TBLNAME
					AND OBJS.[schema_id] = SCHEMA_ID(@SCHEMANAME); 
			END

			SET @input = @FINALSQL
				;

			WITH CTD1 (N)
			AS (
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				
				UNION ALL
				
				SELECT 1
				)
				,
			CTD2 (N)
			AS (
				SELECT 1
				FROM CTD1 a
					,CTD1 b
				)
				,
			CTD4 (N)
			AS (
				SELECT 1
				FROM CTD2 a
					,CTD2 b
				)
				,
			CTD8 (N)
			AS (
				SELECT 1
				FROM CTD4 a
					,CTD4 b
				)
				,
			Tally (N)
			AS (
				SELECT ROW_NUMBER() OVER (
						ORDER BY N
						)
				FROM CTD8
				)
				,ItemSplit (
				ItemOrder
				,Item
				)
			AS (
				SELECT N
					,SUBSTRING(@vbCrLf + @input + @vbCrLf, N + DATALENGTH(@vbCrLf), CHARINDEX(@vbCrLf, @vbCrLf + 
					@input + @vbCrLf, N + DATALENGTH(@vbCrLf)) - N - DATALENGTH(@vbCrLf))
				FROM Tally
				WHERE N < DATALENGTH(@vbCrLf + @input)
					AND SUBSTRING(@vbCrLf + @input + @vbCrLf, N, DATALENGTH(@vbCrLf)) = @vbCrLf -- find the delimiter
				)
			SELECT
				Item
			FROM ItemSplit;

			--RETURN 0
		END
		ELSE
		BEGIN
			SET @FINALSQL = 'Object ' + quotename(@SCHEMANAME) + '.' + quotename(@TBLNAME) + 
			' does not exist in Database ' + quotename(DB_NAME()) + ' ' + 
			CASE 
					WHEN @ISSYSTEMOBJECT = 0
						THEN @vbCrLf + ' (also note that ' + @PROCNAME + 
						' is not marked as a system proc and cross db access to sys.tables will fail.)'
					ELSE ''
					END
			IF LEFT(@TBLNAME, 1) = '#'
				SET @FINALSQL = @FINALSQL + ' OR in The tempdb database.'

			SELECT @FINALSQL AS Item; 

			-- RETURN 0
		END
	END
	
	------------------------------------------
	-- VALID TABLE, CONTINUE PROCESSING
	------------------------------------------
	SELECT @FINALSQL = 'IF OBJECT_ID(''' + QUOTENAME(@SCHEMANAME) + '.' + 
		QUOTENAME(@TBLNAME) + ''') IS NOT NULL ' + @vbcrlf + 'DROP TABLE ' + 
		QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ' + @vbcrlf + 'GO' + 
		@vbcrlf + 'CREATE TABLE ' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ( '

	SELECT @STRINGLEN = MAX(LEN(COLS.[name])) + 1
	FROM sys.objects OBJS
	INNER JOIN sys.columns COLS ON OBJS.[object_id] = COLS.[object_id]
		AND OBJS.[object_id] = @TABLE_ID;


			
	------------------------------------------
	-- GET THE COLUMNS, THEIR DEFINITIONS AND DEFAULTS
	------------------------------------------
	SELECT @FINALSQL = @FINALSQL + 
		CASE 
			WHEN COLS.[is_computed] = 1
				THEN @vbCrLf + QUOTENAME(COLS.[name]) + ' ' + 
				SPACE(@STRINGLEN - LEN(COLS.[name])) + 'AS ' + 
				ISNULL(CALC.DEFINITION, '') + 
					CASE 
						WHEN CALC.is_persisted = 1
							THEN ' PERSISTED'
						ELSE ''
						END
			ELSE @vbCrLf + QUOTENAME(COLS.[name]) + ' ' + 
			SPACE(@STRINGLEN - LEN(COLS.[name])) + 
			UPPER(TYPE_NAME(COLS.[user_type_id])) + 
				CASE 
					-- NUMERIC(10,2)
					WHEN TYPE_NAME(COLS.[user_type_id]) IN (
							'decimal'
							,'numeric'
							)
						THEN '(' + CONVERT(VARCHAR, COLS.[precision]) + 
						',' + CONVERT(VARCHAR, COLS.[scale]) + ') ' + 
						SPACE(6 - LEN(CONVERT(VARCHAR, COLS.[precision]) + 
						',' + CONVERT(VARCHAR, COLS.[scale]))) + SPACE(7) + 
						SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
							CASE 
								WHEN COLUMNPROPERTY(@TABLE_ID, COLS.[name], 'IsIdentity') = 0
									THEN ''
								ELSE ' IDENTITY(' + CONVERT(VARCHAR, ISNULL(IDENT_SEED(@TBLNAME), 1)) + 
								',' + CONVERT(VARCHAR, ISNULL(IDENT_INCR(@TBLNAME), 1)) + ')'
								END + CASE 
								WHEN COLS.[is_nullable] = 0
									THEN ' NOT NULL'
								ELSE '     NULL'
								END
							-- FLOAT(53)
					WHEN TYPE_NAME(COLS.[user_type_id]) IN ('float') --,'real')
						THEN
							CASE 
								WHEN COLS.[precision] = 53
									THEN SPACE(11 - LEN(CONVERT(VARCHAR, COLS.[precision]))) + 
									SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
										CASE 
											WHEN COLS.[is_nullable] = 0
												THEN ' NOT NULL'
											ELSE '     NULL'
											END
								ELSE '(' + CONVERT(VARCHAR, COLS.[precision]) + ') ' + 
								SPACE(6 - LEN(CONVERT(VARCHAR, COLS.[precision]))) + SPACE(7) + 
								SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
									CASE 
										WHEN COLS.[is_nullable] = 0
											THEN ' NOT NULL'
										ELSE '     NULL'
										END
								END
							-- VARCHAR(40)
							
							------------------------------------------
							-- COLLATE STATEMENTS -- Collation controls the way string values are sorted.
							------------------------------------------
					WHEN TYPE_NAME(COLS.[user_type_id]) IN (
							'char'
							,'varchar'
							)
						THEN CASE 
								WHEN COLS.[max_length] = - 1
									THEN '(max)' + SPACE(6 - LEN(CONVERT(VARCHAR, COLS.[max_length]))) + 
									SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
										+ CASE 
											WHEN COLS.[is_nullable] = 0
												THEN ' NOT NULL'
											ELSE '     NULL'
											END
								ELSE '(' + CONVERT(VARCHAR, COLS.[max_length]) + ') ' + 
								SPACE(6 - LEN(CONVERT(VARCHAR, COLS.[max_length]))) + SPACE(7) + 
								SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
									+ CASE 
										WHEN COLS.[is_nullable] = 0
											THEN ' NOT NULL'
										ELSE '     NULL'
										END
								END
							-- NVARCHAR(40)
					WHEN TYPE_NAME(COLS.[user_type_id]) IN (
							'nchar'
							,'nvarchar'
							)
						THEN CASE 
								WHEN COLS.[max_length] = - 1
									THEN '(max)' + SPACE(6 - LEN(CONVERT(VARCHAR, (COLS.[max_length] / 2)))) + 
									SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
										+ CASE 
											WHEN COLS.[is_nullable] = 0
												THEN ' NOT NULL'
											ELSE '     NULL'
											END
								ELSE '(' + CONVERT(VARCHAR, (COLS.[max_length] / 2)) + ') ' + 
								SPACE(6 - LEN(CONVERT(VARCHAR, (COLS.[max_length] / 2)))) + SPACE(7) + 
								SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
									+ CASE 
										WHEN COLS.[is_nullable] = 0
											THEN ' NOT NULL'
										ELSE '     NULL'
										END
								END
							-- datetime
					WHEN TYPE_NAME(COLS.[user_type_id]) IN (
							'datetime'
							,'money'
							,'text'
							,'image'
							,'real'
							)
						THEN SPACE(18 - LEN(TYPE_NAME(COLS.[user_type_id]))) + '              ' + 
							CASE 
								WHEN COLS.[is_nullable] = 0
									THEN ' NOT NULL'
								ELSE '     NULL'
								END
							-- VARBINARY(500)
					WHEN TYPE_NAME(COLS.[user_type_id]) = 'varbinary'
						THEN CASE 
								WHEN COLS.[max_length] = - 1
									THEN '(max)' + SPACE(6 - LEN(CONVERT(VARCHAR, (COLS.[max_length])))) + 
									SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
										CASE 
											WHEN COLS.[is_nullable] = 0
												THEN ' NOT NULL'
											ELSE ' NULL'
											END
								ELSE '(' + CONVERT(VARCHAR, (COLS.[max_length])) + ') ' + 
								SPACE(6 - LEN(CONVERT(VARCHAR, (COLS.[max_length])))) + SPACE(7) + 
								SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
									CASE 
										WHEN COLS.[is_nullable] = 0
											THEN ' NOT NULL'
										ELSE ' NULL'
										END
								END
							-- INT
					ELSE SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id]))) + 
						CASE 
							WHEN COLUMNPROPERTY(@TABLE_ID, COLS.[name], 'IsIdentity') = 0
								THEN '              '
							ELSE ' IDENTITY(' + CONVERT(VARCHAR, ISNULL(IDENT_SEED(@TBLNAME), 1)) + ',' + 
							CONVERT(VARCHAR, ISNULL(IDENT_INCR(@TBLNAME), 1)) + ')'
							END + SPACE(2) + 
							CASE 
								WHEN COLS.[is_nullable] = 0
									THEN ' NOT NULL'
								ELSE '     NULL'
								END
					END + 
					CASE 
						WHEN COLS.[default_object_id] = 0
							THEN ''
						ELSE '  CONSTRAINT ' + quotename(DEF.NAME) + ' DEFAULT ' + ISNULL(DEF.[definition], '')
						END 
			END 
		+ ','
	FROM sys.columns COLS
	LEFT OUTER JOIN sys.default_constraints DEF ON COLS.[default_object_id] = DEF.[object_id]
	LEFT OUTER JOIN sys.computed_columns CALC ON COLS.[object_id] = CALC.[object_id]
		AND COLS.[column_id] = CALC.[column_id]
	WHERE COLS.[object_id] = @TABLE_ID
	ORDER BY COLS.[column_id]

		
	------------------------------------------
	-- USED FOR FORMATTING THE REST OF THE CONSTRAINTS:
	------------------------------------------
	SELECT @STRINGLEN = MAX(LEN([name])) + 1
	FROM sys.objects OBJS

		
	------------------------------------------
	-- PK/UNIQUE CONSTRAINTS AND INDEXES
	------------------------------------------
	DECLARE @Results TABLE (
		[SCHEMA_ID] INT
		,[SCHEMA_NAME] VARCHAR(255)
		,[OBJECT_ID] INT
		,[OBJECT_NAME] VARCHAR(255)
		,[index_id] INT
		,[index_name] VARCHAR(255)
		,[ROWS] BIGINT
		,[SizeMB] DECIMAL(19, 3)
		,[IndexDepth] INT
		,[TYPE] INT
		,[type_desc] VARCHAR(30)
		,[fill_factor] INT
		,[is_unique] INT
		,[is_primary_key] INT
		,[is_unique_constraint] INT
		,[index_columns_key] VARCHAR(MAX)
		,[index_columns_include] VARCHAR(MAX)
		,[has_filter] BIT
		,[filter_definition] VARCHAR(MAX)
		,[currentFilegroupName] VARCHAR(128)
		,[CurrentCompression] VARCHAR(128)
		);
		
	INSERT INTO @Results
	SELECT SCH.schema_id
		,SCH.[name] AS SCHEMA_NAME
		,OBJS.[object_id]
		,OBJS.[name] AS OBJECT_NAME
		,IDX.index_id
		,ISNULL(IDX.[name], '---') AS index_name
		,partitions.ROWS
		,partitions.SizeMB
		,INDEXPROPERTY(OBJS.[object_id], IDX.[name], 'IndexDepth') AS IndexDepth
		,IDX.type
		,IDX.type_desc
		,IDX.fill_factor
		,IDX.is_unique
		,IDX.is_primary_key
		,IDX.is_unique_constraint
		,ISNULL(Index_Columns.index_columns_key, '---') AS index_columns_key
		,ISNULL(Index_Columns.index_columns_include, '---') AS index_columns_include
		,IDX.[has_filter]
		,IDX.[filter_definition]
		,filz.NAME
		,ISNULL(p.data_compression_desc, '')
	FROM sys.objects OBJS
	INNER JOIN sys.schemas SCH ON OBJS.schema_id = SCH.schema_id
	INNER JOIN sys.indexes IDX ON OBJS.[object_id] = IDX.[object_id]
	INNER JOIN sys.filegroups filz ON IDX.data_space_id = filz.data_space_id
	INNER JOIN sys.partitions p ON IDX.object_id = p.object_id
		AND IDX.index_id = p.index_id
	INNER JOIN (
		SELECT [object_id]
			,index_id
			,SUM(row_count) AS ROWS
			,CONVERT(NUMERIC(19, 3), CONVERT(NUMERIC(19, 3), SUM(in_row_reserved_page_count + 
			lob_reserved_page_count + row_overflow_reserved_page_count)) / CONVERT(NUMERIC(19, 3), 128)) AS SizeMB
		FROM sys.dm_db_partition_stats STATS
		GROUP BY [OBJECT_ID]
			,index_id
		) AS partitions ON IDX.[object_id] = partitions.[object_id]
		AND IDX.index_id = partitions.index_id
	CROSS APPLY (
		SELECT LEFT(index_columns_key, LEN(index_columns_key) - 1) AS index_columns_key
			,LEFT(index_columns_include, LEN(index_columns_include) - 1) AS index_columns_include
		FROM (
			SELECT (
					SELECT QUOTENAME(COLS.[name]) + 
						CASE 
							WHEN IXCOLS.is_descending_key = 0
								THEN ' asc'
							ELSE ' desc'
							END + ',' + ' '
					FROM sys.index_columns IXCOLS
					INNER JOIN sys.columns COLS ON IXCOLS.column_id = COLS.column_id
						AND IXCOLS.[object_id] = COLS.[object_id]
					WHERE IXCOLS.is_included_column = 0
						AND IDX.[object_id] = IXCOLS.[object_id]
						AND IDX.index_id = IXCOLS.index_id
					ORDER BY key_ordinal
					FOR XML PATH('')
					) AS index_columns_key
				,(
					SELECT QUOTENAME(COLS.[name]) + ',' + ' '
					FROM sys.index_columns IXCOLS
					INNER JOIN sys.columns COLS ON IXCOLS.column_id = COLS.column_id
						AND IXCOLS.[object_id] = COLS.[object_id]
					WHERE IXCOLS.is_included_column = 1
						AND IDX.[object_id] = IXCOLS.[object_id]
						AND IDX.index_id = IXCOLS.index_id
					ORDER BY index_column_id
					FOR XML PATH('')
					) AS index_columns_include
			) AS Index_Columns
		) AS Index_Columns
	WHERE SCH.[name] LIKE CASE 
			WHEN @SCHEMANAME = ''
				THEN SCH.[name]
			ELSE @SCHEMANAME
			END
		AND OBJS.[name] LIKE CASE 
			WHEN @TBLNAME = ''
				THEN OBJS.[name]
			ELSE @TBLNAME
			END
	ORDER BY SCH.[name]
		,OBJS.[name]
		,IDX.[name]

	-- @Results table has both PK,s Uniques and indexes. add to final results:
	SET @CONSTRAINTSQLS = ''
	SET @INDEXSQLS = ''

	
		
	------------------------------------------
	-- CONSTRAINTS
	------------------------------------------
	SELECT @CONSTRAINTSQLS = @CONSTRAINTSQLS + 
		CASE 
			WHEN is_primary_key = 1
				OR is_unique = 1
				THEN @vbCrLf + 'CONSTRAINT   ' + quotename(index_name) + ' ' + 
					CASE 
						WHEN is_primary_key = 1
							THEN ' PRIMARY KEY '
						ELSE CASE 
								WHEN is_unique = 1
									THEN ' UNIQUE      '
								ELSE ''
								END
						END + type_desc + 
							CASE 
							WHEN type_desc = 'NONCLUSTERED'
								THEN ''
							ELSE '   '
							END + ' (' + index_columns_key + ')' + 
						CASE 
							WHEN index_columns_include <> '---'
							THEN ' INCLUDE (' + index_columns_include + ')'
							ELSE ''
							END + 
						CASE 
							WHEN [has_filter] = 1
							THEN ' ' + [filter_definition]
							ELSE ' '
							END + CASE 
						WHEN fill_factor <> 0
							OR [CurrentCompression] <> 'NONE'
							THEN ' WITH (' + CASE 
									WHEN fill_factor <> 0
										THEN 'FILLFACTOR = ' + CONVERT(VARCHAR(30), fill_factor)
									ELSE ''
									END + 
									CASE 
										WHEN fill_factor <> 0
											AND [CurrentCompression] <> 'NONE'
										THEN ',DATA_COMPRESSION = ' + [CurrentCompression] + ' '
										WHEN fill_factor <> 0
											AND [CurrentCompression] = 'NONE'
										THEN ''
										WHEN fill_factor = 0
											AND [CurrentCompression] <> 'NONE'
										THEN 'DATA_COMPRESSION = ' + [CurrentCompression] + ' '
									ELSE ''
									END + ')'
						ELSE ''
						END
			ELSE ''
			END + ','
	FROM @RESULTS
	WHERE [type_desc] != 'HEAP'
		AND is_primary_key = 1
		OR is_unique = 1
	ORDER BY is_primary_key DESC
		,is_unique DESC

			
	------------------------------------------
	-- INDEXES
	------------------------------------------
	SELECT @INDEXSQLS = @INDEXSQLS + 
		CASE 
			WHEN is_primary_key = 0
				OR is_unique = 0
				THEN @vbCrLf + 'CREATE ' + type_desc + ' INDEX ' + quotename(index_name) + ' ' + 
				@vbCrLf + '   ON ' + quotename([schema_name]) + '.' + quotename([OBJECT_NAME]) + ' (' + 
				index_columns_key + ')' + 
					CASE 
						WHEN index_columns_include <> '---'
							THEN @vbCrLf + '   INCLUDE (' + index_columns_include + ')'
						ELSE ''
						END + 
						CASE 
						WHEN has_filter = 1
							THEN @vbCrLf + '   WHERE ' + filter_definition
						ELSE ''
						END + 
						CASE 
						WHEN fill_factor <> 0
							OR [CurrentCompression] <> 'NONE'
							THEN ' WITH (' + 
							CASE 
									WHEN fill_factor <> 0
										THEN 'FILLFACTOR = ' + CONVERT(VARCHAR(30), fill_factor)
									ELSE ''
									END + 
									CASE 
									WHEN fill_factor <> 0
										AND [CurrentCompression] <> 'NONE'
										THEN ',DATA_COMPRESSION = ' + [CurrentCompression] + ' '
									WHEN fill_factor <> 0
										AND [CurrentCompression] = 'NONE'
										THEN ''
									WHEN fill_factor = 0
										AND [CurrentCompression] <> 'NONE'
										THEN 'DATA_COMPRESSION = ' + [CurrentCompression] + ' '
									ELSE ''
									END + ')'
						ELSE ''
						END
			END
	FROM @RESULTS
	WHERE [type_desc] != 'HEAP'
		AND is_primary_key = 0
		AND is_unique = 0
	ORDER BY is_primary_key DESC
		,is_unique DESC

	IF @INDEXSQLS <> ''
		SET @INDEXSQLS = @vbCrLf + 'GO' + @vbCrLf + @INDEXSQLS

			
			
	------------------------------------------
	-- CHECK CONSTRAINTS
	------------------------------------------
	SET @CHECKCONSTSQLS = ''

	SELECT @CHECKCONSTSQLS = @CHECKCONSTSQLS + @vbCrLf + ISNULL('CONSTRAINT   ' + 
		quotename(OBJS.[name]) + ' ' + SPACE(@STRINGLEN - LEN(OBJS.[name])) + ' CHECK ' + 
		ISNULL(CHECKS.DEFINITION, '') + ',', '')
	FROM sys.objects OBJS
	INNER JOIN sys.check_constraints CHECKS ON OBJS.[object_id] = CHECKS.[object_id]
		WHERE OBJS.type = 'C'
			AND OBJS.parent_object_id = @TABLE_ID

			
			
	------------------------------------------
	-- FOREIGN KEYS
	------------------------------------------
	SET @FKSQLS = '';

	SELECT @FKSQLS = @FKSQLS + @vbCrLf + 'CONSTRAINT   ' + quotename(OBJECT_NAME(constid)) + 
		'' + SPACE(@STRINGLEN - LEN(OBJECT_NAME(constid))) + '  FOREIGN KEY (' + 
		quotename(COL_NAME(fkeyid, fkey)) + ') REFERENCES ' + quotename(OBJECT_NAME(rkeyid)) + 
		'(' + quotename(COL_NAME(rkeyid, rkey)) + '),' + CASE 
			WHEN sfk.delete_referential_action = 1
				THEN N'ON DELETE CASCADE '
			WHEN sfk.delete_referential_action = 2
				THEN N'ON DELETE SET NULL '
			WHEN sfk.delete_referential_action = 3
				THEN N'ON DELETE SET DEFAULT '
			ELSE ''
			END + CASE 
			WHEN sfk.update_referential_action = 1
				THEN N'ON UPDATE CASCADE '
			WHEN sfk.update_referential_action = 2
				THEN N'ON UPDATE SET NULL '
			WHEN sfk.update_referential_action = 3
				THEN N'ON UPDATE SET DEFAULT '
			ELSE ''
			END + CASE 
			WHEN sfk.is_not_for_replication = 1
				THEN N'NOT FOR REPLICATION '
			ELSE ''
			END + ','
	FROM sysforeignkeys FKEYS
	JOIN sys.foreign_keys sfk ON FKEYS.fkeyid = sfk.parent_object_id
	WHERE fkeyid = @TABLE_ID

		
	------------------------------------------
	-- RULES
	------------------------------------------
	SET @RULESCONSTSQLS = ''

	SELECT @RULESCONSTSQLS = @RULESCONSTSQLS + ISNULL(@vbCrLf + 
		'if not exists(SELECT [name] FROM sys.objects WHERE TYPE=''R'' AND schema_id = ' + 
		CONVERT(VARCHAR(30), OBJS.schema_id) + ' AND [name] = ''' + 
		quotename(OBJECT_NAME(COLS.[rule_object_id])) + 
		''')' + @vbCrLf + MODS.DEFINITION + @vbCrLf + 'GO' + @vbCrLf + 'EXEC sp_binderule  ' + 
		quotename(OBJS.[name]) + ', ''' + quotename(OBJECT_NAME(COLS.[object_id])) + '.' + 
		quotename(COLS.[name]) + '''' + @vbCrLf + 'GO', '')
	FROM sys.columns COLS
	INNER JOIN sys.objects OBJS ON OBJS.[object_id] = COLS.[object_id]
	INNER JOIN sys.sql_modules MODS ON COLS.[rule_object_id] = MODS.[object_id]
	WHERE COLS.[rule_object_id] <> 0
		AND COLS.[object_id] = @TABLE_ID

		
	------------------------------------------
	-- TRIGGERS
	------------------------------------------
	SET @TRIGGERSTATEMENT = ''

	SELECT @TRIGGERSTATEMENT = @TRIGGERSTATEMENT + @vbCrLf + 
		MODS.[definition] + @vbCrLf + 'GO'
	FROM sys.sql_modules MODS
	WHERE [OBJECT_ID] IN (
			SELECT [OBJECT_ID]
			FROM sys.objects OBJS
			WHERE TYPE = 'TR'
				AND [parent_object_id] = @TABLE_ID
			)

	IF @TRIGGERSTATEMENT <> ''
		SET @TRIGGERSTATEMENT = @vbCrLf + 'GO' + @vbCrLf + @TRIGGERSTATEMENT

		
		
	------------------------------------------
	-- QUERY ALL EXTENDED PROPERTIES
	------------------------------------------
	SET @EXTENDEDPROPERTIES = ''

	SELECT @EXTENDEDPROPERTIES = @EXTENDEDPROPERTIES + @vbCrLf + 
			  'EXEC sys.sp_addextendedproperty
			  @name = N''' + [name] + ''', @value = N''' + 
			  REPLACE(CONVERT(VARCHAR(MAX), [VALUE]), '''', '''''') + ''',
			  @level0type = N''SCHEMA'', @level0name = ' + 
			  quotename(@SCHEMANAME) + ',
			  @level1type = N''TABLE'', @level1name = ' + 
			  quotename(@TBLNAME) + ';'
	FROM fn_listextendedproperty(NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, NULL, NULL);;
	
	WITH obj
	AS (
		SELECT split.a.value('.', 'VARCHAR(20)') AS NAME
		FROM (
			SELECT CAST('<M>' + REPLACE('column,constraint,index,trigger,parameter', ',', '</M><M>') + 
			'</M>' AS XML) AS data
			) AS A
		CROSS APPLY data.nodes('/M') AS split(a)
		)
	SELECT @EXTENDEDPROPERTIES = @EXTENDEDPROPERTIES + @vbCrLf + @vbCrLf + 
			'EXEC sys.sp_addextendedproperty
			 @name = N''' + lep.[name] + ''', @value = N''' + 
			 REPLACE(convert(VARCHAR(max), lep.[value]), '''', '''''') + ''',
			 @level0type = N''SCHEMA'', @level0name = ' + quotename(@SCHEMANAME) + ',
			 @level1type = N''TABLE'', @level1name = ' + quotename(@TBLNAME) + ',
			 @level2type = N''' + UPPER(obj.NAME) + ''', @level2name = ' + 
			 quotename(lep.[objname]) + ';'
	FROM obj
	CROSS APPLY fn_listextendedproperty(NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, obj.NAME, NULL) AS lep;

	IF @EXTENDEDPROPERTIES <> ''
		SET @EXTENDEDPROPERTIES = @vbCrLf + 'GO' + 
			@vbCrLf + @EXTENDEDPROPERTIES


		
	------------------------------------------
	--FINAL CLEANUP AND PRESENTATION
	------------------------------------------
	-- there could be a trailing comma, or blank
	SELECT @FINALSQL = @FINALSQL + @CONSTRAINTSQLS + @CHECKCONSTSQLS + @FKSQLS

	-- note that this trims the trailing comma from the end of the statements
	SET @FINALSQL = SUBSTRING(@FINALSQL, 1, LEN(@FINALSQL) - 1);
	SET @FINALSQL = @FINALSQL + ')' + @vbCrLf;
	SET @input = @vbCrLf + @FINALSQL + @INDEXSQLS + @RULESCONSTSQLS + 
		@TRIGGERSTATEMENT + @EXTENDEDPROPERTIES

	--SELECT @input AS Item;
	

	SELECT @SOLUTION  = @input  -- returns

	RETURN;
	
	
	
--         ,'%% \\-*%%
--       ;%%%%%*% _%%%"
--           ,%%% \(* ,%%%.
--     % *%%, ,%%*(% *%%,%*
--      %^  ,* \  )\| %^,* 
--        *%    \/ #)*%
--            _.),/    
--             /#(     ' 
--    *%     \ #).\  



END -- SP