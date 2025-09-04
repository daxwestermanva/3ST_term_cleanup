
/* =============================================
-- Author:		Rebecca Stephens
-- Create date: 2020-08-04
-- Description: This code uses pre-definied business rules to get a patient population that we consider "active" in CDS.
				Different projects use different criteria as a starting point for computation, which can be seen in these views:
				Present.SPatient_v02: Population for projects to begin analysis. Flags do NOT indicate inclusion in any risk tiers or project cohorts. 
										(e.g., STORM=1 means we compute a ORM risk score, NOT that the patient is high risk or uses opioids)
				Present.StationAssignments_v02: Flags indicate in which station a patient will DISPLAY on project reports. MVIPersonSID with relevant ChecklistIDs.
 -- Modifications:
    2020-08-04 RAS:	V02 - Based on Code.Present_SPatient and Code.Present_StationAssignments
	2020-10-30 RAS: VM - Added SourceEHR logic and PatientSID/PersonSID column
	2020-12-10 RAS:	Changed PatientPersonSID to be PatientSID where available and only PersonSID if they patient ONLY exists in Cerner and not VistA
	2020-12-11 RAS: Added missing STORM and PDSI meds requirements.
	2021-07-21 CMH: Added SMI cohort: dx in prior 2 years
	2021-08-10  AI: Changed App.OutpatWorkload_StatusShowed reference to App.vwOutpatWorkload_StatusShowed
	2021-09-13	AI:	Enclave Refactoring - Counts confirmed
	2021-12-19 RAS:	Added ODPastYear for STORM Cohort
	2022-03-10  SG:	Updated following colums that are changed in Present.Provider
	                        RelationshipEndDateTime to RelationshipEndDate 
                            pcm_std_team_care_type_id in (7,13) to  TeamType = 'PACT'
                            PCM_Std_Team_Care_Type_ID =4 to TeamType = 'BHIP'
	2022-06-21 RAS: For requirement RxPDSI, which requires an active prescription, changed logic to "DrugStatus = 'ActiveRx'"
					instead of "RxStatus IN ('HOLD', 'SUSPENDED', 'ACTIVE', 'PROVIDER HOLD')"
					The new column DrugStatus should account for the old logic that was specific to VistA data AND should
					also be populated for Millennium records.  The status in that field is either 'ActiveRx' or 'PillsOnHand'
	2023-10-06 AER  Update PatientPersonID for CERNER sites to always be the personID regaurless of the patients VISTA history with that site
	2023-12-14 LM	Removed MERGE and switched to Maintenance.PublishTable to publish results for faster runtime after consultation with RAS; added NOLOCKs
	2024-01-03 LM	Changed BHIP label to MH/BHIP to reflect broader definition of this concept
	2024-09-26 MCP	Adjusted RxPDSI requirements to reflect active measures

--Questions:
	Why are there NULL STAPAs in UxOutpat?
-- ============================================= */
/* NOTES:
	UPSTREAM DEPENDENCIES:
		- Inpatient_BedSection
		- PRF_HRS_ActiveAndHistory
		- Common_Providers
		- Present_HomeStationMonthly
	CORE DOWNSTREAM DEPENDENCIES (not comprehensive list)
		- Present_Appointments
		- Present.SPatient (view)
		- Present.StationAssignments (view)
*/
--TRUNCATE TABLE [Present].[ActivePatient]




CREATE PROCEDURE [Code].[Present_ActivePatient]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.Present_ActivePatient','Execution of SP Code.Present_ActivePatient'	

 ---------------------------------------------------------
 /*******Active Patient Population Criteria*********/
-----------------------------------------------------------
DECLARE @EndDate datetime2,@EndDate_1m date,@EndDate_6mo date,@EndDate_1Yr date,@EndDate_2Yr date
	,@1YearAgo date

SET @EndDate=dateadd(day, datediff(day, -1, getdate()),0)
SET @EndDate_1m=dateadd(day,-31,@EndDate) -- SG
SET @EndDate_6mo=dateadd(month,-6,@EndDate)
SET @EndDate_1Yr=dateadd(day,-366,@EndDate)
SET @EndDate_2Yr=dateadd(day,-731,@EndDate)
SET @1YearAgo=dateadd(day,-366,@EndDate)

DROP TABLE IF EXISTS #Criteria
CREATE TABLE #Criteria (
	MVIPersonSID INT
	,PatientPersonSID INT
	,ChecklistID VARCHAR(5) NULL
	,RequirementName VARCHAR(25) NOT NULL
	,Sta3n_Loc SMALLINT NULL
	,Sta3n_EHR SMALLINT NULL
	)

