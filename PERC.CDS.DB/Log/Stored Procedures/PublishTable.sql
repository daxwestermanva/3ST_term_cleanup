
/********************************************************************************************************************
DESCRIPTION: Add an entry to [Log].[PublishedTableLog]. If the entry is associated to a user, set CreateBy to the user's windows  account.

[Log].[PublishedTableLog] entries are categorized by PublishedType, and should use the following pre-defined types:
 - Replace
 - Merge 
 - Append

Message is nullable and can have additonal information

UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]

EXAMPLE:
	EXEC [Log].[ExecutionBegin] @Name = 'My Process', @Description = 'My Description'
	EXEC [Log].[Message] 'Information', 'Information Description'
	EXEC [Log].[PublishTable] 
			@SchemaName = 'App'
			,@TableName = 'MyTable'
			,@SourceTableName = '#MyTableStage'
			,@PublishedType = 'Replace'
			,@PublishedRowCount = 1000
			,@PublishedBy = 'VHAMASTER\VHAISBBACANJ'
	EXEC [Log].[ExecutionEnd]
********************************************************************************************************************/
CREATE PROCEDURE [Log].[PublishTable]
	@SchemaName VARCHAR(128)
	,@TableName VARCHAR(128)
	,@SourceTableName VARCHAR(128)
	,@PublishedType VARCHAR(50) 
	,@PublishedRowCount INT
	,@PublishedBy VARCHAR(256) = NULL
	,@ExecutionLogID INT = NULL
	,@Message VARCHAR(MAX) = NULL
AS
BEGIN
	
	-- Validate the Type conforms to the pre-defined types.
	IF @PublishedType NOT IN ('Replace','Merge','Append')
	BEGIN
		THROW 60000, 'PublishTable Message: Must use pre-defined types of Replace, Merge, or Append.', 1;
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
	INSERT INTO [Log].[PublishedTableLog]
	(
         [SchemaName]
        ,[TableName]
        ,[SourceTableName]
        ,[PublishedType]
        ,[PublishedRowCount]
        ,[PublishedBy]
        ,[PublishedDateTime]
        ,[ExecutionLogID]
	)
	VALUES (
		@SchemaName
		,@TableName
		,@SourceTableName
		,@PublishedType
		,@PublishedRowCount
		,ISNULL(@PublishedBy,CURRENT_USER)
		,GETDATE()
		,@ExecutionLogID
	)

END