
/*=============================================
-- Author:		Liam Mina
-- Create date: 2021-10-07
-- Description:	This code finds all present active patients with an active or a history of a behavioral or missing patient national patient record flag
	Tables are created for active flags as well as a history of flag action (for active and inactive)
	that is cleaned to account for multiple actions per day, etc.
	This code is based on and modified from Code.PRF_HRS_ActiveAndHistory
-- Updates:
--	2024-11-14	LM	Add flag actions for Refresh Active (8) Refresh Inactive (7) and DBRS#/Other Field Updated (6)

=========================================================================================================================================*/
CREATE PROCEDURE [Code].[PRF_BehavioralMissingPatient]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_BehavioralMissingPatient', @Description = 'Execution of Code.PRF_BehavioralMissingPatient SP'

------------------------------------------------------------------------------
-- 1. GET PATIENTS WITH BEHAVIORAL OR MISSING PATIENT FLAGS AND FACILITY INFO
------------------------------------------------------------------------------
--Get National PRF SIDs for Behavioral or MIssing Patient flags
	DROP TABLE IF EXISTS #FlagTypeSID;
	SELECT DISTINCT NationalPatientRecordFlagSID 
		,NationalPatientRecordFlag
	INTO #FlagTypeSID 
	FROM [Dim].[NationalPatientRecordFlag]
	WHERE NationalPatientRecordFlag IN ('BEHAVIORAL','MISSING PATIENT')
	
--Find all flags using above SIDs (this includes inactives)
	DROP TABLE IF EXISTS #flags;
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,prf.PatientRecordFlagAssignmentSID
		,prf.OwnerInstitutionSID
		,prf.ActiveFlag 
		,f.NationalPatientRecordFlag
	INTO #flags
	FROM #FlagTypeSID f
	INNER JOIN [SPatient].[PatientRecordFlagAssignment] AS prf WITH (NOLOCK)
		ON prf.NationalPatientRecordFlagSID = f.NationalPatientRecordFlagSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK)
		ON prf.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] AS c WITH(NOLOCK)
		ON mvi.MVIPersonSID = c.MVIPersonSID
		
--Add in facility info
DROP TABLE IF EXISTS #WithChecklistID;
SELECT prf.*
	  ,ChecklistID
	  ,Facility
INTO #WithChecklistID 
FROM #flags AS prf
INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
	ON i.InstitutionSID=prf.OwnerInstitutionSID
LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
	ON i.StaPa=c.Sta6aID
ORDER BY ChecklistID
  ;
------------------------------------------------------------------------------
-- 2. FIND DISCREPANCIES, CORRECT TO CREATE A CLEAN COHORT
------------------------------------------------------------------------------
--Find all patients with BOTH ActiveFlag='Y' and ActiveFlag='N' and put their info in a separate table
	DROP TABLE IF EXISTS #discrepancies;
	SELECT a.* 
	INTO #discrepancies
	FROM #WithChecklistID as a
	INNER JOIN ( 
		SELECT MVIPersonSID
			  ,CountFlagSID=COUNT(DISTINCT PatientRecordFlagAssignmentSID)
			  ,CountActiveValue=COUNT(DISTINCT ActiveFlag) 
		FROM #WithChecklistID
		GROUP BY MVIPersonSID, NationalPatientRecordFlag
		HAVING COUNT(DISTINCT ActiveFlag)>1 --where this is a Y and N for the same patient
	  ) AS ct
	ON a.MVIPersonSID=ct.MVIPersonSID
	;

----------FOR THOSE WITHOUT DISCREPANCIES----------
--Remove patients with discrepancies from with checklist ID table
	DELETE FROM #WithChecklistID
	WHERE MVIPersonSID IN (
		SELECT MVIPersonSID 
		FROM #discrepancies
		)
	;--3991
	