/*Outpatient encounter in past 1 month*/
--Using view that restricts by appt status. Not present appointments just to minimize dependency
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='Outpat'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT DISTINCT
	MVIPersonSID
	,MAX(PatientSID) AS PatientSID
	,ISNULL(d.ChecklistID,w.Sta3n) as ChecklistID
	,RequirementName = 'Outpatient'
	,w.Sta3n
	,w.Sta3n
FROM [App].[vwOutpatWorkload_StatusShowed] w WITH(NOLOCK)
LEFT JOIN [Dim].[Location] l WITH(NOLOCK) on l.LocationSID=w.LocationSID
LEFT JOIN [LookUp].[DivisionFacility] d WITH(NOLOCK) on d.DivisionSID=l.DivisionSID
WHERE VisitDateTime >= @EndDate_1m
GROUP BY MVIPersonSID,d.ChecklistID,w.Sta3n

INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT DISTINCT 
	MVIPersonSID
	,PersonSID
	,STAPA
	,RequirementName = 'Outpatient'
	,Sta3n_Loc = LEFT(STAPA,3)
	,Sta3n_EHR = 200
FROM [Cerner].[FactUtilizationOutpatient] op WITH(NOLOCK)
WHERE TZDerivedVisitDateTime >= @EndDate_1m

	--SELECT * FROM #Criteria WHERE RequirementID=6 AND SourceEHR=200

/*Inpatient Past 1 Month*/ --separated into 2 from original spatient to facilitate "station assignments" later
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='Inpatient'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	,PatientPersonSID
	,ChecklistID
	,RequirementName = 'Inpatient'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_EHR
FROM [Inpatient].[Bedsection] ip WITH(NOLOCK)
WHERE (DischargeDateTime BETWEEN @EndDate_1m AND @EndDate)
GROUP BY MVIPersonSID,ChecklistID,PatientPersonSID,Sta3n_EHR

/*Inpatient Census*/
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='InpatientCensus'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	,PatientPersonSID
	,ChecklistID
	,RequirementName = 'InpatientCensus'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_EHR
FROM [Inpatient].[Bedsection] ip WITH(NOLOCK)
WHERE Census=1 

/*Active Medications or Pills On Hand*/
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='Rx'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT DISTINCT
	MVIPersonSID
	,PatientPersonSID
	,ChecklistID
	,RequirementName = 'Rx'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_EHR = Sta3n
FROM [Present].[Medications] WITH(NOLOCK)

	INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
	SELECT DISTINCT
		MVIPersonSID
		,PatientPersonSID
		,ChecklistID
		,RequirementName = 'RxSTORM'
		,Sta3n_Loc = LEFT(ChecklistID,3)
		,Sta3n_EHR = Sta3n
	FROM [Present].[Medications] WITH(NOLOCK)
	WHERE SedatingPainORM_Rx = 1 
		OR OpioidForPain_Rx = 1 
		OR Anxiolytics_Rx = 1 

	--Opioid active rx or pills on hand
	INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
	SELECT DISTINCT
		MVIPersonSID
		,PatientPersonSID
		,ChecklistID
		,RequirementName = 'RxOpioid'
		,Sta3n_Loc = LEFT(ChecklistID,3)
		,Sta3n_EHR = Sta3n
	FROM [Present].[Medications] WITH(NOLOCK)
	WHERE OpioidForPain_Rx=1

	-- PDSI relevant med, active rx status
	INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
	SELECT DISTINCT
		MVIPersonSID
		,PatientPersonSID
		,ChecklistID
		,RequirementName = 'RxPDSI'
		,Sta3n_Loc = LEFT(ChecklistID,3)
		,Sta3n_EHR = Sta3n
	FROM [Present].[Medications] WITH(NOLOCK)
	WHERE DrugStatus = 'ActiveRx' 
		AND (AlcoholPharmacotherapy_Rx = 1 
			OR Benzodiazepine_Rx = 1
			OR OpioidAgonist_Rx = 1 
			OR NaloxoneKit_Rx =1 
			OR NaltrexoneINJ_Rx = 1
			OR OpioidAgonist_Rx = 1
			OR OpioidForPain_Rx = 1
			OR Sedative_zdrug_Rx = 1
			OR StimulantADHD_Rx = 1
			)

