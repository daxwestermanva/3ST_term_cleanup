/*=============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2018-02-08
-- Description:	This code finds all patients with an active or a history of a high risk for suicide flag.
	Tables are created for active flags as well as a history of flag action (for active and inactive)
	that is cleaned to account for multiple actions per day, etc.
	This has been edited and separated from the other portions of the original HighRisk.Tracking code.
-- Updates:
--	2018-11-03 - Jason Bacani	- Corrected nested IF-THEN and BEGIN-TRY blocks that were incorectly set and had created deadlocks
--	2018-11-05 - Jason Bacani	- Further corrected deadlock handling by using OPTION (MAXDOP 1) 
--	2019-02-18 - Jason Bacani - To fix errors, included a LEFT JOIN to #reach to get the ReachStatus feild value; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--  2019-05-02 - RAS	Added WHERE statement to #history creation to exclude records that do not have an action type in CDW table (incomplete data, not useful)
--  2019-05-20 - RAS	Added section to remove "episodes" that were "entered in error" within 7 days of the beginning action (if a flag was new, continued, or
						reactivated and then an action of "Entered in Error" was taken within 7 days, ignore both of those entries)
--	2019-12-18 - LM		Changed WHERE statement in #history creation to exclude action types other than 1-5, since action types greater than 5 are not relevant for this report
--	2020-04-06 - LM		Added time zone conversions for Manila, Alaska, and Hawaii. Changed ranking to privilege actiondatetime at owning facility, to minimize changes of DST conversion issues
--  2020-06-10 - RAS	Changed ActivePRF from table to view. 
--	2020-08-11 - LM		Cleaned up some cases where the last action type was 5 and the flag is no longer active
--  2021-09-13 - AI		Enclave Refactoring - Counts confirmed
--	2021-12-15 - LM		Changes to better handle 'entered in error' flag actions
--	2022-01-22 - LM		Added MostRecentActivation date for flags activated in past 100 days and not yet reviewed between 80-100 days
--	2023-06-01 - LM		Added next flag review date from health factors
--	2023-12-12 - LM		For continuations that occur after another continuation, pull forward the original review date if a new review date is not documented
--	2024-04-09 - LM		Added join on SecondaryVisitSID to connect review date health factors to note
=========================================================================================================================================*/
CREATE PROCEDURE [Code].[PRF_HRS_ActiveAndHistory]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_HRS_ActiveAndHistory', @Description = 'Execution of Code.PRF_HRS_ActiveAndHistory SP'

------------------------------------------------------------------------------
-- 1. GET PATIENTS WITH HIGH RISK FOR SUICIDE FLAGS AND FACILITY INFO
------------------------------------------------------------------------------
--Get National PRF SIDs for High Risk Suicide flags
	DROP TABLE IF EXISTS #FlagTypeSID;
	SELECT DISTINCT NationalPatientRecordFlagSID 
	INTO #FlagTypeSID 
	FROM [Dim].[NationalPatientRecordFlag] WITH (NOLOCK)
	WHERE NationalPatientRecordFlag = 'HIGH RISK FOR SUICIDE' 
	
--Find all High Risk Suicide flags using above SIDs (this includes inactives)
	DROP TABLE IF EXISTS #flags;
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,s.PatientICN
		,prf.PatientRecordFlagAssignmentSID
		,prf.OwnerInstitutionSID
		,prf.ActiveFlag 
	INTO #flags
	FROM #FlagTypeSID f
	INNER JOIN [SPatient].[PatientRecordFlagAssignment] AS prf WITH (NOLOCK)
		ON prf.NationalPatientRecordFlagSID = f.NationalPatientRecordFlagSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK)
		ON prf.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] AS s WITH (NOLOCK)
		ON s.MVIPersonSID = mvi.MVIPersonSID
	WHERE s.TestPatient = 0
	--WHERE a.ActiveFlag='Y'--the patient's flag is active
	/*RAS - Removed this where statement because some patients have conflicting information. 
		In the next section this will be cleaned. */
		
--Add in facility info
	DROP TABLE IF EXISTS #WithChecklistID;
	SELECT prf.MVIPersonSID
		  ,prf.PatientICN
		  ,prf.PatientRecordFlagAssignmentSID
		  ,prf.OwnerInstitutionSID
		  ,prf.ActiveFlag
		  ,c.ChecklistID
		  ,c.Facility
	INTO #WithChecklistID 
	FROM #flags AS prf
	INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK)
		ON i.InstitutionSID=prf.OwnerInstitutionSID
	LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK)
		ON i.StaPa=c.Sta6aID
	ORDER BY ChecklistID
	  ;--291018

