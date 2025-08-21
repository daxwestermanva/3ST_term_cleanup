


/*=============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2018-02-14
-- Description:	Information is joined into one table, with row per patient from 
	current flags, outpatient visits, and, inpatient stays.
	Then note titles are added and metric calculated.
	Data is then filtered and transformed for dashboard dataset query. (3 tables)
-- Modifications:
--  2018-08-07	RAS: Added HRF_SP_ReviewDecline_TIU to note title query so that all review notes appear on dashboard
--  2018-10-16	RAS: Safety Plans removed from TIU query -- using new Present.SP_SafetyPlan instead. Added MVIPersonSID and removed PatientSID.
--	2019-02-19	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--  2019-04-05  LM: Added SBOR and CSRE notes to NoteTitleDetail
--  2019-05-09  LM: Updated date range for inpatient safety plans
--	2020-01-06	RAS: Added code to exclude SP_RefusedSafetyPlanning_HF=1 
--	2020-01-10	LM: Changed source of SBR details from note titles to OMHSP_Standard.SuicideOverdoseEvent
--	2020-02-07	LM: Added Sta6a for PCP and MHTC to allow filtering on report
--	2020-03-25	RAS: Changed residential treating specialty to RRTP treating specialty
--  2020-05-12	LM: Added patients with flags inactivated in the past year, to support new caring contacts requirement
--	2020-08-11	LM: Restructured code to streamline and make overlay with Cerner data easier
--	2020-09-16	LM: Pointing to _VM tables and overlaying Cerner data
--	2021-04-20	LM: Adding patients who are deceased but still have active flags
--	2021-09-13	LM: Removed deleted TIU documents
--	2021-09-15	AI:	Enclave Refactoring - Counts confirmed
--	2021-09-23	LM:	Added health factor data from PRF review note
--	2021-12-08	LM: Added MostRecentActivation date for flags activated in past 100 days and not yet reviewed between 80-100 days.
					Use this as the anchor date for safety plan, MH visits, flag reviews when flag is transferred or prematurely continued before 80 days 
					(instead of continuation date), to align with metrics.
--	2022-05-11	LM: Excluded local PRF review note titles before 4/2/22; all facilities are required to use national note title after this date.
--	2022-06-16	LM: Overlaid next flag review date from Cerner data
--	2022-08-05	LM: Identified flag records that are different between VistA and Cerner
--	2023-01-22	LM:	Added indicator from health factors that patient should not receive caring letters 
--	2023-05-04	LM: Added successful outreach attempts from SRM note
--	2023-06-22	LM:	Get next review date from OMHSP_Standard.PRF_HRS_CompleteHistory
--	2024-01-16	LM: Differentiate patients getting national vs local caring letters - can be updated in Feb 2025 when local caring letters have been fully phased out
--	2024-06-20	LM: Prevent multiple rows from populating if patient has historic VistA flag record and discrepant current Cerner flag record
--	2024-10-17	LM: Add SP2.0 consult
--	2025-03-06	LM: Add MHTC Team; Update caring letters query since all HRF caring letters are national now
--	2025-06-16	LM: Incorporate code from PRF_HRS_Inpat_Detail, using AdmitDateTime and DischargeDateTime instead of BSDateTimes
  =============================================*/
CREATE PROCEDURE [Code].[PRF_HRS_PatientReport_v02]
AS
BEGIN 

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_HRS_PatientReport', @Description = 'Execution of Code.PRF_HRS_PatientReport SP'

/****
COHORT FOR REPORT
****/
--Get cohort
DROP TABLE IF EXISTS #Cohort
SELECT MVIPersonSID
INTO #cohort
-- Any active flag in past year 
FROM [App].[fn_PRF_HRS_ActivePeriod] (DATEADD(YEAR,-1,CAST(GetDate() AS DATE)),CAST(GetDate() AS DATE))
UNION 
SELECT MVIPersonSID
FROM [PRF_HRS].[ActivePRF] WITH(NOLOCK) --currently active

--Latest record from history, add facility, exclude decedents
DROP TABLE IF EXISTS #CohortDetailVistA
SELECT h.MVIPersonSID
	,h.InitialActivation
	,h.ActionDateTime
	,CASE WHEN h.ActiveFlag='N' THEN 3
		ELSE h.ActionType END AS ActionType
	,CASE WHEN h.ActiveFlag='N' THEN 'Inactivated'
		ELSE h.ActionTypeDescription END AS ActionTypeDescription
	,h.MostRecentActivation
	,h.NextReviewDate
	,h.MinReviewDate
	,h.MaxReviewDate
	,h.ActiveFlag
	,h.OwnerChecklistID
	,c.ADMPARENT_FCDM AS OwnerFacility
	,mp.PatientICN
	,mp.SourceEHR
	,CASE WHEN h.ActiveFlag = 'N' AND h.ActionType in (1,2,4) AND h.ActionDateTime < DateAdd(Year,-1,GetDate()) THEN 1
		ELSE 0 END AS Ignore --When flag is inactive and last action was activation/continuation/reactivation, keep on 'inactivated' list for 1 year after the last flag action
	,DateOfDeath_Combined AS DateOfDeath
	,CernerVistADiff = CAST(NULL as varchar(100))
INTO #CohortDetailVistA
FROM #Cohort AS a
INNER JOIN [OMHSP_Standard].[PRF_HRS_CompleteHistory] AS h WITH(NOLOCK) 
	ON h.MVIPersonSID=a.MVIPersonSID 
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON mp.MVIPersonSID=a.MVIPersonSID
INNER JOIN [LookUp].[ChecklistID] AS c WITH(NOLOCK) 
	ON c.ChecklistID=h.OwnerChecklistID
WHERE (mp.DateOfDeath_Combined IS NULL OR h.ActiveFlag='Y')
	AND h.EntryCountDesc=1
	AND mp.TestPatient=0

DELETE FROM #CohortDetailVistA
WHERE Ignore=1