----------FOR THOSE WITH DISCREPANCIES----------
--Find the flag record SIDs that contain most recent data for those with conflicting information
	DROP TABLE IF EXISTS #corrections;
	SELECT DISTINCT 
		 d.MVIPersonSID
		,d.NationalPatientRecordFlag
		,d.PatientRecordFlagAssignmentSID
		,d.OwnerInstitutionSID
		,d.ActiveFlag
		,d.ChecklistID
		,d.Facility
	INTO #corrections
	FROM (
		SELECT d.MVIPersonSID
			  ,d.PatientRecordFlagAssignmentSID
			  ,PatientRecordFlagHistoryAction
			  ,NationalPatientRecordFlag
			  ,MinDate=min(convert(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.PatientRecordFlagAssignmentSID,d.NationalPatientRecordFlag)
			  ,MaxDate=max(convert(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.PatientRecordFlagAssignmentSID,d.NationalPatientRecordFlag)
			  ,MinMin =min(convert(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.NationalPatientRecordFlag)
			  ,MaxMax =max(convert(date,ActionDateTime)) OVER (PARTITION BY d.MVIPersonSID,d.NationalPatientRecordFlag)
		FROM #discrepancies as d
		INNER JOIN [SPatient].[PatientRecordFlagHistory] AS h WITH (NOLOCK) 
			ON d.PatientRecordFlagAssignmentSID=h.PatientRecordFlagAssignmentSID
		) AS m
	INNER JOIN #discrepancies AS d ON m.PatientRecordFlagAssignmentSID=d.PatientRecordFlagAssignmentSID
	WHERE m.MaxMax=m.MaxDate--only use the flag records where there is data up to the latest date possible
	;

--COMBINE CORRECTIONS WITH PREVIOUS TABLE
DROP TABLE IF EXISTS #final;
SELECT MVIPersonSID
	  ,NationalPatientRecordFlag
	  ,PatientRecordFlagAssignmentSID
	  ,OwnerInstitutionSID
	  ,ActiveFlag
	  ,ChecklistID
	  ,Facility 
  INTO #final
  FROM #WithChecklistID
UNION ALL
  SELECT MVIPersonSID
	  ,NationalPatientRecordFlag
	  ,PatientRecordFlagAssignmentSID
	  ,OwnerInstitutionSID
	  ,ActiveFlag
	  ,ChecklistID
	  ,Facility 
  FROM #corrections;
  
------------------------------------------------------------------------------
-- 3. GET HISTORY OF ACTIONS, THEN CLEAN
------------------------------------------------------------------------------
--Get all actions in history for the flag SIDs identified in previous section 
	--add fields for sorting
	DROP TABLE IF EXISTS #history;
	SELECT f.MVIPersonSID
		  ,f.ChecklistID
		  ,f.Facility
		  ,f.NationalPatientRecordFlag
		  ,f.ActiveFlag
		  ,Sta3n_History=h.Sta3n
		  ,t.TimeZone
		  ,t.HoursAdd --calculated in subquery to adjust time for time zone because entries are repeated for each facility
		  ,h.ActionDateTime
		  ,AdjDateTime=DateAdd(hh,t.HoursAdd,h.ActionDateTime) 
		  ,ActionDate=cast(h.ActionDateTime as date)
		  ,AdjDate=cast(DateAdd(hh,t.HoursAdd,h.ActionDateTime) as date)
		  ,h.TIUDocumentSID 
		  ,OwnerMatch=CASE WHEN left(f.Checklistid,3)=cast(h.Sta3n as varchar) THEN 1 ELSE 0 END 
		  ,ActionType=h.PatientRecordFlagHistoryAction
		  ,ActionPriority=CASE --priority for when actions have EXACT same datetime - assume active (rare, but happens)
				WHEN PatientRecordFlagHistoryAction='1' THEN 1 
				WHEN PatientRecordFlagHistoryAction='4' THEN 2
				WHEN PatientRecordFlagHistoryAction='2' THEN 3 
				WHEN PatientRecordFlagHistoryAction='6' THEN 4
				WHEN PatientRecordFlagHistoryAction='8' THEN 5
				WHEN PatientRecordFlagHistoryAction='3' THEN 6  	
				WHEN PatientRecordFlagHistoryAction='5' THEN 7 
				WHEN PatientRecordFlagHistoryAction='7' THEN 8
			  END
	INTO #history
	FROM #final AS f
	LEFT JOIN [SPatient].[PatientRecordFlagHistory] AS h WITH (NOLOCK)
		ON f.PatientRecordFlagAssignmentSID=h.PatientRecordFlagAssignmentSID
	LEFT JOIN (
			SELECT Sta3n
				  ,TimeZone
				  ,HoursAdd=CASE 
						WHEN TimeZone='Central Standard Time'  THEN 1
						WHEN TimeZone='Mountain Standard Time' THEN 2 
						WHEN TimeZone='Pacific Standard Time'  THEN 3 
						WHEN TimeZone='Alaskan Standard Time' THEN 4
						WHEN TimeZone='Hawaiian Standard Time' THEN 6
						WHEN TimeZone='Taipei Standard Time' THEN -12
					  ELSE 0 END
			FROM [Dim].[Sta3n] WITH (NOLOCK)
			) as t on t.Sta3n=h.Sta3n  --where h.PatientRecordFlagAssignmentSID is null (10 rows)
	WHERE h.PatientRecordFlagAssignmentSID > 0 
	--AND h.PatientRecordFlagHistoryAction IN ('1','2','3','4','5') --Ignore NULL entries that have no useful data, and ActionType 6-8 which don't correspond with a relevant flag action
	;  
--Get 1 record per day and actiontype for each Patient
	DROP TABLE IF EXISTS #OneActionTYPEperDay;
	SELECT * INTO #OneActionTYPEperDay
	FROM ( 
		SELECT *
			  ,RN=Row_Number() OVER(PARTITION BY MVIPersonSID,AdjDate,ActionType, NationalPatientRecordFlag ORDER BY OwnerMatch DESC,AdjDateTime DESC,TIUDocumentSID DESC)
		FROM #history
		) AS r  
	WHERE RN=1 --The last time that type of action was taken on that specific day
	;

--Get only 1 record per DAY (action type that occurred at the latest time)
	DROP TABLE IF EXISTS #OneACTIONperDay;
	SELECT *
		  ,TrueAction=CASE 
			WHEN TimeRank=1 THEN (CASE 
					WHEN ActionType in (1,3) 
					  THEN ActionType --if the last action of the day was Activate or Deactivate, that's the action for the day
					WHEN ActionType=5 and min(PreviousAction) OVER(PARTITION BY MVIPersonSID, ActionDate, NationalPatientRecordFlag)<>5 
					  THEN NULL --if other actions were taken, then assume 5 cancels out that day's actions and ignore the day
					WHEN ActionType in (2,4) and min(PreviousAction) OVER(PARTITION BY MVIPersonSID, ActionDate, NationalPatientRecordFlag)=1 
					  THEN 1 --if a flag was continued, but was new at an earlier time, then count as new
					WHEN ActionType=2 and max(PreviousAction) OVER(PARTITION BY MVIPersonSID, ActionDate, NationalPatientRecordFlag)=4 
					  THEN 4 --if a flag was continued, but was reactivated at an earlier time, then count as reactivated
					ELSE ActionType
				  END )
			 END
	INTO #OneACTIONperDay
	FROM (SELECT *
			  ,TimeRank=row_number() OVER(PARTITION BY MVIPersonSID,ActionDate, NationalPatientRecordFlag ORDER BY AdjDateTime DESC,ActionPriority)
 			  ,PreviousAction=lead(ActionType,1) OVER(PARTITION BY MVIPersonSID,ActionDate, NationalPatientRecordFlag ORDER BY AdjDateTime DESC,ActionPriority)
		  FROM #OneActionTYPEperDay
		) AS a
	WHERE TimeRank=1
;
--Get the correct record for the day 
----because we don't want the row where TrueAction<>ActionType
DROP TABLE IF EXISTS #HistoryByDay;
SELECT b.*
	,a.TrueAction
INTO #HistoryByDay
FROM #OneACTIONperDay AS a
INNER JOIN #OneActionTYPEperDay AS b ON
	a.MVIPersonSID=b.MVIPersonSID
	AND a.ActionDate=b.ActionDate 
	AND a.TrueAction=b.ActionType
	AND a.NationalPatientRecordFlag=b.NationalPatientRecordFlag
WHERE TrueAction IS NOT NULL


DROP TABLE IF EXISTS #RemoveErrors;
SELECT CASE WHEN ActionType=5 AND PrevAction IS NULL THEN 1
			WHEN ActionType=5 AND ActiveFlag='N' AND PrevAction in (1,2,4,6,8) AND TwoPrevAction in (1,2,4,6,8) AND NextAction IS NULL THEN 0 --if last action was 'entered in error' and flag is not active, treat as inactivation (don't ignore)
			WHEN ActionType=5 AND DateDiff(d,PrevActionDate,ActionDate) <=7 AND PrevAction in (1,2,4,6,8) THEN 1
			WHEN NextAction=5 AND DateDiff(d,ActionDate,NextActionDate) <=7 AND ActionType in (1,2,4,6,8) THEN 1
			WHEN OwnerMatch=0 AND ActiveFlag='N' AND ActionType in (1,2,4,6,8) AND NextAction IS NULL THEN 1 --if non-owning facility took action inconsistent with flag record, ignore
			ELSE 0 END AS Ignore
		,DateDiff(d,PrevActionDate,ActionDate) as DaysSincePrev
		,DateDiff(d,ActionDate,NextActionDate) as DaysUntilNext
		,a.MVIPersonSID
		,a.ChecklistID
		,a.Facility
		,a.NationalPatientRecordFlag
		,a.ActiveFlag
		,a.Sta3n_History
		,a.ActionDateTime
		,a.ActionDate
		,a.ActionType
		,a.TrueAction
INTO #RemoveErrors
FROM (
	SELECT PrevActionDate=lead(ActionDate,1) OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDate DESC)
			,PrevAction=lead(ActionType,1) OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDate DESC)
			,TwoPrevAction=lead(ActionType,2) OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDate DESC)
			,NextActionDate=lead(ActionDate,1) OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDate)
			,NextAction=lead(ActionType,1) OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDate)
			,*
	FROM #HistoryByDay	
	) a
	