------------------------------------------------------------------------------
-- 2. FIND DISCREPANCIES, CORRECT TO CREATE A CLEAN COHORT
------------------------------------------------------------------------------
--Find all patients with BOTH ActiveFlag='Y' and ActiveFlag='N' and put their info in a separate table
	DROP TABLE IF EXISTS #discrepancies;
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientRecordFlagAssignmentSID
		,a.OwnerInstitutionSID
		,a.ActiveFlag
		,a.ChecklistID
		,a.Facility
	INTO #discrepancies
	FROM #WithChecklistID AS a
	INNER JOIN ( 
		SELECT MVIPersonSID
			  ,CountFlagSID=COUNT(DISTINCT PatientRecordFlagAssignmentSID)
			  ,CountActiveValue=COUNT(DISTINCT ActiveFlag) 
		FROM #WithChecklistID
		GROUP BY MVIPersonSID
		HAVING COUNT(DISTINCT ActiveFlag)>1 --where this is a Y and N for the same patient
	  ) AS ct
	ON a.MVIPersonSID=ct.MVIPersonSID
	;

----------FOR THOSE WITHOUT DISCREPANCIES----------
--Remove patients with discrepancies from with checklist ID table
	DELETE FROM #WithChecklistID
	WHERE MVIPersonSID in (
		SELECT MVIPersonSID 
		FROM #discrepancies
		)
	;