--Get records that are mismatching in VistA and Cerner
DROP TABLE IF EXISTS #CernerFlags
SELECT TOP 1 WITH TIES a.*
	,CASE WHEN l.StaPa IS NULL THEN 1 ELSE 0 END AS Ignore
INTO #CernerFlags
FROM [Cerner].[FactPatientRecordFlag] a WITH (NOLOCK)
INNER JOIN [Cerner].[FactUtilizationStopCode] o WITH (NOLOCK) --ignore patients who have had no contact at Cerner site; syndicated data is incorrect in some of these cases
	ON a.MVIPersonSID=o.MVIPersonSID
LEFT JOIN [Lookup].[ChecklistID] l WITH (NOLOCK)
	ON l.STAPA=a.StaPa AND l.IOCDate < getdate()
WHERE a.DerivedPRFType = 'High Risk for Suicide' 
AND a.StaPa <> '459' --Hawaii flags still managed through VistA; only inpatient unit on Cerner currently
ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.TZDerivedModifiedDateTime DESC, DerivedHistoryTrackingSID DESC)

UPDATE #CernerFlags
SET ActiveFlag = 'N'
WHERE DerivedActionType = 3

DELETE FROM #CernerFlags
WHERE Ignore=1

DROP TABLE IF EXISTS #ActiveCernerNotVistA
SELECT TOP 1 WITH TIES
	a.MVIPersonSID
	,a.DerivedActionType as ActionType
	,a.DerivedActionTypeDescription as ActionTypeDescription 
	,a.StaPa
	,a.TZDerivedModifiedDateTime 
	,a.DerivedNextReviewDateTime
	,MinReviewDate=DateAdd(day,-10,a.DerivedNextReviewDateTime)
	,MaxReviewDate=DateAdd(day,10,a.DerivedNextReviewDateTime)
	,CernerVistADiff = 'Flag is active in Cerner and inactive in VistA'
INTO #ActiveCernerNotVistA
FROM #CernerFlags a
LEFT JOIN #CohortDetailVistA b on a.MVIPersonSID = b.MVIPersonSID
WHERE a.DerivedPRFType = 'High Risk for Suicide' AND a.ActiveFlag = 'Y'
AND (b.MVIPersonSID IS NULL OR (b.ActiveFlag = 'N' AND b.ActionDateTime < DATEADD(day,-2,CAST(getdate() AS date)))) --prevent error message from displaying just because of timing issues
ORDER BY ROW_NUMBER() OVER (PARTITION BY b.MVIPersonSID ORDER BY a.DerivedModifiedDateTime DESC, CASE WHEN a.DerivedActionType=2 THEN 1 ELSE 2 END) --if activation and continuation happened at exactly same time, use continuation

DROP TABLE IF EXISTS #ActiveVistANotCerner
SELECT 
	a.MVIPersonSID
	,a.DerivedActionType AS CernerActionType
	,a.DerivedActionTypeDescription AS CernerActionDescription
	,a.StaPa
	,a.TZDerivedModifiedDateTime
	,CernerVistADiff = 'Flag is inactive in Cerner and active in VistA'
INTO #ActiveVistANotCerner
FROM #CernerFlags a
INNER JOIN #CohortDetailVistA b on a.MVIPersonSID = b.MVIPersonSID
WHERE a.DerivedPRFType = 'High Risk for Suicide' AND a.ActiveFlag = 'N'
AND b.ActiveFlag = 'Y'
ORDER BY ROW_NUMBER() OVER (PARTITION BY b.MVIPersonSID ORDER BY a.DerivedModifiedDateTime DESC) --use derivedModifiedDateTime to sort because it is not time-zone adjusted

DROP TABLE IF EXISTS #MismatchActionDates
SELECT TOP 1 WITH TIES
	a.MVIPersonSID
	,a.DerivedActionType AS CernerActionType
	,a.DerivedActionTypeDescription AS CernerActionDescription
	,c.ChecklistID AS CernerOwnerChecklistID
	,c.ADMPARENT_FCDM AS CernerOwnerFacility
	,b.ActionDateTime
	,a.TZDerivedModifiedDateTime
	,b.CernerVistADiff --this needs more investigation
		--CASE
		--WHEN a.StaPa <> b.OwnerChecklistID AND CAST(a.TZDerivedModifiedDateTime as date)>CAST(b.ActionDateTime AS date)
		--	THEN CONCAT('VistA flag owned by ',b.OwnerChecklistID,'; Cerner flag owned by ',c.ChecklistID,'. Flag action on ',CAST(a.TZDerivedModifiedDateTime AS date),' missing from VistA record.')
		--WHEN a.StaPa <> b.OwnerChecklistID AND CAST(a.TZDerivedModifiedDateTime as date)<CAST(b.ActionDateTime AS date)
		--	THEN CONCAT('VistA flag owned by ',b.OwnerChecklistID,'; Cerner flag owned by ',c.ChecklistID,'. Flag action on ',CAST(b.ActionDateTime AS date),' missing from Cerner record.')
		--WHEN a.StaPa <> b.OwnerChecklistID THEN CONCAT('VistA flag owned by ',b.OwnerChecklistID,'; Cerner flag owned by ',c.ChecklistID)
		--WHEN CAST(a.TZDerivedModifiedDateTime as date)>CAST(b.ActionDateTime AS date)
		--	THEN CONCAT('Flag action on ',CAST(a.TZDerivedModifiedDateTime AS date),' missing from VistA record.')
		--WHEN CAST(a.TZDerivedModifiedDateTime as date)<CAST(b.ActionDateTime AS date)
		--	THEN CONCAT('Flag action on ',CAST(b.ActionDateTime AS date),' missing from Cerner record.')
		--	ELSE NULL END
	,CASE WHEN a.StaPa <> b.OwnerChecklistID THEN 1 ELSE 0 END AS DifferentFacility
	,CASE WHEN a.TZDerivedModifiedDateTime > b.ActionDateTime THEN 'V'
		WHEN b.ActionDateTime > a.TZDerivedModifiedDateTime THEN 'M'
		END AS MostRecentActionMissingFrom