/*Active PCP assignment*/ 
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='PCP'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID 
	,prov.PatientSID
	,prov.ChecklistID
	,RequirementName = 'PCP'
	,prov.Sta3n
	,prov.Sta3n
FROM [Common].[Providers] prov WITH(NOLOCK)
WHERE RelationshipEndDateTime is null
    AND PCP=1  

/*Active PACT assignment*/ 
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='PACT'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID 
	,prov.PatientSID
	,prov.ChecklistID
	,RequirementName = 'PACT'
	,prov.Sta3n
	,prov.Sta3n
FROM [Common].[Providers] prov WITH(NOLOCK)
WHERE RelationshipEndDateTime is null
    AND TeamType = 'PACT'  

/*Active provider assignment*/ 
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='MHTC'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID 
	,prov.PatientSID
	,prov.ChecklistID
	,RequirementName = 'MHTC'
	,prov.Sta3n
	,prov.Sta3n
FROM [Common].[Providers] prov WITH(NOLOCK)
WHERE RelationshipEndDateTime is null
    AND MHTC=1

/*Active MH or BHIP team assignment*/ 
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='MH/BHIP'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID 
	,prov.PatientSID
	,prov.ChecklistID
	,RequirementName = 'MH/BHIP'
	,prov.Sta3n
	,prov.Sta3n
FROM [Common].[Providers] prov WITH(NOLOCK)
WHERE RelationshipEndDateTime is null
    AND (TeamType = 'BHIP' OR TeamType = 'MH')

/*Homestation*/
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='HomeStation'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	,PatientSID = -99 --tag to fill in later
	,ChecklistID
	,RequirementName = 'HomeStation'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_Loc = LEFT(ChecklistID,3) --don't actually know, but going to assume VistA to get that PatientSID, if present
FROM [Present].[HomestationMonthly] WITH(NOLOCK)
WHERE MVIPersonSID IS NOT NULL


