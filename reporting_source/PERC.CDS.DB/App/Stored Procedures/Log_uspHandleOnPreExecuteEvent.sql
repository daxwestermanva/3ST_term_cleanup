
CREATE PROCEDURE [App].[Log_uspHandleOnPreExecuteEvent]
	 @ExecutionLogID		INT
	,@ExecutionGuid		VARCHAR(38)
	,@TaskName VARCHAR(255)
	,@TaskID VARCHAR(38)
	,@TaskDesc VARCHAR(50)
WITH EXECUTE AS caller
AS
/**********************************************************************************************************
* SP Name:
*		App.Log_uspHandleOnPreExecuteEvent
* Parameters:
*  
* Purpose:	This procedure is called by SSIS packages (from an event handler) before a task is
*               executed.
*              
* Example:
*              
* Revision Date/Time:
*
**********************************************************************************************************/
BEGIN
	SET nocount ON
	
    INSERT INTO App.Log_ExecutionTaskLog
		(ExecutionLogID
		,ExecutionGuid
		,TaskName
		,TaskID
		,TaskDesc
		,OnPreExecuteTime
		)
	VALUES
		(@ExecutionLogID
		,CAST(@ExecutionGuid AS UNIQUEIDENTIFIER)
		,@TaskName
		,CAST(@TaskID AS UNIQUEIDENTIFIER)
		,@TaskDesc
		,GETDATE()
		)

	SET nocount OFF
END --proc