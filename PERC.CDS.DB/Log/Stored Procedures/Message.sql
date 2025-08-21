
/********************************************************************************************************************
DESCRIPTION: Add a message log entry. If the entry is associated to a user, set CreateBy to the user's windows 
account.

Messages are categorized by Type, and should use the following pre-defined types:
 - Error
 - Warning
 - Information
 - Variable
 - Security

Name further defines the log entry within the given Type. For example:
 - MPR Active Patients Step
 - Access Denied
 - Record Count

Message contains the contents of the log entry, such as the full error message or message description.  For example:
 - Runtime Error: Divide by zero
 - Access denied to report to user X in procedure Y.
 - 12345

UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]

EXAMPLE 1:
	EXEC [Log].[Message] 'Security', 'Access Denied', 'ReporProcedure: User XYZ does not have access to Sta3n 402.'

EXAMPLE 2:
	EXEC [Log].[ExecutionBegin] @Name = 'My Process', @Description = 'My Description'
	EXEC [Log].[Message] 'Error', 'Error Description'
	EXEC [Log].[ExecutionEnd]
********************************************************************************************************************/
CREATE PROCEDURE [Log].[Message]
	@Type VARCHAR(50) = NULL
	,@Name VARCHAR(100) = NULL
	,@Message VARCHAR(MAX) = NULL
	,@CreatedBy VARCHAR(50) = NULL
	,@StackTrace VARCHAR(MAX) = NULL
	,@ExecutionLogID INT = NULL
AS
BEGIN
	
	-- Validate the Type conforms to the pre-defined types.
	IF @Type NOT IN ('Error', 'Warning', 'Information', 'Security', 'Variable')
	BEGIN
		THROW 60000, 'LogMessage: Must use pre-defined types of Error, Warning, Information, Variable, or Security.', 1;
	END

	-- If no ExecutionLogID is passed, attempt to auto-correlate with associated logs.
	IF @ExecutionLogID IS NULL
	BEGIN
		-- SPIDs can be recycled so also use the associated login_time for the current session.
		DECLARE @SessionDateTime DATETIME = (SELECT login_time FROM sys.dm_exec_sessions WITH (NOLOCK) WHERE session_id  = @@SPID)
		
		SELECT TOP 1 @ExecutionLogID = ExecutionLogID
		FROM [Log].[ExecutionLog]
		WHERE 
			[EndDateTime] IS NULL
			AND [SessionID] = @@SPID
			AND [SessionDateTime] = @SessionDateTime
		ORDER BY ExecutionLogID DESC
	END

	-- Add the message log entry.
	INSERT INTO [Log].[MessageLog] (
		[ExecutionLogID]
        ,[Type]
        ,[Name]
        ,[Message]
        ,[StackTrace]
        ,[CreatedBy]
		,[CreatedDateTime]
	)
	VALUES (
		@ExecutionLogID
        ,ISNULL(@Type, 'Information')
        ,@Name
        ,@Message
        ,@StackTrace
        ,ISNULL(@CreatedBy, SUSER_NAME())
        ,GETDATE()
	)

END