INTO #MismatchActionDates
FROM #CernerFlags a
INNER JOIN #CohortDetailVistA b on a.MVIPersonSID = b.MVIPersonSID 
	AND (a.StaPa <> b.OwnerChecklistID
	OR CAST(a.TZDerivedModifiedDateTime as date) <> CAST(b.ActionDateTime as date))
INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) 
	ON a.StaPa = c.StaPa
WHERE a.DerivedPRFType = 'High Risk for Suicide' AND a.ActiveFlag = 'Y'
AND b.ActiveFlag = 'Y'
ORDER BY ROW_NUMBER() OVER (PARTITION BY b.MVIPersonSID ORDER BY a.DerivedModifiedDateTime DESC)

--For patients with an active flag in Cerner but not Vista, insert them into the cohort and flag their record
--For patients with an active flag in VistA but not Cerner, keep them in the cohort and flag their record
--For patients with an active flag in both EHRs but with different action dates or owning facilities, keep them in the cohort and flag their record

--ALTER TABLE #CohortDetail
--ADD CernerVistADiff varchar(20)
--   ,CernerActionType smallint
--   ,CernerActionDateTime datetime
--   ,CernerOwnerChecklistID varchar(5)
--;

--Remove historic record from #CohortDetailVistA when there is a newer record in Cerner before adding Cerner record
DELETE FROM #CohortDetailVistA 
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #ActiveCernerNotVistA)


INSERT INTO #CohortDetailVistA
SELECT a.MVIPersonSID
	,InitialActivation = NULL
	,TZDerivedModifiedDateTime AS ActionDateTime
	,ActionType
	,ActionTypeDescription
	,MostRecentActivation = NULL
	,DerivedNextReviewDateTime
	,MinReviewDate
	,MaxReviewDate
	,ActiveFlag = 'Y'
	,b.ChecklistID AS OwnerChecklistID
	,b.ADMPARENT_FCDM AS OwnerFacility
	,mp.PatientICN
	,mp.SourceEHR
	,Ignore  = 0
	,mp.DateOfDeath_Combined AS DateOfDeath
	,a.CernerVistADiff
FROM #ActiveCernerNotVistA a
INNER JOIN Lookup.ChecklistID b  WITH (NOLOCK)
	ON a.StaPa = b.StaPa
INNER JOIN Common.MasterPatient mp WITH (NOLOCK)
	ON a.MVIPersonSID = mp.MVIPersonSID

UPDATE #CohortDetailVistA
SET CernerVistADiff = 'Flag is inactive in Cerner and active in VistA'
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #ActiveVistANotCerner)

DROP TABLE IF EXISTS #CohortDetail
SELECT DISTINCT a.MVIPersonSID
	,a.InitialActivation
	,a.ActionDateTime
	,a.ActionType
	,a.ActionTypeDescription
	,a.MostRecentActivation
	,a.NextReviewDate
	,a.MinReviewDate
	,a.MaxReviewDate
	,a.ActiveFlag
	,a.OwnerChecklistID
	,a.OwnerFacility
	,a.PatientICN
	,a.SourceEHR
	,a.Ignore
	,a.DateOfDeath
	,CASE WHEN l.StaPa IS NULL THEN NULL ELSE ISNULL(b.CernerVistADiff, a.CernerVistADiff) END AS CernerVistADiff
	,CASE WHEN DifferentFacility=1 THEN b.CernerOwnerChecklistID ELSE NULL END AS CernerOwnerChecklistID
INTO #CohortDetail
FROM #CohortDetailVistA a
LEFT JOIN #MismatchActionDates b ON a.MVIPersonSID = b.MVIPersonSID
LEFT JOIN [Lookup].[ChecklistID] l WITH (NOLOCK) ON a.OwnerChecklistID=l.ChecklistID AND l.IOCDate < getdate()


UPDATE #CohortDetail
SET CernerVistADiff = NULL
WHERE CAST(ActionDateTime as date) >= DATEADD(day,-2,CAST(getdate() AS date))

-------------------------------------------------------
-- SAFETY PLAN METRIC
-------------------------------------------------------
--could get a compare date for safety plans that is either the last action date OR, for those that are continued, the most recent new/reactivation???
--Each inpatient stay with each SP and whether or not it met
DROP TABLE IF EXISTS #InpatDates;
SELECT DISTINCT 
	hrf.MVIPersonSID
	,hrf.InitialActivation
	,hrf.ActionDateTime as LastActionDateTime
	,inp.AdmitDateTime
	,inp.DischargeDateTime
	,FlaggedInpt=CASE 
		WHEN ISNULL(hrf.MostRecentActivation,hrf.ActionDateTime) between DateAdd(d,-7,cast(inp.AdmitDateTime as date)) and ISNULL(inp.DischargeDateTime,cast(GetDate() as date)) 
		THEN 1 ELSE 0 END
INTO #InpatDates
FROM [Common].[InpatientRecords] AS inp WITH(NOLOCK)
INNER JOIN [PRF_HRS].[ActivePRF] AS hrf WITH(NOLOCK) 
	ON hrf.MVIPersonSID=inp.MVIPersonSID 
	AND ((inp.AdmitDateTime >=DateAdd(d,-30,hrf.InitialActivation) OR inp.DischargeDateTime>=hrf.InitialActivation) 
		OR DischargeDateTime IS NULL)	

