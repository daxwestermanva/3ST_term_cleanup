




CREATE VIEW [Maintenance].[vwMonitoringSSRSStatus] AS
-- Join the monitoring counts table with the statistics table to find the last day accessed report status.
-- This view could be shortend since not all values are currently used.
SELECT
	mcounts.ObjectFileName
	,mcounts.ObjectPath
	,mcounts.ReportLocation
	,mcounts.Environment
	,mcounts.GroupName
	,mcounts.Date AS LastDayAccessed
	,mcounts.HitCount
	,mcounts.UserCount
	,mcounts.SuccessRate
	,mstats.DaysSpan
	,mstats.HitCount AS HitTotalCount
	,mstats.UserCount AS UserTotalCount
	--*************TimeDataRetrieval***************
	,mcounts.TimeDataRetrievalAvg AS TimeDataRetrievalDayAvg
	,mstats.TimeDataRetrievalAvg
	,mstats.TimeDataRetrievalProjected
	,CASE WHEN mstats.TimeDataRetrievalProjected <> 0
		THEN (mcounts.TimeDataRetrievalAvg - mstats.TimeDataRetrievalProjected) / mstats.TimeDataRetrievalProjected
		ELSE 0
	END AS TimeDataRetrievalProjectedDeviation
	,mstats.TimeDataRetrievalSigma AS TimeDataRetrievalStandardDeviation
	,CASE WHEN mstats.TimeDataRetrievalSigma <> 0
		THEN (mcounts.TimeDataRetrievalAvg - mstats.TimeDataRetrievalAvg) / mstats.TimeDataRetrievalSigma
		ELSE 0
	END AS TimeDataRetrievalStandardDeviationDelta
	--*************TimeProcessing******************
	,mcounts.TimeProcessingAvg AS TimeProcessingDayAvg
	,mstats.TimeProcessingAvg
	,mstats.TimeProcessingProjected
	,CASE WHEN mstats.TimeProcessingProjected <> 0
		THEN (mcounts.TimeProcessingAvg - mstats.TimeProcessingProjected) / mstats.TimeProcessingProjected
		ELSE 0
	END AS TimeProcessingProjectedDeviation
	,mstats.TimeProcessingSigma AS TimeProcessingStandardDeviation
	,CASE WHEN mstats.TimeProcessingSigma <> 0
		THEN (mcounts.TimeProcessingAvg - mstats.TimeProcessingAvg) / mstats.TimeProcessingSigma
		ELSE 0
	END AS TimeProcessingStandardDeviationDelta
	--************TimeRendering********************
	,mcounts.TimeRenderingAvg AS TimeRenderingDayAvg
	,mstats.TimeRenderingAvg
	,mstats.TimeRenderingProjected
	,CASE WHEN mstats.TimeRenderingProjected <> 0
		THEN (mcounts.TimeRenderingAvg - mstats.TimeRenderingProjected) / mstats.TimeRenderingProjected
		ELSE 0
	END AS TimeRenderingProjectedDeviation
	,mstats.TimeRenderingSigma AS TimeRenderingStandardDeviation
	,CASE WHEN mstats.TimeRenderingSigma <> 0
		THEN (mcounts.TimeRenderingAvg - mstats.TimeRenderingAvg) / mstats.TimeRenderingSigma
		ELSE 0
	END AS TimeRenderingStandardDeviationDelta
	--**************Runtime****************************
	,mcounts.RuntimeAvg AS RuntimeDayAvg
	,mstats.RuntimeAvg
	,mstats.RuntimeProjected
	,CASE WHEN mstats.RuntimeProjected <> 0
		THEN (mcounts.RuntimeAvg - mstats.RuntimeProjected) / mstats.RuntimeProjected
		ELSE 0
	END AS RuntimeProjectedDeviation
	,mstats.RuntimeSigma AS RuntimeStandardDeviation
	,CASE WHEN mstats.RuntimeSigma <> 0
		THEN (mcounts.RuntimeAvg - mstats.RuntimeAvg) / mstats.RuntimeSigma
		ELSE 0
	END AS RuntimeStandardDeviationDelta
FROM Maintenance.MonitoringSSRSCount AS mcounts
	INNER JOIN (
		SELECT
			ObjectFileName, ReportLocation, Environment, MAX(Date) AS Date
		FROM Maintenance.MonitoringSSRSCount WHERE CountType='DAY' AND Weekday BETWEEN 2 AND 6 -- We only care about weekdays and need to exclude the weekend
		GROUP BY ObjectFileName, ReportLocation, Environment
	) mcounts2
		ON mcounts.ObjectFileName = mcounts2.ObjectFileName
			AND mcounts.ReportLocation = mcounts2.ReportLocation
			AND mcounts.Environment = mcounts2.Environment
			AND mcounts.Date = mcounts2.Date
			AND mcounts.CountType='DAY' -- We only want to evaluate DAY counts.
	INNER JOIN Maintenance.vwMonitoringSSRSStatistics AS mstats
		ON mcounts.ObjectFileName = mstats.ObjectFileName
			AND mcounts.ReportLocation = mstats.ReportLocation
			AND mcounts.Environment = mstats.Environment