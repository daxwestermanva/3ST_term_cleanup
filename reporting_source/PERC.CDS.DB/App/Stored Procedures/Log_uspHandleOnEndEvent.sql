
CREATE PROCEDURE [App].[Log_uspHandleOnEndEvent]
	(
	 @ExecutionLogID		INT
	,@LogicalDate		DATETIME = NULL
	)
WITH EXECUTE AS CALLER
AS

	/**********************************************************************************************************
	* SP Name:	App.Log_uspHandleOnEndEvent
	*
	* Parameters:
	*		@ExecutionLogID		ExecutionLogID of the calling package
	*		@LogicalDate		Date associated to the business Date for the package(Optional)
	*
	* Purpose:	This stored procedure updates an existing entry in the custom execution log table. It flags the
	*		execution run as complete and inserts the end time of the SSIS package.
	*
	* Example:
			EXEC App.Log_uspHandleOnEndEvent
				 0
				,'6/1/2009'
	*
	* Revision Date/Time:
	*
	**********************************************************************************************************/

	BEGIN

	SET NOCOUNT ON

	UPDATE App.[Log_ExecutionLog] SET
		 [EndTime] = GETDATE()
		,[Status] =
			CASE
				WHEN [Status] = 'In Process' THEN 'Completed'
				ELSE [Status]
			END
		,LogicalDate = ISNULL(@LogicalDate,LogicalDate)		--Only update the LogicalDate if a values is passed in
	WHERE 
		ExecutionLogID = @ExecutionLogID

	SET NOCOUNT OFF

	END