DROP TABLE IF EXISTS #inptSP;
SELECT DISTINCT 
	i.MVIPersonSID
	,i.InitialActivation
	,i.LastActionDateTime 
	,c.MostRecentActivation
	,i.AdmitDateTime
	,i.DischargeDateTime
	,s.SafetyPlanDateTime AS ActionDateTime
	,CASE WHEN MostRecentActivation IS NULL THEN NULL
	WHEN (s.SafetyPlanDateTime >= i.AdmitDateTime AND (CAST(s.SafetyPlanDateTime AS date) <= CAST(i.DischargeDateTime AS DATE) OR DischargeDateTime IS NULL)) --before end of day on discharge date
		OR ABS(DateDiff(d,c.MostRecentActivation,s.SafetyPlanDateTime)) < 8 
		THEN 1 --met
		WHEN i.DischargeDateTime IS NOT NULL 
			AND (s.SafetyPlanDateTime IS NULL OR CAST(s.SafetyPlanDateTime as date) > CAST (i.DischargeDateTime as date)) 
			AND DateDiff(d,c.MostRecentActivation,getdate()) >= 8 
			THEN 0
		WHEN i.DischargeDateTime IS NULL OR DateDiff(d,c.MostRecentActivation,getdate()) < 8 THEN -1 --still time allowed for completion
		ELSE 0 --not met
		END AS SP_Met
	,ABS(DateDiff(DAY,c.MostRecentActivation,s.SafetyPlanDateTime)) AS DaysBetween
	,SP_Inpt=1
INTO #inptSP
FROM #InpatDates AS i WITH(NOLOCK)
INNER JOIN #CohortDetail AS c WITH(NOLOCK)
	ON i.MVIPersonSID=c.MVIPersonSID
LEFT JOIN (SELECT * FROM [OMHSP_Standard].[SafetyPlan] WITH(NOLOCK) 
	WHERE SP_RefusedSafetyPlanning_HF=0	
	AND (TIUDocumentDefinition LIKE '%SUICIDE PREVENTION SAFETY PLAN%' OR TIUDocumentDefinition = 'VA Safety Plan' OR SafetyPlanDateTime < '2022-06-13')) s 
	ON i.MVIPersonSID=s.MVIPersonSID
WHERE i.FlaggedInpt=1 

--Get rid of possible duplicates from above
DROP TABLE IF EXISTS #inptSP_met;
SELECT * 
INTO #inptSP_met
FROM (
	SELECT *  --for each discharge get the first SP that met criteria or else the one closest to meeting
		,RN=Row_Number() OVER(Partition By MVIPersonSID order by CASE WHEN DischargeDateTime IS NULL THEN 0 ELSE 1 END, DischargeDateTime desc
			,CASE WHEN SP_Met=1 THEN 1 WHEN SP_Met=-1 THEN 2 WHEN SP_Met=0 THEN 3 END,DaysBetween,ActionDateTime)
	FROM #inptSP
	) AS a
WHERE RN=1

--People NOT flagged during inpatient stay
DROP TABLE IF EXISTS #sp;
SELECT DISTINCT f.MVIPersonSID,f.PatientICN,f.ActionDateTime AS LastActionDateTime,SafetyPlanDateTime AS ActionDateTime, MostRecentActivation
		--,SP_met=CASE WHEN DateDiff(d,LastActionDateTime,ActionDateTime) between -7 AND 7 THEN 1 ELSE 0 END
		,DaysBetween=ABS(DateDiff(d,cast(f.MostRecentActivation as date),cast(d.SafetyPlanDateTime as date)))
		,DaysBetweenFlag=ABS(DateDiff(d,cast(f.MostRecentActivation as date),cast(getdate() as date)))
INTO #sp
FROM #CohortDetail AS f
LEFT JOIN (SELECT * FROM [OMHSP_Standard].[SafetyPlan] WITH(NOLOCK) 
	WHERE SP_RefusedSafetyPlanning_HF=0
	AND (TIUDocumentDefinition LIKE '%SUICIDE PREVENTION SAFETY PLAN%' OR TIUDocumentDefinition = 'VA Safety Plan' OR SafetyPlanDateTime < '2022-06-13')) AS d
	ON d.MVIPersonSID=f.MVIPersonSID
WHERE f.MVIPersonSID NOT IN (SELECT MVIPersonSID FROM #inptsp_met)

DROP TABLE IF EXISTS #sp_met;
SELECT * 
		,SP_met=CASE WHEN DaysBetween<8 THEN 1 
			WHEN DaysBetweenFlag<8 THEN -1
			ELSE 0 END
INTO #sp_met
FROM (
	SELECT *
			,RN=Row_Number() OVER(Partition By MVIPersonSID order by DaysBetween,ActionDateTime)
	FROM #sp
	) AS a WHERE RN=1

DROP TABLE IF EXISTS #sp_final;
SELECT *
INTO #sp_final 
FROM (
	SELECT MVIPersonSID,ActionDateTime,SP_Met,DaysBetween FROM #inptSP_met
	UNION ALL
	SELECT MVIPersonSID,ActionDateTime,SP_Met,DaysBetween FROM #SP_met
	) AS sp
	
-------------------------------------------------------
-- COUNT FOLLOW-UP VISITS
-------------------------------------------------------
DROP TABLE IF EXISTS #vm;
SELECT MVIPersonSID
	  ,InitialActivation
	  ,LastActionDateTime
	  ,SUM(VisitsM1) AS VisitsM1
	  ,SUM(VisitsM2) AS VisitsM2
	  ,SUM(VisitsM3) AS VisitsM3
INTO #vm
FROM (
	SELECT o.MVIPersonSID
		  ,h.InitialActivation
		  ,h.ActionDateTime AS LastActionDateTime
		  ,CAST(OutpatDateTime AS date) AS ActionDateTime
		  ,VisitsM1=MAX(CASE WHEN DateDiff(d,ISNULL(c.MostRecentActivation,h.ActionDateTime),OutpatDateTime) BETWEEN 0 AND 30 THEN 1 ELSE 0 END) 
		  ,VisitsM2=MAX(CASE WHEN DateDiff(d,ISNULL(c.MostRecentActivation,h.ActionDateTime),OutpatDateTime) BETWEEN 31 AND 60 THEN 1 ELSE 0 END) 
		  ,VisitsM3=MAX(CASE WHEN DateDiff(d,ISNULL(c.MostRecentActivation,h.ActionDateTime),OutpatDateTime) BETWEEN 61 AND 90 THEN 1 ELSE 0 END) 
	FROM [PRF_HRS].[OutpatDetail] o WITH(NOLOCK)
	LEFT JOIN ( --Flags continued or transferred within first 80 days of activation
		SELECT MVIPersonSID
			,MostRecentActivation
		FROM #CohortDetail 
		WHERE MostRecentActivation IS NOT NULL
			AND ActionType = 2
		) c ON o.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN OMHSP_Standard.PRF_HRS_CompleteHistory h WITH (NOLOCK)
		ON o.MVIPersonSID = h.MVIPersonSID AND h.EntryCountDesc=1
	WHERE HRF_ApptCategory = 1
	GROUP BY o.MVIPersonSID
		,h.InitialActivation
		,h.ActionDateTime
		,CAST(OutpatDateTime AS date)
  ) AS a
GROUP BY MVIPersonSID,InitialActivation,LastActionDateTime

-------------------------------------------------------
-- SPECIFIC VISIT INFO TO DISPLAY
-------------------------------------------------------
DROP TABLE IF EXISTS #LastVisit
SELECT MVIPersonSID
	  ,OutpatDateTime
	  ,LastVisitDetail
INTO #LastVisit
FROM (
	SELECT MVIPersonSID
		  ,OutpatDateTime
		  ,PrimaryStopCode+' '+PrimaryStopCodeName AS LastVisitDetail
		  ,RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY OutpatDateTime DESC)
	FROM [PRF_HRS].[OutpatDetail] WITH(NOLOCK)
	WHERE HRF_ApptCategory in (1,0) -- visit completed within 90 day time frame
	) v
