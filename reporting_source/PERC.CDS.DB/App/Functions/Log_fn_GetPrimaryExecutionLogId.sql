
CREATE FUNCTION [App].[Log_fn_GetPrimaryExecutionLogId]
/**********************************************************************************************************
* SP Name:	Log.[fn_GetPrimaryExecutionLogId]
*
* Parameters:
*		@ExecutionLogID		ExecutionLogID of the current package 
*
* Purpose:	This function find the 1st parent pacakge that executed the chain of pacakges
*
* Example:
* Revision Date/Time:
*
**********************************************************************************************************/
(
	 @CurrentExecutionLogID INT
)
RETURNS INT
AS
BEGIN
	
	DECLARE @ParentExecutionLogID INT = -1
		,@iLoop INT = 0
	
	WHILE @CurrentExecutionLogID IS NOT NULL OR @iLoop > 20
	BEGIN
		SET @iLoop = @iLoop + 1

		SELECT @ParentExecutionLogID = @CurrentExecutionLogID
			,@CurrentExecutionLogID = ParentExecutionLogID
		FROM [App].[Log_ExecutionLog]
		WHERE ExecutionLogID = @CurrentExecutionLogID

	END

	RETURN  @ParentExecutionLogID
END