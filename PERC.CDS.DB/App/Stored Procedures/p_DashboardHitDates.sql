

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <12/29/2021>
-- Description:	
-- Modifications:

-- =============================================
CREATE PROCEDURE [App].[p_DashboardHitDates]


--DECLARE
	@Period VARCHAR(100),
	@ReportCategory VARCHAR(1000)

--SET @Period='Fiscal Year'
--SET @Period='Quarter'; 
--SET @Period='Month';
--SET @ReportCategory='All CDS Reports';--,BupDirectory,CRISTAL,Definitions,EBP,HRF,PDE,PDSI,Pharm,REACH VET,SMI,SPPRITE,STORM'

AS
BEGIN
SET NOCOUNT ON

DECLARE @PeriodParam TABLE (Value VARCHAR(100))
INSERT @PeriodParam
SELECT Value FROM string_split(@Period,',')

DECLARE @ReportCategoryParam TABLE (Value VARCHAR(100))
INSERT @ReportCategoryParam
SELECT Value FROM string_split(@ReportCategory,',')

DROP TABLE IF EXISTS #GetMonths
SELECT ISNULL(h.Month,'') AS Month
      ,d.MonthName
	  ,ISNULL(h.FiscalQuarter,'') AS FiscalQuarter
      ,ISNULL(h.Year,'') AS Year
      ,ISNULL(h.FiscalYear,'') AS FiscalYear
      ,h.Period
	  ,CASE WHEN Period = 'Month' THEN CONCAT(d.MonthName,' ', h.Year)
		WHEN Period = 'Quarter' AND PeriodComplete = 0 THEN CONCAT('FY',h.FiscalYear,' Q',h.FiscalQuarter, ' - Partial')
		WHEN Period = 'Quarter' AND PeriodComplete = 1 THEN CONCAT('FY',h.FiscalYear,' Q',h.FiscalQuarter)
		WHEN Period = 'Fiscal Year' AND PeriodComplete = 0 THEN CONCAT('FY',h.FiscalYear, ' - Partial')
		WHEN Period = 'Fiscal Year' AND PeriodComplete = 1 THEN CONCAT('FY',h.FiscalYear)
		END AS Display
INTO #GetMonths
FROM [CDS].[DashboardHits] AS h WITH (NOLOCK)
LEFT JOIN Dim.Date AS d WITH (NOLOCK)
	ON h.Month = d.MonthofYear AND h.Year = d.CalendarYear
INNER JOIN @PeriodParam AS p
	ON h.Period = p.Value
INNER JOIN @ReportCategoryParam AS r
	ON h.ReportCategory = r.Value

SELECT DISTINCT * FROM #GetMonths h
ORDER BY h.Year DESC, h.Month DESC, h.FiscalYear DESC, h.FiscalQuarter DESC
 


END