WHERE RN=1

DROP TABLE IF EXISTS #NextVisit
SELECT MVIPersonSID
	  ,OutpatDateTime
	  ,NextApptDetail
INTO #NextVisit
FROM (
	SELECT MVIPersonSID
		  ,OutpatDateTime
		  ,PrimaryStopCode+' '+PrimaryStopCodeName AS NextApptDetail
		  ,RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY OutpatDateTime ASC)
	FROM [PRF_HRS].[OutpatDetail] WITH(NOLOCK)
	WHERE HRF_ApptCategory=2 --Future scheduled appt
	) v
WHERE RN=1

DROP TABLE IF EXISTS #NoShow
SELECT MVIPersonSID
	  ,LastNoShowDateTIme
	  ,CountNS30Days
INTO #NoShow
FROM (
	SELECT MVIPersonSID
		  ,OutpatDateTime AS LastNoShowDateTIme
		  ,count(*) OVER(Partition By MVIPersonSID) AS CountNS30Days
		  ,RN=ROW_NUMBER() OVER(Partition BY MVIPersonSID ORDER BY OutpatDateTime DESC) 
	FROM [PRF_HRS].[OutpatDetail] WITH(NOLOCK)
	WHERE HRF_ApptCategory=4 --No show
		AND (CancelDateTime BETWEEN dateadd(d,-30,getdate()) AND getdate() 
		OR OutpatDateTime BETWEEN dateadd(d,-30,getdate()) AND getdate() )
	) v 
WHERE RN=1

DROP TABLE IF EXISTS #CancelAppt
SELECT MVIPersonSID
	  ,OutpatDateTime
	  ,CancelDateTime
INTO #CancelAppt
FROM (
	SELECT MVIPersonSID
		  ,OutpatDateTime 
		  ,CancelDateTime 
		  ,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY OutpatDateTime ASC)
	FROM [PRF_HRS].[OutpatDetail] WITH(NOLOCK)
	WHERE HRF_ApptCategory=5 --Future appt canceled
	) c
WHERE RN=1

-------------------------------------------------------
-- HEALTH FACTOR DATA FROM PRF REVIEW NOTE
-------------------------------------------------------
DROP TABLE IF EXISTS #HealthFactors;
SELECT a.MVIPersonSID
	,a.HealthFactorDateTime
	,a.List
	,a.Comments
INTO #HealthFactors
FROM OMHSP_Standard.HealthFactorSuicPrev a WITH (NOLOCK)
INNER JOIN #CohortDetail b ON a.MVIPersonSID=b.MVIPersonSID
WHERE Category= 'HRS-PRF Review'

DROP TABLE IF EXISTS #AssignedSPC
SELECT MVIPersonSID, AssignedSPC
INTO #AssignedSPC
FROM (SELECT
	 MVIPersonSID
	,HealthFactorDateTime
	,REPLACE(Comments, ',', '') AS AssignedSPC
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) AS rn
	FROM #HealthFactors
	WHERE List='PRF_AssignedSPC_HF'
	) a
WHERE a.rn=1

DROP TABLE IF EXISTS #TransferDate
SELECT MVIPersonSID, TransferDate
INTO #TransferDate
FROM (SELECT
	 MVIPersonSID
	,TransferDate = HealthFactorDateTime
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) AS rn
	FROM #HealthFactors
	WHERE List='PRF_ReceivingFacility_HF'
	) a
WHERE a.rn=1

DROP TABLE IF EXISTS #CaringLetters
SELECT TOP 1 WITH TIES c.MVIPersonSID
	,CASE WHEN DonotSend=1 THEN 0 --opted out/removed
		ELSE 2 --national
		END AS CaringLetters
INTO #CaringLetters
FROM [CaringLetters].[HRF_Cohort] b WITH (NOLOCK)
INNER JOIN #CohortDetail c ON b.MVIPersonSID=c.MVIPersonSID
ORDER BY ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY b.InsertDate DESC)