----------FOR THOSE WITH DISCREPANCIES----------
--Find the flag record SIDs that contain most recent data for those with conflicting information
	DROP TABLE IF EXISTS #corrections;
	SELECT DISTINCT 
		 d.MVIPersonSID
		,d.PatientICN
		,d.PatientRecordFlagAssignmentSID
		,d.OwnerInstitutionSID
		,d.ActiveFlag
		,d.ChecklistID
		,d.Facility
	INTO #corrections
	FROM (
		SELECT d.MVIPersonSID,d.PatientICN
			  ,d.PatientRecordFlagAssignmentSID
			  ,PatientRecordFlagHistoryAction
			  ,MinDate = MIN(CONVERT(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.PatientRecordFlagAssignmentSID)
			  ,MaxDate = MAX(CONVERT(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.PatientRecordFlagAssignmentSID)
			  ,MinMin = MIN(CONVERT(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID)
			  ,MaxMax = MAX(CONVERT(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID)
		FROM #discrepancies AS d
		INNER JOIN [SPatient].[PatientRecordFlagHistory] AS h WITH (NOLOCK)
			ON d.PatientRecordFlagAssignmentSID=h.PatientRecordFlagAssignmentSID
		) AS m
	INNER JOIN #discrepancies AS d 
		ON m.PatientRecordFlagAssignmentSID=d.PatientRecordFlagAssignmentSID
	WHERE m.MaxMax=m.MaxDate--only use the flag records where there is data up to the latest date possible
	;

--COMBINE CORRECTIONS WITH PREVIOUS TABLE
	DROP TABLE IF EXISTS #final;
	SELECT MVIPersonSID
		  ,PatientICN
		  ,PatientRecordFlagAssignmentSID
		  ,OwnerInstitutionSID
		  ,ActiveFlag
		  ,ChecklistID
		  ,Facility 
	INTO #final
	FROM #WithChecklistID
	UNION ALL
	SELECT MVIPersonSID
		  ,PatientICN
		  ,PatientRecordFlagAssignmentSID
		  ,OwnerInstitutionSID
		  ,ActiveFlag
		  ,ChecklistID
		  ,Facility 
	FROM #corrections;

	/*Patients that still have discrepancies (5)
	SELECT PatientICN,count(distinct ActiveFlag)
	FROM #final
	GROUP BY PatientICN
	having count(distinct ActiveFlag)>1
	*/
	
------------------------------------------------------------------------------
-- 3. GET HISTORY OF ACTIONS, THEN CLEAN
------------------------------------------------------------------------------
--Get all actions in history for the flag SIDs identified in previous section 
	--add fields for sorting
	DROP TABLE IF EXISTS #history;
	SELECT DISTINCT f.MVIPersonSID
		  ,f.PatientICN
		  ,f.ChecklistID
		  ,f.Facility
		  ,f.ActiveFlag
		  ,Sta3n_History=h.Sta3n
		  ,t.TimeZone
		  ,t.HoursAdd --calculated in subquery to adjust time for time zone because entries are repeated for each facility
		  ,h.ActionDateTime
		  ,AdjDateTime = DATEADD(hh,t.HoursAdd,h.ActionDateTime) 
		  ,ActionDate = CAST(h.ActionDateTime AS date)
		  ,AdjDate = CAST(DATEADD(hh,t.HoursAdd,h.ActionDateTime) AS date)
		  ,h.TIUDocumentSID 
		  ,td.VisitSID
		  ,td.SecondaryVisitSID
		  ,OwnerMatch = CASE WHEN LEFT(f.Checklistid,3)=cast(h.Sta3n AS varchar) THEN 1 ELSE 0 END 
		  ,ActionType = h.PatientRecordFlagHistoryAction
		  ,ActionPriority = --priority for when actions have EXACT same datetime - assume active (rare, but happens)
			CASE WHEN PatientRecordFlagHistoryAction='1' THEN 1 
				 WHEN PatientRecordFlagHistoryAction='4' THEN 2
				 WHEN PatientRecordFlagHistoryAction='2' THEN 3 
				 WHEN PatientRecordFlagHistoryAction='3' THEN 4  	
				 WHEN PatientRecordFlagHistoryAction='5' THEN 5 
			  END
	INTO #history
	FROM #final AS f
	LEFT JOIN [SPatient].[PatientRecordFlagHistory] AS h WITH (NOLOCK)
		ON f.PatientRecordFlagAssignmentSID=h.PatientRecordFlagAssignmentSID
	LEFT JOIN (
			SELECT Sta3n
				  ,TimeZone
				  ,HoursAdd =  
					CASE WHEN TimeZone='Central Standard Time'  THEN 1
						 WHEN TimeZone='Mountain Standard Time' THEN 2 
						 WHEN TimeZone='Pacific Standard Time'  THEN 3 
						 WHEN TimeZone='Alaskan Standard Time' THEN 4
						 WHEN TimeZone='Hawaiian Standard Time' THEN 6
						 WHEN TimeZone='Taipei Standard Time' THEN -12
					ELSE 0 END
			FROM [Dim].[Sta3n] WITH (NOLOCK)
			) AS t ON t.Sta3n=h.Sta3n  --where h.PatientRecordFlagAssignmentSID is null (10 rows)
	LEFT JOIN [Stage].[FactTIUNoteTitles] td WITH (NOLOCK) ON h.TIUDocumentSID = td.TIUDocumentSID AND td.List='HRF_FlagReview_TIU'
	WHERE h.PatientRecordFlagAssignmentSID > 0 
	AND h.PatientRecordFlagHistoryAction IN ('1','2','3','4','5') --Ignore NULL entries that have no useful data, and ActionType 6-8 which don't correspond with a relevant flag action
	;
--Get 1 record per day and actiontype for each Patient ICN
	DROP TABLE IF EXISTS #OneActionTYPEperDay;
	SELECT r.* INTO #OneActionTYPEperDay
	FROM ( 
		SELECT MVIPersonSID
		  ,PatientICN
		  ,ChecklistID
		  ,Facility
		  ,ActiveFlag
		  ,Sta3n_History
		  ,ActionDateTime
		  ,AdjDateTime 
		  ,ActionDate
		  ,AdjDate 
		  ,OwnerMatch  
		  ,ActionType 
		  ,ActionPriority
		  ,VisitSID
		  ,SecondaryVisitSID
		  ,RN=Row_Number() OVER(PARTITION BY MVIPersonSID,AdjDate,ActionType ORDER BY OwnerMatch DESC,AdjDateTime DESC,TIUDocumentSID DESC)
		FROM #history
		) AS r  
	WHERE RN=1 --The last time that type of action was taken on that specific day
	;

--Get only 1 record per DAY (action type that occurred at the latest time)
	DROP TABLE IF EXISTS #OneACTIONperDay;
	SELECT a.*
		  ,TrueAction=
			CASE WHEN TimeRank=1 THEN ( 
					CASE WHEN ActionType IN (1,3,5) 
					  THEN ActionType --if the last action of the day was Activate, Deactivate, or Entered in Error, that's the action for the day
					WHEN ActionType IN (2,4) and MIN(PreviousAction) OVER(PARTITION BY MVIPersonSID,ActionDate)=1 
					  THEN 1 --if a flag was continued or reactivated, but was newly activated at an earlier time, then count as new
					WHEN ActionType=2 and MAX(PreviousAction) OVER(PARTITION BY MVIPersonSID,ActionDate)=4 
					  THEN 4 --if a flag was continued, but was reactivated at an earlier time, then count as reactivated
					ELSE ActionType
				  END )
			 END
	INTO #OneACTIONperDay
	FROM (SELECT MVIPersonSID
		  ,PatientICN
		  ,ChecklistID
		  ,Facility
		  ,ActiveFlag
		  ,Sta3n_History
		  ,ActionDateTime
		  ,ActionDate
		  ,OwnerMatch  
		  ,ActionType 
		  ,VisitSID
		  ,TimeRank=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,ActionDate ORDER BY AdjDateTime desc, ActionPriority)
 		  ,PreviousAction=LEAD(ActionType,1) OVER(PARTITION BY MVIPersonSID,ActionDate ORDER BY AdjDateTime desc, ActionPriority)
		  FROM #OneActionTYPEperDay
		) AS a
	WHERE TimeRank=1
;	
--Get the correct record for the day 
----because we don't want the row where TrueAction<>ActionType
DROP TABLE IF EXISTS #HistoryByDay;
SELECT DISTINCT b.MVIPersonSID
	,b.PatientICN
	,b.ChecklistID
	,b.Facility
	,b.ActiveFlag
	,a.Sta3n_History
	,a.ActionDateTime
	,a.ActionDate
	,b.OwnerMatch  
	,b.ActionType 
	,a.TrueAction
	,b.VisitSID
	,b.SecondaryVisitSID
INTO #HistoryByDay
FROM #OneACTIONperDay a
INNER JOIN #OneActionTYPEperDay b ON
	a.MVIPersonSID=b.MVIPersonSID
	AND a.ActionDate=b.ActionDate 
	AND a.TrueAction=b.ActionType
WHERE TrueAction IS NOT NULL

--Duplicate records on subsequent days
DROP TABLE IF EXISTS #RemoveDuplicates
SELECT a.*
	,CASE WHEN a.OwnerMatch=0 AND b.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS Ignore
INTO #RemoveDuplicates
FROM #HistoryByDay a
LEFT JOIN #HistoryByDay b
	ON a.MVIPersonSID=b.MVIPersonSID
	AND a.ActionType=b.ActionType
	AND a.ActionDate BETWEEN DateAdd(day,-1,b.ActionDate) AND DateAdd(day,1,b.ActionDate)
	AND a.ActionDate <> b.ActionDate
	
/*
If 'Entered in Error' (EiE) is entered within 7 days of a new/reactivated flag, ignore record of activation and EiE
If EiE is entered within 7 days of a continuation, ignore record of continuation but keep EiE record to get inactivation date
If EiE is first action, or if it follows an inactivation or another EiE, ignore (flag is already inactive)
If EiE is most recent action, prior action was not inactivation, and flag is not active, keep EiE record to get inactivation date
*/
DROP TABLE IF EXISTS #RemoveErrors;
SELECT DISTINCT CASE WHEN ActionType=5 AND DateDiff(d,CAST(PrevActionDate AS date),CAST(ActionDate AS date)) <=7 AND PrevAction in (1,4) THEN 1 --If flag was activated in past 7 days, ignore activation and entered in error
			WHEN NextAction=5 AND DateDiff(d,CAST(ActionDate AS date),CAST(NextActionDate AS date)) <=7 AND ActionType in (1,2,4) THEN 1 --If flag was activated/continued in past 7 days, ignore activation/continuation. Keep entered in error to inactivate te
			WHEN ActionType=5 AND (PrevAction IS NULL OR PrevAction IN (3,5)) THEN 1
			WHEN ActionType=5 AND ActiveFlag='N' AND NextAction IS NULL THEN 0 --if last action was 'entered in error', treat as inactivation (don't ignore)
			WHEN OwnerMatch=0 AND ActiveFlag='N' AND ActionType in (1,2,4) AND NextAction IS NULL THEN 1 --if non-owning facility took action inconsistent with flag record, ignore
			ELSE 0 END AS Ignore
		,DateDiff(d,PrevActionDate,ActionDate) as DaysSincePrev
		,DateDiff(d,ActionDate,NextActionDate) as DaysUntilNext
		,a.MVIPersonSID
		,a.PatientICN
		,a.ChecklistID
		,a.Facility
		,a.ActiveFlag
		,a.Sta3n_History
		,a.ActionDateTime
		,a.ActionDate
		,a.ActionType
		,a.TrueAction
		,a.VisitSID
		,a.SecondaryVisitSID
		,ownermatch
INTO #RemoveErrors
FROM (
	SELECT PrevActionDate=lead(ActionDate,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDate DESC)
			,PrevAction=lead(ActionType,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDate DESC)
			,TwoPrevAction=lead(ActionType,2) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDate DESC)
			,NextActionDate=lead(ActionDate,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDate)
			,NextAction=lead(ActionType,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDate)
			,*
	FROM #RemoveDuplicates	
	WHERE Ignore = 0
	) a

DELETE FROM #RemoveErrors
WHERE OwnerMatch=0 AND (DaysSincePrev=0 OR DaysUntilNext=0)

DROP TABLE IF EXISTS #cleanhistory;
SELECT a.*
	,EntryCountDesc=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY ActionDateTime desc)
	,EntryCountAsc =ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY ActionDateTime asc)
INTO #cleanhistory
FROM (SELECT DISTINCT MVIPersonSID
	  ,PatientICN
	  ,ChecklistID
	  ,Facility
	  ,Sta3n_History
	  ,ActionDateTime
	  ,TrueAction
	  ,VisitSID
	  ,SecondaryVisitSID
FROM #RemoveErrors AS c
WHERE Ignore=0) a

------------------------------------------------------------------------------
-- 4. DETERMINE CURRENT STATUS BASED ON CLEAN HISTORY
------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Status;
SELECT DISTINCT MVIPersonSID
	,ActiveFlag 
INTO #status
  FROM #WithChecklistID
UNION ALL
  SELECT DISTINCT h.MVIPersonSID
	,ActiveFlag='N'
  FROM #cleanhistory AS h 
  INNER JOIN #corrections AS c ON c.MVIPersonSID=h.MVIPersonSID
  WHERE (EntryCountDesc=1 AND TrueAction=3)
UNION ALL
  SELECT DISTINCT h.MVIPersonSID
	,c.ActiveFlag
  FROM #cleanhistory as h 
  INNER JOIN #corrections AS c ON c.MVIPersonSID=h.MVIPersonSID
  WHERE (EntryCountDesc=1 AND TrueAction IN (1,2,4))
UNION ALL
  SELECT DISTINCT h.MVIPersonSID
	,ActiveFlag='N'
  FROM #cleanhistory AS h 
  INNER JOIN #corrections AS c ON c.MVIPersonSID=h.MVIPersonSID
  WHERE (EntryCountDesc=1 AND TrueAction=5)
;

------------------------------------------------------------------------------
-- 5. CREATE PERMANENT TABLE WITH ALL HISTORY AND CURRENT STATUS
------------------------------------------------------------------------------
DROP TABLE IF EXISTS #StageHistory1
SELECT c.MVIPersonSID
	  ,c.PatientICN
	  ,OwnerChecklistID=c.ChecklistID
	  ,OwnerFacility=c.Facility
	  ,s.ActiveFlag
	  ,InitialActivation=CAST(NULL AS datetime2)
	  ,c.ActionDateTime
	  ,ActionType=CASE WHEN c.TrueAction = 5 THEN 3 -- Entered in Error inactivates the flag
		ELSE c.TrueAction END
	  ,ActionTypeDescription=
		CASE WHEN c.TrueAction = 1 THEN 'New'
			 WHEN c.TrueAction = 2 THEN 'Continued'
			 WHEN c.TrueAction = 3 THEN 'Inactivated'
			 WHEN c.TrueAction = 4 THEN 'Reactivated' 
			 WHEN c.TrueAction = 5 THEN 'Inactivated' END -- Entered in Error inactivates the flag
	  ,HistoricStatus=
		CASE WHEN c.TrueAction IN (1,2,4) THEN 'Y'
			 WHEN c.TrueAction IN (3,5)   THEN 'N' END
	  ,EntryCountDesc=ROW_NUMBER() OVER(PARTITION BY c.MVIPersonSID ORDER BY c.ActionDateTime desc)
	  ,c.EntryCountAsc
	  ,PastWeekActivity=CASE WHEN c.ActionDateTime>DateAdd(d,-8,getdate()) THEN 1 ELSE 0 END
	  ,c.VisitSID
	  ,c.SecondaryVisitSID
INTO #StageHistory1
FROM #cleanhistory AS c
LEFT JOIN #status AS s 
	ON s.MVIPersonSID=c.MVIPersonSID
	
--Update table with the initial activation date
	DROP TABLE IF EXISTS #initial;
	SELECT a.* 
	INTO #initial 
	FROM (
		SELECT MVIPersonSID
			  ,ActionDateTime
			  ,ActionType
			  ,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY ActionDateTime) 
		FROM #StageHistory1
		WHERE ActionType in (1,2,4)
		) AS a
	WHERE RN=1
	


