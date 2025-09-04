
CREATE PROCEDURE [App].[Log_uspHandleOnBeginEvent]
	(
	 @ParentExecutionLogID		INT
	,@Description			VARCHAR(200) = NULL
	,@PackageName			VARCHAR(100)
	,@PackageID			UNIQUEIDENTIFIER
	,@PackageVersionMajor		INT = 0
	,@PackageVersionMinor		INT = 0
	,@PackageVersionBuild		INT = 0
	,@MachineName			VARCHAR(50)
	,@ExecutionInstanceGUID		UNIQUEIDENTIFIER
	,@LogicalDate			DATETIME = NULL
	,@UserName			VARCHAR(50)
	,@SSISDBServerExecutionID INT
	,@NewExecutionLogID		INT = NULL OUTPUT
	)
WITH EXECUTE AS CALLER
AS

/**********************************************************************************************************
* SP Name:	App.[Log_uspHandleOnBeginEvent]
*
* Parameters:
*		@ParentExecutionLogID	ExecutionLogID of the parent of the calling package
*		@Description			Description of the calling package
*		@PackageName			Name of the calling package
*		@PackageID				Unique ID of the calling package
*		@PackageVersionMajor	VersionMajor of calling package
*		@PackageVersionMinor	VersionMinor of calling package
*		@PackageVersionBuild	VersionBuild of calling package
*		@MachineName			Name of the machine executing the calling package
*		@ExecutionInstanceGUID	Unique execution ID of the calling package
*		@LogicalDate			Logical date (currently not used)
*		@UserName				Name of the user executing the calling package
*		@SSISDBServerExecutionID SSISDB Internal Key
*		@NewExecutionLogID		New ExecutionLogID for the calling package
*		
*
* Purpose:	This stored procedure logs a starting event to the custom execution log table.
*
* Example:
		DECLARE @ExecutionLogID INT
		
		EXEC App.[Log_uspHandleOnBeginEvent]
			 0
			,'Description'
			,'PackageName'
			,'00000000-0000-0000-0000-000000000000'
			,1
			,2
			,34
			,'MachineName'
			,'00000000-0000-0000-0000-000000000000'
			,'2010-01-01'
			,'Matt'
			,'2010-02-28 15:14:19.657'
			,1
			,@ExecutionLogID OUTPUT
*
* Revision Date/Time:
*
**********************************************************************************************************/

BEGIN

	SET NOCOUNT ON

	--Coalesce @LogicalDate
	--SET @LogicalDate = ISNULL(@LogicalDate, GETDATE())
	--Updated to leave LogicalDate NULL if it comes in a NULL

	--Coalesce @Operator
	SET @UserName = NULLIF(LTRIM(RTRIM(@UserName)), '')
	SET @UserName = ISNULL(@UserName, SUSER_SNAME())

	--Root-level nodes should have a null parent
	IF @ParentExecutionLogID <= 0
		SET @ParentExecutionLogID = NULL

	--Root-level nodes should not have a null Description
	SET @Description = NULLIF(LTRIM(RTRIM(@Description)), '')
	IF @Description IS NULL AND @ParentExecutionLogID IS NULL
		SET @Description = @PackageName

	--Insert the log record
	INSERT INTO App.[Log_ExecutionLog]
		(
		 SSISDBServerExecutionID
		,ParentExecutionLogID
		,Description
		,PackageName
		,PackageID
		,PackageVersionMajor
		,PackageVersionMinor
		,PackageVersionBuild
		,MachineName
		,ExecutionInstanceGUID
		,LogicalDate
		,UserName
		,StartTime
		,EndTime
		,Status
		,FailureTask
		)
	VALUES
		(
		 @SSISDBServerExecutionID
		,@ParentExecutionLogID
		,@Description
		,@PackageName
		,@PackageID
		,@PackageVersionMajor
		,@PackageVersionMinor
		,@PackageVersionBuild
		,@MachineName
		,@ExecutionInstanceGUID
		,@LogicalDate
		,@UserName
		,GETDATE()
		,NULL
		,'In Process'
		,NULL
		)

	SET @NewExecutionLogID = SCOPE_IDENTITY()

	UPDATE App.[Log_ExecutionLog]
	SET [PrimaryExecutionLogID] = App.Log_fn_GetPrimaryExecutionLogId(@NewExecutionLogID)
	WHERE [ExecutionLogID] = @NewExecutionLogID


	SET NOCOUNT OFF

END