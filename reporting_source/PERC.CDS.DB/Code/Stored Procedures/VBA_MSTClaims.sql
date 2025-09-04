
/****** Object:  StoredProcedure [Code].[VBA_MSTClaims]    Script Date: 9/13/2021 10:57:23 PM ******/
CREATE PROCEDURE [Code].[VBA_MSTClaims]

AS
BEGIN

-- ---------------------------------------------------------
-- AUTHOR:	Elena Cherkasova
-- CREATE DATE: 2024-09-04
-- DESCRIPTION:	Nightly code for creating tables for VBA MST Claims Event Notification dashboard
--              [VBA].[MSTClaimsCohort]
--              [VBA].[MSTClaimsNotifications]
--				[VBA].[MSTClaimsEvents]

-- MODIFICATIONS:
-- 2025-03-20	Elena C		Fixed logic related to notes for patients with multiple facilities
-- ---------------------------------------------------------


--STILL TO BE ADDED: CHECK VBA VIEW FOR ROWS OR LOAD DATE OR BOTH FIRST
--should i double check patienticn on vba's birth date? or in the core view?
--should i look for encounters this month for Unassigned

------------------------------------------------------------
-- CREATE PATIENT LEVEL COHORT WITH FACILITY ASSIGNMENTS  --
------------------------------------------------------------

DECLARE @LoadDate datetime2 = (SELECT MAX(Load_date) FROM [VBA].[MST_Claims_Events] WITH(NOLOCK)) 
PRINT @LoadDate
  
  DROP TABLE IF EXISTS #data;
  SELECT [LAST_NAME]
      ,[FIRST_NAME]
      ,[MVIPERSONFULLICN]
      ,[MVIPersonSID]
      ,[PatientICN]
      ,[BIRTH_DATE]
      ,[EVENT_TYPE]
      ,[EVENT_DT]
      ,[LOAD_DATE]
  INTO #data
  FROM [VBA].[MST_Claims_Events] 
  WHERE LOAD_DATE = @LoadDate
  ;

  DROP TABLE IF EXISTS #Uniques;
  SELECT DISTINCT MVIPersonSID
  INTO #Uniques
  FROM #data
;

--Assign Veterans to facilities based on presence of PCP or MHTC assignment
  DROP TABLE IF EXISTS #Cohort_provider;
  SELECT vba.MVIPersonSID
	  ,StaPa_PCP = CASE WHEN PCP=1 THEN p.ChecklistID ELSE NULL END
	  ,StaPa_MHTC = CASE WHEN MHTC=1 THEN p.ChecklistID ELSE NULL END
	  ,StaPa_Homestation = CASE WHEN hs.MVIPersonSID IS NOT NULL THEN hs.ChecklistID ELSE NULL END
  INTO #Cohort_provider
  FROM #Uniques as vba 
  LEFT JOIN [Common].[Providers] as p WITH(NOLOCK) 
  ON vba.MVIPersonSID = p.MVIPersonSID AND (p.PCP=1 OR p.MHTC=1) AND p.provrank_icn=1	--most recent PCP or MHTC
  LEFT JOIN [Present].[HomestationMonthly] as hs  WITH(NOLOCK)
  on vba.MVIPersonSID = hs.MVIPersonSID
  ;
 
  --(one row per patient)
  DROP TABLE IF EXISTS #Cohort_facility; 
  SELECT DISTINCT MVIPersonSID
	  ,StaPa_PCP = CAST(MAX(StaPa_PCP) AS nvarchar)
	  ,StaPa_MHTC = CAST(MAX(StaPa_MHTC) AS nvarchar)
	  ,StaPa_Homestation = CAST(MAX(StaPa_Homestation) AS nvarchar)
  INTO #Cohort_facility
  FROM #Cohort_provider 
  GROUP BY MVIPersonSID
  ;

--First and latest event dates by patient (one row per patient)
  DROP TABLE IF EXISTS #Cohort_dates;
  SELECT DISTINCT MVIPersonSID
		,EventsCount = COUNT(*)
		,FirstEventDate = MIN(EVENT_DT)
		,LatestEventDate = MAX(EVENT_DT)
		,DropOffDate = DATEADD(DAY,90,MAX(EVENT_DT))	--Date patient drops off the dashboard
  INTO #Cohort_dates
  FROM #data
  GROUP BY MVIPersonSID
  ;

--List of patients and responsible facilities (one row per patient and facility, so multiple rows per patient possible)
  DROP TABLE IF EXISTS #Stations;
  SELECT DISTINCT MVIPersonSID,Station
  INTO #Stations
  FROM (SELECT MVIPersonSID, StaPa_PCP, StaPa_MHTC, StaPa_Homestation 
		FROM #Cohort_facility
  ) p
  UNPIVOT
  (
	Station for StaPa IN(StaPa_PCP, StaPa_MHTC, StaPa_Homestation )
  ) as unpvt
