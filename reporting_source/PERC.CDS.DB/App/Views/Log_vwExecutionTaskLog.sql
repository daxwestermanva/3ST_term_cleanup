
CREATE VIEW [App].[Log_vwExecutionTaskLog]
AS
	SELECT 
		 E.ExecutionLogID
		,ETL.ExecutionTaskLogID
		,E.SSISDBServerExecutionID
		,E.PackageName
		,ETL.TaskName
		,ETL.TaskDesc
		,ETL.OnPreExecuteTime AS TaskStart
		,ETL.OnPostExecuteTime AS TaskEnd
		,DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) / 3600 AS TaskRunTimeHour
		,DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) / 60 AS TaskRunTimeMin
		,DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) AS TaskRunTimeSec
		,CASE	WHEN DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) >= 3600
					THEN CAST(DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) / 3600 AS VARCHAR(50)) + 'h '
						+ CAST((DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) % 3600) / 60 AS VARCHAR(50))+ 'm ' 
						+ CAST((DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) % 3600) % 60 AS VARCHAR(50)) + 's'
				WHEN DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) >= 60
					THEN CAST(DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) / 60 AS VARCHAR(50))+ 'm ' 
						+ CAST(DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) % 60 AS VARCHAR(50)) + 's'
				ELSE CAST(DATEDIFF(SECOND, ETL.OnPreExecuteTime, ETL.OnPostExecuteTime) % 60 AS VARCHAR(50)) + 's'
			END AS TaskRunTimeDisplay
		,E.StartTime AS PacakgeStartTime
		,E.EndTime AS PackageEndTime
		,DATEDIFF(MINUTE, E.StartTime, E.EndTime) AS PackageRunTimeMin
		,E.Status AS PackageStatus
	FROM [App].[Log_ExecutionLog] AS e WITH (NOLOCK)
	INNER JOIN [App].[Log_ExecutionTaskLog] AS ETL WITH (NOLOCK)
		ON E.ExecutionLogID = ETL.ExecutionLogID
	WHERE ETL.TaskName NOT IN ('SQL HandleOnBeginEvent','SQL HandleOnEndEvent')