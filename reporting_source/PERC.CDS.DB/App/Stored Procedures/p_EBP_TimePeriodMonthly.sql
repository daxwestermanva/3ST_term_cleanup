
-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/29/2017
-- Description: Data Set for the EBPTemplates_MonthlySummary report parameter (TimePeriod).
-- =============================================
-- EXEC [App].[p_EBP_TimePeriodMonthly] 
-- =============================================
CREATE PROCEDURE [App].[p_EBP_TimePeriodMonthly]  
AS
BEGIN	
SET NOCOUNT ON

DECLARE @maxdate date = (Select max(date) from EBP.FacilityMonthly )
--PRINT @maxdate

SELECT TimePeriod
	  ,[Date],TimePeriodType
 FROM (SELECT * FROM(
	SELECT DISTINCT Month + ' ' + Year AS TimePeriod, Date,TimePeriodType='Month' 
	FROM  [EBP].[FacilityMonthly]
	UNION
	SELECT DISTINCT  'Qtr ' + Date2 AS TimePeriod, date ,TimePeriodType='Quarter' 
	FROM [EBP].[QuarterlySummary]
	UNION
	SELECT 'Last 12 Months',Date,'YTD'
	FROM EBP.Clinician
	WHERE ReportingPeriod like 'YTD'
  ) as a
WHERE Date > DateAdd(m,-24,@maxdate) 
) as b
ORDER BY Date DESC, TimePeriodType desc

END