


CREATE VIEW [Maintenance].[vwMonitoringSSRSStatistics] AS
-- Pivot table that rotates the vertical table into a horizontal table
-- For each report we get day average (YAvg), project value (Projected) and the amount of 
-- standard deviation (Sigma) for TimeDataRetrieval, TimeProcessing, TimeRendering and Runtime
SELECT DISTINCT
	lr.ObjectFileName
	,lr.ReportLocation
	,lr.Environment
	,lr.HitCount
	,lr.UserCount
	,lr.DaysSpan
	,YAvg.TimeDataRetrievalAvg
	,Projected.TimeDataRetrievalAvg AS TimeDataRetrievalProjected
	,Sigma.TimeDataRetrievalAvg AS TimeDataRetrievalSigma
	,YAvg.TimeProcessingAvg
	,Projected.TimeProcessingAvg AS TimeProcessingProjected
	,Sigma.TimeProcessingAvg AS TimeProcessingSigma
	,YAvg.TimeRenderingAvg
	,Projected.TimeRenderingAvg AS TimeRenderingProjected
	,Sigma.TimeRenderingAvg AS TimeRenderingSigma
	,YAvg.RuntimeAvg
	,Projected.RuntimeAvg AS RuntimeProjected
	,Sigma.RuntimeAvg AS RuntimeSigma
FROM Maintenance.MonitoringSSRSLinearRegression AS lr
INNER JOIN
	(SELECT * FROM (
		SELECT
			ObjectFileName
			,ReportLocation
			,Environment
			,ColumnName
			,YAvg
			,DaysSpan
		FROM Maintenance.MonitoringSSRSLinearRegression
	) AS m
	PIVOT (
		AVG(YAvg) FOR ColumnName IN ([TimeDataRetrievalAvg], [TimeProcessingAvg], [TimeRenderingAvg], [RuntimeAvg])
	) AS a) AS YAvg
ON lr.ObjectFileName = YAvg.ObjectFileName
	AND lr.ReportLocation = YAvg.ReportLocation
	AND lr.Environment = YAvg.Environment
	AND lr.DaysSpan = YAvg.DaysSpan
INNER JOIN
	(SELECT * FROM (
		SELECT
			ObjectFileName
			,ReportLocation
			,Environment
			,ColumnName
			,Projected
			,DaysSpan
		FROM Maintenance.MonitoringSSRSLinearRegression
	) AS m
	PIVOT (
		AVG(Projected) FOR ColumnName IN ([TimeDataRetrievalAvg], [TimeProcessingAvg], [TimeRenderingAvg], [RuntimeAvg])
	) AS a) AS Projected
ON lr.ObjectFileName = Projected.ObjectFileName
	AND lr.ReportLocation = Projected.ReportLocation
	AND lr.Environment = Projected.Environment
	AND lr.DaysSpan = Projected.DaysSpan
INNER JOIN
	(SELECT * FROM (
		SELECT
			ObjectFileName
			,ReportLocation
			,Environment
			,ColumnName
			,Sigma
			,DaysSpan
		FROM Maintenance.MonitoringSSRSLinearRegression
	) AS m
	PIVOT (
		AVG(Sigma) FOR ColumnName IN ([TimeDataRetrievalAvg], [TimeProcessingAvg], [TimeRenderingAvg], [RuntimeAvg])
	) AS a) AS Sigma
ON lr.ObjectFileName = Sigma.ObjectFileName
	AND lr.ReportLocation = lr.ReportLocation
	AND lr.Environment = Sigma.Environment
	AND lr.DaysSpan = Sigma.DaysSpan