/********************************************************************************************************************
DESCRIPTION: Main code for ReachVet Metrics monthly report
	Results reported at National, VISN, and ChecklistID levels
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2019-08-02		RAS		New version to replace Code.Reach_MetricBasetable and Code.Reach_MetricBasetable_long
	2020-06-15		RAS		Added week parameters to allow week-specific code to run this SP twice per month
	2020-10-05		LM		Pointed to _VM tables for Cerner overlay
	2020-03-26		LM		Removed join on Sta3n_EHR; it is not necessary and was dropping Cerner patients from the count
	2021-04-23		LM		Excluding patients who were incorrectly not identified in (and later added to) the April 2021 run
	2021-05-11		LM		Removed exclusion for 'April Correction'
	2022-09-21		CW		Removed Veterans ineligible for care based on Priority Group 8e/8g
	2023-10-25		LM		Added new care eval options from templates implemented in July; removed inpatient/incarcerated from counting for outreach attempted
	2024-03-18		LM		Use ChecklistID from REACH.History to ensure patient is in the metrics for the facility where they were displayed on the dashboard
	2025-05-06		LM		Updated references to point to REACH 2.0 objects
********************************************************************************************************************/

/*****REACH VET Monthly Reports******
Requested by REACH VET Coordinator Aaron Eagan in June 2017; communicated to Amy Robinson
Reports contain the following information, for 1 to 4 weeks after the release date:
	a. Total number of patients
	b. Number eligible for outreach
	c. with coordinator assigned
	d. who asked provider to re-evaluate care
	e. with provider or designee assigned
	f. with a care evaluation performed
	g. with an attempted outreach -- as of January 2019, includes admitted and incarcerated (questions 24 and 25)
	h. with a successful outreach
*/

CREATE PROCEDURE [Code].[Reach_MonthlyMetrics] 
	(@ForceUpdate BIT = 0
	,@BeginDate DATE = NULL
	,@EndDate DATE = NULL
	,@MaxWeek TINYINT = 4
	,@MinWeek TINYINT = 1 )
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics','Execution of SP Code.Reach_MonthlyMetrics'

/*************************************************************************************
--Set begin and end dates and get Release Dates 
----default to previous month's release, but you could run it for multiple months
*************************************************************************************/
	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics 1','Declare variables and check for existing data'

	--For testing:
	--DECLARE @ForceUpdate bit = 1,@BeginDate DATE =NULL ,@EndDate DATE = NULL,@MaxWeek TINYINT = 4,@MinWeek TINYINT=3

IF @BeginDate IS NULL 
BEGIN
	SET @BeginDate=DATEADD(d,1,EOMONTH(DATEADD(M,-2,getdate())))
	SET @EndDate=EOMONTH(DATEADD(M,-1,getdate()))
END
IF @EndDate IS NULL 
BEGIN
	SET @EndDate=EOMONTH(DATEADD(M,-1,getdate()))
END
PRINT @BeginDate
PRINT @EndDate

	--For testing:
	--DECLARE @BeginDate DATE
	--	   ,@EndDate DATE

	--SET @BeginDate=DATEADD(d,1,EOMONTH(DATEADD(M,-2,getdate())))
	--SET @EndDate=EOMONTH(DATEADD(M,-1,getdate()))
	--PRINT @BeginDate
	--PRINT @EndDate

-- Get release dates that fall between begin and end dates
DROP TABLE IF EXISTS #ReleaseDate;
SELECT ReleaseDate,NumDays
INTO #ReleaseDate
FROM (
	SELECT ReleaseDate
		  ,DateDiff(d,ReleaseDate,lead(ReleaseDate,1) OVER (ORDER BY ReleaseDate)) NumDays
	FROM [REACH].[ReleaseDates] WITH(NOLOCK)
	) a
WHERE ReleaseDate BETWEEN @BeginDate AND @EndDate 
ORDER BY ReleaseDate DESC

/*************************************************************************************
-- Check for existing data in MetricBasetable 
*************************************************************************************/
-- Find existing data for release date(s) of interest
DROP TABLE IF EXISTS #existingdata
SELECT DISTINCT r.ReleaseDate,m.Wk
INTO #existingdata
FROM [REACH].[MonthlyMetrics] m WITH(NOLOCK)
INNER JOIN #ReleaseDate r on 
	r.ReleaseDate=m.ReleaseDate
	AND Wk BETWEEN @MinWeek AND @MaxWeek

	--Create string of dates for existing data to use in messages
	DECLARE @dates varchar(250) = (
			SELECT TOP 1 CONCAT(ReleaseDate,' Wk ', Wk)
				--STRING_AGG(ReleaseDate,',') 
			FROM #existingdata rd
			ORDER BY ReleaseDate DESC,Wk DESC
			)

