/********************************************************************************************************************
DESCRIPTION: ReachVet Metrics monthly report - Metrics for Weeks 1 and 2
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2019-08-02		RAS		New version to replace Code.Reach_MetricBasetable and Code.Reach_MetricBasetable_long
	2020-06-10		LM		Broke out into separate codes for weeks 1 and 2 metrics
	2020-09-16		LM		Added benchmark for successful outreach (80%) starting Sept 2020
	2023-07-25		LM		Updated parameters to allow this procedure to run after the end of the month, on the Sunday following the 4th Wednesday
	2025-05-06		LM		Updated references to point to REACH 2.0 objects
	2025-06-10		LM		Changed benchmark for first 4 metrics to 90% from 95% starting in July 2025
********************************************************************************************************************/

CREATE PROCEDURE [Code].[Reach_MonthlyMetrics_Wk12] 
AS
BEGIN


--Run Monthly Metrics with parameters for 2-week reporting
DROP TABLE IF EXISTS #MaxReleaseDate
SELECT MAX(ReleaseDate) MaxRelease
	,MetricRunDate = DateAdd(day,18,MAX(ReleaseDate)) --Sunday after 4th Wednesday; 18 days after 2nd Wednesday
	,BeginDate = DATEADD(d,1,EOMONTH(DATEADD(M,-1,MAX(ReleaseDate))))
	,EndDate = EOMONTH(DATEADD(M,0,MAX(ReleaseDate))) 
INTO #MaxReleaseDate
FROM [REACH].[RiskScoreHistoric] WITH (NOLOCK)