-------------------------------------------------------
-- SP2.0 Consults
-------------------------------------------------------

	--Get list of patients with SP 2.0 consults
	DROP TABLE IF EXISTS #SP2_Prep
	SELECT DISTINCT
		 m.MVIPersonSID
		,MAX(CAST(con.RequestDate AS DATE)) RequestDate
	INTO #SP2_Prep
	FROM [PDW].[NEPEC_MHICM_DOEx_TH_Consult_AllFacilities] con WITH(NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID m WITH(NOLOCK)
		ON con.PatientSID=m.PatientPersonSID
	INNER JOIN #CohortDetail c ON m.MVIPersonSID=c.MVIPersonSID
	WHERE C_Sent=1 OR C_Received=1
	GROUP BY m.MVIPersonSID;

	--Get most recent SP 2.0 consult and identify when consult was plaed within the year
	DROP TABLE IF EXISTS #SP2
	SELECT *, RequestDatePastYr=CASE WHEN RequestDate > dateadd(day,-366,getdate()) THEN 1 ELSE 0 END
	INTO #SP2
	FROM #SP2_Prep;

	--Suicial behaviors, including preparatory behaviors
	DROP TABLE IF EXISTS #SDV_Prep
	SELECT c.ChecklistID
		,s.MVIPersonSID
		,c.Facility
		,MAX(ISNULL(EventDateFormatted,EntryDateTime)) SDVDate
	INTO #SDV_Prep
	FROM OMHSP_Standard.SuicideOverdoseEvent s WITH (NOLOCK)
	INNER JOIN LookUp.ChecklistID c  WITH (NOLOCK)
		ON s.ChecklistID=c.ChecklistID
	INNER JOIN #CohortDetail d ON s.MVIPersonSID=d.MVIPersonSID
	WHERE EventType='Suicide Event' 
		AND Fatal=0 
		AND Intent='Yes'
		AND ISNULL(EventDateFormatted,EntryDateTime) > dateadd(year,-5,cast(getdate() as date))
	GROUP BY s.MVIPersonSID, c.ChecklistID, c.Facility

	--Get most recent suicide behavior and identify when SDV occurred within the year
	DROP TABLE IF EXISTS #SDV
	SELECT *, SDVPastYr=CASE WHEN SDVDate > dateadd(day,-366,getdate()) THEN 1 ELSE 0 END
	INTO #SDV
	FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SDVDate DESC) RN
			FROM #SDV_Prep ) Src
	WHERE RN=1;
	
	DROP TABLE IF EXISTS #Consults
	SELECT DISTINCT sdv.MVIPersonSID
			,sdv.ChecklistID
			,con.RequestDate
			,sdv.SDVDate
			,Actionable=	CASE WHEN (SDVPastYr=1 AND (con.RequestDate IS NULL OR con.RequestDatePastYr=0)) 
								   OR (SDVPastYr=1 AND (con.RequestDate < SDVDate)) THEN 1 ELSE 0 END
	INTO #Consults
	FROM #SDV sdv
	LEFT JOIN #SP2 con on con.MVIPersonSID=sdv.MVIPersonSID

	DELETE FROM #Consults WHERE Actionable=0 AND RequestDate IS NULL

-------------------------------------------------------
-- COMPILE DATA
-------------------------------------------------------
DROP TABLE IF EXISTS #TIUAll
SELECT
	c.MVIPersonSID
	,MAX(t.ReferenceDateTime) AS NoteDateTime 
	,CASE
		WHEN t.List='HRF_FlagReview_TIU' THEN 'FlagReview'
		WHEN t.List='SuicidePrevention_CSRE_TIU' THEN 'CSRE'
	 END AS NoteType
INTO #TIUAll
FROM [Stage].[FactTIUNoteTitles] t WITH(NOLOCK)
INNER JOIN #CohortDetail c 
	ON t.MVIPersonSID = c.MVIPersonSID
WHERE t.List IN ('HRF_FlagReview_TIU','SuicidePrevention_CSRE_TIU') 
GROUP BY c.MVIPersonSID, t.List

DROP TABLE IF EXISTS #SBOR
SELECT s.MVIPersonSID
	,MAX(s.EntryDateTime) AS SuicideBehaviorReport
	,COUNT(*) AS SuicideEventCount
INTO #SBOR
FROM [OMHSP_Standard].[SuicideOverdoseEvent] AS s WITH(NOLOCK)
INNER JOIN #CohortDetail AS c ON s.MVIPersonSID=c.MVIPersonSID
WHERE s.EventType = 'Suicide Event'
GROUP BY s.MVIPersonSID