--End procedure if there is pre-existing data and @ForceUpdate is not set to 1
IF @ForceUpdate=0 
	AND EXISTS (SELECT * FROM #existingdata WHERE Wk=@MaxWeek)
BEGIN
	DECLARE @msg0 varchar(250) = 'Data for release date '+@dates+' already exists in Reach.MonthlyMetrics. Run SP with @ForceUpdate=1 to overwrite existing data.'
	PRINT @msg0
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg0

	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 1
	EXEC [Log].[ExecutionEnd] @Status='Error' --Reach_MonthlyMetrics
	
	RETURN
END 

--Delete pre-existing data if force update is set 
----add message to log with release dates that were deleted and will be re-computed
IF @ForceUpdate=1 
BEGIN
	DELETE m 
	FROM [REACH].[MonthlyMetrics] m
	INNER JOIN #existingdata r on 
		r.ReleaseDate=m.ReleaseDate
		AND r.Wk=m.Wk
	
	DECLARE @msg2 varchar(250) = 'Force update executed - pre-existing data (max '+@dates+') will be deleted.'
	EXEC [Log].[Message] 'Information','Overwriting data'
		,@msg2
END
	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 1

/***************************************************************/
--Get a list of distinct patients for the month(s)
----Remove people reported as deceased BEFORE the month's release
/***************************************************************/
	EXEC [Log].ExecutionBegin 'Reach_MonthlyMetrics 2','Defining cohort for historic metrics.'
DROP TABLE IF EXISTS #cohort;
SELECT MVIPersonSID
	  ,ReleaseDate
	  ,NumDays
	  ,ChecklistID
	  ,DeathDateTime
	  ,d_wk = CASE WHEN datediff(day, ReleaseDate, DeathDateTime)>=0  and datediff(day, ReleaseDate, DeathDateTime)<=7  THEN 1
				   WHEN datediff(day, ReleaseDate, DeathDateTime)>=8  and datediff(day, ReleaseDate, DeathDateTime)<=14 THEN 2 
				   WHEN datediff(day, ReleaseDate, DeathDateTime)>=15 and datediff(day, ReleaseDate, DeathDateTime)<=21 THEN 3
				   WHEN datediff(day, ReleaseDate, DeathDateTime)>=22 and datediff(day, ReleaseDate, DeathDateTime)<NumDays THEN 4 
				END
INTO #cohort
FROM (
	SELECT p.MVIPersonSID
		  ,a.ReleaseDate
		  ,h.ChecklistID --facility that has the patient at the time the metrics are run
		  ,rd.NumDays
		  ,m.DateOfDeath as DeathDateTime
	FROM [REACH].[RiskScoreHistoric] AS a WITH(NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] p WITH(NOLOCK) ON p.PatientPersonSID=a.PatientPersonSID 
	INNER JOIN [Common].[MasterPatient] m WITH(NOLOCK) ON p.MVIPersonSID=m.MVIPersonSID
	INNER JOIN [REACH].[History] h WITH (NOLOCK) ON m.MVIPersonSID=h.MVIPersonSID
	INNER JOIN #ReleaseDate rd on rd.ReleaseDate=a.ReleaseDate
	WHERE a.DashboardPatient=1 
	AND (m.DateOfDeath IS NULL OR m.DateOfDeath>=a.ReleaseDate)
	AND NOT (m.PriorityGroup = 8 AND m.PrioritySubGroup IN ('e', 'g'))
	GROUP BY p.MVIPersonSID,a.ReleaseDate,h.ChecklistID,rd.NumDays,m.DateOfDeath
	) c
	
	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 2
/******************************************/
/* Get health factor data for the cohort **/
/******************************************/
--Define weeks and metric to which each question applies

	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics 3','Getting health factor data for metrics'

DROP TABLE IF EXISTS #rv_monthly_1;
SELECT c.MVIPersonSID
	  ,c.ReleaseDate
	  ,c.ChecklistID as ChecklistID_rv
	  ,hf.ChecklistID as ChecklistID_hf
	  ,hf.HealthFactorDateTime
	  ,Wk=CASE WHEN datediff(day, ReleaseDate, hf.HealthFactorDateTime)<=0  THEN 0
			   WHEN datediff(day, ReleaseDate, hf.HealthFactorDateTime)<=7  THEN 1 
			   WHEN datediff(day, ReleaseDate, hf.HealthFactorDateTime)>=8  and datediff(day, ReleaseDate, hf.HealthFactorDateTime)<=14 THEN 2 
			   WHEN datediff(day, ReleaseDate, hf.HealthFactorDateTime)>=15 and datediff(day, ReleaseDate, hf.HealthFactorDateTime)<=21 THEN 3
			   WHEN datediff(day, ReleaseDate, hf.HealthFactorDateTime)>=22 and datediff(day, ReleaseDate, hf.HealthFactorDateTime)<NumDays THEN 4 
			ELSE 0 END
	  ,Metric=CASE WHEN (QuestionStatus=1 AND Coordinator=1) THEN 'Coord'
				   WHEN QuestionStatus=1 AND CareEval=1 THEN 'Eval'
				   WHEN QuestionStatus=1 AND OutreachSuccess=1 THEN 'OutreachSucc'
				   WHEN QuestionStatus=1 AND OutreachAttempted=1 THEN 'OutreachAtt' --Note that this will NOT overwrite OutreachSucc (see next step)
				   WHEN QuestionStatus=1 AND Provider=1 THEN 'ProvAssign'
				END
INTO #rv_monthly_1
FROM #cohort c
LEFT JOIN [REACH].[HealthFactors] AS hf WITH (NOLOCK) ON hf.MVIPersonSID=c.MVIPersonSID 
WHERE HealthFactorDateTime<=DateAdd(day,NumDays,ReleaseDate)
;
	--Adding additional rows for questions 13-16 that also count toward outreach attempt
	DROP TABLE IF EXISTS #rv_monthly;
	SELECT MVIPersonSID
		  ,ReleaseDate
		  ,ChecklistID_rv
		  ,ChecklistID_hf
		  ,HealthFactorDateTime
		  ,Wk
		  ,Metric
	INTO #rv_monthly
	FROM #rv_monthly_1
	UNION ALL 
	SELECT MVIPersonSID
		  ,ReleaseDate
		  ,ChecklistID_rv
		  ,ChecklistID_hf
		  ,HealthFactorDateTime
		  ,Wk
		  ,Category='OutreachAtt'
	FROM #rv_monthly_1
	WHERE Metric='OutreachSucc'
	UNION ALL
	SELECT MVIPersonSID
		  ,ReleaseDate
		  ,ChecklistID_rv
		  ,ChecklistID_hf
		  ,HealthFactorDateTime
		  ,Wk
		  ,Category='ProvAssign'
	FROM #rv_monthly_1
	WHERE Metric IN ('Eval','OutreachAtt')

	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 3

	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics 4','Finding min dates for metrics, determiing transfers, and assigning weekly station'

--Get earliest date for each category
DROP TABLE IF EXISTS #minwk;
SELECT MVIPersonSID
	,Metric
	,ReleaseDate
	,min(Wk) Wk
INTO #minwk
FROM #rv_monthly
WHERE Metric IS NOT NULL
GROUP BY MVIPersonSID
	,Metric
	,ReleaseDate

/*
2024-03-18: LM Removed transfer steps from code. Week 2 metrics are the only ones that matter and metrics are run right after week 2.  
Instead of logic to start with facility of assignment in RiskScoreHistoric and then identify each transfer afterwards, switching to just using facility where patient is currently on the dashboard (REACH.History).
Errors for a few months in late 2023/early 2024 where assigment in RiskScoreHistoric was incorrect and some patients were included in metrics for the wrong facility.
*/


--Assign station for each week
----All combinations of weeks 1-4 and original station
DROP TABLE IF EXISTS #wk_sta;
SELECT MVIPersonSID
	  ,ChecklistID
	  ,ReleaseDate
	  ,w.Wk
INTO #wk_sta
FROM #cohort c
	,(values (1),(2),(3),(4)) w(Wk) 


--Remove row if patient died during or before the week
DELETE s
FROM #wk_sta s
INNER JOIN #cohort c on 
	s.MVIPersonSID=c.MVIPersonSID
	AND c.d_wk<=s.Wk -- week of death was before or same as week of interest
WHERE d_wk IS NOT NULL

	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 4

	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics 5','Computing metrics'

--Add rows for all measure categories 
DROP TABLE IF EXISTS #wk_sta_ctgy;
SELECT MVIPersonSID
	  ,ChecklistID
	  ,ReleaseDate
	  ,Wk
	  ,Metric
INTO #wk_sta_ctgy
FROM #wk_sta 
	,(SELECT DISTINCT Metric 
	  FROM #rv_monthly
	  WHERE Metric IS NOT NULL
	  ) c

--Compute whether metric was met or not for each patient
----Add VISN
DROP TABLE IF EXISTS #numerator;
SELECT c.ReleaseDate
	  ,c.MVIPersonSID
	  ,c.ChecklistID
	  ,c.Wk
	  ,c.Metric
	  ,m.Wk as WeekMet
	  ,CASE WHEN m.Wk<=c.Wk THEN 1 ELSE 0 END as Num
	  ,l.VISN
INTO #numerator
FROM #wk_sta_ctgy c
LEFT JOIN #minwk m on c.MVIPersonSID=m.MVIPersonSID 
	AND m.Metric=c.Metric
	AND m.ReleaseDate=c.ReleaseDate
INNER JOIN [LookUp].[ChecklistID] l WITH(NOLOCK) on l.ChecklistID=c.ChecklistID

--Aggregate data per release, week, metric
DROP TABLE IF EXISTS #aggregate
SELECT ISNULL(VISN,0) VISN
	  ,CASE WHEN ChecklistID IS NULL AND VISN IS NOT NULL THEN cast(VISN as varchar)
			WHEN ChecklistID IS NULL AND VISN IS NULL THEN '0' 
			ELSE ChecklistID
			END as ChecklistID
	  ,ReleaseDate
	  ,Wk
	  ,Metric
	  ,count(MVIPersonSID) as Denominator
	  ,sum(Num) as Numerator
INTO #aggregate
FROM #numerator
GROUP BY Grouping Sets (
	 (ReleaseDate,VISN,ChecklistID,Wk,Metric)
	,(ReleaseDate,VISN,Wk,Metric)
	,(ReleaseDate,Wk,Metric)
	)
ORDER BY ReleaseDate,VISN,ChecklistID,Metric,Wk

--Change denominator for successful outreach
UPDATE #aggregate
SET Denominator = Den
FROM (
	SELECT ISNULL(VISN,0) VISN
		  ,CASE WHEN ChecklistID IS NULL AND VISN IS NOT NULL THEN cast(VISN as varchar)
				WHEN ChecklistID IS NULL AND VISN IS NULL THEN '0' 
				ELSE ChecklistID
				END as ChecklistID
		  ,ReleaseDate
		  ,Wk
		  ,count(MVIPersonSID) as Den
	FROM #numerator
	WHERE Metric='OutreachAtt'
		AND Num=1
	GROUP BY Grouping Sets (
		 (ReleaseDate,VISN,ChecklistID,Wk,Metric)
		,(ReleaseDate,VISN,Wk,Metric)
		,(ReleaseDate,Wk,Metric)
		)
	) o
INNER JOIN #aggregate a on 
	a.ReleaseDate=o.ReleaseDate
	AND a.VISN=o.VISN 
	AND a.ChecklistID=o.ChecklistID
	AND a.Wk=o.Wk
WHERE Metric='OutreachSucc'

	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 5

	EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics 6','Final stage and insert'

--Stage final table and insert results
DROP TABLE IF EXISTS #StageReachMetrics
SELECT ReleaseDate
	  ,VISN
	  ,ChecklistID
	  ,Wk
	  ,Metric
	  ,Denominator
	  ,Numerator
	  ,Score=cast(Numerator as decimal)/cast(Denominator as decimal)
INTO #StageReachMetrics
FROM #aggregate
WHERE Wk BETWEEN @MinWeek AND @MaxWeek

INSERT INTO [REACH].[MonthlyMetrics] (ReleaseDate
	  ,VISN
	  ,ChecklistID
	  ,Wk
	  ,Metric
	  ,Denominator
	  ,Numerator
	  ,Score)
SELECT ReleaseDate
	  ,VISN
	  ,ChecklistID
	  ,Wk
	  ,Metric
	  ,Denominator
	  ,Numerator
	  ,Score
FROM #StageReachMetrics

DECLARE @rows varchar(10) = (SELECT count(*) FROM #StageReachMetrics)

	EXEC [Log].[PublishTable] 'REACH','MonthlyMetrics','#StageReachMetrics','Append',@rows --Inserts record into Log.PublishedTableLog (other SPs use Mainteance.PublishTable that does )

	EXEC [Log].[ExecutionEnd] --Reach_MonthlyMetrics 6

EXEC [Log].[ExecutionEnd]

END