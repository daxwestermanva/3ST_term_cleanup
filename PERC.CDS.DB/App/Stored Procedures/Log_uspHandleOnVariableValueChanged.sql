


CREATE PROCEDURE [App].[Log_uspHandleOnVariableValueChanged]
	 @ExecutionLogID				INT
	,@VariableName		VARCHAR(255)
	,@VariableValue		VARCHAR(MAX)
	,@VariableDescription VARCHAR(MAX) = NULL
WITH EXECUTE AS caller
AS
	/**********************************************************************************************************
	* SP Name:
	*		App.Log_uspHandleOnVariableValueChanged
	* Parameters:
		 @ExecutionLogID				int
		,@VariableName		varchar(255)
		,@VariableValue		varchar(max)
		,@VariableDescription VARCHAR(MAX) (Optional)
	*  
	* Purpose:	
	*              
	* Example:
	*              
	* Revision Date/Time:
	*
	**********************************************************************************************************/
	BEGIN
		SET nocount ON

		--Insert the log record
		INSERT INTO App.Log_ExecutionVariableLog(
			  ExecutionLogID
			, VariableName
			, VariableValue
			, VariableDescription
			, CaptureTime
		) VALUES (
			 ISNULL(@ExecutionLogID, 0)
			,@VariableName
			,@VariableValue
			,@VariableDescription
			,GETDATE()
		)

		SET nocount OFF
	END --proc