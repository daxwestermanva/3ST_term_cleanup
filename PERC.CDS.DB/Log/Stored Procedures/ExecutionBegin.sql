
/********************************************************************************************************************
DESCRIPTION: Begins logging for a process execution. If the process is a child of another process, set the 
ParentExecutionLogID to the parent. If ParentExecutionLogID is omitted, routine will attempt to search for any open
executions tied to the current SPID and auto-correlate the two. Auto-correlatation does not work when executing 
parent/child across two different connections/SPIDs.

UPDATE:
	2019-02-06	- Matt Wollner	- Update [PrimaryExecutionLogID] if it is NULL

EXAMPLE 1:
	EXEC [Log].[ExecutionBegin] @Name = 'My Name', @Description = 'My Description'
	...do something
	EXEC [Log].[ExecutionEnd]
	
EXAMPLE 2:
	DECLARE @ParentLogID INT, @ChildLogID INT
	EXEC [Log].[ExecutionBegin] @Name = 'My Parent', @Description = 'My Description', @ExecutionLogID = @ParentLogID OUTPUT
		EXEC [Log].[ExecutionBegin] @Name = 'My Child', @Description = 'My Description', @ParentExecutionLogID = @ParentLogID, @ExecutionLogID = @ChildLogID OUTPUT
		EXEC [Log].[ExecutionEnd] @ChildLogID
	EXEC [Log].[ExecutionEnd] @ParentLogID

EXAMPLE 3:
	EXEC [Log].[ExecutionBegin] @Name = 'My Parent', @Description = 'My Description'
		EXEC [Log].[ExecutionBegin] @Name = 'My Child 1', @Description = 'My Description'
			EXEC [Log].[ExecutionBegin] @Name = 'My Grandchild 1', @Description = 'My Description'
			EXEC [Log].[ExecutionEnd]
		EXEC [Log].[ExecutionEnd]
		EXEC [Log].[ExecutionBegin] @Name = 'My Child 2', @Description = 'My Description'
			EXEC [Log].[ExecutionBegin] @Name = 'My Grandchild 2', @Description = 'My Description'
			EXEC [Log].[ExecutionEnd]
		EXEC [Log].[ExecutionEnd]
	EXEC [Log].[ExecutionEnd]
********************************************************************************************************************/
CREATE PROCEDURE [Log].[ExecutionBegin]
	@Name VARCHAR(100)
	,@Description VARCHAR(200) = NULL
	,@ExecutionServer VARCHAR(50) = NULL
	,@Status VARCHAR(50) = 'In Process'
	,@ParentExecutionLogID INT = NULL
	,@ExecutionLogID INT = NULL OUTPUT
AS
BEGIN
	
	-- Determine the login_time of the active session (SPID) used for auto-correlation.
	DECLARE @SessionDateTime DATETIME = (SELECT login_time FROM sys.dm_exec_sessions WITH (NOLOCK) WHERE session_id  = @@SPID)

	-- If no ParentExecutionLogID is passed, attempt to auto-correlate with the current SPID.
	IF @ParentExecutionLogID IS NULL
	BEGIN
		-- SPIDs can be recycled so also use the associated login_time for the current session.
		SELECT TOP 1 @ParentExecutionLogID = ExecutionLogID
		FROM [Log].[ExecutionLog]
		WHERE
			[EndDateTime] IS NULL
			AND [SessionID] = @@SPID
			AND [SessionDateTime] = @SessionDateTime
		ORDER BY ExecutionLogID DESC
	END

	-- Identify the primary execution, which is the root process spawning all child processes. The code below supports a max of 5 levels, but is
	-- much simpler to understand than a CTE.
	DECLARE @PrimaryExecutionLogID INT
	SELECT @PrimaryExecutionLogID = COALESCE(p4.ParentExecutionLogID, p4.ExecutionLogID, p3.ExecutionLogID, p2.ExecutionLogID, p1.ExecutionLogID)
	FROM [Log].[ExecutionLog] p1
	LEFT JOIN [Log].[ExecutionLog] p2 ON p1.ParentExecutionLogID = p2.ExecutionLogID
	LEFT JOIN [Log].[ExecutionLog] p3 ON p2.ParentExecutionLogID = p3.ExecutionLogID
	LEFT JOIN [Log].[ExecutionLog] p4 ON p3.ParentExecutionLogID = p4.ExecutionLogID
	WHERE p1.ExecutionLogID = @ParentExecutionLogID

	-- Add the log entry
	INSERT INTO [Log].[ExecutionLog] (
		[ParentExecutionLogID]
		,[PrimaryExecutionLogID]
		,[Name]
		,[Description]
		,[ExecutionServer]
		,[ExecutionUserName]
		,[StartDateTime]
		,[Status]
		,[SessionID]
		,[SessionDateTime]
	)
	VALUES (
		@ParentExecutionLogID
		,@PrimaryExecutionLogID
		,@Name
		,@Description
		,ISNULL(@ExecutionServer, @@SERVERNAME)
		,SUSER_NAME()
		,GETDATE()
		,@Status
		,@@SPID
		,@SessionDateTime
	)

	-- Return the new Execution LogID
	SET @ExecutionLogID = @@IDENTITY

	UPDATE  [Log].[ExecutionLog]
	SET [PrimaryExecutionLogID] = @ExecutionLogID
	WHERE ExecutionLogID = @ExecutionLogID
	AND [PrimaryExecutionLogID] IS NULL

END