;

---------------------------------
--  MEDICAL RECORD NOTE TABLE  --
---------------------------------

--VISTA NOTES
--gets any visits using VA-C&P CLAIMS EVENT NOTIFICATION HF 
--(BUT BE AWARE OTHER VISITS SEEM TO BE GETTING HF ATTACHED, MUST JOIN WITH MST COHORT)
DROP TABLE IF EXISTS #Vista;
SELECT DISTINCT mvi.MVIPersonSID
	,hf.VisitSID
	,hf.HealthFactorDateTime
	,StaPa = CASE WHEN (i.StaPa IS NULL or  i.StaPa like '*') AND hf.sta3n='612' THEN '612A4'--fix for missing StaPa specifically for sta3n 612 / stapa 612A4
				  WHEN i.StaPa IS NULL or  i.StaPa like '*' THEN CAST(hf.Sta3n AS NVARCHAR(50)) ELSE i.StaPa END --deals with for missings and unknown StaPa-
	,mp.TestPatient
INTO #Vista
FROM [hf].[HealthFactor] as hf WITH (NOLOCK)
INNER JOIN [LookUp].[ListMember] as lm  WITH (NOLOCK)
	ON lm.ItemID = hf.HealthFactorTypeSID 
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] as mvi
	ON hf.PatientSID = mvi.PatientPersonSID
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK) 
	ON mp.MVIPersonSID = mvi.MVIPersonSID
LEFT JOIN [Outpat].[Visit] AS ov  WITH (NOLOCK) ON hf.VisitSID = ov.VisitSID
LEFT JOIN [Dim].[Division] AS d  WITH (NOLOCK) ON ov.DivisionSID = d.DivisionSID
LEFT JOIN [Dim].[Institution] AS i WITH (NOLOCK) ON d.InstitutionSID = i.InstitutionSID
WHERE 1=1
	AND lm.List LIKE 'MST_VBA_Cohort'
	AND mp.TestPatient=0
;

--CERNER NOTES
DROP TABLE IF EXISTS #Cerner;
SELECT DISTINCT pf.MVIPersonSID
	,VisitSID = pf.EncounterSID 
	,HealthFactorDateTime =pf.TZFormUTCDateTime
	,pf.Stapa
INTO #Cerner
FROM [Cerner].[FactPowerForm] AS pf WITH (NOLOCK) 
INNER JOIN [LookUp].[ListMember] as lm  WITH (NOLOCK)
	ON lm.ItemID = pf.DCPFormsReferenceSID
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK) 
	ON mp.MVIPersonSID = pf.MVIPersonSID
WHERE 1 = 1 
	AND lm.List LIKE 'MST_VBA_Cohort'
	AND mp.TestPatient=0
;

--UNION NOTES
DROP TABLE IF EXISTS #Notes;
SELECT MVIPersonSID
	,VisitSID
	,HealthFactorDateTime
	,StaPa
INTO #Notes
FROM #Vista

UNION ALL

SELECT MVIPersonSID
	,VisitSID
	,HealthFactorDateTime
	,StaPa
FROM #Cerner
;

--(BUT BE AWARE OTHER VISITS SEEM TO BE GETTING HF ATTACHED, MUST JOIN WITH MST COHORT)
--Join notes with MST cohort 
DROP TABLE IF EXISTS #MSTNotes;
SELECT u.MVIPersonSID
	,NoteNumber = ROW_NUMBER() OVER(PARTITION BY u.MVIPersonSID,n.StaPa ORDER BY n.HealthFactorDateTime) 
	,n.VisitSID
	,n.HealthFactorDateTime
	,n.StaPa
INTO #MSTNotes
FROM #Notes as n
INNER JOIN #Uniques as u
ON n.MVIPersonSID = u.MVIPersonSID
;

--select * from #MSTnotes
--drop table VBA.MSTClaimsNotes

EXEC [Maintenance].[PublishTable] 'VBA.MSTClaimsNotes','#MSTNotes';


--One row per patient and facility, so multiple rows per patient possible
DROP TABLE IF EXISTS #NoteSummary;
SELECT s.MVIPersonSID
	,StaPa = s.Station
	,NoteCount = MAX(ISNULL(NoteNumber,0))
	,FirstNoteDate = CAST(MIN(HealthFactorDateTime) AS DATE)
	,LatestNoteDate = CAST(MAX(HealthFactorDateTime) AS DATE)
	,NoteNeededDate = DATEADD(DAY,21,CAST(MAX(HealthFactorDateTime) AS DATE))
INTO #NoteSummary
FROM #Stations as s
LEFT JOIN #MSTNotes	as n
ON s.MVIPersonSID = n.MVIPersonSID and s.Station = n.StaPa 
GROUP BY s.MVIPersonSID,s.Station
;