DROP TABLE IF EXISTS #PatientTracking;
SELECT a.MVIPersonSID 
	  ,a.PatientICN
	  ,a.DateOfDeath
	  ,a.SourceEHR
	  ,a.OwnerChecklistID
	  ,a.OwnerFacility
	  ,a.ActiveFlag
	  ,a.InitialActivation
	  ,a.MostRecentActivation
	  ,a.ActionDateTime AS LastActionDateTime
	  ,a.ActionType AS LastActionType
	  ,CASE WHEN tr.MVIPersonSID IS NOT NULL THEN a.ActionTypeDescription + ' (Transfer)' 
		ELSE a.ActionTypeDescription END AS LastActionDescription
	  	   
	  ,ISNULL(ip.Census,0) AS IP_Current
	  ,CASE WHEN ip.Census=1 THEN ip.AdmitDateTime
			WHEN ip.Census=0 THEN ip.DischargeDateTime END AS IP_DateTime
	  ,ip.BedSectionName AS IP_BedSection
	  ,ip.ADMPARENT_FCDM AS IP_Location

	  ,spr.SafetyPlanDateTime AS LastSafetyPlanDateTime
	  ,f.NoteDateTime AS LastFlagReviewDateTime
	  ,sb.SuicideBehaviorReport
	  ,sb.SuicideEventCount
	  ,c.NoteDateTime AS CSRE

	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL 
		ELSE ISNULL(vm.VisitsM1,0) END AS VisitsM1
	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL 
		WHEN DateDiff(d,ISNULL(a.MostRecentActivation,a.ActionDateTime),getdate()) <=30 THEN NULL
		ELSE ISNULL(vm.VisitsM2,0) END AS VisitsM2
	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL 
		WHEN DateDiff(d,ISNULL(a.MostRecentActivation,a.ActionDateTime),getdate()) <=60 THEN NULL
		ELSE ISNULL(vm.VisitsM3,0) END AS VisitsM3

	  ,spm.ActionDateTime AS SP_DateTime
	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL
			WHEN a.ActionType IN (1,4) OR a.MostRecentActivation IS NOT NULL THEN spm.SP_met
			ELSE NULL END AS SP_Met
	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL
			WHEN a.ActionType IN (1,4) OR a.MostRecentActivation IS NOT NULL THEN spm.DaysBetween
			ELSE NULL END AS SP_DayCountAbs
	  
	  ,ISNULL(lv.OutpatDateTime,pa.VisitDateTime) AS LastVisitDateTime
	  ,lv.LastVisitDetail
	  
	  ,ISNULL(nv.OutpatDateTime,fa.AppointmentDateTime) AS NextApptDateTime
	  
	  ,ns.LastNoShowDateTime
	  ,ns.CountNS30Days
	  
	  ,ca.CancelDateTime AS FutureCancelDateTime
	  ,ca.OutpatDateTime AS FutureCancelApptDateTime

	  ,CASE WHEN a.ActiveFlag='N' OR a.DateOfDeath IS NOT NULL THEN NULL
			ELSE a.NextReviewDate END AS NextReviewDate
	  ,a.MinReviewDate
	  ,a.MaxReviewDate

	  ,spc.AssignedSPC
	  ,cl.CaringLetters

	  ,con.SDVDate
	  ,con.RequestDate
	  ,con.Actionable
	  
	  ,a.CernerVistADiff
	  ,a.CernerOwnerChecklistID

INTO #PatientTracking
FROM #CohortDetail a
LEFT JOIN (
	SELECT c.ADMPARENT_FCDM
		,b.MVIPersonSID
		,b.BedSectionName
		,b.AdmitDateTime
		,b.DischargeDateTime
		,b.Census
	FROM [Inpatient].[BedSection] b WITH(NOLOCK)
	INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) 
		ON c.ChecklistID=b.ChecklistID
	WHERE b.Census=1 OR b.DischargeDateTime>DATEADD(DAY,-90,CAST(GetDate() AS DATE))
		AND b.LastRecord=1
	) ip ON ip.MVIPersonSID=a.MVIPersonSID
LEFT JOIN (
	SELECT MVIPersonSID
		  ,MAX(SafetyPlanDateTime) AS SafetyPlanDateTime
	FROM  [OMHSP_Standard].[SafetyPlan] WITH(NOLOCK)
	WHERE SP_RefusedSafetyPlanning_HF=0
	AND (TIUDocumentDefinition LIKE '%SUICIDE PREVENTION SAFETY PLAN%' OR TIUDocumentDefinition = 'VA Safety Plan' OR SafetyPlanDateTime < '2022-06-13') 
		--local templates will be excluded from safety plan table after 7/1/22 but facilities have been given final notice to stop using them after 6/13.
		--ok to remove this date exclusion 3 months after 6/13
	GROUP BY MVIPersonSID
	) spr ON spr.MVIPersonSID=a.MVIPersonSID
LEFT JOIN (SELECT * FROM #TIUAll WHERE NoteType='FlagReview'
	) AS f ON a.MVIPersonSID=f.MVIPersonSID
LEFT JOIN #SBOR sb ON a.MVIPersonSID=sb.MVIPersonSID
LEFT JOIN (SELECT * FROM #TIUAll WHERE NoteType='CSRE'
	) AS c ON a.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #vm AS vm ON a.MVIPersonSID=vm.MVIPersonSID
LEFT JOIN #sp_final AS spm ON spm.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #LastVisit AS lv ON lv.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #NextVisit AS nv ON nv.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #NoShow AS ns ON ns.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #CancelAppt AS ca ON ca.MVIPersonSID=a.MVIPersonSID
LEFT JOIN ( --for those inactivated in past year
	SELECT MVIPersonSID
		  ,MAX(VisitDateTime) AS VisitDateTime
	FROM [Present].[AppointmentsPast] WITH(NOLOCK)
	WHERE ApptCategory IN ('MHRecent','HomelessRecent')
		AND MostRecent_ICN=1
		GROUP BY MVIPersonSID
	) AS pa ON a.MVIPersonSID=pa.MVIPersonSID
LEFT JOIN ( --for those inactivated in past year
	SELECT MVIPersonSID
		  ,MIN(AppointmentDateTime) AS AppointmentDateTime
	FROM [Present].[AppointmentsFuture] WITH(NOLOCK)
	WHERE ApptCategory IN ('MHFuture','HomelessFuture')
		AND NextAppt_ICN=1
		GROUP BY MVIPersonSID
	) AS fa ON a.MVIPersonSID=fa.MVIPersonSID
LEFT JOIN #AssignedSPC spc
	ON a.MVIPersonSID=spc.MVIPersonSID
LEFT JOIN #TransferDate tr
	ON a.MVIPersonSID=tr.MVIPersonSID AND CAST(a.ActionDateTime AS date)=CAST(tr.TransferDate AS date)
LEFT JOIN #CaringLetters cl
	ON a.MVIPersonSID = cl.MVIPersonSID
LEFT JOIN #Consults con
	ON a.MVIPersonSID=con.MVIPersonSID

/*****************************************************************
 ADD SUCCESSFUL AND UNSUCCESSFUL OUTREACH ATTEMPTS
******************************************************************/
DROP TABLE IF EXISTS #SRMUnsuccess
SELECT a.MVIPersonSID
	,UnsuccessDate = convert(DATE, max(srm.EntryDateTime))
	,UnsuccessCount = count(srm.VisitSID) 
INTO #SRMUnsuccess
FROM #PatientTracking a
INNER JOIN [OMHSP_Standard].[SuicideRiskManagement] srm WITH(NOLOCK)
	ON a.MVIPersonSID=srm.MVIPersonSID