--Update table with most recent activation/reactivation in previous 100 days (to be used to get correct review dates for continuations/transfers that occurred before 90 day +/-10 review mark)
DROP TABLE IF EXISTS #ActivationsOnly
SELECT * 
INTO #ActivationsOnly
FROM #StageHistory1 WHERE ActionType IN (1,4)

DROP TABLE IF EXISTS #ContinuationsInactivationsOnly
SELECT * 
INTO #ContinuationsInactivationsOnly
FROM #StageHistory1 WHERE ActionType IN (2,3)

DROP TABLE IF EXISTS #MostRecentActivation
SELECT DISTINCT a.MVIPersonSID, a.ActionDateTime
	,CASE WHEN b.ActionDateTime IS NULL THEN NULL --if there has not been an activation in previous 100 days
		WHEN c.ActionDateTime IS NOT NULL THEN NULL --if there has been a continuation/inactivation in the 80-100 after activation
		ELSE MAX(b.ActionDateTime) OVER (PARTITION BY a.MVIPersonSID, a.ActionDateTime) END AS MostRecentActivation
INTO #MostRecentActivation
FROM #StageHistory1 a
INNER JOIN #ActivationsOnly b ON a.MVIPersonSID=b.MVIPersonSID --actions where an activation has occurred within previous 100 days
	AND a.ActionType<>3
	AND CAST(a.ActionDateTime AS date) BETWEEN CAST(b.ActionDateTime AS date) AND CAST(DateAdd(day,100,b.ActionDateTime) AS date)