DROP TABLE IF EXISTS #cleanhistory;
SELECT MVIPersonSID
	  ,ChecklistID
	  ,Facility
	  ,Sta3n_History
	  ,NationalPatientRecordFlag
	  ,ActionDateTime
	  ,TrueAction
	  ,EntryCountDesc=row_number() OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDateTime DESC)
	  ,EntryCountAsc =row_number() OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDateTime ASC)
INTO #cleanhistory
FROM #RemoveErrors AS c
WHERE Ignore=0
------------------------------------------------------------------------------
-- 4. DETERMINE CURRENT STATUS BASED ON CLEAN HISTORY
------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Status;
SELECT DISTINCT h.MVIPersonSID
	,h.ActiveFlag
	,h.NationalPatientRecordFlag  
INTO #status
FROM #WithChecklistID AS h
UNION ALL
SELECT DISTINCT h.MVIPersonSID
	,ActiveFlag='N'
	,h.NationalPatientRecordFlag 
FROM #cleanhistory AS h 
INNER JOIN #corrections AS c 
	ON c.MVIPersonSID=h.MVIPersonSID 
	AND h.NationalPatientRecordFlag=c.NationalPatientRecordFlag
WHERE (EntryCountDesc=1 and TrueAction IN (3,7))
UNION ALL
SELECT DISTINCT h.MVIPersonSID
	,c.ActiveFlag
	,h.NationalPatientRecordFlag 