WHERE OutreachStatus='Unsuccess' 
	AND srm.EntryDateTime >= a.LastActionDateTime
GROUP BY a.MVIPersonSID 

DROP TABLE IF EXISTS #SRMSuccess
SELECT a.MVIPersonSID
	,SuccessDate = convert(DATE, max(srm.EntryDateTime))
	,SuccessCount = count(srm.VisitSID) 
INTO #SRMSuccess
FROM #PatientTracking a
INNER JOIN [OMHSP_Standard].[SuicideRiskManagement] srm WITH(NOLOCK)
	ON a.MVIPersonSID=srm.MVIPersonSID
WHERE OutreachStatus='Success' 
	AND srm.EntryDateTime >= a.LastActionDateTime
GROUP BY a.MVIPersonSID

/*****************************************************************
 ADD PROVIDER INFORMATION
******************************************************************/
DROP TABLE IF EXISTS #pcpcount;
SELECT c.MVIPersonSID
	  ,count(ChecklistID) AS CountPCP
INTO #pcpcount
FROM [PRF_HRS].[ActivePRF] AS c WITH(NOLOCK)
INNER JOIN [Present].[Provider_PCP] AS p WITH(NOLOCK)
	ON p.MVIPersonSID=c.MVIPersonSID
GROUP BY c.MVIPersonSID

DROP TABLE IF EXISTS #mhtccount;
SELECT c.MVIPersonSID
	  ,count(ChecklistID) AS CountMHTC
INTO #mhtccount
FROM [PRF_HRS].[ActivePRF] AS c WITH(NOLOCK)
INNER JOIN [Present].[Provider_MHTC] AS m WITH(NOLOCK)
	ON m.MVIPersonSID=c.MVIPersonSID
GROUP BY c.MVIPersonSID

DROP TABLE IF EXISTS #withProviders;
SELECT a.*
	  ,ISNULL(p.StaffName,'*Unassigned*') AS StaffName_PCP 
	  ,IsNull(CountPCP,0) AS CountPCP
	  ,ISNULL(p.Sta6a,0) AS Sta6a_PCP
	  ,ISNULL(m.StaffName,'*Unassigned*') AS StaffName_MHTC
	  ,IsNull(CountMHTC,0) AS CountMHTC
	  ,ISNULL(m.Sta6a,0) AS Sta6a_MHTC
	  ,m.Team AS Team_MHTC
	  ,srm1.UnsuccessCount
	  ,srm1.UnsuccessDate
	  ,srm2.SuccessCount
	  ,srm2.SuccessDate
INTO #withProviders 
FROM #PatientTracking AS a
LEFT JOIN [Present].[Provider_PCP] AS p WITH(NOLOCK)
	ON p.PatientICN=a.PatientICN  AND a.OwnerChecklistID=p.ChecklistID
LEFT JOIN [Common].[Providers] AS m WITH(NOLOCK) 
	ON m.PatientICN=a.PatientICN AND a.OwnerChecklistID=m.ChecklistID AND m.MHTC=1
LEFT JOIN #pcpcount AS ps
	ON ps.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #mhtccount AS ms
	ON ms.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #SRMUnsuccess AS srm1
	ON srm1.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #SRMSuccess AS srm2
	ON srm2.MVIPersonSID=a.MVIPersonSID

;
DROP TABLE IF EXISTS #final;
SELECT DISTINCT p.MVIPersonSID
	  ,p.ActiveFlag
	  ,p.InitialActivation
	  ,p.LastActionDateTime
	  ,p.MostRecentActivation
	  ,p.OwnerChecklistID
	  ,p.CernerVistADiff
	  ,p.CernerOwnerChecklistID
	  ,p.LastActionType
	  ,p.LastActionDescription
	  ,p.IP_Current
	  ,p.IP_DateTime
	  ,p.IP_BedSection
	  ,p.IP_Location
	  ,p.LastSafetyPlanDateTime
	  ,p.LastFlagReviewDateTime
	  ,p.SuicideBehaviorReport
	  ,p.SuicideEventCount
	  ,p.CSRE
	  ,p.VisitsM1
	  ,p.VisitsM2
	  ,p.VisitsM3
	  ,p.SP_DateTime
	  ,p.SP_Met
	  ,p.SP_DayCountAbs
	  ,p.NextReviewDate
	  ,p.MinReviewDate
	  ,p.MaxReviewDate
	  ,CASE WHEN p.AssignedSPC IS NULL THEN 'Unknown' ELSE p.AssignedSPC END AS AssignedSPC
	  ,p.LastVisitDateTime
	  ,p.LastVisitDetail
	  ,p.NextApptDateTime	  
	  ,p.LastNoShowDateTime
	  ,p.CountNS30Days
	  ,p.FutureCancelDateTime
	  ,p.FutureCancelApptDateTime
	  ,p.UnsuccessDate
	  ,p.UnsuccessCount
	  ,p.SuccessDate
	  ,p.SuccessCount
	  ,CASE WHEN p.ActiveFlag='Y' THEN NULL ELSE p.CaringLetters END AS CaringLetters
	  ,p.SDVDate AS SP2EligibleDate
	  ,p.RequestDate AS SP2ConsultRequestDate
	  ,p.Actionable AS SP2ConsultActionable
	  ,p.StaffName_PCP
	  ,p.CountPCP
	  ,p.Sta6a_PCP
	  ,p.StaffName_MHTC
	  ,p.CountMHTC
	  ,p.Sta6a_MHTC
	  ,p.Team_MHTC
	  ,p.SourceEHR
	  ,p.DateOfDeath
	  ,UpdateDate=GetDate()
INTO #final
FROM #WithProviders AS p

;	
/*****************************************************************
TRUNCATE AND INSERT INTO PERMANENT TABLE
******************************************************************/
EXEC [Maintenance].[PublishTable] 'PRF_HRS.PatientReport_v02', '#final'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'


END