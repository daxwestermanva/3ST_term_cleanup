CREATE TRIGGER PreventGrantPermissions_DDLTrigger
ON DATABASE
FOR GRANT_DATABASE, DENY_DATABASE, REVOKE_DATABASE 
AS
	/* ------------------------------------------------------------------------
		Purpose		Prevent workgroup users from granting permissions
		Called by	Events 
		Input
		Output		Custom error message for the user
	---------------------------------------------------------------------------*/
	DECLARE @Msg nvarchar(MAX)
		, @ObjectType sysname
		, @SchemaName sysname
		, @ObjectName sysname
		, @TargetObjectName sysname
		, @LoginName sysname
		, @UserName sysname
		, @ErrorMessage NVARCHAR(4000)
		, @ErrorSeverity INT
		, @ErrorState INT

	SELECT @UserName = EVENTDATA().value('(/EVENT_INSTANCE/UserName)[1]','nvarchar(max)')  
	-- =====================================================================================
	-- Main Logic
	-- =====================================================================================
	BEGIN TRY
		IF	@UserName != 'dbo'
			BEGIN
				SET @Msg = '>> ERROR >> You cannot GRANT, REVOKE, or DENY permissions in a workgroup database. ' ;
				THROW 51000, @Msg, 16;
			END
	END TRY
	BEGIN CATCH
		THROW 51000, @Msg, 16;;
		ROLLBACK;
	END CATCH

RETURN;