DECLARE @BeginDate DATE = (SELECT BeginDate FROM #MaxReleaseDate)
	,@EndDate DATE= (SELECT EndDate FROM #MaxReleaseDate)
	,@MetricRunDate DATE = (SELECT MetricRunDate FROM #MaxReleaseDate)

IF CAST(GetDate() AS date) >= @MetricRunDate --only run on or after specified date. Once it runs once for the month, the table will have data and will not update again due to rules in Code.REACH_MonthlyMetrics.
											 --intentionally not setting just to '=' in case for some reason the nightly job doesn't run that day, it will update the following day.
BEGIN	
	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics_Wk12','Execution of SP Code.Reach_MonthlyMetrics_Wk12'

	EXEC [Code].[Reach_MonthlyMetrics] @BeginDate=@BeginDate,@EndDate=@EndDate,@MaxWeek=2


--Get performance based on target benchmarks
DROP TABLE IF EXISTS #Wk2Scores
SELECT DISTINCT m.ReleaseDate
	,m.VISN
	,m.ChecklistID
	,m.Wk
	,max(c.Score) AS Coord
	,max(p.Score) AS ProvAssign
	,max(e.Score) AS Eval
	,max(o.Score) AS OutreachAtt
	,max(s.Score) AS OutreachSucc
INTO #Wk2Scores
FROM REACH.MonthlyMetrics m
INNER JOIN (SELECT * FROM REACH.MonthlyMetrics WHERE Wk=2 AND Metric='Coord') AS c
	ON m.ReleaseDate=c.ReleaseDate AND m.ChecklistID=c.ChecklistID 
INNER JOIN (SELECT * FROM REACH.MonthlyMetrics WHERE Wk=2 AND Metric='ProvAssign') AS p
	ON m.ReleaseDate=p.ReleaseDate AND m.ChecklistID=p.ChecklistID
INNER JOIN (SELECT * FROM REACH.MonthlyMetrics WHERE Wk=2 AND Metric='Eval') AS e
	ON m.ReleaseDate=e.ReleaseDate AND m.ChecklistID=e.ChecklistID
INNER JOIN (SELECT * FROM REACH.MonthlyMetrics WHERE Wk=2 AND Metric='OutreachAtt') AS o
	ON m.ReleaseDate=o.ReleaseDate AND m.ChecklistID=o.ChecklistID
INNER JOIN (SELECT * FROM REACH.MonthlyMetrics WHERE Wk=2 AND Metric='OutreachSucc') AS s
	ON m.ReleaseDate=s.ReleaseDate AND m.ChecklistID=s.ChecklistID
WHERE m.Wk=2 
GROUP BY m.VISN, m.Wk, m.ChecklistID, m.ReleaseDate

--Benchmark for first 4 metrics returns to 90% starting in July 2025; fifth metric remains at 80%
DROP TABLE IF EXISTS #Performance9080
SELECT DISTINCT [ReleaseDate]
      ,[VISN]
      ,[ChecklistID]
	  ,Wk
      ,CASE WHEN (Coord<.895 OR ProvAssign<.895 OR Eval<.895 OR OutreachAtt<.895 OR OutreachSucc<.795) THEN 1 ELSE 0 END AS Underperforming
	  ,CASE WHEN (Coord=1 AND ProvAssign=1 AND Eval=1 AND OutreachAtt=1 AND OutreachSucc=1) THEN 1 ELSE 0 END AS All100Pct
INTO #Performance9080 
FROM #Wk2Scores
WHERE ReleaseDate > '2025-07-01'
ORDER BY ChecklistID, ReleaseDate DESC

--Benchmark for successful outreach is 80% starting in September 2020; first 4 metrics remain at 95%
DROP TABLE IF EXISTS #Performance9580
SELECT DISTINCT [ReleaseDate]
      ,[VISN]
      ,[ChecklistID]
	  ,Wk
      ,CASE WHEN (Coord<.945 OR ProvAssign<.945 OR Eval<.945 OR OutreachAtt<.945 OR OutreachSucc<.795) THEN 1 ELSE 0 END AS Underperforming
	  ,CASE WHEN (Coord=1 AND ProvAssign=1 AND Eval=1 AND OutreachAtt=1 AND OutreachSucc=1) THEN 1 ELSE 0 END AS All100Pct
INTO #Performance9580 
FROM #Wk2Scores
WHERE ReleaseDate BETWEEN '2020-09-01' AND '2025-07-01'
ORDER BY ChecklistID, ReleaseDate DESC

--Benchmark is 95% for first 4 metrics and no benchmark for fifth starting in May 2020
DROP TABLE IF EXISTS #Performance95
SELECT DISTINCT [ReleaseDate]
      ,[VISN]
      ,[ChecklistID]
	  ,Wk
      ,CASE WHEN (Coord<.945 OR ProvAssign<.945 OR Eval<.945 OR OutreachAtt<.945) THEN 1 ELSE 0 END AS Underperforming
	  ,CASE WHEN (Coord=1 AND ProvAssign=1 AND Eval=1 AND OutreachAtt=1) THEN 1 ELSE 0 END AS All100Pct
INTO #Performance95 
FROM #Wk2Scores
WHERE ReleaseDate between '2020-05-01' AND '2020-09-01'
ORDER BY ChecklistID, ReleaseDate DESC

--Benchmark is 90% for first 4 metrics and no benchmark for fifth starting in November 2019
DROP TABLE IF EXISTS #Performance90
SELECT DISTINCT [ReleaseDate]
      ,[VISN]
      ,[ChecklistID]
	  ,Wk
      ,CASE WHEN (Coord<.895 OR ProvAssign<.895 OR Eval<.895 OR OutreachAtt<.895) THEN 1 ELSE 0 END AS Underperforming
	  ,CASE WHEN (Coord=1 AND ProvAssign=1 AND Eval=1 AND OutreachAtt=1) THEN 1 ELSE 0 END AS All100Pct
INTO #Performance90 
FROM #Wk2Scores
WHERE ReleaseDate between '2019-11-01' and '2020-04-30'
ORDER BY ChecklistID, ReleaseDate DESC

--No lower benchmark before November 2019
DROP TABLE IF EXISTS #PerformanceNoTarget
SELECT DISTINCT [ReleaseDate]
      ,[VISN]
      ,[ChecklistID]
	  ,Wk
      ,Underperforming=0
	  ,CASE WHEN (Coord=1 AND ProvAssign=1 AND Eval=1 AND OutreachAtt=1) THEN 1 ELSE 0 END AS All100Pct
INTO #PerformanceNoTarget
FROM #Wk2Scores
WHERE ReleaseDate < '2019-11-01'
ORDER BY ChecklistID, ReleaseDate DESC

DROP TABLE IF EXISTS #Performance
SELECT * 
INTO #Performance
FROM #Performance9080
UNION ALL
SELECT * FROM #Performance9580
UNION ALL
SELECT * FROM #Performance95
UNION ALL
SELECT * FROM #Performance90
UNION ALL
SELECT * FROM #PerformanceNoTarget

DROP TABLE IF EXISTS #GetMonthsUnderperforming
SELECT DISTINCT a.ChecklistID
	,a.ReleaseDate
	,a.Underperforming
	,sum(c.Underperforming) over (partition by a.checklistid, a.releasedate) AS MonthsUnderperforming
	,max(b.releasedate) over (partition by a.checklistid, a.releasedate) AS LastBenchmarkDate
INTO #GetMonthsUnderperforming
FROM #Performance a
LEFT JOIN (SELECT * FROM #Performance WHERE Underperforming=0) b on a.ChecklistID=b.ChecklistID and a.ReleaseDate>=b.ReleaseDate
LEFT JOIN (SELECT * FROM #Performance WHERE Underperforming=1) c on a.ChecklistID=c.ChecklistID and a.ReleaseDate>=c.ReleaseDate

DROP TABLE IF EXISTS #MetricPerformanceFinal
SELECT a.ReleaseDate
	,a.VISN
	,a.ChecklistID
	,a.Wk
	,CASE WHEN a.All100pct=1 THEN '100%'
		WHEN a.Underperforming=1 THEN 'Underperforming'
		ELSE 'Meeting Benchmark' END AS Benchmark
	,CASE WHEN a.Underperforming=0 THEN 0
		ELSE IsNull(DateDiff(mm,b.LastBenchmarkDate,a.ReleaseDate), b.MonthsUnderperforming)
		END AS ConsecMonthsUnderperforming
INTO #MetricPerformanceFinal
FROM #Performance a
LEFT JOIN #GetMonthsUnderperforming b on a.ChecklistID=b.ChecklistID and a.ReleaseDate=b.ReleaseDate

EXEC [Maintenance].[PublishTable] 'REACH.MonthlyMetricBenchmarks', '#MetricPerformanceFinal'

EXEC [Log].[ExecutionEnd]

END;

END