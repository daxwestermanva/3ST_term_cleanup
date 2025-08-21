
-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/29/2017
-- Description: Data Set for the EBPTemplates_Clinician report parameter (Month).
-- =============================================
-- EXEC [App].[p_EBP_Month] 
-- =============================================
CREATE PROCEDURE [App].[p_EBP_Month]

AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT CASE WHEN b.ReportingPeriod LIKE 'YTD' THEN 'Last 12 Months' ELSE b.ReportingPeriod END AS ReportingPeriod
	,ReportingPeriodID
	,ReportingPeriodShort
FROM EBP.Clinician AS a 
INNER JOIN App.EBP_ReportingPeriodID AS b ON a.ReportingPeriod=b.ReportingPeriod
ORDER BY ReportingPeriodID desc

END