-- SMI diagnosis in prior 2 years--------------------------------------------

	--OP VistA
	  DROP TABLE IF EXISTS #OutpatVDiagnosis;
	  SELECT DISTINCT 
		ISNULL(mvi.MVIPersonSID, 0) AS MVIPersonSID
		,a.PatientSID
		,a.Sta3n
		,e.ChecklistID
		,a.VisitDateTime
	  INTO  #OutpatVDiagnosis 
	  FROM [Outpat].[VDiagnosis] a WITH(NOLOCK)
	  LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
			ON a.PatientSID = mvi.PatientPersonSID
	  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH(NOLOCK)
			ON a.ICD10SID = b.ICD10SID
	  INNER JOIN [Outpat].[Visit] c WITH(NOLOCK)
			ON a.VisitSID = c.VisitSID
	  LEFT JOIN [Dim].[Division] d WITH(NOLOCK)
			ON c.DivisionSID = d.DivisionSID
	  LEFT JOIN [LookUp].[Sta6a] e WITH(NOLOCK)
			ON d.Sta6a = e.Sta6a
	  WHERE (a.[VisitDateTime] >= @EndDate_2Yr AND a.[VisitDateTime] < @EndDate)
		  AND a.WorkloadLogicFlag = 'Y'
		  AND b.DxCategory='SMI'


	--IP Vista
	  DROP TABLE IF EXISTS #InpatientDiagnosis;
	  SELECT
		ISNULL(mvi.MVIPersonSID, 0) AS MVIPersonSID
		,a.PatientSID
		,a.Sta3n
		,f.ChecklistID
		,d.AdmitDateTime
	  INTO #InpatientDiagnosis 
	  FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
	  LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
			ON a.PatientSID = mvi.PatientPersonSID
	  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH(NOLOCK)
			ON a.ICD10SID = b.ICD10SID
	  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
			ON a.InpatientSID = d.InpatientSID
	  LEFT JOIN [Dim].[WardLocation] e WITH(NOLOCK)
			ON d.DischargeWardLocationSID = e.WardLocationSID 
	  LEFT JOIN [LookUp].[Sta6a] f WITH(NOLOCK)
			ON e.Sta6a = f.Sta6a
	  WHERE ((a.DischargeDateTime >= @EndDate_2Yr AND a.DischargeDateTime < @EndDate)
			OR a.DischargeDateTime  IS NULL)
			AND b.DxCategory = 'SMI'

	  DROP TABLE IF EXISTS #InpatientDischargeDiagnosis;
	  SELECT
		ISNULL(mvi.MVIPersonSID, 0) AS MVIPersonSID
		,a.PatientSID
		,a.Sta3n
		,f.ChecklistID
		,d.AdmitDateTime 
	  INTO #InpatientDischargeDiagnosis 
	  FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
	  LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
			ON a.PatientSID = mvi.PatientPersonSID
	  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH(NOLOCK)
			ON a.ICD10SID = b.ICD10SID
	  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
			ON a.InpatientSID = d.InpatientSID
	  LEFT JOIN [Dim].[WardLocation] e WITH(NOLOCK)
			ON d.DischargeWardLocationSID = e.WardLocationSID 
	  LEFT JOIN [LookUp].[Sta6a] f WITH(NOLOCK)
			ON e.Sta6a = f.Sta6a
	  WHERE ((a.DischargeDateTime >= @EndDate_2Yr AND a.DischargeDateTime < @EndDate)
			OR a.DischargeDateTime IS NULL)
			AND b.DxCategory = 'SMI'

	  DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis;
	  SELECT
		ISNULL(mvi.MVIPersonSID, 0) AS MVIPersonSID
		,a.PatientSID
		,a.Sta3n
		,f.ChecklistID
		,d.AdmitDateTime 
	  INTO #SpecialtyTransferDiagnosis 
	  FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
	  LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
			ON a.PatientSID = mvi.PatientPersonSID
	  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH(NOLOCK)
			ON a.ICD10SID = b.ICD10SID
	  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
			ON a.InpatientSID = d.InpatientSID
	  LEFT JOIN [Dim].[WardLocation] e WITH(NOLOCK)
			ON d.DischargeWardLocationSID = e.WardLocationSID 
	  LEFT JOIN [LookUp].[Sta6a] f WITH(NOLOCK)
			ON e.Sta6a = f.Sta6a
	  WHERE ((a.SpecialtyTransferDateTime >= @EndDate_2Yr AND a.SpecialtyTransferDateTime < @EndDate)
			OR a.SpecialtyTransferDateTime IS NULL)
			AND b.DxCategory = 'SMI'		

	--Cerner
	DROP TABLE IF EXISTS #MillDiagnosis
	SELECT c.MVIPersonSID
		  ,c.PersonSID
		  ,Sta3n=200
		  ,s.ChecklistID
		  ,c.TZDerivedDiagnosisDateTime AS DiagnosisDateTime
	INTO #MillDiagnosis
	FROM [Cerner].[FactDiagnosis] c WITH(NOLOCK)
	INNER JOIN [LookUp].[ICD10_VerticalSID] l WITH(NOLOCK)
		ON l.ICD10SID=c.NomenclatureSID 
	INNER JOIN [LookUp].[Sta6a] s WITH(NOLOCK)
		ON c.sta6a=s.Sta6a
	INNER JOIN [LookUp].[ChecklistID] i WITH(NOLOCK) 
		ON s.ChecklistID=i.ChecklistID
	WHERE c.SourceVocabulary = 'ICD-10-CM' 
		AND c.MVIPersonSID>0
		AND  (c.TZDerivedDiagnosisDateTime >= @EndDate_2Yr AND c.TZDerivedDiagnosisDateTime < @EndDate)
		AND l.DxCategory='SMI'
		AND i.IOCDate is not NULL

	--Combine all and take Sta3n associated with most recent dx date
	DROP TABLE IF EXISTS #SMI_combine
	SELECT *
		,RN=row_number() OVER (Partition By MVIPersonSID order by VisitDateTime DESC)
	INTO #SMI_combine
	FROM (
			SELECT *
			FROM #OutpatVDiagnosis
			UNION ALL
			SELECT *
			FROM #InpatientDiagnosis
			UNION ALL
			SELECT *
			FROM #InpatientDischargeDiagnosis
			UNION ALL
			SELECT *
			FROM #SpecialtyTransferDiagnosis
			UNION ALL
			SELECT *
			FROM #MillDiagnosis
		) a

	DROP TABLE IF EXISTS #SMI_combine2
	SELECT a.MVIPersonSID 
		,a.PatientSID
		,a.Sta3n
		,a.ChecklistID
	INTO #SMI_combine2
	FROM #SMI_combine a
	LEFT JOIN [Common].[MasterPatient] b WITH(NOLOCK) ON a.MVIPersonSID=b.MVIPersonSID
	WHERE a.RN=1 
		AND b.Veteran=1

INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID, ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	,PatientSID
	,ChecklistID
	,RequirementName = 'SMI'
	,Sta3n_Loc = Sta3n
	,Sta3n_EHR = Sta3n
FROM #SMI_combine2

