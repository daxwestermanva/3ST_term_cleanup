CREATE   PROCEDURE dbo.SetDDLTriggerStatus
	@Action varchar(10)
	, @Password varchar(128)
	, @Debug bit = 0
WITH EXECUTE AS SELF
--WITH ENCRYPTION, EXECUTE AS SELF -- removed 2018-08-01 RRT to permit DACPAC scripting
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @PasswordHash varbinary(64)
		, @ErrMsg varchar(2000)
	IF @Action IS NULL
		BEGIN
			SET @ErrMsg = 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Parameter @Action cannot be NULL'
			RAISERROR (@ErrMsg, 16, 1)
			RETURN
		END
	IF @Action NOT IN ('Enable', 'Disable')
		BEGIN
			SET @ErrMsg = 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Parameter @Action must be Enable or Disable'
			RAISERROR (@ErrMsg, 16, 1)
			RETURN
		END
	IF @Password IS NULL 
		BEGIN
			SET @ErrMsg = 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Parameter @Password cannot be NULL'
			RAISERROR (@ErrMsg, 16, 1)
			RETURN
		END
	IF LTRIM(RTRIM(@Password)) = '' 
		BEGIN
			SET @ErrMsg = 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Parameter @Password cannot be blank'
			RAISERROR (@ErrMsg, 16, 1)
			RETURN
		END
	
	SET @PasswordHash = HASHBYTES('SHA2_512', @Password)
	IF @PasswordHash != 0x839F69DEEEDCB1D9CB24E220177C01333D7C69CFCB256387A53C823F6CB79036E874C03B6E673D030B0838ED662B84C0B3739A65E68CF97740BEA7A005F5F14B
		BEGIN
			SET @ErrMsg = 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Parameter @Password is not correct'
			RAISERROR (@ErrMsg, 16, 1)
			RETURN
		END
	IF @Debug = 0
		BEGIN
			IF @Action = 'Enable' 
				BEGIN
					EXEC('ENABLE TRIGGER PreventDDLEvents_DDLTrigger ON DATABASE;')
				END
			IF @Action = 'Disable'
				BEGIN
					EXEC('DISABLE TRIGGER PreventDDLEvents_DDLTrigger ON DATABASE;')
				END
		END
	IF @Debug = 1
		BEGIN
			IF @Action = 'Enable' 
				BEGIN
					PRINT 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': command is ENABLE TRIGGER PreventDDLEvents_DDLTrigger ON DATABASE;'
				END
			IF @Action = 'Disable'
				BEGIN
					PRINT 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': command is DISABLE TRIGGER PreventDDLEvents_DDLTrigger ON DATABASE;'
				END
		END
	IF (SELECT is_disabled FROM sys.Triggers WHERE name = 'PreventDDLEvents_DDLTrigger') = 1
		PRINT 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Trigger PreventDDLEvents_DDLTrigger on database ' + DB_NAME() + ' is now DISABLED'; 
	ELSE
		PRINT 'Procedure dbo.' + OBJECT_NAME(@@PROCID) + ': Trigger PreventDDLEvents_DDLTrigger on database ' + DB_NAME() + ' is now ENABLED'; 
	RETURN
END


