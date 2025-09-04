


CREATE PROCEDURE [App].[Log_uspHandleOnErrorEvent] 
	 @ExecutionLogID		INT
	,@ExecutionGuid VARCHAR(38)=NULL
	,@TaskName VARCHAR(255)
	,@TaskID VARCHAR(38)=NULL
	,@ErrorCode INT
	,@ErrorDescription VARCHAR(MAX)
WITH EXECUTE AS caller
AS
	/**********************************************************************************************************
	* SP Name:
	*		App.Log_uspHandleOnErrorEvent
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
		SET nocount ON
			
		INSERT INTO App.Log_ExecutionErrorLog
			( ExecutionLogID
			, ExecutionGuid
			, TaskName
			, TaskID
			, ErrorCode
			, ErrorDescription
			, ErrorTime
			)
		VALUES(
			 @ExecutionLogID
			,CAST(@ExecutionGuid AS UNIQUEIDENTIFIER)
			,@TaskName
			,CAST(@TaskID AS UNIQUEIDENTIFIER)
			,@ErrorCode
			,@ErrorDescription
			,GETDATE()
			)

		SET nocount OFF
	END --proc