FROM #cleanhistory AS h 
INNER JOIN #corrections AS c 
	ON c.MVIPersonSID=h.MVIPersonSID 
	AND h.NationalPatientRecordFlag=c.NationalPatientRecordFlag
WHERE (EntryCountDesc=1 and TrueAction in (1,2,4,6,8))
UNION ALL
SELECT DISTINCT h.MVIPersonSID
	,ActiveFlag = 'N'
	,h.NationalPatientRecordFlag 
FROM #cleanhistory AS h 
INNER JOIN #corrections AS c 
	ON c.MVIPersonSID=h.MVIPersonSID 
	AND h.NationalPatientRecordFlag=c.NationalPatientRecordFlag
WHERE (EntryCountDesc=1 and TrueAction=5)
;

------------------------------------------------------------------------------
-- 5. CREATE PERMANENT TABLE WITH ALL HISTORY AND CURRENT STATUS
------------------------------------------------------------------------------
DROP TABLE IF EXISTS #StageHistory1
SELECT c.MVIPersonSID
	  ,OwnerChecklistID=c.ChecklistID
	  ,OwnerFacility=c.Facility
	  ,c.NationalPatientRecordFlag
	  ,s.ActiveFlag
	  ,InitialActivation=CAST(NULL as datetime2)
	  ,c.ActionDateTime
	  ,ActionType=c.TrueAction
	  ,ActionTypeDescription=
		CASE WHEN c.TrueAction = 1 THEN 'New'
			 WHEN c.TrueAction = 2 THEN 'Continued'
			 WHEN c.TrueAction = 3 THEN 'Inactivated'
			 WHEN c.TrueAction = 4 THEN 'Reactivated' 
			 WHEN c.TrueAction = 5 THEN 'Previous Action Entered in Error' 
			 WHEN c.TrueAction = 6 THEN 'DBRS#/Other Field Updated'
			 WHEN c.TrueAction = 7 THEN 'Refresh Inactive'
			 WHEN c.TrueAction = 8 THEN 'Refresh Active' END
	  ,HistoricStatus=
		CASE WHEN c.TrueAction in (1,2,4,6,8) THEN 'Y'
			 WHEN c.TrueAction in (3,5,7)   THEN 'N' END
	  ,EntryCountDesc=row_number() OVER(PARTITION BY c.MVIPersonSID, c.NationalPatientRecordFlag ORDER BY c.ActionDateTime DESC)
	  ,c.EntryCountAsc
