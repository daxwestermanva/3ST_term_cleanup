
/********************************************************************************************************************
DESCRIPTION: ReportLocation parameter for SSRSMonitoringReport
TEST:
	EXEC [App].[p_Monitoring_SSRSGroupName] 'OMHSP_PsychPharm','Production',
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
********************************************************************************************************************/

CREATE PROCEDURE [App].[p_Monitoring_SSRSLocation]

AS

BEGIN

SET NOCOUNT ON

SELECT DISTINCT ReportLocation
FROM [Maintenance].[MonitoringSSRSCount] --App.OMHSP_PERC_Library_Dflt_ReportDayCounts
ORDER BY ReportLocation
 
END