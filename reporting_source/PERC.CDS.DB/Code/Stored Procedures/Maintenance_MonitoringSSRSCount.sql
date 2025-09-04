
/* =============================================
-- Author:		Justin Chambers
-- Create date: 9/9/2019
-- Description:	Generate all the counts used for Reports each DAY and Groups for each MONTH and FISCAL_YEAR.
-- Modifications:
	2019-09-27	RAS	Added logging. Updated table name for UsersToOmit
	2019-09-30	RAS	Renamed SP. Added grouping sets. Changed column Day(datetime2) to Date(date)
	2021-07-16  Elena Updating to point to new reports and removing unneccessary fields
	2022-06-08	LM	Added Test report data
-- =============================================
*/

CREATE PROCEDURE [Code].[Maintenance_MonitoringSSRSCount] AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Maintenance_MonitoringSSRSCount','Execution of SP Code.Maintenance_MonitoringSSRSCount'
	
	-- Compute counts for Reports 
	DROP TABLE IF EXISTS #StageMonitoringSSRSCount;
	SELECT ObjectFileName
		  ,ObjectPath
		  ,ReportLocation
		  ,Environment
		  ,GroupName
		  ,CASE WHEN [Day] IS NOT NULL THEN 'DAY' 
				WHEN FiscalYear IS NULL THEN 'MONTH' 
				ELSE 'FISCAL_YEAR' 
				END AS CountType
		  ,CASE WHEN [Day] IS NOT NULL THEN convert(date,[Day])
				WHEN [Month] IS NOT NULL THEN EOMONTH(DATEFROMPARTS([Year],[Month],1))
				END AS [Date]
		  ,ISNULL([Weekday],0) [Weekday]
		  ,ISNULL([Week],0) [Week]
		  ,[Month]
		  ,[Year]
		  ,FiscalYear
		  ,COUNT(*) AS HitCount
		  ,COUNT(DISTINCT UserName) AS UserCount
		  ,AVG(CAST(StatusSuccess AS FLOAT)) AS SuccessRate
		  ,AVG(CAST(TimeDataRetrieval AS BIGINT)) + AVG(CAST(TimeProcessing AS BIGINT)) + AVG(CAST(TimeRendering AS BIGINT)) AS RuntimeAvg
		  ,AVG(CAST(TimeDataRetrieval AS BIGINT)) AS TimeDataRetrievalAvg
		  ,AVG(CAST(TimeProcessing AS BIGINT)) AS TimeProcessingAvg
		  ,AVG(CAST(TimeRendering AS BIGINT)) AS TimeRenderingAvg
	INTO #StageMonitoringSSRSCount
	FROM [Maintenance].[vwMonitoringSSRSLog] WITH (NOLOCK)
	WHERE (ObjectPath like 'RVS/OMHSP_PERC/SSRS/Production/CDS/%' and (UserName NOT IN (SELECT UserName FROM Config.WritebackUsersToOmit WITH (NOLOCK))))
		OR (ObjectPath like 'RVS/OMHSP_PERC/SSRS/Test/CDS/%')
	GROUP BY Grouping Sets (
		--Counts for reports on daily basis
		 (ObjectPath,ReportLocation,Environment,ObjectFileName,GroupName,FiscalYear,Year,Month,Week,Day,Weekday)
		--Counts for reports on monthly basis
		,(ObjectPath,ReportLocation,Environment,ObjectFileName,GroupName,Year,Month)
		--Counts for reports groups on a monthly basis
		,(			 ReportLocation,Environment,GroupName,Year,Month)
		--Counts for reports groups on a fiscal year basis
		,(			 ReportLocation,Environment,GroupName,FiscalYear)
		);

	EXEC [Maintenance].[PublishTable] 'Maintenance.MonitoringSSRSCount','#StageMonitoringSSRSCount'
	

	--Compute counts for all PERC reports on a Fiscal Year basis.

	INSERT INTO [Maintenance].[MonitoringSSRSCount]
	
	SELECT '' AS ObjectFileName
		  ,'' AS ObjectPath
		  ,'' AS ReportLocation
		  ,'' AS Environment
		  ,'' AS GroupName
		  ,'FISCAL_YEAR' AS CountType
		  ,NULL AS [Date]
		  ,0 AS Weekday
		  ,0 AS Week
		  ,0 AS Month
		  ,0 AS Year
		  ,FiscalYear
		  ,COUNT(*) AS HitCount
		  ,COUNT(DISTINCT UserName) AS UserCount
		  ,0 AS SuccessRate
		  ,AVG(CAST(TimeDataRetrieval AS BIGINT)) + AVG(CAST(TimeProcessing AS BIGINT)) + AVG(CAST(TimeRendering AS BIGINT)) AS RuntimeAvg
		  ,AVG(CAST(TimeDataRetrieval AS BIGINT)) AS TimeDataRetrievalAvg
		  ,AVG(CAST(TimeProcessing AS BIGINT)) AS TimeProcessingAvg
		  ,AVG(CAST(TimeRendering AS BIGINT)) AS TimeRenderingAvg
	FROM [Maintenance].[vwMonitoringSSRSLog] WITH (NOLOCK)
	WHERE GroupName NOT IN ('Home','Other','Monitoring') 
	AND Environment IN ('Production','Test')
	GROUP BY FiscalYear;

EXEC [Log].[ExecutionEnd]

END;