INTO #StageHistory1
FROM #cleanhistory AS c
LEFT JOIN #status AS s 
	ON s.MVIPersonSID=c.MVIPersonSID 
	AND s.NationalPatientRecordFlag=c.NationalPatientRecordFlag

--Update table with the initial activation date
	DROP TABLE IF EXISTS #initial;
	SELECT * 
	INTO #initial 
	FROM (
		SELECT MVIPersonSID
			  ,ActionDateTime
			  ,ActionType
			  ,NationalPatientRecordFlag
			  ,RN=Row_Number() OVER(PARTITION BY MVIPersonSID, NationalPatientRecordFlag ORDER BY ActionDateTime) 
		FROM #StageHistory1
		WHERE ActionType in (1,2,4)
		) AS a
	WHERE RN=1 
	  ;

DROP TABLE IF EXISTS #StageHistory;
SELECT a.MVIPersonSID
	  ,a.OwnerChecklistID
	  ,a.OwnerFacility
	  ,a.NationalPatientRecordFlag
	  ,a.ActiveFlag
	  ,InitialActivation=i.ActionDateTime
	  ,a.ActionDateTime
	  ,a.ActionType
	  ,a.ActionTypeDescription
	  ,a.HistoricStatus
	  ,a.EntryCountDesc
	  ,a.EntryCountAsc
INTO #StageHistory
FROM #StageHistory1 a
LEFT JOIN #initial AS i 
	ON i.MVIPersonSID=a.MVIPersonSID AND i.NationalPatientRecordFlag=a.NationalPatientRecordFlag


EXEC [Maintenance].[PublishTable] 'PRF.BehavioralMissingPatient','#StageHistory'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END