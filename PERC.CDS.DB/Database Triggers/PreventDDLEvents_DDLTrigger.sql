CREATE   TRIGGER PreventDDLEvents_DDLTrigger
ON DATABASE
FOR DDL_TABLE_VIEW_EVENTS 
AS
	/* ------------------------------------------------------------------------
		Purpose		Prevent users from modifying any objects
		Output		Custom error message for the user
	---------------------------------------------------------------------------*/
	DECLARE @Msg nvarchar(MAX)
		, @ObjectType sysname
		, @SchemaName sysname
		, @ObjectName sysname
		, @TargetObjectName sysname
		, @ErrorMessage NVARCHAR(4000)
		, @ErrorSeverity INT
		, @ErrorState INT

	SELECT 
		  @ObjectType		= EVENTDATA().value('(/EVENT_INSTANCE/ObjectType)[1]','nvarchar(max)') 
		, @SchemaName		= EVENTDATA().value('(/EVENT_INSTANCE/SchemaName)[1]','nvarchar(max)') 
		, @ObjectName		= EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(max)')  
		, @TargetObjectName = EVENTDATA().value('(/EVENT_INSTANCE/TargetObjectName)[1]','nvarchar(max)')  

	-- -------------------------------------------------------------------------------------
	-- Exception for ETL Account
	-- -------------------------------------------------------------------------------------
	IF SUSER_SNAME() = 'VHAMaster\OMHSP_PERC_ETL' 
		BEGIN
			RETURN;
		END;

	-- =====================================================================================
	-- Main Logic
	-- =====================================================================================
	BEGIN TRY
		SET @Msg = '>> ERROR >> You cannot create, alter or drop objects in the ' + DB_NAME() + ' database, user ' + SUSER_SNAME()
		RAISERROR (@Msg, 16, 1);
	END TRY
	BEGIN CATCH
		SELECT @Msg = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
		RAISERROR (@Msg, @ErrorSeverity, @ErrorState );
		ROLLBACK;
	END CATCH

RETURN;


GO
DISABLE TRIGGER [PreventDDLEvents_DDLTrigger]
    ON DATABASE;