DROP TABLE IF EXISTS #OutpatVDiagnosis
DROP TABLE IF EXISTS #InpatientDiagnosis
DROP TABLE IF EXISTS #InpatientDischargeDiagnosis
DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis
DROP TABLE IF EXISTS #MillDiagnosis
DROP TABLE IF EXISTS #SMI_combine
DROP TABLE IF EXISTS #SMI_combine2

--HRF--------------------------------------------
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='PRFHRS'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	  ,PatientSID = -99 --tag to fill in later
	  ,OwnerChecklistID
	  ,RequirementName = 'PRFHRS'
	  ,Sta3n_Loc = LEFT(OwnerChecklistID,3)
	  ,Sta3n_EHR = LEFT(OwnerChecklistID,3)
FROM [PRF_HRS].[ActivePRF] WITH(NOLOCK)

--PRFHRS_12mo
----SELECT * FROM  [Config].[Present_ActivePatientRequirement] WHERE RequirementName='PRFHRS_12mo'
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT MVIPersonSID
	  ,PatientSID = -99 --tag to fill in later
	  ,OwnerChecklistID
	  ,RequirementName = 'PRFHRS_12mo'
	  ,Sta3n_Loc = LEFT(OwnerChecklistID,3)
	  ,Sta3n_EHR = LEFT(OwnerChecklistID,3)
FROM (
	SELECT MVIPersonSID,OwnerChecklistID
		  ,RN=Row_Number() OVER(Partition By MVIPersonSID ORDER BY ActionDateTime desc)
	FROM [App].[fn_PRF_HRS_ActivePeriod] (@EndDate_1Yr,@EndDate)
	) h  
WHERE RN=1
GROUP BY MVIPersonSID,OwnerChecklistID

/** STORM additional cohort: ODPastYear **/
-- There are cases where an OD is reported, but no other criteria is met to appear in STORM cohort
INSERT INTO #Criteria (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
SELECT DISTINCT 
	od.MVIPersonSID
	,p.PatientPersonSID 
	,od.ChecklistID
	,RequirementName = 'ODPastYear'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_EHR = od.Sta3n
FROM [OMHSP_Standard].[SuicideOverdoseEvent] od WITH(NOLOCK)
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] p WITH(NOLOCK)
	ON  p.MVIPersonSID=od.MVIPersonSID
	AND p.Sta3n=LEFT(od.ChecklistID,3)
WHERE (
		EventDateFormatted >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))
		OR (EventDateFormatted IS NULL
			AND EntryDateTime > DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)))
		)
	AND Overdose = 1
	AND Fatal = 0
	AND od.MVIPersonSID IS NOT NULL

/****REACH VET Risk Score Population (to add any not identified through any other criteria****/
/*Added this section to keep all patients seen in past 2 years (reach criterion) because CRISTAL is 
	currently dependent on SPatient, so we want all patients to display. When we change CRISTAL 
	then we can remove this section.*/
----SELECT * FROM [Config].[Present_ActivePatientRequirement] WHERE RequirementName='ReachPop'
DROP TABLE IF EXISTS #AddMissingReach;
SELECT r.MVIPersonSID
	,PatientPersonSID = ISNULL(p.PatientPersonSID,r.PatientPersonSID) 
	,r.ChecklistID
	,RequirementName = 'ReachPop'
	,Sta3n_Loc = LEFT(ChecklistID,3)
	,Sta3n_EHR = ISNULL(p.Sta3n,r.Sta3n_EHR)
INTO #AddMissingReach
FROM [REACH].[ActivePatient] r WITH(NOLOCK)
LEFT JOIN [Common].[MVIPersonSIDPatientPersonSID] p WITH(NOLOCK)
	ON 	p.MVIPersonSID=r.MVIPersonSID
	AND p.Sta3n=LEFT(r.ChecklistID,3)
	
MERGE #Criteria as t
USING #AddMissingReach as s ON s.MVIPersonSID=t.MVIPersonSID
WHEN NOT MATCHED BY TARGET THEN 
	INSERT (MVIPersonSID,PatientPersonSID,ChecklistID,RequirementName,Sta3n_Loc,Sta3n_EHR)
	VALUES (s.MVIPersonSID,s.PatientPersonSID,s.ChecklistID,s.RequirementName,s.Sta3n_Loc,s.Sta3n_EHR)
;
DROP TABLE IF EXISTS #AddMissingReach


