-- =============================================
-- Author:		Liam Mina
-- Create date: 02.12.2019
-- Description:	Pulls most recent months the patient was identified in REACH VET, and the number of months the patient has been identified
-- Updates:
-- 2019-02-26 - LM - Updated date logic to count months based on REACH release date, not date this code is run
-- 2019-09-20 - RAS - Implemented MVIPersonSID; added join to new RiskScoreHistoric using only PatientSID 
-- 2020-10-05 - LM - Pointed to Reach.RiskScoreHistoric for Cerner overlay
-- 2020-10-26 - RAS - Added most recent coordinator facilty
-- 2021-04-14 - RAS - Changed column reference RiskScoreHistoric.Top01Percent to DashboardPatient per name change.
-- 2023-06-26 - AER - Added column for removed by randomization 
-- 2023-10-12 - LM - Update Sta3n_EHR along with ChecklistID to ensure PatientPersonSID updates in cases of facility transfer
-- 2025-05-06 - LM - Updated references to point to REACH 2.0 objects
-- =============================================
CREATE PROCEDURE [Code].[REACH_History] 
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC REACH_History','Execution of SP Code.REACH_History'

 -- Cohort
 DROP TABLE IF EXISTS #RVCohort_SIDs
 SELECT DISTINCT MVIPersonSID
 INTO #RVCohort_SIDs
 FROM [REACH].[RiskScoreHistoric] h WITH(NOLOCK)
 INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] p WITH(NOLOCK) 
	ON p.PatientPersonSID=h.PatientPersonSID 
 WHERE h.DashboardPatient=1 OR h.ImpactedByRandomization = 1
 

 DROP TABLE IF EXISTS #RVCohort
 SELECT DISTINCT 
	p.MVIPersonSID
	,h.PatientPersonSID
	,h.Sta3n_EHR
	,MAX(ReleaseDate) OVER(PARTITION BY p.MVIPersonSID) AS MaxReleaseAny
 INTO #RVCohort
 FROM [REACH].[RiskScoreHistoric] h WITH(NOLOCK)
 INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] p WITH(NOLOCK) 
	ON p.PatientPersonSID=h.PatientPersonSID 
 INNER JOIN #RVCohort_SIDs s WITH (NOLOCK)
	ON p.MVIPersonSID=s.MVIPersonSID
 WHERE p.MVIPersonSID > 0


 --Step 1: Get all dates the patient has ever been identified in REACH VET (Top 0.1%)
 DROP TABLE IF EXISTS #MonthsIdentifiedAllTime
 SELECT DISTINCT 
	p.MVIPersonSID
	,h.ReleaseDate
	,h.RunDate
	,h.DashboardPatient
	,MAX(h.ReleaseDate) OVER(PARTITION BY 1 ORDER BY h.ReleaseDate DESC) AS MaxReleaseDate
	,MAX(h.RunDate) OVER(PARTITION BY 1 ORDER BY h.RunDate DESC) AS MostRecentRun -- date that REACH VET was most recently run - the patient may or may not have been identified in RV during this run
		--using [RiskScore] so the flag is only for the most recent run
	,CASE WHEN s.ImpactedByRandomization = 1 AND s.DashboardPatient = 0 THEN 1 ELSE 0 END AS RemovedByRandomization 
 INTO #MonthsIdentifiedAllTime
 FROM [REACH].[RiskScoreHistoric] AS h WITH(NOLOCK)
 INNER JOIN #RVCohort AS p 
	 ON p.PatientPersonSID=h.PatientPersonSID 
 LEFT JOIN [REACH].[RiskScore] AS s WITH(NOLOCK)
	ON h.PatientPersonSID = s.PatientPersonSID
 WHERE h.DashboardPatient = 1 



 ---Add in patients with no RV history who were removed by Randomization
 INSERT INTO #MonthsIdentifiedAllTime 
 SELECT DISTINCT 
	s.MVIPersonSID
	,NULL AS ReleaseDate
	,s.RunDate
	,s.DashboardPatient
	,NULL AS MaxReleaseDate
	,NULL AS MostRecentRun -- date that REACH VET was most recently run - the patient may or may not have been identified in RV during this run
		--using [RiskScore] so the flag is only for the most recent run
	,1 as RemovedByRandomization  
 FROM [REACH].[RiskScoreHistoric] AS h WITH(NOLOCK)
 INNER JOIN #RVCohort p WITH(NOLOCK)
	ON p.PatientPersonSID=h.PatientPersonSID 
 LEFT JOIN [REACH].[RiskScore] AS s WITH (NOLOCK)
	ON h.PatientPersonSID = s.PatientPersonSID
 WHERE h.DashboardPatient = 0  AND s.ImpactedByRandomization = 1
 AND p.MVIPersonSID NOT IN (SELECT MVIPersonSID FROM #MonthsIdentifiedAllTime)
 
 
 --Step 2: Get the count of months in the last 12 months that the patient was identified in REACH VET (Top 0.1%)
 DROP TABLE IF EXISTS #MonthsIdentified12
 SELECT MVIPersonSID
	   ,COUNT(ReleaseDate) MonthsIdentified12
 INTO #MonthsIdentified12
 FROM #MonthsIdentifiedAllTime
 WHERE EOMonth(ReleaseDate) > DateAdd(yy, -1, EOMonth(MaxReleaseDate)) --using end of month, to avoid counting 13th month when 2nd Wednesday (release date) falls earlier than in previous year 
 and DashboardPatient = 1
 GROUP BY MVIPersonSID

 --Step 3: Get the count of months in the last 24 months that the patient was identified in REACH VET (Top 0.1%), inclusive of the past 12 months
 DROP TABLE IF EXISTS #MonthsIdentified24
 SELECT MVIPersonSID
	   ,COUNT(ReleaseDate) MonthsIdentified24
 INTO #MonthsIdentified24
 FROM #MonthsIdentifiedAllTime
 WHERE EOMonth(ReleaseDate) > DateAdd(yy, -2, EOMonth(MaxReleaseDate)) --using end of month, to avoid counting 25th month when 2nd Wednesday (release date) falls earlier than in previous years 
  and DashboardPatient = 1
 GROUP BY MVIPersonSID

 --Step 4: In order to get the second most recent date the patient was identified in REACH VET
 ----a requirement for the RV Patient Details report, assign a row number to each release date where the patient was identified in REACH VET
 DROP TABLE IF EXISTS #ReleaseDatesRanked
 SELECT MVIPersonSID
	   ,ReleaseDate as PreviousRVDate --second most recent date the patient was identified in REACH VET
 INTO #ReleaseDatesRanked
 FROM (
	 SELECT MVIPersonSID
		   ,ReleaseDate
		   ,row_number() OVER(PARTITION BY MVIPersonSID ORDER BY ReleaseDate DESC) AS rownum
	 FROM #MonthsIdentifiedAllTime
	 ) a 
 WHERE rownum=2
	
 --Step 5: Get the first, most recent, all time count, min, and max dates the patient was identified in REACH VET
 DROP TABLE IF EXISTS #ReleaseDates
 SELECT MVIPersonSID
	   ,COUNT(ReleaseDate)  AS MonthsIdentifiedAllTime
	   ,MAX(ReleaseDate)    AS MostRecentRVDate --most recent date the patient was identified in REACH VET
	   ,MIN(ReleaseDate)    AS FirstRVDate  --first date the patient was identified in REACH VET
	   ,MAX(MaxReleaseDate) AS MaxReleaseDate
	   ,MAX(MostRecentRun)  AS MostRecentRun
     ,Max(RemovedByRandomization) as RemovedByRandomization
 INTO #ReleaseDates
 FROM #MonthsIdentifiedAllTime
 GROUP BY MVIPersonSID


--Step 6: Add most recent coordinator location
DROP TABLE IF EXISTS #Facility
SELECT c.MVIPersonSID
	,h.PatientPersonSID
	,h.ChecklistID
	,c.Sta3n_EHR
INTO #Facility
FROM [REACH].[RiskScoreHistoric] h WITH (NOLOCK)
INNER JOIN #RVCohort c ON 
	c.PatientPersonSID=h.PatientPersonSID
	AND c.Sta3n_EHR=h.Sta3n_EHR
	AND c.MaxReleaseAny=h.ReleaseDate

	--Get updated checklistID for patients who have had a REACH VET transfer
	UPDATE #Facility
	SET ChecklistID = pr.NewChecklistID
	FROM (
		SELECT DISTINCT a.MVIPersonSID
			,a.ChecklistID
			,b.ChecklistID AS NewChecklistID
			,'Coordinator' AS Source
		FROM #Facility AS a
		INNER JOIN [REACH].[HealthFactors] AS b WITH (NOLOCK) ON a.MVIPersonSID = b.MVIPersonSID
		WHERE (a.ChecklistID <> b.ChecklistID OR a.Sta3n_EHR <> b.Sta3n)
			AND b.QuestionNumber = 0
			AND b.QuestionStatus = 1
			AND b.MostRecentFlag = 1 
		) AS pr   
	INNER JOIN #Facility AS r ON pr.MVIPersonSID = r.MVIPersonSID

	--Get updated Sta3n based on ChecklistID
	UPDATE #Facility
	SET Sta3n_EHR = pr.NewSta3n
		,ChecklistID = pr.ChecklistID
	FROM (SELECT DISTINCT a.MVIPersonSID
			,a.Sta3n_EHR
			,CASE WHEN c.IOCDate < getdate() AND m.MVIPersonSID IS NOT NULL 
				THEN 200 --Set Sta3n as 200 for patients who are at sites that have switched over to Cerner and have a record in Cerner data
				ELSE c.Sta3n 
				END AS NewSta3n
			,a.ChecklistID
		FROM #Facility AS a
		INNER JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
			ON a.ChecklistID = c.ChecklistID
		LEFT JOIN (SELECT * FROM [Common].[MVIPersonSIDPatientPersonSID] WITH (NOLOCK) WHERE Sta3n = 200) m
			ON a.MVIPersonSID = m.MVIPersonSID
		) AS pr   
	INNER JOIN #Facility AS r ON pr.MVIPersonSID = r.MVIPersonSID 

	--Get PatientPersonSID corresponding with Sta3n
	UPDATE #Facility
	SET PatientPersonSID = pr.NewPatientPersonSID
	FROM (
		SELECT DISTINCT a.MVIPersonSID
			,b.PatientPersonSID AS NewPatientPersonSID
			,a.Sta3n_EHR
		FROM #Facility AS a
		INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] AS b WITH (NOLOCK)
			ON a.MVIPersonSID = b.MVIPersonSID AND a.Sta3n_EHR = b.Sta3n		
		) AS pr   
	INNER JOIN #Facility AS r ON pr.MVIPersonSID = r.MVIPersonSID 