LEFT JOIN #ContinuationsInactivationsOnly c ON b.MVIPersonSID=c.MVIPersonSID --continuations or inactivations that occur between 80-100 days after an activation
	AND CAST(c.ActionDateTime AS date) BETWEEN CAST(DateAdd(day,80,b.ActionDateTime) AS date) AND CAST(DateAdd(day,100,b.ActionDateTime) AS date)
	AND c.ActionDateTime = a.ActionDateTime
	AND c.EntryCountAsc BETWEEN b.EntryCountAsc AND a.EntryCountAsc
	
DELETE FROM #MostRecentActivation WHERE MostRecentActivation IS NULL

--Flag Review notes - to join to health factors to get reference dates
DROP TABLE IF EXISTS #Notes
SELECT t.MVIPersonSID
	,t.VisitSID
	,t.SecondaryVisitSID
	,t.ReferenceDateTime
	,t.EntryDateTime
	,t.Sta3n
INTO #Notes
FROM [Stage].[FactTIUNoteTitles] t WITH (NOLOCK)
WHERE List='HRF_FlagReview_TIU'
AND EntryDateTime > '2022-04-01'

--Update table with next review dates
DROP TABLE IF EXISTS #MonthYearExclude
SELECT CONCAT(MonthName, ' ', CalendarYear) AS MonthYear
INTO #MonthYearExclude
FROM [Dim].[Date] WITH (NOLOCK)

