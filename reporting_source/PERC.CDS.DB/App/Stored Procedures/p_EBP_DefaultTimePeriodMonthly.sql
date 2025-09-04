
-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/29/2017
-- Description: Data Set for the EBPTemplates_MonthlySummary report parameter (DefaultTimePeriod).
-- =============================================
-- EXEC [App].[p_EBP_DefaultTimePeriodMonthly] 
-- =============================================
CREATE PROCEDURE [App].[p_EBP_DefaultTimePeriodMonthly]  
AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT TOP 6 Month + ' ' + Year as TimePeriod, Date 
FROM  [EBP].[FacilityMonthly]
ORDER BY Date DESC

END