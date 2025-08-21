
/********************************************************************************************************************
DESCRIPTION: Count dataset for SSRSMonitoringReport
TEST:
	EXEC [App].[Monitoring_SSRSCount]
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2021-07-16  EC Removed unneccessary fields ReportName and Environment; parameters ReportLocation and Environment
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_SSRSCount]
	 @GroupName VARCHAR(55)
	,@ObjectFileName VARCHAR(55) 
	,@StartDate DATE
	,@EndDate DATE
	,@Environment VARCHAR(50)
AS
BEGIN
SET NOCOUNT ON
 
SELECT ObjectFileName
	  ,ObjectPath
	  ,ReportLocation
	  ,GroupName
	  ,CountType
	  ,[Date]
	  ,Weekday
	  ,Week
	  ,Month
	  ,Year
	  ,FiscalYear
	  ,HitCount
	  ,UserCount
	  ,SuccessRate
	  ,RuntimeAvg
	  ,TimeDataRetrievalAvg
	  ,TimeProcessingAvg
	  ,TimeRenderingAvg
FROM [Maintenance].[MonitoringSSRSCount] 
WHERE (GroupName = @GroupName) 
	AND (ObjectFileName = @ObjectFileName) 
	AND ([Date] BETWEEN @StartDate AND @EndDate) 
	AND (CountType = 'DAY') 
	AND Environment = @Environment

END