DROP TABLE IF EXISTS #ReviewDates
SELECT
	h.MVIPersonSID
	,h.HealthFactorDateTime
	,CASE WHEN e.MonthYear IS NOT NULL THEN NULL
		ELSE COALESCE(TRY_CAST(h.Comments AS date), TRY_CAST(TRIM('*.~() abcdefghijklmnopqrstuvwxyz:/,-[]#' FROM h.Comments) AS date)) 
		END AS NextReviewDate
	,h.VisitSID
	,COALESCE(n.EntryDateTime,n1.EntryDateTime) AS EntryDateTime
	,COALESCE(n.ReferenceDateTime,n1.ReferenceDateTime) AS ReferenceDateTime
INTO #ReviewDates
FROM [OMHSP_Standard].[HealthFactorSuicPrev] h WITH (NOLOCK)
LEFT JOIN #MonthYearExclude e
	ON h.Comments = e.MonthYear
LEFT JOIN #Notes n 
	ON h.VisitSID = n.VisitSID AND n.Sta3n>200
LEFT JOIN #Notes n1 
	ON h.VisitSID = n1.SecondaryVisitSID AND n1.Sta3n>200
WHERE List='PRF_NextReviewDate_HF'

UNION ALL

SELECT 
	h.MVIPersonSID
	,h.TZDerivedModifiedDateTime as TZModifiedDateTime
	,TRY_CAST(h.TZDerivedNextReviewDateTime AS date) AS NextReviewDate
	,h.DerivedHistoryTrackingSID
	,ISNULL(n.EntryDateTime,n2.EntryDateTime)
	,ISNULL(n.ReferenceDateTime,n2.ReferenceDateTime)
