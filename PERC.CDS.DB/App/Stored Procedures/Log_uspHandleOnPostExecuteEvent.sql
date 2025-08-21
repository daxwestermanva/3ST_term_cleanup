
CREATE PROCEDURE [App].[Log_uspHandleOnPostExecuteEvent]
	 @ExecutionLogID		INT
	,@ExecutionGuid		VARCHAR(38)
	,@TaskName VARCHAR(255)
	,@TaskID VARCHAR(38)
WITH EXECUTE AS caller
AS
/**********************************************************************************************************
* SP Name:
*		App.Log_uspHandleOnPostExecuteEvent
* Parameters:
*  
* Purpose:	This procedure is called by SSIS packages (from an event handle) when a task completes
*               execution.
*              
* Example:
*              
* Revision Date/Time:
*
**********************************************************************************************************/
BEGIN
	SET nocount ON
	
    UPDATE App.Log_ExecutionTaskLog
	SET OnPostExecuteTime = GETDATE()
	WHERE ExecutionGuid = CAST(@ExecutionGuid AS UNIQUEIDENTIFIER)
		AND TaskName = @TaskName
		AND TaskID = CAST(@TaskID AS UNIQUEIDENTIFIER)
	SET nocount OFF
END --proc