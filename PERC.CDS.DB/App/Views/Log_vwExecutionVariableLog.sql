
CREATE VIEW App.[Log_vwExecutionVariableLog]
AS
SELECT E.ExecutionLogID
	,E.ParentExecutionLogID
	,VL.ExecutionVariableID
	,E.SSISDBServerExecutionID
	,E.PackageName
	,VL.VariableName, VL.VariableValue, VL.CaptureTime
	,E.StartTime AS PackageStartTime
	,E.EndTime AS PackageEndTime
	,DATEDIFF(MINUTE, E.StartTime, VL.CaptureTime) AS PackageRunTimeMin
	,E.Status AS PackageStatus
FROM    App.Log_ExecutionLog E
INNER JOIN App.Log_ExecutionVariableLog VL ON E.ExecutionLogID = VL.ExecutionLogID