
/********************************************************************************************************************
DESCRIPTION: Status dataset for SSRSMonitoringReport
TEST:
	EXEC [App].[Monitoring_SSRSDayCounts]
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2021-07-16  EC Removed unneccessary parameters ReportLocation and Environment
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_SSRSDayCounts]
	 @GroupName VARCHAR(55)
	,@ObjectFileName VARCHAR(55) 
	,@StartDate DATE
	,@EndDate DATE
	,@Environment VARCHAR(50)
AS

BEGIN

SET NOCOUNT ON
 
SELECT SUM(HitCount) AS HitCount
	  ,SUM(UserCount) AS UserCount
	  ,[Date] AS EventDate
FROM [Maintenance].[MonitoringSSRSCount] 
WHERE GroupName = @GroupName 
	AND [Date] BETWEEN @StartDate AND @EndDate
	AND ObjectFileName = @ObjectFileName
	AND Environment = @Environment
GROUP BY [Date]

END