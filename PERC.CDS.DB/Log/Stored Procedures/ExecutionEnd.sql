

/********************************************************************************************************************
DESCRIPTION: Ends logging for a process execution. If no ExecutionLogID is passed, routine will attempt to 
auto-correlate based on the current SPID.

See [Log].[ExecutionBegin] for examples.

UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
********************************************************************************************************************/
CREATE PROCEDURE [Log].[ExecutionEnd]
	@ExecutionLogID INT = NULL
	,@Status VARCHAR(50) = 'Completed'
AS
BEGIN
	
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

	UPDATE [Log].[ExecutionLog]
	SET 
		[EndDateTime] = GETDATE()
		,[Status] = @Status
	WHERE ExecutionLogID = @ExecutionLogID

END