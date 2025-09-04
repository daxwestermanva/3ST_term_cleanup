
/********************************************************************************************************************
DESCRIPTION: GroupName parameter for SSRSMonitoringReport
TEST:
	EXEC [App].[p_Monitoring_SSRSGroupName] 'Production'
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2021-07-16  EC Removed unneccessary parameters ReportLocation and Environment
********************************************************************************************************************/

CREATE PROCEDURE [App].[p_Monitoring_SSRSGroupName]

AS

BEGIN

SET NOCOUNT ON
 
SELECT DISTINCT GroupName
FROM [Maintenance].[MonitoringSSRSCount]
WHERE GroupName <> ''
ORDER BY GroupName
END