
CREATE PROCEDURE [Maintenance].[RefreshAllViews]
---------------------------------------------------------------------------------------------------------------------------------------
-- 2018/12/01 - Jason E Bacani - Basic procedure to dynamically refresh all non-system views 
-- 2020-02-13	RAS	Used code from OMHSP_PERC_Share to create code in CDS
-- 2020-09-01	RAS Added TRY/CATCH to make sure all views are refreshed and all errors returned (instead of stopping at first error)
---------------------------------------------------------------------------------------------------------------------------------------
AS
BEGIN

	DECLARE 
		@DebugOnly BIT = 0 -- Use 1 for debugging
		, @sql NVARCHAR(MAX) = ''
		, @TableIDPointer INT = 1
		, @FullTableNamePointer VARCHAR(500)
	;

	DECLARE @ViewData TABLE
	(
		TableID INT IDENTITY
		, FullTableName VARCHAR(500)
	);

	--Get all views in the database
	INSERT @ViewData (FullTableName)
	SELECT DISTINCT
		s.Name + '.' + o.Name AS FullTableName 
	FROM sys.objects o WITH (NOLOCK)
	INNER JOIN sys.schemas s WITH (NOLOCK )
		ON o.schema_id = s.schema_id
	WHERE o.type_desc = 'VIEW'
	ORDER BY 1;


	--Create a table to save the errors as they are encountered
	DROP TABLE IF EXISTS #Errors
	CREATE TABLE #Errors (	
		ViewName VARCHAR(500)
		)

	--Loop attempts to refresh every view in @ViewData
	WHILE (@TableIDPointer <= (SELECT MAX(TableID) FROM @ViewData))
	BEGIN
		SET @sql = '';
		SELECT @FullTableNamePointer = FullTableName
		FROM @ViewData
		WHERE TableID= @TableIDPointer
	
		SET @sql =
		'EXECUTE SP_REFRESHVIEW N'''+@FullTableNamePointer+'''; ' ;

		PRINT @sql;
		IF @DebugOnly = 0
		BEGIN TRY --Use try/catch so that if an error is encountered, it can still continue to refresh other views
			EXECUTE SP_EXECUTESQL @sql;
			PRINT '  ' + @FullTableNamePointer + ' refreshed';
		END TRY
			BEGIN CATCH --If an error is encountered, the view name is saved to a temp table
			INSERT INTO #Errors
			VALUES (@FullTableNamePointer)
			PRINT '  ' + @FullTableNamePointer + ' ERROR - NOT REFRESHED';
			END CATCH

		SET @TableIDPointer = @TableIDPointer + 1;
	
	END

	--Check if there were any view names added to the error table and throw an error with any view names causing an error
	IF (SELECT count(*) FROM #Errors)>0 
	BEGIN
		DECLARE @ErrorList VARCHAR(MAX) = 'Invalid view(s): ' + (
			SELECT STRING_AGG(ViewName,',') FROM #Errors
			)
		;THROW 51000,@ErrorList,1
	END

END