

/********************************************************************************************************************
DESCRIPTION: CDS Dashboard hits
CREATED BY: Liam Mina

********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_DashboardHits]
--DECLARE
	@Period VARCHAR(100),
	@ReportCategory VARCHAR(1000),
	@Display VARCHAR(1000)
--SET @Period='Month'; SET @Display='November 2021'; SET @ReportCategory='CRISTAL'--,BupDirectory,CRISTAL,Definitions,EBP,HRF,PDE,PDSI,Pharm,REACH VET,SMI,SPPRITE,STORM'

AS
BEGIN
SET NOCOUNT ON

DECLARE @PeriodParam TABLE (Value VARCHAR(100))
INSERT @PeriodParam
SELECT Value FROM string_split(@Period,',')

DECLARE @ReportCategoryParam TABLE (Value VARCHAR(100))
INSERT @ReportCategoryParam
SELECT Value FROM string_split(@ReportCategory,',')

DECLARE @DisplayParam TABLE (Value VARCHAR(100))
INSERT @DisplayParam
SELECT Value FROM string_split(@Display,',')

SELECT DISTINCT CASE WHEN h.ReportCategory='Cerner' THEN 'Oracle Health QI' ELSE h.ReportCategory END AS ReportCategory
      ,ISNULL(h.ReportFileName,'Report Category') AS ReportFileName
      ,h.Users
      ,h.Hits
      ,h.Month
      ,h.FiscalQuarter
      ,h.Year
      ,h.FiscalYear
      ,h.Period
	  ,CONCAT(d.MonthName,' ', h.Year) AS Display
FROM [CDS].[DashboardHits] AS h WITH (NOLOCK)
INNER JOIN Dim.Date AS d WITH (NOLOCK)
	ON h.Month = d.MonthofYear AND h.Year = d.CalendarYear
INNER JOIN @PeriodParam AS p
	ON h.Period = p.Value
INNER JOIN @ReportCategoryParam AS rc
	ON h.ReportCategory = rc.Value
INNER JOIN @DisplayParam di
	ON CONCAT(d.MonthName,' ', h.Year) = di.Value
WHERE h.Period = 'Month'

UNION ALL

SELECT DISTINCT CASE WHEN h.ReportCategory='Cerner' THEN 'Oracle Health QI' ELSE h.ReportCategory END AS ReportCategory
      ,ISNULL(h.ReportFileName,'Report Category')
      ,h.Users
      ,h.Hits
      ,h.Month
      ,h.FiscalQuarter
      ,h.Year
      ,h.FiscalYear
      ,h.Period
	  ,CASE WHEN PeriodComplete=0 THEN CONCAT ('FY',h.FiscalYear,' Q',h.FiscalQuarter, ' - Partial')
		WHEN PeriodComplete=1 THEN  CONCAT('FY',h.FiscalYear,' Q',h.FiscalQuarter) END AS Display
FROM [CDS].[DashboardHits] AS h WITH (NOLOCK)
INNER JOIN @PeriodParam AS p
	ON h.Period = p.Value
INNER JOIN @ReportCategoryParam AS rc
	ON h.ReportCategory = rc.Value
INNER JOIN @DisplayParam AS di
	ON CONCAT('FY',h.FiscalYear,' Q',h.FiscalQuarter) = di.Value
	OR CONCAT('FY',h.FiscalYear,' Q',h.FiscalQuarter, ' - Partial') = di.Value
WHERE h.Period = 'Quarter'

UNION ALL

SELECT DISTINCT CASE WHEN h.ReportCategory='Cerner' THEN 'Oracle Health QI' ELSE h.ReportCategory END AS ReportCategory
      ,ISNULL(h.ReportFileName,'Report Category')
      ,h.Users
      ,h.Hits
      ,h.Month
      ,h.FiscalQuarter
      ,h.Year
      ,h.FiscalYear
      ,h.Period
	  ,CASE WHEN PeriodComplete=0 THEN CONCAT ('FY',h.FiscalYear, ' - Partial')
		WHEN PeriodComplete=1 THEN  CONCAT('FY',h.FiscalYear) END AS Display
FROM [CDS].[DashboardHits] AS h WITH (NOLOCK)
INNER JOIN @PeriodParam AS p
	ON h.Period = p.Value
INNER JOIN @ReportCategoryParam AS rc
	ON h.ReportCategory = rc.Value
INNER JOIN @DisplayParam AS di
	ON CONCAT('FY',h.FiscalYear) = di.Value
	OR CONCAT('FY',h.FiscalYear,' - Partial') = di.Value
WHERE h.Period = 'Fiscal Year'



END