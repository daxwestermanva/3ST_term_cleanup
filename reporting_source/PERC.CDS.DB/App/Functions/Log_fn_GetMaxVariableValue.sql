

CREATE FUNCTION App.[Log_fn_GetMaxVariableValue]
/**********************************************************************************************************
* SP Name:	Log.fn_GetMaxVariableValue
*
* Parameters:
*		@ExecutionLogID		ExecutionLogID of the package 
*		@VariableName			Name of the Variable
*
* Purpose:	This function will return the value for the last instance of the varible for the ExecutionLogID
*
* Example:
* Revision Date/Time:
*
**********************************************************************************************************/
(
	 @ExecutionLogID INT
	,@VariableName VARCHAR(255)
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	
	DECLARE @VariableValue VARCHAR(MAX);
	
	WITH MaxExecutionVariableID as
		(SELECT MAX(ExecutionVariableID) AS MaxExecutionVariableID
		FROM App.[Log_ExecutionVariableLog]
		WHERE ExecutionLogID = @ExecutionLogID
		AND VariableName = @VariableName
		)
	
	SELECT @VariableValue = VariableValue
	FROM App.[Log_ExecutionVariableLog] EVL
	INNER JOIN MaxExecutionVariableID MEVL
		ON EVL.ExecutionVariableID = MEVL.MaxExecutionVariableID
	
	RETURN @VariableValue
END