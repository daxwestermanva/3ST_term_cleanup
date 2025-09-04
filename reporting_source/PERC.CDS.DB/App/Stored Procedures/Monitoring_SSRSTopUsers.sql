
/********************************************************************************************************************
DESCRIPTION: LogTopUsers dataset for SSRSMonitoringReport
TEST:
	EXEC [App].[Monitoring_SSRSDayCounts] 'Production'
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2021-07-16  EC Removed unneccessary parameter Environment
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_SSRSTopUsers]
	 @ObjectFileName VARCHAR(55) 
	,@StartDate DATE
	,@EndDate DATE
	,@Environment VARCHAR(50)
AS

BEGIN

SET NOCOUNT ON
 
SELECT TOP 20
	 UserName
	,COUNT(UserName) AS UserNameCount
FROM [Maintenance].[vwMonitoringSSRSLog]
WHERE ObjectFileName = @ObjectFileName
	AND Day BETWEEN @StartDate AND @EndDate
	AND Environment = @Environment
GROUP BY  UserName
ORDER BY UserNameCount DESC

END