--Step 7: Join tables to pull information together to form final table
 DROP TABLE IF EXISTS #REACHHistory
 SELECT DISTINCT a.MVIPersonSID  
	   ,a.MonthsIdentifiedAllTime
	   ,c.MonthsIdentified12
	   ,d.MonthsIdentified24
	   ,a.FirstRVDate
	   ,a.MostRecentRVDate
	   ,CASE WHEN t.DashboardPatient = 1 THEN r.PreviousRVDate
	     ELSE a.MostRecentRVDate
	     END LastIdentifiedExcludingCurrentMonth -- this is the most recent date the patient has been identified in RV excluding the current month (for those currently identified)
	   ,MostRecentRun
	   ,CASE WHEN t.DashboardPatient = 1 THEN 1 ELSE 0 END Top01Percent
	   ,a.RemovedByRandomization
	   ,f.ChecklistID AS ChecklistID
	   ,f.Sta3n_EHR
	   ,f.PatientPersonSID
 INTO #REACHHistory
 FROM #ReleaseDates AS a
 LEFT JOIN (
	SELECT MVIPersonSID,max(DashboardPatient) as DashboardPatient
	FROM #MonthsIdentifiedAllTime 
	WHERE ReleaseDate=MaxReleaseDate
	GROUP BY MVIPersonSID
	) t on a.MVIPersonSID = t.MVIPersonSID
 LEFT JOIN #MonthsIdentified12 AS c ON a.MVIPersonSID = c.MVIPersonSID
 LEFT JOIN #MonthsIdentified24 AS d ON a.MVIPersonSID = d.MVIPersonSID
 LEFT JOIN #ReleaseDatesRanked AS r on a.MVIPersonSID = r.MVIPersonSID
 LEFT JOIN #Facility f ON a.MVIPersonSID = f.MVIPersonSID

;
 EXEC [Maintenance].[PublishTable] 'REACH.History', '#REACHHistory'
 ;

 EXEC [Log].[ExecutionEnd]

END