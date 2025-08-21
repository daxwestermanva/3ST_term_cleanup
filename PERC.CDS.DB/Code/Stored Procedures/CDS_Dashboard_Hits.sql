-- =============================================
-- Author:		Liam Mina
-- Create date: 8/7/2019
-- Description:	Get count of hits and users to the CDS dashboards by month
-- Modifications:
	--2021-07-01	LM	Pointed to new report paths after migration of SSRS reports
	--2024-03-05	LM	Add PBI reports
-- =============================================
CREATE PROCEDURE [Code].[CDS_Dashboard_Hits]
AS
BEGIN

DECLARE @ForceUpdate BIT = 0

DECLARE @EndDateMonth DATETIME
SET @EndDateMonth = dateadd(day,-1,dateadd(month,datediff(month,0,GetDate()),0))
PRINT @EndDateMonth

DECLARE @BeginDateMonth DATETIME
SET @BeginDateMonth = dateadd(month,datediff(month,0,GetDate())-1,0)
PRINT @begindateMonth

DROP TABLE IF EXISTS #Dates
SELECT DISTINCT MonthOfYear, CalendarYear, FiscalQuarter, FiscalYear
INTO #Dates 
FROM [Dim].[Date] d
WHERE d.Date > @BeginDateMonth and d.Date < @EndDateMonth

