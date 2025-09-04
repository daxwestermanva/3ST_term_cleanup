
/********************************************************************************************************************
DESCRIPTION: Status dataset for SSRSMonitoringReport and SSRSMonitoringLastAccess
TEST:
	EXEC [App].[[Monitoring_SSRSLogStatus]   'Production'
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2021-07-16  EC Removed unneccessary parameter Environment
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_SSRSLogStatus]
	 @GroupName VARCHAR(55)
	,@ObjectFileName VARCHAR(55) 
	,@StartDate DATETIME
	,@EndDate DATETIME
	,@Environment VARCHAR(50)

AS
BEGIN
SET NOCOUNT ON

DECLARE @Groups TABLE (GroupName VARCHAR(55))
  -- Add values to the table
INSERT @Groups SELECT value FROM string_split(@GroupName, ',')

SELECT Status
	  ,COUNT(Status) AS StatusCount
FROM [Maintenance].[vwMonitoringSSRSLog]
WHERE ObjectFileName = @ObjectFileName
	AND (Day BETWEEN @StartDate AND @EndDate)
	AND Environment = @Environment
GROUP BY Status
ORDER BY StatusCount DESC

END