FROM [Cerner].[FactPatientRecordFlag] h WITH (NOLOCK)
LEFT JOIN #Notes n 
	ON h.MVIPersonSID = n.MVIPersonSID
	AND CAST(h.TZDerivedModifiedDateTime as date) = CAST(n.EntryDateTime AS date) AND n.Sta3n=200
LEFT JOIN #Notes n2 
	ON h.MVIPersonSID = n2.MVIPersonSID
	AND CAST(h.TZDerivedModifiedDateTime as date) = CAST(n2.ReferenceDateTime AS date) AND n.Sta3n=200

DROP TABLE IF EXISTS #CombineNoteDates
SELECT MVIPersonSID
	,CAST(EntryDateTime AS date) AS EntryDateTime
	,NextReviewDate
	,VisitSID
INTO #CombineNoteDates
FROM #ReviewDates
UNION
SELECT MVIPersonSID
	,CAST(ReferenceDateTime AS date)
	,NextReviewDate
	,VisitSID
FROM #ReviewDates

--Review date for new and reactivated flags is 90 days (+/- 10 days)
--Review date for continued flags before 4/1/2022 is 7-90 days from flag action
--Review date for continued flags after 4/1/2022 is +/- 10 days from date set in health factor comments, (review date must be within 7-90 days from flag action)
DROP TABLE IF EXISTS #NextReviewDate
SELECT a.MVIPersonSID
	,a.ActionDateTime
	,MIN(CAST(
			CASE WHEN a.ActionType IN (1,4) THEN DATEADD(day,80,a.ActionDateTime) 
			WHEN a.ActionType = 2 AND a.ActionDateTime < '2022-04-01' THEN DATEADD(day,7,a.ActionDateTime)
			WHEN m.MostRecentActivation IS NOT NULL THEN DATEADD(day,80,m.MostRecentActivation)
			WHEN a.ActionType = 2 AND a.ActionDateTime >= '2022-04-01' AND DATEADD(day,-10,COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate)) < DATEADD(day,7,a.ActionDateTime) 
				THEN DATEADD(day,7,a.ActionDateTime)
			WHEN a.ActionType = 2 AND a.ActionDateTime >= '2022-04-01' AND COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate) IS NOT NULL 
				THEN DATEADD(day,-10,COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate))
			ELSE NULL END 
		AS date)) OVER (PARTITION BY a.MVIPersonSID, a.ActionDateTime) AS MinReviewDate
	,MAX(CAST(
			CASE WHEN a.ActionType IN (1,4) THEN DATEADD(day,100,a.ActionDateTime) 
			WHEN a.ActionType = 2 AND a.ActionDateTime < '2022-04-01' THEN DATEADD(day,100,a.ActionDateTime)
			WHEN m.MostRecentActivation IS NOT NULL THEN DATEADD(day,100,m.MostRecentActivation)
			WHEN a.ActionType = 2 AND a.ActionDateTime >= '2022-04-01' AND DATEADD(day,10,COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate)) > DATEADD(day,100,a.ActionDateTime) 
				THEN DATEADD(day,100,a.ActionDateTime)
			WHEN a.ActionType = 2 AND a.ActionDateTime >= '2022-04-01' AND COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate) IS NOT NULL 
				THEN DATEADD(day,10,COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate))			
			ELSE NULL END
		as date)) OVER (PARTITION BY a.MVIPersonSID, a.ActionDateTime) AS MaxReviewDate
	,MAX(CAST(
			CASE WHEN a.ActionType IN (1,4) OR (a.ActionType=2 AND a.ActionDateTime < '2022-04-01') THEN DATEADD(day,90,a.ActionDateTime) 
			WHEN m.MostRecentActivation IS NOT NULL THEN DATEADD(day,90,m.MostRecentActivation)
			WHEN a.ActionType = 2 AND COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate) IS NOT NULL AND a.ActionDateTime >= '2022-04-01' 
				THEN COALESCE(b1.NextReviewDate,b4.NextReviewDate,b2.NextReviewDate,b3.NextReviewDate)			
			ELSE NULL END
		as date)) OVER (PARTITION BY a.MVIPersonSID, a.ActionDateTime)  AS NextReviewDate
	,a.ActionType
	,a.EntryCountAsc
	,a.EntryCountDesc