DECLARE @BeginDateQuarter DATETIME
SET @BeginDateQuarter = (SELECT MIN(Date) FROM [Dim].[Date] d
						INNER JOIN #Dates d2 ON d.FiscalQuarter = d2.FiscalQuarter AND d.FiscalYear = d2.FiscalYear)
PRINT @BeginDateQuarter

DECLARE @EndDateQuarter DATETIME
SET @EndDateQuarter = (SELECT MAX(Date) FROM [Dim].[Date] d
						INNER JOIN #Dates d2 ON d.FiscalQuarter = d2.FiscalQuarter AND d.FiscalYear = d2.FiscalYear)
PRINT @EndDateQuarter

DECLARE @BeginDateYear DATETIME
SET @BeginDateYear = (SELECT MIN(Date) FROM [Dim].[Date] d
						INNER JOIN #Dates d2 ON d.FiscalYear = d2.FiscalYear)
PRINT @BeginDateYear

DECLARE @EndDateYear DATETIME
SET @EndDateYear = (SELECT MAX(Date) FROM [Dim].[Date] d
						INNER JOIN #Dates d2 ON d.FiscalYear = d2.FiscalYear)
PRINT @EndDateYear


/*************************************************************************************/
-- Find existing data for release date(s) of interest
DROP TABLE IF EXISTS #existingdata
SELECT DISTINCT Month,Year
INTO #existingdata
FROM [CDS].[DashboardHits] h
--INNER JOIN #Dates d
WHERE (DateFromParts(h.Year,h.Month,1) between @BeginDateMonth AND @EndDateMonth AND Period='Month')

--Drop extra/summary rows that are generated in pivot table for PowerBI reports
DELETE FROM CDS.DashboardHits_PBI_Stage WHERE UserName=''

--End procedure if there is pre-existing data and @ForceUpdate is not set to 1
IF @ForceUpdate=0 
	AND EXISTS (SELECT * FROM #existingdata)
BEGIN
	DECLARE @msg0 varchar(250) = 'Data for most recent month already exists in CDS.DashboardHits. Run SP with @ForceUpdate=1 to overwrite existing data.'
	PRINT @msg0
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg0

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END 

--Check for available data on PBI reports
IF (SELECT COUNT(*) FROM CDS.DashboardHits_PBI_Stage a
		INNER JOIN #Dates d ON a.Year = d.CalendarYear AND a.Month = d.MonthOfYear) =0
BEGIN
	DECLARE @msg1 varchar(250) = 'PBI Data for current month is not yet populated in CDS.DashboardHits_PBI_Stage.'
	PRINT @msg1
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg1

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END 

--Delete pre-existing data if force update is set 
IF @ForceUpdate=1 
BEGIN
	DELETE h
	FROM [CDS].[DashboardHits] h
	INNER JOIN #existingdata d on 
		h.Month=d.Month
		AND h.Year=d.Year
	
	DECLARE @msg2 varchar(250) = 'Force update executed - pre-existing data will be deleted.'
	EXEC [Log].[Message] 'Information','Overwriting data'
		,@msg2
END
	EXEC [Log].[ExecutionEnd] 

/***************************************************************/


--Get counts for hits/users to each invidiual report
DROP TABLE IF EXISTS #GetReports
SELECT DISTINCT 
	r.ReportFileName
	,CASE WHEN r.ReportFileName LIKE '%CaringLetters%' THEN 'Caring Letters'
		WHEN r.ReportFileName like '%HRF%' OR r.ReportFileName LIKE '%PRF%' THEN 'HRF'
		WHEN r.ReportFileName like '%SPPRITE%' THEN 'SPPRITE'
		WHEN r.ReportPath like '%RV' THEN 'REACH VET'
		ELSE SubString(r.ReportPath,36,15) END AS ReportCategory
	,count(DISTINCT l.UserName) AS Users
	,count(DISTINCT l.TimeStart) AS Hits 
	,month(l.TimeStart) AS Month
	,year(l.TimeStart) AS Year
	,CASE WHEN month(l.TimeStart) in (10,11,12) THEN year(l.TimeStart)+1
		ELSE year(l.TimeStart) END AS FY
	,l.UserName
	,d.FiscalQuarter
	,d.FiscalYear
INTO #GetReports
FROM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog] AS l WITH (NOLOCK)
INNER JOIN [PDW].[BISL_SSRSLog_DOEx_Reports] AS r WITH (NOLOCK) 
	ON l.ReportKey = r.ReportKey
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK) 
	ON l.DateKey = d.DateSID
WHERE r.ReportPath IN 
	('RVS/OMHSP_PERC/SSRS/Production/CDS/BHIP'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/Cerner'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/ClinicalAdmin'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/CRISTAL'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/Definitions'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/EBP'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/PDE'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/PDSI'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/Pharm' 
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/RV'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/SMI'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/SP'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/STORM'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/SUD'
	)
AND UserName NOT IN (SELECT UserName FROM Config.WritebackUsersToOmit AS z)
AND ReportFileName NOT LIKE '%writeback%'
AND CAST(l.TimeStart AS date) <= @EndDateMonth 
AND ReportAction in ('Render','DrillThrough','Execute')
GROUP BY ReportFileName, ReportPath, month(TimeStart), year(TimeStart), FiscalQuarter, FiscalYear, UserName

--Add data from PBI reports
INSERT INTO #GetReports
SELECT DISTINCT a.Report
	,CASE WHEN a.Report = 'SBOSR' THEN 'SBOSR'
		WHEN a.Report like 'BHIP%' OR a.Report LIKE 'MHTC%' THEN 'BHIP'
		WHEN a.Report IN ('IDU_Triage','TobaccoUD_SummaryStats') THEN 'SUD'
		WHEN a.Report = 'CSRE_Patients' THEN 'Cerner'
		WHEN a.Report = 'Community Care Overdose' THEN 'STORM'
		WHEN a.Report = 'COMPACT' THEN 'COMPACT'
		WHEN a.Report IN ('CaseFactors','Clincal_Insights') THEN 'Case Factors'
		END AS ReportCategory
	,Users=1
	,a.Hits 
	,a.Month
	,a.Year
	,CASE WHEN a.Month in (10,11,12) THEN a.Year+1
		ELSE a.Year END AS FY
	,a.UserName
	,d.FiscalQuarter
	,d.FiscalYear
FROM CDS.DashboardHits_PBI_Stage a WITH (NOLOCK)
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK) 
	ON a.Month = d.MonthOfYear AND a.Year = d.CalendarYear
LEFT JOIN Config.WritebackUsersToOmit c WITH (NOLOCK)
	ON c.UserName LIKE CONCAT('%',a.UserName)
WHERE a.UserName IS NOT NULL AND c.UserName IS NULL
AND DATEFROMPARTS(a.Year,a.Month,1) < @EndDateMonth


--Get monthly counts by report category/dashboard project
DROP TABLE IF EXISTS #ReportCategoriesMonthly
SELECT DISTINCT 
	a.ReportCategory
	,ReportFileName = CAST(NULL AS varchar)
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,a.Month
	,FiscalQuarter=NULL
	,a.Year
	,FiscalYear=NULL
	,Period='Month'
	,PeriodComplete = 1
INTO #ReportCategoriesMonthly
FROM #GetReports AS a
INNER JOIN #Dates AS d ON a.Month = d.MonthOfYear AND a.Year = d.CalendarYear
WHERE (DateFromParts(a.Year, a.Month, 1)) BETWEEN @BeginDateMonth AND @EndDateMonth
GROUP BY a.ReportCategory, a.Month, a.Year

DROP TABLE IF EXISTS #ReportCategoriesQuarter
SELECT DISTINCT 
	a.ReportCategory
	,ReportFileName = CAST(NULL AS varchar)
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,Month=NULL
	,b.FiscalQuarter
	,Year=NULL
	,b.FiscalYear
	,Period='Quarter'
	,CASE WHEN GETDATE() > @EndDateQuarter THEN 1 ELSE 0 END AS PeriodComplete
INTO #ReportCategoriesQuarter
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalQuarter=b.FiscalQuarter AND a.FiscalYear=b.FiscalYear
WHERE DateFromParts(a.Year, a.Month, 1) BETWEEN @BeginDateQuarter AND @EndDateQuarter
--AND GETDATE() > @EndDateQuarter
GROUP BY a.ReportCategory, b.FiscalYear, b.FiscalQuarter

DROP TABLE IF EXISTS #ReportCategoriesFiscalYear
SELECT DISTINCT 
	a.ReportCategory
	,ReportFileName = CAST(NULL AS varchar)
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,Month=NULL
	,FiscalQuarter=NULL
	,Year=NULL
	,b.FiscalYear
	,Period='Fiscal Year'
	,CASE WHEN GETDATE() > @EndDateYear THEN 1 ELSE 0 END AS PeriodComplete
INTO #ReportCategoriesFiscalYear
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalYear=b.FiscalYear
WHERE (DateFromParts(a.Year, a.Month, 1)) BETWEEN @BeginDateYear AND @EndDateYear
--AND GETDATE() > @EndDateYear
GROUP BY a.ReportCategory, b.FiscalYear

--Get counts by each individual dashboard
DROP TABLE IF EXISTS #ReportsMonthly
SELECT DISTINCT 
	a.ReportCategory
	,a.ReportFileName
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,a.Month
	,FiscalQuarter=NULL
	,a.Year
	,FiscalYear=NULL
	,Period='Month'
	,PeriodComplete = 1
INTO #ReportsMonthly
FROM #GetReports AS a
WHERE (DateFromParts(a.Year, a.Month, 1)) between @BeginDateMonth AND @EndDateMonth
AND GETDATE() > @EndDateMonth
GROUP BY a.ReportFileName, a.ReportCategory, a.Month, a.Year

DROP TABLE IF EXISTS #ReportsQuarter
SELECT DISTINCT 
	a.ReportCategory
	,a.ReportFileName
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,Month=NULL
	,b.FiscalQuarter
	,Year=NULL
	,b.FiscalYear
	,Period='Quarter'
	,CASE WHEN GETDATE() > @EndDateQuarter THEN 1 ELSE 0 END AS PeriodComplete
INTO #ReportsQuarter
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalQuarter=b.FiscalQuarter AND a.FiscalYear=b.FiscalYear
WHERE (DateFromParts(a.Year, a.Month, 1)) BETWEEN @BeginDateQuarter AND @EndDateQuarter
--AND GETDATE() > @EndDateQuarter
GROUP BY a.ReportFileName, a.ReportCategory, b.FiscalYear, b.FiscalQuarter

DROP TABLE IF EXISTS #ReportsFiscalYear
SELECT DISTINCT 
	a.ReportCategory
	,a.ReportFileName
	,Users=Count(DISTINCT a.UserName)
	,Hits=Sum(a.Hits)
	,Month=NULL
	,FiscalQuarter=NULL
	,Year=NULL
	,b.FiscalYear
	,Period='Fiscal Year'
	,CASE WHEN GETDATE() > @EndDateYear THEN 1 ELSE 0 END AS PeriodComplete
INTO #ReportsFiscalYear
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalYear=b.FiscalYear
WHERE (DateFromParts(a.Year, a.Month, 1)) BETWEEN @BeginDateYear AND @EndDateYear
--AND GETDATE() > @EndDateYear
GROUP BY a.ReportFileName, a.ReportCategory, b.FiscalYear

--Get total counts (not broken out by category)
DROP TABLE IF EXISTS #AllReportsMonthly
SELECT DISTINCT 
	ReportCategory = 'All CDS Reports'
	,ReportFileName = CAST(NULL AS varchar)
	,Users = Count(DISTINCT a.UserName)
	,Hits = Sum(a.Hits)
	,a.Month
	,FiscalQuarter = NULL
	,a.Year
	,FiscalYear = NULL
	,Period = 'Month'
	,PeriodComplete = 1
INTO #AllReportsMonthly
FROM #GetReports AS a
WHERE (DateFromParts(a.Year, a.Month, 1)) BETWEEN @BeginDateMonth AND @EndDateMonth
AND GETDATE() > @EndDateMonth
GROUP BY a.Month, a.Year

DROP TABLE IF EXISTS #AllReportsQuarter
SELECT DISTINCT 
	ReportCategory = 'All CDS Reports'
	,ReportFileName = CAST(NULL AS varchar)
	,Users = Count(DISTINCT a.UserName)
	,Hits = Sum(a.Hits)
	,Month = NULL
	,b.FiscalQuarter
	,Year = NULL
	,b.FiscalYear
	,Period = 'Quarter'
	,CASE WHEN GETDATE() > @EndDateQuarter THEN 1 ELSE 0 END AS PeriodComplete
INTO #AllReportsQuarter
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalQuarter=b.FiscalQuarter AND a.FiscalYear=b.FiscalYear
WHERE (DateFromParts(a.Year, a.Month, 1)) between @BeginDateQuarter AND @EndDateQuarter
--AND GETDATE() > @EndDateQuarter
GROUP BY b.FiscalYear, b.FiscalQuarter

DROP TABLE IF EXISTS #AllReportsFiscalYear
SELECT DISTINCT 
	ReportCategory = 'All CDS Reports'
	,ReportFileName = CAST(NULL AS varchar)
	,Users = Count(DISTINCT a.UserName)
	,Hits = Sum(a.Hits)
	,Month = NULL
	,FiscalQuarter = NULL
	,Year = NULL
	,b.FiscalYear
	,Period = 'Fiscal Year'
	,CASE WHEN GETDATE() > @EndDateYear THEN 1 ELSE 0 END AS PeriodComplete
INTO #AllReportsFiscalYear
FROM #GetReports AS a
INNER JOIN #Dates AS b ON a.FiscalYear=b.FiscalYear
WHERE (DateFromParts(a.Year, a.Month, 1)) between @BeginDateYear AND @EndDateYear
--AND GETDATE() > @EndDateYear
GROUP BY b.FiscalYear


DROP TABLE IF EXISTS #ReportHits
SELECT *
INTO #ReportHits
FROM #ReportCategoriesMonthly
UNION ALL 
SELECT * FROM #ReportCategoriesQuarter
UNION ALL 
SELECT * FROM #ReportCategoriesFiscalYear
UNION ALL 
SELECT * FROM #ReportsMonthly
UNION ALL 
SELECT * FROM #ReportsQuarter
UNION ALL 
SELECT * FROM #ReportsFiscalYear
UNION ALL 
SELECT * FROM #AllReportsMonthly
UNION ALL 
SELECT * FROM #AllReportsQuarter
UNION ALL 
SELECT * FROM #AllReportsFiscalYear
ORDER BY Year, Month

DELETE FROM [CDS].[DashboardHits]
WHERE PeriodComplete = 0

INSERT INTO [CDS].[DashboardHits] (
	ReportCategory
	,ReportFileName
	,Users
	,Hits
	,Month
	,FiscalQuarter
	,Year
	,FiscalYear
	,Period
	,PeriodComplete)
SELECT ReportCategory
	,ReportFileName
	,Users
	,Hits
	,Month
	,FiscalQuarter
	,Year
	,FiscalYear
	,Period
	,PeriodComplete
FROM #ReportHits

DECLARE @rows varchar(10) = (SELECT count(*) FROM #ReportHits)

EXEC [Log].[PublishTable] 'CDS','ReportHits','#ReportHits','Append',@rows --Inserts record into Log.PublishedTableLog (other SPs use Mainteance.PublishTable that does )

END