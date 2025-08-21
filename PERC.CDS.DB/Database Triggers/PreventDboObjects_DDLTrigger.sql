CREATE TRIGGER PreventDboObjects_DDLTrigger
ON DATABASE
FOR CREATE_TABLE, CREATE_VIEW, CREATE_PROCEDURE, CREATE_FUNCTION
AS
	/* ------------------------------------------------------------------------
		Purpose		Prevent users from creating objects in the dbo schema
		Called by	Embedded in the CreateProject stored procedure
		Input
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
	-- Exception for Database Diagrams
	-- -------------------------------------------------------------------------------------
	IF	@SchemaName = N'dbo' AND 
		(
			(@ObjectType = 'Table' AND @ObjectName IN ('sysdiagrams'))
		OR
			(@ObjectType = 'Procedure' AND @ObjectName IN ('sp_alterdiagram', 'sp_creatediagram', 'sp_dropdiagram', 'sp_helpdiagramdefinition', 'sp_helpdiagrams', 'sp_renamediagram', 'sp_upgraddiagrams'))
		)
		OR
			(@ObjectType = 'Function' AND @ObjectName IN ('fn_diagramobjects'))
		BEGIN
			RETURN;
		END;

	-- =====================================================================================
	-- Main Logic
	-- =====================================================================================
	BEGIN TRY
		IF @SchemaName = 'dbo'
			BEGIN
				SET @Msg = '>> ERROR >> You cannot create objects in the dbo schema: ' + @SchemaName + '.' + @ObjectName + '. Please use a different schema.'
				RAISERROR (@Msg, 16, 1);
			END
	END TRY
	BEGIN CATCH
		SELECT @Msg = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
		RAISERROR (@Msg, @ErrorSeverity, @ErrorState );
		ROLLBACK;
	END CATCH

RETURN;

