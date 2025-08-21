
CREATE PROCEDURE [App].[Log_uspHandleOnErrorEventExecutionLog] 
	 @ExecutionLogID		INT
	,@TaskName VARCHAR(255)
	,@ErrorDescription VARCHAR(MAX)
	,@TaskId VARCHAR(50)
WITH EXECUTE AS caller
AS
	/**********************************************************************************************************
	* SP Name:
	*		App.Log_uspHandleOnErrorEventExecutionLog
	* Parameters:
	*  
	* Purpose:	This stored procedure logs an error entry in the custom event-log table.
	*
	* Example:
	*              
	* Revision Date/Time:
	*
	**********************************************************************************************************/
	BEGIN
		SET NOCOUNT ON

		DECLARE @PackageName VARCHAR(100)
			,@CurrentPackageFlag BIT

		SELECT @PackageName = EL.PackageName
			,@CurrentPackageFlag = CASE WHEN ETL.ExecutionLogID = @ExecutionLogID THEN  1 ELSE 0 END
		FROM App.[Log_ExecutionTaskLog] ETL  WITH (NOLOCK)
		INNER JOIN App.[Log_ExecutionLog] EL  WITH (NOLOCK) ON ETL.ExecutionLogID = EL.ExecutionLogID
		LEFT OUTER JOIN App.[Log_ExecutionLog] ELP WITH (NOLOCK) ON EL.ParentExecutionLogID = ELP.ExecutionLogID
		WHERE ETL.TaskID = @TaskId
		AND (EL.ExecutionLogID = @ExecutionLogID 
			OR EL.ParentExecutionLogID = @ExecutionLogID
			OR ELP.ParentExecutionLogID = @ExecutionLogID)
		
		UPDATE App.Log_ExecutionLog 
		SET	 EndTime = GETDATE()
			,Status = 'Failed'
			,FailureTask = CASE WHEN @CurrentPackageFlag = 1 THEN '' ELSE 'Package: ' + ISNULL(@PackageName,'') + '. ' END
				+ 'Task: ' + @TaskName
			,FailureMessage = @ErrorDescription
		WHERE ExecutionLogID = @ExecutionLogID
		

		SET nocount OFF
	END --proc