INTO #NextReviewDate
FROM #StageHistory1 a 
LEFT JOIN #MostRecentActivation AS m
	ON a.MVIPersonSID=m.MVIPersonSID AND a.ActionDateTime=m.ActionDateTime
LEFT JOIN #ReviewDates b1 ON a.VisitSID = b1.VisitSID
	AND CAST(b1.NextReviewDate as date) BETWEEN CAST(DateAdd(day,7,a.ActionDateTime) as date) AND CAST(DATEADD(day,100,a.ActionDateTime) as date)
LEFT JOIN #ReviewDates b4 ON a.SecondaryVisitSID = b4.VisitSID
	AND CAST(b4.NextReviewDate as date) BETWEEN CAST(DateAdd(day,7,a.ActionDateTime) as date) AND CAST(DATEADD(day,100,a.ActionDateTime) as date)
LEFT JOIN #ReviewDates b2 ON a.MVIPersonSID=b2.MVIPersonSID 
	AND CAST(b2.NextReviewDate as date) BETWEEN CAST(DateAdd(day,7,a.ActionDateTime) as date) AND CAST(DATEADD(day,100,a.ActionDateTime) as date)
	AND CAST(a.ActionDateTime as date) = CAST(b2.HealthFactorDateTime AS date)
LEFT JOIN #CombineNoteDates b3 ON a.MVIPersonSID=b3.MVIPersonSID
	AND CAST(b3.NextReviewDate as date) BETWEEN CAST(DateAdd(day,7,a.ActionDateTime) as date) AND CAST(DATEADD(day,100,a.ActionDateTime) as date)
	AND CAST(a.ActionDateTime as date) = CAST(b3.EntryDateTime AS date)
	

DROP TABLE IF EXISTS #FillInMissingDates
SELECT a.MVIPersonSID
	,a.ActionDateTime
	,CASE WHEN a.MinReviewDate IS NULL AND a.ActionDateTime < b.MinReviewDate THEN b.MinReviewDate
		ELSE a.MinReviewDate END AS MinReviewDate
	,CASE WHEN a.MinReviewDate IS NULL AND a.ActionDateTime < b.MinReviewDate THEN b.MaxReviewDate
		ELSE a.MaxReviewDate END AS MaxReviewDate
	,CASE WHEN a.MinReviewDate IS NULL AND a.ActionDateTime < b.MinReviewDate THEN b.NextReviewDate
		ELSE a.NextReviewDate END AS NextReviewDate
INTO #FillInMissingDates
FROM #NextReviewDate a
LEFT JOIN #NextReviewDate b ON a.MVIPersonSID = b.MVIPersonSID
	AND a.EntryCountAsc - 1 = b.EntryCountAsc
	AND a.ActionType = b.ActionType

DROP TABLE IF EXISTS #StageHistory;
SELECT DISTINCT a.MVIPersonSID
	  ,a.PatientICN 
	  ,a.OwnerChecklistID
	  ,a.OwnerFacility
	  ,a.ActiveFlag
	  ,InitialActivation=i.ActionDateTime
	  ,m.MostRecentActivation
	  ,a.ActionDateTime
	  ,a.ActionType
	  ,a.ActionTypeDescription
	  ,a.HistoricStatus
	  ,a.EntryCountDesc
	  ,a.EntryCountAsc
	  ,a.PastWeekActivity
	  ,r.NextReviewDate
	  ,r.MinReviewDate
	  ,r.MaxReviewDate
INTO #StageHistory
FROM #StageHistory1 a
LEFT JOIN #initial AS i 
	ON a.MVIPersonSID=i.MVIPersonSID
LEFT JOIN #MostRecentActivation AS m
	ON a.MVIPersonSID=m.MVIPersonSID AND a.ActionDateTime=m.ActionDateTime
LEFT JOIN #FillInMissingDates AS r
	ON a.MVIPersonSID = r.MVIPersonSID AND a.ActionDateTime = r.ActionDateTime

EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.PRF_HRS_CompleteHistory','#StageHistory'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
