CREATE TRIGGER PreventObjectsOnPrimaryFG_DDLTrigger
ON DATABASE
FOR CREATE_TABLE, CREATE_INDEX
AS
/* ------------------------------------------------------------------------
	Purpose		Prevent users from creating tables or indexes on the PRIMARY filegroup
	
	Called by	Embedded in the CreateProject stored procedure

	Input

	Output		Custom error message for the user

 
	Author:		RRT
	Created:	2013-02-06
	Revised:
---------------------------------------------------------------------------*/
BEGIN TRY
	DECLARE @Msg nvarchar(MAX)
		, @ObjectName sysname
		, @ObjectType sysname
		, @SchemaName sysname
		, @TargetObjectName sysname
		, @ErrorMessage NVARCHAR(4000)
		, @ErrorSeverity INT
		, @ErrorState INT

	SELECT 
		  @ObjectType		= EVENTDATA().value('(/EVENT_INSTANCE/ObjectType)[1]','nvarchar(max)') 
		, @SchemaName		= EVENTDATA().value('(/EVENT_INSTANCE/SchemaName)[1]','nvarchar(max)') 
		, @ObjectName		= EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(max)')  
		, @TargetObjectName = EVENTDATA().value('(/EVENT_INSTANCE/TargetObjectName)[1]','nvarchar(max)')  

	-- Debugging:
	-- IF @Debug = 1 SELECT @ObjectType AS '@ObjectType', @SchemaName AS '@SchemaName',@ObjectName AS '@ObjectName', @TargetObjectName AS '@TargetObjectName'

	-- =====================================================================================
	-- Exceptions for Database Diagrams
	-- =====================================================================================
	IF	(@SchemaName = N'dbo' AND @ObjectType = N'TABLE' AND @ObjectName = N'sysdiagrams')
		BEGIN
			RETURN;
		END;


	-- =====================================================================================
	-- Test for PRIMARY filegroup
	-- =====================================================================================

	-- Tables
	IF @ObjectType = N'TABLE' 
		IF EXISTS(
			SELECT 
				SO.name AS TableName
				, SI.index_id AS IndexID
				, SI.data_space_id
				, SF.name AS FileGroupName
			FROM sys.indexes AS SI
			JOIN sys.objects AS SO
				ON SI.object_id = SO.object_id
			JOIN sys.filegroups AS SF
				ON SI.data_space_id = SF.data_space_id
			WHERE 1=1 
				AND SO.name = @ObjectName
				AND SCHEMA_NAME(SO.schema_id) = @SchemaName
				AND SF.name = N'PRIMARY'
			)
			BEGIN
				SET @Msg = '>> ERROR >> You cannot create the table ' + @SchemaName + '.' + @ObjectName + ' ON [PRIMARY]. Use [DefFG] instead.'
				RAISERROR (@Msg, 16, 1);
			END

	-- Indexes
	IF @ObjectType = N'INDEX'
		IF EXISTS(
			SELECT 
				  SI.index_id AS IndexID
				, SI.data_space_id
				, SF.name AS FileGroupName
			FROM sys.indexes AS SI
			JOIN sys.objects AS SO
				ON SI.object_id = SO.object_id
			JOIN sys.filegroups AS SF
				ON SI.data_space_id = SF.data_space_id
			WHERE 1=1
				AND SCHEMA_NAME(SO.schema_id) = @SchemaName
				AND SO.name = @TargetObjectName 
				AND SI.name = @ObjectName
				AND SF.name = N'PRIMARY'
			)
			BEGIN
				SET @Msg = '>> ERROR >> You cannot create the index ' + @ObjectName + ' for table ' + @TargetObjectName + ' on [PRIMARY]. If you are using Management Studio, specify the DefFG filegroup on the Storage tab of the New Index dialog. If you are using T-SQL, specify ON [DefFG].'
				RAISERROR (@Msg, 16, 1);
			END
END TRY
BEGIN CATCH
    SELECT @Msg = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
    RAISERROR (@Msg, @ErrorSeverity, @ErrorState );
	ROLLBACK;
END CATCH
RETURN;

