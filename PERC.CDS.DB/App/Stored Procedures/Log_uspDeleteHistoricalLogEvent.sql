-- Procedures



CREATE PROCEDURE [App].[Log_uspDeleteHistoricalLogEvent]
      @StartDate DATE
	  ,@TruncateAll BIT = 0
WITH EXECUTE AS caller
AS

  /*******************************************************************************************************
* Procedure:		[App].[Log_uspDeleteHistoricalLogEvent]
* Created By:		Matt Wollner - Matt.Wollner@key2consulting.com
* Date Created:		2014-12-10
* Description:		Archives Audit Execution Log from before a given date
*					Deletes all other audit data from before a given date
* Updates:	Updated By	-	Update Date	-	Notes	

*******************************************************************************************************/


BEGIN
	IF (@TruncateAll = 1)
	BEGIN 
		TRUNCATE TABLE [App].[Log_ExecutionLog]
		TRUNCATE TABLE [App].[Log_ExecutionVariableLog]
		TRUNCATE TABLE [App].[Log_ExecutionErrorLog]
		TRUNCATE TABLE [App].[Log_ExecutionTaskLog]
		TRUNCATE TABLE [App].[Log_ExecutionLogArchive]
		TRUNCATE TABLE [App].[Log_ExecutionProcedureLog]
	END --IF
	ELSE BEGIN
		--Update Pacakges that did not finish.  Most likely killed during execution.
		UPDATE [App].[Log_ExecutionLog]
		SET Status = 'Did Not Complete'
		FROM App.[Log_ExecutionLog]
		WHERE Status = 'In Process'
		AND StartTime < DATEADD(dd,-2,GETDATE())
 
		DELETE VL
		FROM [App].[Log_ExecutionVariableLog] VL
		INNER JOIN [App].[Log_ExecutionLog] EL    ON VL.ExecutionLogID = EL.ExecutionLogID
		WHERE EL.StartTime < @StartDate
 
		DELETE EEL
		FROM [App].[Log_ExecutionErrorLog]  EEL
		INNER JOIN [App].[Log_ExecutionLog] EL    ON EEL.ExecutionLogID = EL.ExecutionLogID
		WHERE EL.StartTime < @StartDate
 
		DELETE TL
		FROM [App].[Log_ExecutionTaskLog]   TL
		INNER JOIN [App].[Log_ExecutionLog] EL    ON TL.ExecutionLogID = EL.ExecutionLogID
		WHERE EL.StartTime < @StartDate
 
		DELETE
		FROM [App].[Log_ExecutionTaskLog]
		WHERE OnPreExecuteTime < @StartDate
		AND ExecutionLogID = -1
 
		--Move Old Rows to Archive Table 
		INSERT INTO [App].[Log_ExecutionLogArchive]
		SELECT EL.*
		FROM [App].[Log_ExecutionLog] EL
		LEFT OUTER JOIN [App].[Log_ExecutionLogArchive] ARC
		ON EL.[ExecutionLogID] = ARC.[ExecutionLogID]
		WHERE ARC.[ExecutionLogID] IS NULL
		AND EL.StartTime < @StartDate

		--Delete Old Rows from [App].[Log_ExecutionLog 
		DELETE
		FROM  [App].[Log_ExecutionLog]     
		WHERE StartTime < @StartDate
	END--Else
END --proc