--------------------------
--  EVENTS-LEVEL TABLE  --
--------------------------
--Events are notifications from the VBA system, e.g. the date an EXAMINATION was scheduled or the date a Notification of Decision was created.

--Make list of patients and facilities, patients with multiple facilities will have multiple rows per event
DROP TABLE IF EXISTS #stapa;
SELECT MVIPersonSID
	,StaPa_PCP as StaPa
INTO #stapa
FROM #Cohort_facility
WHERE StaPa_PCP IS NOT NULL

UNION

SELECT MVIPersonSID
	,StaPa_MHTC
FROM #Cohort_facility
	WHERE StaPa_MHTC IS NOT NULL

UNION

SELECT MVIPersonSID
	,StaPa_Homestation
FROM #Cohort_facility
	WHERE StaPa_Homestation IS NOT NULL
;	
	
DROP TABLE IF EXISTS #Events;
SELECT e.MVIPersonSID
  	,EventNumber = row_number() OVER(PARTITION BY e.MVIPersonSID,s.StaPa ORDER BY e.[EVENT_DT]) 
    ,EventType = e.[EVENT_TYPE]
    ,EventDate = e.[EVENT_DT]
	,RecentEvent = CASE WHEN DATEDIFF(DAY,e.[EVENT_DT],GETDATE())<15 THEN 1 ELSE 0 END
	,s.StaPa
INTO #Events
FROM #data as e
INNER JOIN #stapa as s
on e.MVIPersonSID = s.MVIPersonSID
;

--patients with multiple facilities will have multiple rows per event and note information is matched by facility
DROP TABLE IF EXISTS #FinalEvents;
SELECT e.MVIPersonSID
  	,e.EventNumber
    ,e.EventType
    ,e.EventDate
	,e.RecentEvent
	--uncomment for debugging
	--,n.FirstNoteDate
	--,n.LatestNoteDate
	--,n.NoteNeededDate
	,NoteNeeded = CASE WHEN n.NoteCount = 0 THEN 1 --if no note, note needed
		WHEN (n.NoteCount >0 AND CAST(e.EventDate AS DATE) <= n.FirstNoteDate) THEN 0		--after first note, mark all previous events as note NOT needed
		WHEN (n.NoteCount >0 AND CAST(e.EventDate AS DATE) >= NoteNeededDate) THEN 1		--if another event within 21 days of a note, note NOT needed
		ELSE 0 END
	,e.StaPa as StaPa_Event
	,n.StaPa as StaPa_Note
INTO #FinalEvents
FROM #Events as e
LEFT JOIN #NoteSummary as n
ON e.MVIPersonSID = n.MVIPersonSID AND e.StaPa = n.StaPa
;

--SELECT * FROM #FinalEvents ORDER BY MVIPersonSID, EventDate
--drop table VBA.MSTClaimsEvents

EXEC [Maintenance].[PublishTable] 'VBA.MSTClaimsEvents','#FinalEvents';

-------------------------
--  FINAL COHORT TABLE --
-------------------------

--patients with multiple facilities will have one row per facility to capture seperate Note info for each facility
 DROP TABLE IF EXISTS #FinalCohort;
  SELECT DISTINCT u.MVIPersonSID
	  ,f.StaPa_PCP
	  ,f.StaPa_MHTC 
	  ,f.StaPa_Homestation
	  ,Unassigned = CASE WHEN f.StaPa_PCP IS NULL AND f.StaPa_MHTC IS NULL AND f.StaPa_Homestation IS NULL THEN 1 ELSE 0 END
	  ,d.EventsCount
	  ,FirstEventDate = CAST(d.FirstEventDate AS DATE)
	  ,LatestEventDate = CAST(d.LatestEventDate AS DATE)
	  ,DropOffDate = CAST(d.DropOffDate AS DATE)
	  ,StaPa_Note = n.StaPa
	  ,n.NoteCount
	  ,n.FirstNoteDate
	  ,n.LatestNoteDate
	  ,n.NoteNeededDate 
  INTO #FinalCohort
  FROM #Uniques as u
  LEFT JOIN #Cohort_facility as f 
  ON u.MVIPersonSID = f.MVIPersonSID
  LEFT JOIN #Cohort_dates as d
  ON u.MVIPersonSID = d.MVIPersonSID
  LEFT JOIN #NoteSummary as n
  on u.MVIPersonSID = n.MVIPersonSID
  WHERE d.EventsCount >0
  ;

--SELECT * FROM #FinalCohort
--DROP TABLE VBA.MSTClaimsCohort

EXEC [Maintenance].[PublishTable] 'VBA.MSTClaimsCohort','#FinalCohort';

END