--remove any test patients, etc (only valid IDs) --
DELETE C
FROM #Criteria as c
LEFT JOIN [Common].[MasterPatient] mp WITH(NOLOCK) 
	on mp.MVIPersonSID=c.MVIPersonSID
WHERE mp.MVIPersonSID IS NULL -- e.g. test patients
	OR mp.DateOfDeath IS NOT NULL --remove decedents --165779
	OR (c.MVIPersonSID IS NULL OR c.MVIPersonSID=0) --also remove invalid MVIPersonSID


--Set PatientPersonSID to CDW PatientSID if it's missing
UPDATE #Criteria
SET PatientPersonSID = ps.PatientPersonSID
FROM #Criteria c
inner JOIN [Common].[MVIPersonSIDPatientPersonSID] ps WITH(NOLOCK) 
	ON	ps.MVIPersonSID=c.MVIPersonSID
	AND ps.Sta3n=c.Sta3n_Loc
  
  
  
--Set PatientPersonSID to CDW PatientSID if it's missing
UPDATE #Criteria
SET PatientPersonSID = isnull(ps.PatientPersonSID,ps1.PatientPersonSID)
FROM #Criteria c
inner join lookup.checklistid as cl on c.Sta3n_Loc = cl.STA3N
left outer JOIN [Common].[MVIPersonSIDPatientPersonSID] ps WITH(NOLOCK) 
	ON 	ps.MVIPersonSID=c.MVIPersonSID
	AND ps.Sta3n=c.Sta3n_Loc and cl.iocdate is null
left outer JOIN [Common].[MVIPersonSIDPatientPersonSID] ps1 WITH(NOLOCK) 
	ON	ps1.MVIPersonSID=c.MVIPersonSID
	AND ps1.Sta3n = 200 and cl.iocdate is not null

  


/***TO DO: double check for multiple patientsid in 1 station***/

DROP TABLE IF EXISTS #CriteriaFinal
SELECT MVIPersonSID
	,ChecklistID
	,RequirementID
	,MIN(PatientPersonSID) as PatientPersonSID --If there is a PatientSID and a PersonSID for 1 checklistID, take the smallest, which will be the VistA ID (in case of downstream joins e.g., PDSI)
	,SourceEHR = CASE 
		WHEN MAX(Sta3n_EHR) = 200 THEN 'M'	-- only Sta3n is 200, Millenium only
		WHEN MIN(Sta3n_EHR) > 200 THEN 'V'		-- only Sta3ns that are NOT 200, VistA only
		WHEN MIN(Sta3n_EHR)=200 AND MAX(Sta3n_EHR)>200 THEN 'VM'
		ELSE NULL
		END
	,Sta3n_Loc=LEFT(ChecklistID,3)
INTO #CriteriaFinal
FROM #Criteria c
INNER JOIN [Config].[Present_ActivePatientRequirement] pr WITH(NOLOCK)
	ON pr.RequirementName=c.RequirementName
GROUP BY MVIPersonSID
	,ChecklistID
	,RequirementID

DROP TABLE IF EXISTS #Criteria
	
	--SELECT count(*) FROM #CriteriaFinal WHERE PatientPersonSID > 1800000000

-- Clean Up ODPastYear (only need if no other STORM display criteria)
DECLARE @OD INT = (SELECT RequirementID FROM [Config].[Present_ActivePatientRequirement] WHERE RequirementName = 'ODPastYear')
;WITH KeepODOnly AS (
	SELECT MVIPersonSID,@OD as RequirementID
	FROM (
		SELECT c.MVIPersonSID 
			,COUNT(c.RequirementID) as ReqCount
			,MAX(CASE WHEN c.RequirementID = @OD THEN 1 ELSE 0 END) ODFlag
		FROM #CriteriaFinal c
		INNER JOIN [Config].[Present_ProjectDisplayRequirement] d WITH(NOLOCK)
			ON d.RequirementID=c.RequirementID
			AND d.ProjectName = 'STORM'
		GROUP BY c.MVIPersonSID
		) a
	WHERE ODFlag = 1 AND ReqCount > 1 
	)
DELETE #CriteriaFinal
FROM #CriteriaFinal f
INNER JOIN KeepODOnly x ON x.MVIPersonSID = f.MVIPersonSID
	AND x.RequirementID = f.RequirementID

--------------------------------------------------------------------------------
-- PUBLISH
--------------------------------------------------------------------------------
EXEC [Maintenance].[PublishTable] 'Present.ActivePatient','#CriteriaFinal'

DROP TABLE IF EXISTS #CriteriaFinal

EXEC [Log].[ExecutionEnd]

END