



/********************************************************************************************************************
DESCRIPTION: Procedure checks for validation criteria and returns results to Log.MessageLog
AUTHOR:		 SUSANA MARTINS
CREATED:	 2015-03-05
UPDATE:
	2017-10-27	RAS		STORM SPRINT MODIFICATIONS:
						* Removed "key" and "flag" from variable names and corrected variable names to stay consistent with lookup tables
						* Created cohort temp table using ORM.Cohort and use this for inner joins instead of spatient when need all SIDs.
						* replaced [ORM].[MPR_ActiveOpioids] with ORM.Medications (using lastreleasedatetime for most recent prescriber)
						* combined queries for outpatient and ER visits, removed hard coded variables and used [LookUp].StopCode
						* changed and simplified inpatient query to use Inpatient.Bedsection instead of CDW 
						* combined queries for PainAdjs and Sedative
						* removed opioid medd temp table because this information is now pulled from ORM.Cohort
	2017-12-19			Combined RiskVariables and RiskVariablesHypothetical
	2018-06-07	JB		Removed hard coded database references
	2018-06-18	RAS		Changed references to outbox to actual tables. Added PDW partition enhancement. Changed final query to truncate instead of drop.
	2018-06-19	RAS/SM	Verified and corrected SP fields matched table [ORM].[RiskScore]
	2018-07-18  SM		removing dependencies from storm=1 in ActivePatient tables:spatient and stationassignments for hypothetical risk computation (so we compute for all CDS active patients as defined)
	2018-11-19	SM		casted variables to be added since they were changed to bit
	2019-02-15	JB		Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
	2020-03-27	RAS		Added RRTP_TreatingSpecialty in inpatient mental health section (definition needs to include acute and residential settings). 
	2020-04-01	RAS		Changed diagnosis category Psych_poss to Other_MH_STORM.
	2020-04-26	SM		Updated MEDD to use correct MEDD_RiskScore based on new code (updates to MEDD computation detailed in Code.ORM_Cohort)
	2020-06-30	PS		Inclusion of SBOR as suicide events
	2020-07-28	RAS		V02 - Branched from production code and added code to add variables to new RiskScore architecture instead of more involved revamp previously in v02
	2020-10-28  RAS		VM VERSION: Added code for Cerner Millenium data.  See additional notes regarding code structure and method to integrate data
						Reverted some portions to old method so that we can continue to use previous RiskScore code to expedite validation.
						We will work on converting to new architecture after initial Cerner data release in CDS.
	2020-12-04	RAS		Corrected variable names for MHInpat,MHOutpat, and ERvisit which were causing all 0 values in final table.  
						Added missing WHERE statements for VistA MHOutpat and ERvisit inserts. Added case statements for interactions per original code.
	2020-12-06	RAS		Added delete statement to make sure merge to PatientVariable drops the patient-variable rows that no longer meet the criteria.
						Added date restriction to MHOutpat and ERvisit queries from Mill FactOutpatientUtilization
	2020-12-10	RAS		Corrected query for #MostCareChecklistID which was dropping ~300000 patients.
	2020-12-11	RAS		Corrected variable pull from Cohort to keep MEDD as decimal.
	2021-04-09  PS		Overlaying DoD data
	2021-04-22  SM		Correcting 'PainAdjAnticonvulsant_Rx','PainAdjSNRI_Rx','PainAdjTCA_Rx'  computation to look back in past						year.
	2021-05-10  JJR_SA	Changed reference for DimEncMillEncounter with EncMillEncounter table
	2021-05-24  PS		Continued overlay of DoD, to pull Dx from Present.Dx where possible
	2021-07-16	JEB		Enclave Refactoring - Counts confirmed
	2021-07-16	JEB		WHERE clause edited since DaysSupply values of 99,131,319, 7,139,998, 3,040,506, or 419,815, look to be invalid.
	2021-08-10	RAS		Changed references from ORM.Cohort to SUD.Cohort and ORM.OpioidHistory where necessary.
	2021-09-23	JEB		Enclave Refactoring - Removed use of Partition ID
	2021-10-12	LM		Specifying outpat, inpat, and DoD diagnoses (excluding dx only from community care or problem list)
	2021-12-19	RAS		Corrected pull for Overdose_Suicide from DOD that was leading to duplicate patient rows.
	2022-02-22  CLB     Changed reference from synonym pointing to SbxA to [ORM].[vwDOD_TriSTORM] for DoD JVPN data
	2022-05-02	RAS		Changed reference from LookUp CPT to LookUp ListMember.
	2022-05-04	RAS		Refactored LookUp.MorphineEquiv join to use NationalDrugSID for VistA data and VUID for Cerner Mill data
	2022-05-06	LM		Changed MHRecent_Stop to MHOC_MentalHealth_Stop and MHOC_Homeless_Stop
	2022-05-18	RAS		Refactored so that preparatory tables just have a record for every variable value and SourceEHR combination.
						Then clean up of SourceEHR is done at the end in creating #PatientVariableStage
	2022-07-15	SM		Updating MEDDTotal and MEDD_RiskScore to use only 'Pills on hand',
						Renaming current computation with active opioid (active rx status or PoH) to TotalMEDD_ActiveRx,MEDD_Report_ActiveRx
	2022-10-25	LM		Updated logic for long-acting/short-acting/tramadol only opioid history to be mutually exclusive
	2024-07-16  TG     Switched to the new dataset for hospice variable
	
	NOTE RE: ORGANIZATION AND ADDING MILL DATA:
	These sections are computed from VistA and Millenium data that has been previously integrated 
		and the code for these appears first in the code.
		-- DIAGNOSIS
		-- MH INPATIENT ADMISSIONS IN PAST YEAR
		-- PAIN ADJUCT THERAPY CLASSES 
		-- MOST RECENT PRESCRIBER
		-- DEMOGRAPHICS
	Following the above, there is a large section for pieces that are computed separately for
		VistA and Millenium data and are then combined in a final step:
		-- HOSPICE CARE (EXCLUSION)
		-- DETOX

DEPENDENCIES:
	- [Present].[SPatient]
	- [Present].[Diagnosis]
	- [OMHSP_Standard].[SuicideOverdoseEvent]
	- [Inpatient].[BedSection]
		-- MH OUTPATIENT OR ER VISITS
	- [Present].[ActivePatient] 
	- [Common].[MasterPatient]
	- [ORM].[OpioidHistory]			
	- [Present].[Medications]		
	- [SUD].[Cohort]					
********************************************************************************************************************/

/*Cerner Millenium Questions:
Hospice -- Accommodation, MedicalService or both?
*/
CREATE PROCEDURE [Code].[ORM_RiskVariables]

AS

BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_RiskVariables', @Description = 'Execution of Code.ORM_RiskVariables SP'

------------------------------------------------------
-- DIAGNOSIS
------------------------------------------------------
	--Get all patients with diagnoses of interest
	----Present.Diagnosis includes VistA, DoD, and Cerner Millenium data
	DROP TABLE IF EXISTS #DxCohort
	SELECT MVIPersonSID
		,DxCategory as VariableName
		,VariableValue = 1
		,SourceEHR
	INTO #DxCohort
	FROM [Present].[Diagnosis] WITH (NOLOCK)
	WHERE DxCategory IN (
		'EH_AIDS'
		,'EH_CHRNPULM'
		,'EH_COMDIAG'
		,'EH_ELECTRLYTE'
		,'EH_HYPERTENS'
		,'EH_LIVER'
		,'EH_NMETTUMR'
		,'EH_OTHNEURO'
		,'EH_PARALYSIS'
		,'EH_PEPTICULC'
		,'EH_PERIVALV'
		,'EH_RENAL'
		,'EH_HEART'
		,'EH_ARRHYTH'
		,'EH_VALVDIS'
		,'EH_PULMCIRC'
		,'EH_HYPOTHY'
		,'EH_RHEUMART'
		,'EH_COAG'
		,'EH_WEIGHTLS'
		,'EH_DEFANEMIA'
		,'SEDATEISSUE'
		,'AUD_ORM'
		,'OUD'
		,'SUDDX_POSS'
		,'OPIOIDOVERDOSE'
		,'SAE_FALLS'
		,'SAE_OTHERACCIDENT'
		,'SAE_OTHERDRUG'
		,'SAE_VEHICLE'
		,'SAE_ACET'
		,'SAE_SED'
		,'OTHER_MH_STORM'
		,'SUD_NOOUD_NOAUD'
		,'OSTEOPOROSIS'
		,'SLEEPAPNEA'
		,'NICDX_POSS'
		,'BIPOLAR'
		,'PTSD'
		,'MDD'
		,'COCNDX'
		,'OTHERSUD_RISKMODEL'
		,'SEDATIVEUSEDISORDER'
		,'CANNABISUD_HALLUCUD'
		,'COCAINEUD_AMPHUD'
		,'EH_UNCDIAB'
		,'EH_COMDIAB'
		,'EH_LYMPHOMA'
		,'EH_METCANCR'
		,'EH_OBESITY'
		,'EH_BLANEMIA')
	AND (Outpat=1 OR Inpat=1 OR DoD=1)

	-- SUICIDE (Present.Diagnosis AND SBOR)
	INSERT INTO #DxCohort
	SELECT MVIPersonSID 
		  ,VariableName='SUICIDE'
		  ,VariableValue=1
		  ,SourceEHR
	FROM (
		SELECT MVIPersonSID,SourceEHR
		FROM [Present].[Diagnosis] WITH (NOLOCK)
		WHERE DxCategory='SUICIDE'
			AND (Outpat=1 OR Inpat=1 OR DoD=1)
		UNION ALL
		SELECT sbor.MVIPersonSID
			,SourceEHR = CASE WHEN sbor.Sta3n=200 THEN 'M' ELSE 'V' END
		FROM [OMHSP_Standard].[SuicideOverdoseEvent] sbor  WITH (NOLOCK) 
		INNER JOIN [Present].[SPatient] sp  WITH (NOLOCK) on sbor.MVIPersonSID=sp.MVIPersonSID
		WHERE ISNULL(EventDateFormatted,EntryDateTime) >= CAST((GETDATE() - 380) AS DATE)	
		) s
	GROUP BY MVIPersonSID,SourceEHR

	--Overdose_Suicide,SumOverdose_Suicide, and AnySAE are computed in aggregate code
------------------------------------------------------
-- MH INPATIENT ADMISSIONS IN PAST YEAR
------------------------------------------------------
-- Per Oliva et al. 2016: Bed Sections: 33, 70,72-74, 76, 79,89,91-94,25-27,37,39,84-86,88,89,109, 110, 111 

	--Inpatient.BedSection has VistA and Cerner Millennium data, then union in DoD data
	DROP TABLE IF EXISTS #InpatStage;
	SELECT MVIPersonSID
		,MHInpatient = 1
		,SourceEHR=CASE WHEN Sta3n_EHR = 200 THEN 'M' ELSE 'V' END
	INTO #InpatStage
	FROM [Inpatient].[BedSection] as i  WITH (NOLOCK)
	WHERE  (i.DischargeDateTime >= DATEADD(DAY, -366, CAST(GETDATE() as DATE)))
		AND (i.MentalHealth_TreatingSpecialty=1 OR i.RRTP_TreatingSpecialty=1)
	UNION  -- intentionally choosing distinct records so that SourceEHR grouping below is simpler
	SELECT MVIPersonSID
		,MHInpatient = 1
		,SourceEHR = 'O' -- "Other"
	FROM [ORM].[vwDOD_TriSTORM]  WITH (NOLOCK)
	WHERE MHINPAT = 1
	
------------------------------------------------------
-- PAIN ADJUCT THERAPY CLASSES  in past year
-- Source EHR is correct 1=Vista, 2=Cerner, 3= Vista and Cerner
------------------------------------------------------
	--Pills on hand pain adjunct anticonvulsants in past year
DROP TABLE IF EXISTS #PainAdj;--1586129
WITH VUIDVertical AS (
	SELECT VUID
		,DrugCategory
	FROM (
		SELECT VUID,PainAdjAnticonvulsant_Rx
			,PainAdjSNRI_Rx,PainAdjTCA_Rx
		FROM [LookUp].[Drug_VUID] WITH (NOLOCK)
		) p
	UNPIVOT (Flag FOR DrugCategory IN (
		PainAdjAnticonvulsant_Rx
		,PainAdjSNRI_Rx
		,PainAdjTCA_Rx
		)	) u
	WHERE Flag = 1
	)

	SELECT pa.MVIPersonSID
		,VariableName = pa.DrugCategory
		,VariableValue = 1
		,SourceEHR
	INTO #PainAdj
	FROM (
		-- VistA: pills on hand pain adjunct anticonvulsants in past year
		SELECT DISTINCT 
			p.MVIPersonSID
			, b.DrugCategory
			,SourceEHR = 'V'
		FROM [RxOut].[RxOutpatFill] a WITH (NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON a.PatientSID = mvi.PatientPersonSID 
		INNER JOIN [LookUp].[NationalDrug_Vertical] b WITH (NOLOCK)
			ON a.NationalDrugSID = b.NationalDrugSID
		INNER JOIN [SUD].[Cohort] p WITH (NOLOCK)
			ON p.MVIPersonSID = ISNULL(mvi.MVIPersonSID,0)
		WHERE a.DaysSupply <= 100000
			--JEB: Above clause added since DaysSupply values of 99,131,319, 7,139,998, 3,040,506, or 419,815, look to be invalid.
			AND b.DrugCategory IN (
				'PainAdjAnticonvulsant_Rx'
				,'PainAdjSNRI_Rx'
				,'PainAdjTCA_Rx'
				)
			AND	( a.ReleaseDateTime>= CAST((GETDATE() - 380) AS DATE)
				OR (DATEADD (DAY,a.DaysSupply,CAST(a.ReleaseDateTime AS DATE)) >= CAST((GETDATE() - 380) AS DATE) )
				)
		UNION ALL

		--CERNER:  pills on hand adjunct anticonvulsants in past year
		SELECT DISTINCT 
			p.MVIPersonSID
			,v.DrugCategory
			,SourceEHR = 'M'
		FROM [Cerner].[FactPharmacyOutpatientDispensed] a WITH (NOLOCK)
		INNER JOIN VUIDVertical v ON v.VUID = a.VUID
		INNER JOIN [SUD].[Cohort] p WITH (NOLOCK)
			ON p.MVIPersonSID=a.MVIPersonSID
		WHERE 	(	a.TZDerivedCompletedUTCDateTime>= CAST((GETDATE() - 380) AS DATE)
					OR DATEADD(DAY,a.DaysSupply,a.TZDerivedCompletedUTCDateTime) >= CAST((GETDATE() - 380) AS DATE)
				)
		) pa
	GROUP BY pa.MVIPersonSID
		,pa.DrugCategory  
		,pa.SourceEHR

------------------------------------------------------
-- SEDATIVES (benzo, barb, soma, ambien): Active Rx or Pills on hand
-- of note, SourceEHR is not correct
------------------------------------------------------
--CERNER OR VISTA
DROP TABLE IF EXISTS #OtherMeds;
SELECT MVIPersonSID
	,VariableName
	,VariableValue
	,SourceEHR
INTO #OtherMeds
FROM (
	SELECT m.MVIPersonSID
		,SourceEHR = CASE WHEN m.Sta3n  = 200 THEN 'M' ELSE 'V' END
		,SedativeOpioid_Rx	= MAX(CAST(m.SedativeOpioid_Rx AS INT))
		,Anxiolytics_Rx		= MAX(CAST(m.Anxiolytics_Rx AS INT))
		,Bowel_Rx			= MAX(CAST(m.Bowel_Rx AS INT))
	FROM [Present].[Medications] m WITH (NOLOCK)
	INNER JOIN [SUD].[Cohort] as p WITH (NOLOCK) on p.MVIPersonSID = m.MVIPersonSID
	WHERE m.SedativeOpioid_Rx = 1
		OR m.Anxiolytics_Rx = 1
		OR m.Bowel_Rx = 1
	GROUP BY m.MVIPersonSID,CASE WHEN m.Sta3n  = 200 THEN 'M' ELSE 'V' END
	) p
UNPIVOT (VariableValue FOR VariableName IN (
	SedativeOpioid_Rx,Anxiolytics_Rx,Bowel_Rx)	
	) u
WHERE VariableValue = 1
GROUP BY MVIPersonSID,VariableName,VariableValue,SourceEHR

------------------------------------------------------
-- MOST RECENT PRESCRIBER
------------------------------------------------------
	DROP TABLE IF EXISTS #MostRecentPrescriber
	SELECT MVIPersonSID
		  ,MostRecentPrescriberSID
		  ,MostRecentPrescriber
		  ,VISN as MostRecentPrescriberVISN
		  ,Sta3n as MostRecentPrescriberSta3n
	INTO #MostRecentPrescriber 
	FROM (
		SELECT MVIPersonSID
				,StaffName as MostRecentPrescriber
				,ProviderSID as MostRecentPrescriberSID
				,m.ChecklistID as MostRecentPrescriberChecklistID
				,sta.VISN
				,sta.Sta3n
				,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ReleaseDateTime desc) AS MostRecentRank
		FROM [ORM].[OpioidHistory] m WITH(NOLOCK)
		INNER JOIN [LookUp].[ChecklistID] as sta WITH(NOLOCK) on m.ChecklistID=sta.ChecklistID
		WHERE Active = 1
		) as pr
	WHERE MostRecentRank = 1 

	DROP TABLE IF EXISTS #MostCareChecklistID
	SELECT TOP 1 WITH TIES
		MVIPersonSID
		,Sta3n
		,VISN
		,CareSum
	INTO #MostCareChecklistID
	FROM (
		SELECT ap.MVIPersonSID
			,cl.Sta3n
			,cl.VISN
			,CareSum=SUM(CASE WHEN r.RequirementName IN ('HomeStation','MHTC','PCP','MH/BHIP','PACT','Inpatient','InpatientCensus','Rx','ODPastYear')
					THEN 1 ELSE 0 END
					)
			--COUNT(ap.RequirementID)
		FROM [Present].[ActivePatient] ap WITH (NOLOCK)
		INNER JOIN [Config].[Present_ActivePatientRequirement] r WITH (NOLOCK) on ap.RequirementID=r.RequirementID
		INNER JOIN [LookUp].[ChecklistID] cl WITH (NOLOCK) on cl.ChecklistID=ap.ChecklistID
		--WHERE r.RequirementName IN ('HomeStation','MHTC','PCP','MH/BHIP','PACT','Inpatient','InpatientCensus','Rx')
		GROUP BY ap.MVIPersonSID,cl.Sta3n,cl.VISN
		) a
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY CareSum DESC)

	DROP TABLE IF EXISTS #DemogWithPrescriber
	SELECT care.MVIPersonSID
		  ,Sta3n =ISNULL(pr.MostRecentPrescriberSta3n,care.Sta3n)
		  ,VISN	 =ISNULL(pr.MostRecentPrescriberVISN,care.VISN)
		  ,mp.Gender 
		  ,mp.Age
		  ,pr.MostRecentPrescriberSID
		  ,pr.MostRecentPrescriber
		  ,mp.SourceEHR
	INTO #DemogWithPrescriber
	FROM #MostCareChecklistID care
	LEFT JOIN #MostRecentPrescriber as pr WITH (NOLOCK) on pr.MVIPersonSID=care.MVIPersonSID
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) on mp.MVIPersonSID=care.MVIPersonSID

	DROP TABLE IF EXISTS #demographics
	SELECT MVIPersonSID
		  ,VariableName as VariableNameOld
		  ,VariableValue as VariableValueOld
		  ,VariableName=
			CASE 
				WHEN VariableName='Gender' AND VariableValue='M' THEN 'GenderMale'
				WHEN VariableName='Gender' AND VariableValue='F' THEN 'GenderFemale'
				WHEN VariableName='Gender' AND VariableValue='M' THEN 'GenderMale'
				WHEN VariableName='Sta3n' THEN 'STATION'+VariableValue
				WHEN VariableName='VISN' THEN 'VISN'+VariableValue
				ELSE VariableName END
		  ,VariableValue=
			CASE WHEN VariableName IN ('Gender','Sta3n','VISN') THEN 1 ELSE VariableValue END
		  ,SourceEHR
	INTO #demographics
	FROM (
		SELECT MVIPersonSID
			  ,SourceEHR
			  ,CAST(Sta3n AS VARCHAR) as Sta3n
			  ,CAST(VISN AS VARCHAR) as VISN
			  ,CAST(Gender AS VARCHAR) as Gender
			  ,CAST(Age AS VARCHAR) as Age
		FROM #DemogWithPrescriber
		) p
	UNPIVOT (VariableValue FOR VariableName IN (
		Sta3n
		,VISN
		,Gender
		,Age
		) 
		)u
	
	DROP TABLE #MostCareChecklistID
		,#MostRecentPrescriber
	
------------------------------------------------------
-- VistA/Millenium/DoD Separate Processing
------------------------------------------------------
DROP TABLE IF EXISTS #PatientVariableVMD
CREATE TABLE #PatientVariableVMD (
	MVIPersonSID INT NULL, 
	VariableName VARCHAR(25), 
	VariableValue DECIMAL(15,8), 
	SourceEHR VARCHAR(2)
	)		
	------------------------------------------------------
	-- HOSPICE CARE (EXCLUSION)
	------------------------------------------------------
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT os.MVIPersonSID
			,'Hospice'
			,1
			,'V'
		FROM [Present].[SPatient] os WITH (NOLOCK)
		INNER JOIN  ORM.HospicePalliativeCare hp
	ON os.MVIPersonSID = hp.MVIPersonSID AND hp.Hospice = 1
	
			--SELECT distinct medicalservice,EncounterTypeClass,Accommodation FROM [Cerner].[EncMillEncounter] WHERE MedicalService LIKE '%hospice%'	OR Accommodation = 'Hospice'

	------------------------------------------------------
	-- MH OUTPATIENT OR ER VISITS
	------------------------------------------------------
		-- MH Outpatient and ER visits from VistA data (stop codes)
		DROP TABLE IF EXISTS #VistaAStop;
		SELECT v.MVIPersonSID
			,MAX(v.MHRecent_Stop) AS MHRecent_Stop
			,MAX(v.EmergencyRoom_Stop) AS EmergencyRoom_Stop
		INTO #VistaAStop
		FROM (
			SELECT 
				mvi.MVIPersonSID AS MVIPersonSID
				,v1.PrimaryStopCodeSID
				,ISNULL(sc.MHOC_MentalHealth_Stop,sc.MHOC_Homeless_Stop) AS MHRecent_Stop
				,sc.EmergencyRoom_Stop
			FROM [Outpat].[Visit] v1 WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON v1.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [LookUp].[StopCode] sc WITH (NOLOCK) ON sc.StopCodeSID = v1.PrimaryStopCodeSID
			INNER JOIN [Present].[SPatient] p WITH (NOLOCK) ON p.MVIPersonSID = mvi.MVIPersonSID
			WHERE (sc.MHOC_MentalHealth_Stop = 1 OR sc.MHOC_Homeless_Stop = 1 OR sc.EmergencyRoom_Stop = 1) 
				AND v1.VisitDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
			) v
		GROUP BY v.MVIPersonSID ;

		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT MVIPersonSID
			,'MHOutpat'
			,1
			,'V'
		FROM  #VistaAStop
		WHERE MHRecent_Stop = 1

		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT MVIPersonSID
			,'ERvisit'
			,1
			,'V'
		FROM  #VistaAStop
		WHERE EmergencyRoom_Stop = 1

		DROP TABLE #VistaAStop

		-- MH Outpatient and ER visits from millenium data 
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT uxo.MVIPersonSID
			,'MHOutpat'
			,1
			,'M'
		FROM [Cerner].[FactUtilizationOutpatient] uxo WITH (NOLOCK)
		INNER JOIN [LookUp].[ListMember] lat WITH (NOLOCK) ON lat.ItemID=uxo.ActivityTypeCodeValueSID 
		WHERE lat.Domain='ActivityType'
			AND lat.List IN ('MHOC_MH','MHOC_Homeless')
			AND uxo.TZDerivedVisitDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))		
		GROUP BY MVIPersonSID
		
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT uxo.MVIPersonSID
			,'ERvisit'
			,1
			,'M'
		FROM [Cerner].[FactUtilizationOutpatient] uxo WITH (NOLOCK)
		WHERE uxo.TZDerivedVisitDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
			AND EmergencyCareFlag = 1
		GROUP BY MVIPersonSID

		-- ER visits from DoD data
		DROP TABLE IF EXISTS #DoDStop
		
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT MVIPersonSID
			,'ERvisit'
			,1
			,'D'
		FROM [ORM].[vwDOD_TriSTORM] WITH (NOLOCK)
		WHERE ERVISIT = 1

	------------------------------------------------------
	-- DETOX
	------------------------------------------------------
		
		-- Detox CPT from VistA data
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT DISTINCT 
			ss.MVIPersonSID
			,'Detox_CPT'
			,1
			,'V'
		FROM [Outpat].[VProcedure] vp WITH (NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON mvi.PatientPersonSID = vp.PatientSID
		INNER JOIN [Present].[SPatient] ss WITH (NOLOCK) ON mvi.MVIPersonSID = ss.MVIPersonSID
		INNER JOIN [LookUp].[ListMember] lc WITH (NOLOCK) ON lc.ItemID = vp.CPTSID
		WHERE lc.List = 'Detox'
			AND lc.Domain = 'CPT'
			AND vp.VisitDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))	

		-- Detox CPT from Cerner Millenium data	
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT DISTINCT --PersonSID
			p.MVIPersonSID
			,VariableName = 'Detox_CPT'
			,VariableValue = 1
			,SourceEHR = 'M'
		FROM [Cerner].[FactProcedure] p WITH (NOLOCK)
		INNER JOIN [LookUp].[ListMember] c WITH (NOLOCK) ON c.ItemID = p.NomenclatureSID
		WHERE c.List = 'Detox'
			AND c.Domain = 'CPT'
			AND p.SourceVocabulary IN ('CPT4','HCPCS')
			AND p.TZDerivedProcedureDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))

		-- Detox flag from DoD data
		INSERT INTO #PatientVariableVMD (MVIPersonSID,VariableName,VariableValue,SourceEHR)
		SELECT MVIPersonSID
			,VariableName = 'Detox_CPT'
			,VariableValue = 1
			,SourceEHR = 'O' -- "Other"
		FROM [ORM].[vwDOD_TriSTORM] WITH (NOLOCK)
		WHERE DETOX_CPT = 1


/*********************************************************************************
MEDD COMPUTATION: 
Four MEDD's computed:	
(1) TotalMEDD and MEDD_Report (pills on Hand(PoH)) --USED FOR RISK SCORE COMPUTATION
(2) TotalMEDD_ActiveRx and MEDD_Report_ActiveRx (active Rx status or Pills on Hand (PoH))

TotalMEDD and TotalMEDD_ActiveRx  - uses older method used in original modeling (does not have different coefficients for methadone based on daily dose)						
MEDD_Report and MEDD_Report_ActiveRx- Updated method from CDC  (has different coefficients for methadone based on daily dose)

** DEFINITION of which fill to consider active: Per JT, we will compute MEDD for all patients that have opioid on hand independent of RXstatus
** MEDD computation is for select formulations of opioidforpain_rx included in [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] 
	(of note specific formulations such as powder, crystal and injectables are excluded from MEDD computation)
** Daily dose will be computed by aggregating around drugnamewithdose and adding up dayssupply and qty for valid fills then compute daily dose (as opposed to adding up daily dose across DrugNameWithDose). 
	This makes the assumption that multiple fills are not intended to be additive and will be taken sequentially. As a rule, this means we will underestimate.
** Different DoseTypes (liquid vs unitdose) defined in [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] require different formulas to compute daily dose: stregth of med in in StrengthNumeric or StrengthPer_mL
** Methodone MEDD computation depends on a patient's summed daily dose for methadone fills to then apply hard coded conversion factors.
**********************************************************************************************/


/************
STEP 1: Helper table - used in both computations
Useful because we are aggregating MEDD by DrugNameWithDose and not NationalDrugSID
so we only want one copy of each StrengthNumeric, etc.
**************/
DROP TABLE IF EXISTS #ME_helper
SELECT DISTINCT 
	DrugNameWithDose
	,Opioid
	,DosageForm
	,DoseType
	,[StrengthNumeric]
	,StrengthPer_mL
	,StrengthPer_NasalSpray
	,[ConversionFactor_Report]
	,[ConversionFactor_RiskScore]
INTO #ME_helper
FROM [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] WITH (NOLOCK)


/*************************************************
Step 2: MEDD for Active_Rx (active Rx status or PoH)
Variables: TotalMEDD_ActiveRx and MEDD_Report_ActiveRx
**************************************************/
---------------------------------------------
--Step 2.1: Valid Fills
---------------------------------------------
DROP TABLE IF EXISTS #ValidMEDD_RxFills_ActiveRx
SELECT DISTINCT 
	oh.MVIPersonSID
	--,vme.NationalDrugSID
	,Sta3n					= COALESCE(vme.Sta3n,oh.Sta3n)
	,DrugNameWithDose		= COALESCE(vme.DrugNameWithDose,mme.DrugNameWithDose)
	,Opioid					= COALESCE(vme.Opioid,mme.Opioid)
	,DoseType				= COALESCE(vme.DoseType,mme.DoseType)
	,StrengthPer_ml			= COALESCE(vme.StrengthPer_ml,mme.StrengthPer_ml)
	,StrengthPer_NasalSpray	= COALESCE(vme.StrengthPer_NasalSpray,mme.StrengthPer_NasalSpray)
	,oh.RxOutpatSID
	,oh.ReleaseDateTime
	,RxEndDate				= DATEADD(DAY, oh.DaysSupply, oh.ReleaseDateTime)
	,oh.DaysSupply
	,Qty					= CAST(oh.Qty AS numeric)
	,StrengthNumeric		= COALESCE(vme.StrengthNumeric,mme.StrengthNumeric)
	,NasalSprays_PerBottle	= COALESCE(vme.NasalSprays_PerBottle,mme.NasalSprays_PerBottle)
INTO #ValidMEDD_RxFills_ActiveRx
FROM [ORM].[OpioidHistory] oh WITH (NOLOCK)
LEFT JOIN [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] vme WITH (NOLOCK) ON 
	oh.NationalDrugSID = vme.NationalDrugSID
	AND oh.Sta3n <> 200 -- Join on NationalDrugSID for VistA meds, and below on VUID for Millennium records
LEFT JOIN (
	SELECT DISTINCT VUID,DrugNameWithDose,Opioid,DoseType
		,StrengthPer_ml,StrengthNumeric
		,StrengthPer_NasalSpray,NasalSprays_PerBottle
	FROM [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] WITH (NOLOCK)
	) mme ON mme.VUID = oh.VUID
	AND oh.Sta3n = 200
WHERE oh.Active = 1
	-- below condition limits to only medications in the MorphineEquiv table (e.g., no injectables)
	AND (vme.NationalDrugSID IS NOT NULL 
		OR mme.VUID IS NOT NULL)
-----------------------------------------------------------------------------------
--Step 2.2: Just compute SourceEHR once for where the patient is receiving meds
------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #MEDD_EHR_ActiveRx;
	SELECT MVIPersonSID
		,SourceEHR = CASE WHEN MAX(Sta3n) = 200 THEN 'M'
			WHEN MIN(Sta3n) = 200 AND MAX(Sta3n)>200 THEN 'VM'
			ELSE 'V' END
	INTO #MEDD_EHR_ActiveRx
	FROM #ValidMEDD_RxFills_ActiveRx
	GROUP BY MVIPersonSID
----------------------------------------------------------
--Step 2.3 DAILY DOSE METHADONE and NON-METHADONE
----------------------------------------------------------
-- Computing overlapping fills as adjacent and not truly overlapping to compute daily dose
DROP TABLE IF EXISTS  #DailyDose_ActiveRx
SELECT MVIPersonSID
	  ,DrugNameWithDose
	  ,Opioid
	  ,DailyDose=CASE WHEN DoseType ='UNITDOSE' THEN (QtySum/cast(DaysSupply_Sum as decimal))*StrengthNumeric 
					  WHEN DoseType ='LIQUID' Then (QtySum/cast(DaysSupply_Sum as decimal))*StrengthPer_ml 
					  WHEN DoseType ='NasalSpray' Then (NasalSprays_PerBottle * QtySum/CAST(DaysSupply_Sum as decimal))*StrengthPer_NasalSpray 
					ELSE NULL END
	  ,DoseType
INTO #DailyDose_ActiveRx
FROM (
	SELECT MVIPersonSID
		  ,DrugNameWithDose
		  ,Opioid
		  ,StrengthNumeric
		  ,StrengthPer_ml
		  ,StrengthPer_NasalSpray
		  ,NasalSprays_PerBottle
		  ,DoseType
		  ,SUM(DaysSupply) as DaysSupply_Sum
		  ,SUM(Qty) as QtySum
	FROM #ValidMEDD_RxFills_ActiveRx
	GROUP BY MVIPersonSID
		,DrugNameWithDose
		,Opioid
		,StrengthNumeric
		,StrengthPer_ml
		,StrengthPer_NasalSpray
		,NasalSprays_PerBottle
		,DoseType
	) a
----------------------------------------------------------
--Step 2.4: NON-METHADONE MEDD MVIPERSONSID LEVEL
----------------------------------------------------------
-- Computing MEDD and summing up per MVIPersonSID NON Methadone MEDD
DROP TABLE IF EXISTS #MEDD_Report_NonMethadone_ActiveRx
SELECT MVIPersonSID   --Step 2: summing all non methadone opioids at MVIPersonSID level
	  ,SUM(MEDD) as MEDDReport_NonMethadone
INTO #MEDD_Report_NonMethadone_ActiveRx
FROM (
	SELECT dd.MVIPersonSID  --Step 1: computing MEDD_Report
		  ,dd.DrugNameWithDose
		  ,MEDD=dd.DailyDose*me.ConversionFactor_Report
		  ,dd.DailyDose
	FROM #DailyDose_ActiveRx dd
	INNER JOIN #ME_helper me ON dd.DrugNameWithDose=me.DrugNameWithDose
	WHERE dd.Opioid <> 'METHADONE'
	) a
GROUP BY MVIPersonSID
----------------------------------------------------------
--Step 2.5: METHADONE MEDD MVIPERSONSID LEVEL
----------------------------------------------------------
DROP TABLE IF EXISTS  #MEDD_Report_Methadone_ActiveRx
SELECT MVIPersonSID --Step 2 computing MVIPersonSID at ICN level
	  ,MEDD_Methadone= CASE WHEN DailyDose_SUM < 21 THEN 4 * DailyDose_SUM
							WHEN DailyDose_SUM BETWEEN 21 AND 40 THEN 8 * DailyDose_SUM
							WHEN DailyDose_SUM BETWEEN 41 AND 60 THEN 10 * DailyDose_SUM
							WHEN DailyDose_SUM > 60  THEN 12 * DailyDose_SUM
							ELSE NULL
						END 
INTO #MEDD_Report_Methadone_ActiveRx
FROM ( --Step 1: Sum up daily dose of METHADONE at patient level and not drugnamewithoutdose level
	SELECT MVIPersonSID
		  ,SUM(DailyDose) as DailyDose_SUM
	FROM #DailyDose_ActiveRx a
	WHERE Opioid = 'METHADONE'
	GROUP BY MVIPersonSID
	) a
----------------------------------------------------------
--Step 2.6: MEDD_Report - MVIPersonSID level: summing NonMethadone and Methadone
----------------------------------------------------------
DROP TABLE IF EXISTS #MEDD_Report_ActiveRx
SELECT MVIPersonSID
	  ,SUM(MEDD_Methadone) AS MEDD_Report -- summing MEDD from methadone and non methadone computation
INTO #MEDD_Report_ActiveRx
FROM (
	SELECT MVIPersonSID,MEDD_Methadone FROM #MEDD_Report_Methadone_ActiveRx
	UNION ALL
	SELECT MVIPersonSID,MEDDReport_NonMethadone FROM #MEDD_Report_NonMethadone_ActiveRx
	) a
GROUP BY MVIPersonSID
----------------------------------------------------------
-- Step 2.7: MEDD_RiskScore - MVIPersonSID level 
-- no need to differentiate between methadone and non methadone, uses different conversion factors:
----------------------------------------------------------
DROP TABLE IF EXISTS #MEDD_RiskScore_ActiveRx
SELECT MVIPersonSID  -- step2: summing MEDD for all opioids at MVIPersonSID level
	  ,SUM(MEDD) as MEDD_RiskScore
INTO #MEDD_RiskScore_ActiveRx
FROM (
	SELECT MVIPersonSID   --Step 1: computing MEDD for all opioids
		  ,dd.DrugNameWithDose
		  ,MEDD =dd.DailyDose*me.ConversionFactor_RiskScore
		  ,dd.DailyDose
		  ,me.ConversionFactor_RiskScore
	FROM #DailyDose_ActiveRx dd
	INNER JOIN #ME_helper me ON dd.DrugNameWithDose=me.DrugNameWithDose
	) a
GROUP BY MVIPersonSID
-------------------------------------------------------------------------------------
-- Step 2.8: Converting into Variable format for risk score computation architecture
--------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #FinalMEDD_ActiveRx;
WITH UnionMEDD_ActiveRx AS (
	SELECT MVIPersonSID
		,VariableName = 'TotalMEDD_ActiveRx'
		,VariableValue = MEDD_RiskScore
	FROM #MEDD_RiskScore_ActiveRx
	UNION ALL 
	SELECT MVIPersonSID
		,'MEDD_Report_ActiveRx'
		,MEDD_Report
	FROM #MEDD_Report_ActiveRx
	)
SELECT um.MVIPersonSID
	,um.VariableName
	,um.VariableValue
	,ehr.SourceEHR
INTO #FinalMEDD_ActiveRx
FROM UnionMEDD_ActiveRx um
LEFT JOIN #MEDD_EHR_ActiveRx ehr ON ehr.MVIPersonSID = um.MVIPersonSID
-----------------------------------------
--Step 2.9: dropping extraneous tables
DROP TABLE #MEDD_Report_ActiveRx
,#MEDD_RiskScore_ActiveRx
,#MEDD_EHR_ActiveRx
,#ValidMEDD_RxFills_ActiveRx
,#DailyDose_ActiveRx
,#MEDD_Report_Methadone_ActiveRx
,#MEDD_Report_NonMethadone_ActiveRx
-----------------------------------------
/*****************************************************************************
Step 3: MEDD for Pills on Hand (PoH) only - used in risk score computation
Variables: TotalMEDD and MEDD_Report
*********************************************************************************/
----------------------------------------------------------------------------------------------------
--STEP 3.1: ValideFills
--Identifying all fills patient has pills on hand based on releasedatetime + dayssupply
--for opioids in [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] that we use to compute MEDD
-------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ValidMEDD_RxFills_PoH
SELECT DISTINCT 
	oh.MVIPersonSID
	--,vme.NationalDrugSID
	,Sta3n					= COALESCE(vme.Sta3n,oh.Sta3n)
	,DrugNameWithDose		= COALESCE(vme.DrugNameWithDose,mme.DrugNameWithDose)
	,Opioid					= COALESCE(vme.Opioid,mme.Opioid)
	,DoseType				= COALESCE(vme.DoseType,mme.DoseType)
	,StrengthPer_ml			= COALESCE(vme.StrengthPer_ml,mme.StrengthPer_ml)
	,StrengthPer_NasalSpray	= COALESCE(vme.StrengthPer_NasalSpray,mme.StrengthPer_NasalSpray)
	,oh.RxOutpatSID
	,oh.ReleaseDateTime
	,RxEndDate				= DATEADD(DAY, oh.DaysSupply, oh.ReleaseDateTime)
	,oh.DaysSupply
	,Qty					= CAST(oh.Qty AS numeric)
	,StrengthNumeric		= COALESCE(vme.StrengthNumeric,mme.StrengthNumeric)
	,NasalSprays_PerBottle	= COALESCE(vme.NasalSprays_PerBottle,mme.NasalSprays_PerBottle)
INTO #ValidMEDD_RxFills_PoH
FROM [ORM].[OpioidHistory] oh WITH (NOLOCK)
LEFT JOIN [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] vme WITH (NOLOCK) ON 
	oh.NationalDrugSID = vme.NationalDrugSID
	AND oh.Sta3n <> 200 -- Join on NationalDrugSID for VistA meds, and below on VUID for Millennium records
LEFT JOIN (
	SELECT DISTINCT VUID,DrugNameWithDose,Opioid,DoseType
		,StrengthPer_ml,StrengthNumeric
		,StrengthPer_NasalSpray,NasalSprays_PerBottle
	FROM [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] 
	) mme ON mme.VUID = oh.VUID
	AND oh.Sta3n = 200
WHERE oh.OpioidOnHand = 1
	-- below condition limits to only medications in the MorphineEquiv table (e.g., no injectables)
	AND (vme.NationalDrugSID IS NOT NULL 
		OR mme.VUID IS NOT NULL)
--------------------------------------------------------------------------------
-- STEP 3.2: Just compute SourceEHR once for where the patient is receiving meds
--------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #MEDD_EHR_PoH;
	SELECT MVIPersonSID
		,SourceEHR = CASE WHEN MAX(Sta3n) = 200 THEN 'M'
			WHEN MIN(Sta3n) = 200 AND MAX(Sta3n)>200 THEN 'VM'
			ELSE 'V' END
	INTO #MEDD_EHR_PoH
	FROM #ValidMEDD_RxFills_PoH
	GROUP BY MVIPersonSID
----------------------------------------------------------
--Step 3.3: DAILY DOSE METHADONE and NON-METHADONE
----------------------------------------------------------
-- Computing overlapping fills as adjacent and not truly overlapping to compute daily dose
DROP TABLE IF EXISTS  #DailyDose_PoH
SELECT MVIPersonSID
	  ,DrugNameWithDose
	  ,Opioid
	  ,DailyDose=CASE WHEN DoseType ='UNITDOSE' THEN (QtySum/cast(DaysSupply_Sum as decimal))*StrengthNumeric 
					  WHEN DoseType ='LIQUID' Then (QtySum/cast(DaysSupply_Sum as decimal))*StrengthPer_ml 
					  WHEN DoseType ='NasalSpray' Then (NasalSprays_PerBottle * QtySum/CAST(DaysSupply_Sum as decimal))*StrengthPer_NasalSpray 
					ELSE NULL END
	  ,DoseType
INTO #DailyDose_PoH
FROM (
	SELECT MVIPersonSID
		  ,DrugNameWithDose
		  ,Opioid
		  ,StrengthNumeric
		  ,StrengthPer_ml
		  ,StrengthPer_NasalSpray
		  ,NasalSprays_PerBottle
		  ,DoseType
		  ,SUM(DaysSupply) as DaysSupply_Sum
		  ,SUM(Qty) as QtySum
	FROM #ValidMEDD_RxFills_PoH
	GROUP BY MVIPersonSID
		,DrugNameWithDose
		,Opioid
		,StrengthNumeric
		,StrengthPer_ml
		,StrengthPer_NasalSpray
		,NasalSprays_PerBottle
		,DoseType
	) a
----------------------------------------------------------------------
--STEP 3.4: NON-METHADONE MEDD MVIPERSONSID LEVEL
-- Computing MEDD and summing up per MVIPersonSID NON Methadone MEDD
-----------------------------------------------------------------------
DROP TABLE IF EXISTS #MEDD_Report_NonMethadone_PoH
SELECT MVIPersonSID   --Step 2: summing all non methadone opioids at MVIPersonSID level
	  ,SUM(MEDD) as MEDDReport_NonMethadone
INTO #MEDD_Report_NonMethadone_PoH
FROM (
	SELECT dd.MVIPersonSID  --Step 1: computing MEDD_Report
		  ,dd.DrugNameWithDose
		  ,MEDD=dd.DailyDose*me.ConversionFactor_Report
		  ,dd.DailyDose
	FROM #DailyDose_PoH dd
	INNER JOIN #ME_helper me ON dd.DrugNameWithDose=me.DrugNameWithDose
	WHERE dd.Opioid <> 'METHADONE'
	) a
GROUP BY MVIPersonSID
----------------------------------------------------------
--STEP 3.5: METHADONE MEDD MVIPERSONSID LEVEL
----------------------------------------------------------
DROP TABLE IF EXISTS  #MEDD_Report_Methadone_PoH
SELECT MVIPersonSID --Step 2 computing MVIPersonSID at ICN level
	  ,MEDD_Methadone= CASE WHEN DailyDose_SUM < 21 THEN 4 * DailyDose_SUM
							WHEN DailyDose_SUM BETWEEN 21 AND 40 THEN 8 * DailyDose_SUM
							WHEN DailyDose_SUM BETWEEN 41 AND 60 THEN 10 * DailyDose_SUM
							WHEN DailyDose_SUM > 60  THEN 12 * DailyDose_SUM
							ELSE NULL
						END 
INTO #MEDD_Report_Methadone_PoH
FROM ( --Step 1: Sum up daily dose of METHADONE at patient level and not drugnamewithoutdose level
	SELECT MVIPersonSID
		  ,SUM(DailyDose) as DailyDose_SUM
	FROM #DailyDose_PoH a
	WHERE Opioid = 'METHADONE'
	GROUP BY MVIPersonSID
	) a
----------------------------------------------------------
--Step 3.6: MEDD_Report - MVIPersonSID level: summing NonMethadone and Methadone
----------------------------------------------------------
DROP TABLE IF EXISTS #MEDD_Report_PoH
SELECT MVIPersonSID
	  ,SUM(MEDD_Methadone) AS MEDD_Report -- summing MEDD from methadone and non methadone computation
INTO #MEDD_Report_PoH
FROM (
	SELECT MVIPersonSID,MEDD_Methadone FROM #MEDD_Report_Methadone_PoH
	UNION ALL
	SELECT MVIPersonSID,MEDDReport_NonMethadone FROM #MEDD_Report_NonMethadone_PoH
	) a
GROUP BY MVIPersonSID
----------------------------------------------------------
--Step 3.7: MEDD_RiskScore - MVIPersonSID level 
-- no need to differentiate between methadone and non methadone, uses different conversion factors:
----------------------------------------------------------
DROP TABLE IF EXISTS #MEDD_RiskScore_PoH
SELECT MVIPersonSID  -- step2: summing MEDD for all opioids at MVIPersonSID level
	  ,SUM(MEDD) as MEDD_RiskScore
INTO #MEDD_RiskScore_PoH
FROM (
	SELECT MVIPersonSID   --Step 1: computing MEDD for all opioids
		  ,dd.DrugNameWithDose
		  ,MEDD =dd.DailyDose*me.ConversionFactor_RiskScore
		  ,dd.DailyDose
		  ,me.ConversionFactor_RiskScore
	FROM #DailyDose_PoH dd
	INNER JOIN #ME_helper me ON dd.DrugNameWithDose=me.DrugNameWithDose
	) a
GROUP BY MVIPersonSID
---------------------------------------------------------------------------	
--STEP 3.8: PoH - TotalMEDD and MEDD_Report ready as a variable
------------------------------------------------------------------------------
DROP TABLE IF EXISTS  #FinalMEDD_PoH;
WITH UnionMEDD_PoH AS (
	SELECT MVIPersonSID
		,VariableName = 'TotalMEDD'
		,VariableValue = MEDD_RiskScore
	FROM #MEDD_RiskScore_PoH
	UNION ALL 
	SELECT MVIPersonSID
		,'MEDD_Report'
		,MEDD_Report
	FROM #MEDD_Report_PoH
	)

SELECT um.MVIPersonSID
	,um.VariableName
	,um.VariableValue
	,ehr.SourceEHR
INTO #FinalMEDD_PoH
FROM UnionMEDD_PoH um
LEFT JOIN #MEDD_EHR_PoH ehr ON ehr.MVIPersonSID = um.MVIPersonSID
/********************************************
-- STEP 4: UNION of Variables: TotalMEDD, TotalMEDD_ActiveRx, MEDD_Report, MEDD_Report_ActiveRx
********************************************/
DROP TABLE IF EXISTS #FinalMEDD
Select * 
INTO #FinalMEDD
FROM
(
Select * from  #FinalMEDD_ActiveRx
UNION
Select * from  #FinalMEDD_PoH
)a
DROP TABLE #ME_helper
,#MEDD_Report_PoH
,#MEDD_RiskScore_PoH
,#MEDD_EHR_PoH
,#ValidMEDD_RxFills_PoH
,#DailyDose_PoH
,#MEDD_Report_Methadone_PoH
,#MEDD_Report_NonMethadone_PoH
-----------------------------------------------------------------
-- FINAL PUBLISHING STEPS
-----------------------------------------------------------------
/*** ADD VARIABLES TO RiskScore.PatientVariable ***/
DROP TABLE IF EXISTS #PatientVariable
CREATE TABLE #PatientVariable (
	MVIPersonSID INT NULL, --NOT NULL, 
	VariableName VARCHAR(25) NOT NULL, 
	VariableValue DECIMAL(15,8), 
	ImputedFlag BIT,
	SourceEHR VARCHAR(3)
--Constraint PK_TempPV Primary Key(MVIPersonSID,VariableID)
);

-- Demog
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT p.MVIPersonSID
	  ,p.VariableName
	  ,p.VariableValue
	  ,p.SourceEHR
FROM #demographics p 

-- Diagnosis
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT p.MVIPersonSID
	  ,p.VariableName
	  ,p.VariableValue
	  ,p.SourceEHR
FROM #DxCohort p 

-- MHInpatient
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT p.MVIPersonSID
	  ,'MHInpat'
	  ,p.MHInpatient
	  ,p.SourceEHR
FROM #InpatStage p 

-- Meds
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT MVIPersonSID
	,VariableName
	,VariableValue
	,SourceEHR 
FROM #OtherMeds

INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT MVIPersonSID
	,VariableName
	,VariableValue
	,SourceEHR 
FROM #PainAdj

--CPT Codes, MHOutpat, ERVisit
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT p.MVIPersonSID
	,p.VariableName
	,p.VariableValue
	,p.SourceEHR
FROM #PatientVariableVMD p

-- MEDD
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT MVIPersonSID 
	  ,VariableName
	  ,VariableValue
	  ,SourceEHR
FROM #FinalMEDD

-- Cohort variable - Tramadol Only and Opioid history variables
INSERT INTO #PatientVariable (MVIPersonSID,VariableName,VariableValue,SourceEHR) 
SELECT MVIPersonSID 
	  ,VariableName = CASE WHEN LongActing = 1 THEN 'LongActing' --Any long acting
		WHEN SumNonTramadol = 0 THEN 'TramadolOnly' --Only tramadol short acting
		WHEN ChronicShortActing = 1 AND SumNonTramadol > 0 THEN 'ChronicShortActing' --Any chronic short acting, where at least one medication is non-tramadol
		WHEN NonChronicShortActing = 1 AND SumNonTramadol > 0 THEN 'NonChronicShortActing' --Any non-chronic short-acting, where at least one medication is non-tramadol
		END
	  ,VariableValue = CASE WHEN LongActing = 1 THEN 1
		WHEN SumNonTramadol = 0 THEN 1 --TramadolOnly
		WHEN ChronicShortActing = 1 THEN 1
		WHEN NonChronicShortActing = 1 THEN 1
		END
	  ,SourceEHR = CASE WHEN SourceEHR LIKE '%VM%' OR SourceEHR LIKE '%MV%' THEN 'VM'
		WHEN SourceEHR LIKE 'V%' THEN 'V'
		WHEN SourceEHR LIKE 'M%' THEN 'M'
		END
FROM (
	SELECT MVIPersonSID
		,MAX(LongActing) LongActing
		,MAX(ChronicShortActing) ChronicShortActing
		,MAX(NonChronicShortActing) NonChronicShortActing
		,SUM(CASE WHEN Active = 1 THEN NonTramadol ELSE 1 END) AS SumNonTramadol --according to previous code, tramadol only counted when Active=1; there was no such restriction on other groups. correct?
		,SourceEHR = STRING_AGG( CASE WHEN Sta3n = 200 THEN 'M' ELSE 'V' END ,'') WITHIN GROUP (ORDER BY Sta3n DESC)
	FROM [ORM].[OpioidHistory] WITH (NOLOCK)
	WHERE (LongActing > 0 OR ChronicShortActing > 0 OR NonChronicShortActing > 0)
	GROUP BY MVIPersonSID 
	) p

--------------------------------------------------------------------
-- DELETE MVIPersonSID IS NULL (caused by SQL53 test patients)
DELETE #PatientVariable
WHERE MVIPersonSID IS NULL
	
	/*
	-- Validate that variable value is the same, just SourceEHR is different
	SELECT MVIPersonSID
		,VariableName
		,COUNT(DISTINCT VariableValue)
		--,COUNT(SourceEHR)
	FROM #PatientVariable
	GROUP BY MVIPersonSID,VariableName
	HAVING COUNT(DISTINCT VariableValue) > 1
		OR COUNT(SourceEHR) > 1
	*/
DROP TABLE IF EXISTS #PatientVariableStage;
SELECT pv.MVIPersonSID
	,pv.VariableName
	,v.VariableID
	,VariableValue = MAX(pv.VariableValue)
	,SourceEHR = CONCAT(
		CASE WHEN STRING_AGG(pv.SourceEHR,'') LIKE '%V%' THEN 'V' ELSE '' END
		,CASE WHEN STRING_AGG(pv.SourceEHR,'') LIKE '%O%' THEN 'O' ELSE '' END
		,CASE WHEN STRING_AGG(pv.SourceEHR,'') LIKE '%M%' THEN 'M' ELSE '' END
		)
INTO #PatientVariableStage
FROM #PatientVariable pv
INNER JOIN [RiskScore].[Variable] v WITH (NOLOCK) on v.VariableName=pv.VariableName
	-- inner join drops variable GenderFemale, which is OK for computation
GROUP BY pv.MVIPersonSID
	,pv.VariableName
	,v.VariableID

DROP TABLE #PatientVariableVMD
	,#InpatStage
	,#OtherMeds
	,#PainAdj
	,#PatientVariable
	
--Publish Patient Variables to RiskScore table
MERGE [RiskScore].[PatientVariable] AS t 
USING #PatientVariableStage AS s 
ON t.MVIPersonSID=s.MVIPersonSID 
	AND t.VariableID=s.VariableID
WHEN MATCHED THEN 
	UPDATE SET VariableValue=s.VariableValue
		,SourceEHR=s.SourceEHR
WHEN NOT MATCHED THEN
	INSERT (MVIPersonSID,VariableID,VariableValue,SourceEHR)
	VALUES (s.MVIPersonSID,s.VariableID,s.VariableValue,s.SourceEHR)
;
--WHEN NOT MATCHED BY SOURCE
--	AND t.VariableID IN (SELECT VariableID FROM #PatientVariableStage) 
--THEN DELETE;

--Remove rows for those patients who previously had the variable, but now do not
----this was faster than including the deletion in the merge statement
DELETE t
--SELECT t.MVIPersonSID,t.VariableID,t.VariableValue,s.VariableValue,v.VariableID
FROM [RiskScore].[PatientVariable] AS t
LEFT JOIN #PatientVariableStage s ON 
	s.MVIPersonSID=t.MVIPersonSID
	AND s.VariableID=t.VariableID
LEFT JOIN (
	SELECT DISTINCT VariableID 
	FROM #PatientVariableStage
	) v ON v.VariableID=t.VariableID
WHERE v.VariableID IS NOT NULL
	AND s.VariableID IS NULL
	 
DROP TABLE #PatientVariableStage

---------------------------------------------------------------------

-- Compute combination variables 
----(Sum_Painadj,Overdose_Suicide,SumOverdose_Suicide, and AnySAE)
EXEC [Code].[RiskScore_PatVar_AggSub]

-- Insert data to ORM.RiskScore 

-- Pull DoD data for overdose/suicide only. All other Dx flags are pulled at the Present.Diagnosis level
-- but DoD sent overdose/suicide as a composite flag. Waiting on them to adjust and send the split out
-- variables so we can use our existing aggregation functions to flag appropriately. In the meantime, we 
-- have to manually add overdose/suicide flags here.

	-- RAS:  I like the idea of them providing the split out variables so that we could add the pieces and then 
		-- use the AggSub procedure to compute the variable like we do for others. However, another option would also
		-- be to change the Overdose_Suicide field from DoD to update RiskScore.PatientVariable
DROP TABLE IF EXISTS #DoD
SELECT MVIPersonSID
	  ,MAX(Overdose_Suicide) Overdose_Suicide
INTO #DoD
FROM [ORM].[vwDOD_TriSTORM] a WITH (NOLOCK)
GROUP BY MVIPersonSID

-- pivot patient variables to match existing table structure
---- we will get rid of this when we transistion to different architecture.
DROP TABLE IF EXISTS #VA
SELECT MVIPersonSID
	,EH_AIDS
	,EH_CHRNPULM
	,EH_COMDIAB
	,EH_ELECTRLYTE
	,EH_HYPERTENS
	,EH_LIVER
	,EH_NMETTUMR
	,EH_OTHNEURO
	,EH_PARALYSIS
	,EH_PEPTICULC
	,EH_PERIVALV
	,EH_RENAL
	,EH_HEART
	,EH_ARRHYTH
	,EH_VALVDIS
	,EH_PULMCIRC
	,EH_HYPOTHY
	,EH_RHEUMART
	,EH_COAG
	,EH_WEIGHTLS
	,EH_DefANEMIA
	,SedateIssue
	,AUD_ORM
	,OUD
	,SUDdx_poss
	,OpioidOverdose
	,SAE_Falls
	,SAE_OtherAccident
	,SAE_OtherDrug
	,SAE_Vehicle
	,Suicide
	,SAE_sed
	,SAE_acet
	,Overdose_Suicide
	,AnySAE
	,Other_MH_STORM
	,SUD_NoOUD_NoAUD
	,BIPOLAR
	,PTSD
	,MDD
	,OtherSUD_RiskModel
	,SedativeUseDisorder
	,CannabisUD_HallucUD
	,CocaineUD_AmphUD
	,EH_UNCDIAB
	,EH_LYMPHOMA
	,EH_METCANCR
	,EH_OBESITY
	,EH_BLANEMIA
	,SumOverdose_Suicide
	,Osteoporosis
	,SleepApnea
	,NicDx_Poss
	,COCNdx
	,Detox_CPT
	,MHOutpat
	,MHInpat
	,ERvisit
	,PainAdjAnticonvulsant_Rx
	,PainAdjSNRI_Rx
	,PainAdjTCA_Rx
	,Sum_Painadj
	,SedativeOpioid_Rx
	,TotalMEDD
	,MEDD_Report
	,TramadolOnly
	,ChronicShortActing
	,LongActing
	,NonChronicShortActing
	,MostRecentPrescriber
	,MostRecentPrescriberSID
	,Hospice
	,Bowel_Rx
	,Anxiolytics_Rx
	,Age30
	,Age3150
	,Age5165
	,Age66
	,GenderMale
INTO #VA
FROM (
	SELECT pv.MVIPersonSID
		  ,v.VariableName
		  ,pv.VariableValue
	FROM [RiskScore].[PatientVariable] pv WITH (NOLOCK)
	INNER JOIN [RiskScore].[Variable] v WITH (NOLOCK) on v.VariableID=pv.VariableID
	) u
PIVOT (MAX(VariableValue) 
	FOR VariableName IN (
		EH_AIDS
		,EH_CHRNPULM
		,EH_COMDIAB
		,EH_ELECTRLYTE
		,EH_HYPERTENS
		,EH_LIVER
		,EH_NMETTUMR
		,EH_OTHNEURO
		,EH_PARALYSIS
		,EH_PEPTICULC
		,EH_PERIVALV
		,EH_RENAL
		,EH_HEART
		,EH_ARRHYTH
		,EH_VALVDIS
		,EH_PULMCIRC
		,EH_HYPOTHY
		,EH_RHEUMART
		,EH_COAG
		,EH_WEIGHTLS
		,EH_DefANEMIA
		,SedateIssue
		,AUD_ORM
		,OUD
		,SUDdx_poss
		,OpioidOverdose
		,SAE_Falls
		,SAE_OtherAccident
		,SAE_OtherDrug
		,SAE_Vehicle
		,Suicide
		,SAE_sed
		,SAE_acet
		,Overdose_Suicide
		,AnySAE
		,Other_MH_STORM
		,SUD_NoOUD_NoAUD
		,BIPOLAR
		,PTSD
		,MDD
		,OtherSUD_RiskModel
		,SedativeUseDisorder
		,CannabisUD_HallucUD
		,CocaineUD_AmphUD
		,EH_UNCDIAB
		,EH_LYMPHOMA
		,EH_METCANCR
		,EH_OBESITY
		,EH_BLANEMIA
		,SumOverdose_Suicide
		,Osteoporosis
		,SleepApnea
		,NicDx_Poss
		,COCNdx
		,Detox_CPT
		,MHOutpat
		,MHInpat
		,ERvisit
		,PainAdjAnticonvulsant_Rx
		,PainAdjSNRI_Rx
		,PainAdjTCA_Rx
		,Sum_Painadj
		,SedativeOpioid_Rx
		,TotalMEDD
		,MEDD_Report
		,TramadolOnly
		,ChronicShortActing
		,LongActing
		,NonChronicShortActing
		,MostRecentPrescriber
		,MostRecentPrescriberSID
		,Hospice
		,Bowel_Rx
		,Anxiolytics_Rx
		,Age30
		,Age3150
		,Age5165
		,Age66
		,GenderMale
		)
	) p

-- Merge DoD and VA tables, taking the max of the overdose_suicide variable
DROP TABLE IF EXISTS #RiskVariables
SELECT a.MVIPersonSID
		,EH_AIDS 
		,EH_CHRNPULM 
		,EH_COMDIAB 
		,EH_ELECTRLYTE 
		,EH_HYPERTENS 
		,EH_LIVER 
		,EH_NMETTUMR 
		,EH_OTHNEURO 
		,EH_PARALYSIS 
		,EH_PEPTICULC 
		,EH_PERIVALV 
		,EH_RENAL 
		,EH_HEART 
		,EH_ARRHYTH 
		,EH_VALVDIS 
		,EH_PULMCIRC 
		,EH_HYPOTHY 
		,EH_RHEUMART 
		,EH_COAG 
		,EH_WEIGHTLS 
		,EH_DefANEMIA 
		,SedateIssue 
		,AUD_ORM 
		,OUD 
		,SUDdx_poss 
		,OpioidOverdose 
		,SAE_Falls 
		,SAE_OtherAccident 
		,SAE_OtherDrug 
		,SAE_Vehicle 
		,Suicide 
		,SAE_sed 
		,SAE_acet 
		,ISNULL(a.Overdose_Suicide, b.Overdose_Suicide) as Overdose_Suicide
		,AnySAE 
		,Other_MH_STORM 
		,SUD_NoOUD_NoAUD 
		,BIPOLAR 
		,PTSD 
		,MDD 
		,OtherSUD_RiskModel 
		,SedativeUseDisorder 
		,CannabisUD_HallucUD 
		,CocaineUD_AmphUD 
		,EH_UNCDIAB 
		,EH_LYMPHOMA 
		,EH_METCANCR 
		,EH_OBESITY 
		,EH_BLANEMIA 
		,CASE WHEN (SumOverdose_Suicide + b.Overdose_Suicide) > 2 THEN 2
		 ELSE (SumOverdose_Suicide + b.Overdose_Suicide)
		 END AS SumOverdose_Suicide 
		,Osteoporosis 
		,SleepApnea 
		,NicDx_Poss 
		,COCNdx 
		,Detox_CPT 
		,MHOutpat 
		,MHInpat 
		,ERvisit 
		,PainAdjAnticonvulsant_Rx 
		,PainAdjSNRI_Rx 
		,PainAdjTCA_Rx 
		,Sum_Painadj 
		,SedativeOpioid_Rx 
		,TotalMEDD 
		,MEDD_Report
		,TramadolOnly 
		,ChronicShortActing 
		,LongActing 
		,NonChronicShortActing 
		,MostRecentPrescriber 
		,MostRecentPrescriberSID 
		,Hospice 
		,Bowel_Rx 
		,Anxiolytics_Rx 
		,Age30 
		,Age3150 
		,Age5165 
		,Age66 
		,GenderMale 
INTO #RiskVariables
FROM #VA a
LEFT JOIN #DoD b ON a.MVIPersonSID = b.MVIPersonSID

DROP TABLE IF EXISTS #Stage_ORM_RiskScore
SELECT d.MVIPersonSID
	,d.STA3N
	,d.VISN
	,d.Gender
	,d.Age
	,EH_AIDS								= ISNULL(rv.EH_AIDS				,0)
	,EH_CHRNPULM							= ISNULL(rv.EH_CHRNPULM			,0)
	,EH_COMDIAB								= ISNULL(rv.EH_COMDIAB			,0)
	,EH_ELECTRLYTE							= ISNULL(rv.EH_ELECTRLYTE		,0)
	,EH_HYPERTENS							= ISNULL(rv.EH_HYPERTENS		,0)
	,EH_LIVER								= ISNULL(rv.EH_LIVER			,0)
	,EH_NMETTUMR							= ISNULL(rv.EH_NMETTUMR			,0)
	,EH_OTHNEURO							= ISNULL(rv.EH_OTHNEURO			,0)
	,EH_PARALYSIS							= ISNULL(rv.EH_PARALYSIS		,0)
	,EH_PEPTICULC							= ISNULL(rv.EH_PEPTICULC		,0)
	,EH_PERIVALV							= ISNULL(rv.EH_PERIVALV			,0)
	,EH_RENAL								= ISNULL(rv.EH_RENAL			,0)
	,EH_HEART								= ISNULL(rv.EH_HEART			,0)
	,EH_ARRHYTH								= ISNULL(rv.EH_ARRHYTH			,0)
	,EH_VALVDIS								= ISNULL(rv.EH_VALVDIS			,0)
	,EH_PULMCIRC							= ISNULL(rv.EH_PULMCIRC			,0)
	,EH_HYPOTHY								= ISNULL(rv.EH_HYPOTHY			,0)
	,EH_RHEUMART							= ISNULL(rv.EH_RHEUMART			,0)
	,EH_COAG								= ISNULL(rv.EH_COAG				,0)
	,EH_WEIGHTLS							= ISNULL(rv.EH_WEIGHTLS			,0)
	,EH_DefANEMIA							= ISNULL(rv.EH_DefANEMIA		,0)
	,SedateIssue							= ISNULL(rv.SedateIssue			,0)
	,AUD_ORM								= ISNULL(rv.AUD_ORM				,0)
	,OUD									= ISNULL(rv.OUD					,0)
	,SUDdx_poss								= ISNULL(rv.SUDdx_poss			,0)
	,OpioidOverdose							= ISNULL(rv.OpioidOverdose		,0)
	,SAE_Falls								= ISNULL(rv.SAE_Falls			,0)
	,SAE_OtherAccident						= ISNULL(rv.SAE_OtherAccident	,0)
	,SAE_OtherDrug							= ISNULL(rv.SAE_OtherDrug		,0)
	,SAE_Vehicle							= ISNULL(rv.SAE_Vehicle			,0)
	,Suicide								= ISNULL(rv.Suicide				,0)
	,SAE_sed								= ISNULL(rv.SAE_sed				,0)
	,SAE_acet								= ISNULL(rv.SAE_acet			,0)
	,Overdose_Suicide						= ISNULL(rv.Overdose_Suicide	,0)
	,AnySAE									= ISNULL(rv.AnySAE				,0)
	,Other_MH_STORM							= ISNULL(rv.Other_MH_STORM		,0)
	,SUD_NoOUD_NoAUD						= ISNULL(rv.SUD_NoOUD_NoAUD		,0)
	,BIPOLAR								= ISNULL(rv.BIPOLAR				,0)
	,PTSD									= ISNULL(rv.PTSD				,0)
	,MDD									= ISNULL(rv.MDD					,0)
	,OtherSUD_RiskModel						= ISNULL(rv.OtherSUD_RiskModel	,0)
	,SedativeUseDisorder					= ISNULL(rv.SedativeUseDisorder	,0)
	,CannabisUD_HallucUD					= ISNULL(rv.CannabisUD_HallucUD	,0)
	,CocaineUD_AmphUD						= ISNULL(rv.CocaineUD_AmphUD	,0)
	,EH_UNCDIAB								= ISNULL(rv.EH_UNCDIAB			,0)
	,EH_LYMPHOMA							= ISNULL(rv.EH_LYMPHOMA			,0)
	,EH_METCANCR							= ISNULL(rv.EH_METCANCR			,0)
	,EH_OBESITY								= ISNULL(rv.EH_OBESITY			,0)
	,EH_BLANEMIA							= ISNULL(rv.EH_BLANEMIA			,0)
	,SumOverdose_Suicide					= ISNULL(rv.SumOverdose_Suicide	,0)
	,Osteoporosis							= ISNULL(rv.Osteoporosis		,0)
	,SleepApnea								= ISNULL(rv.SleepApnea			,0)
	,NicDx_Poss								= ISNULL(rv.NicDx_Poss			,0)
	,COCNdx									= ISNULL(rv.COCNdx				,0)
	,Detox_CPT								= ISNULL(rv.Detox_CPT			,0)
	,MHOutpat								= ISNULL(rv.MHOutpat			,0)
	,MHInpat								= ISNULL(rv.MHInpat				,0)
	,ERvisit								= ISNULL(rv.ERvisit				,0)
	,PainAdjAnticonvulsant_Rx				= ISNULL(rv.PainAdjAnticonvulsant_Rx,0)
	,PainAdjSNRI_Rx							= ISNULL(rv.PainAdjSNRI_Rx		,0)
	,PainAdjTCA_Rx							= ISNULL(rv.PainAdjTCA_Rx		,0)
	,Sum_Painadj							= ISNULL(rv.Sum_Painadj			,0)
	,SedativeOpioid_Rx						= ISNULL(rv.SedativeOpioid_Rx	,0)
	,TotalMEDD								= ISNULL(rv.TotalMEDD			,0)
	,MEDD_Report							= ISNULL(rv.MEDD_Report			,0)
	,TramadolOnly							= ISNULL(rv.TramadolOnly		,0)
	,ChronicShortActing						= ISNULL(rv.ChronicShortActing	,0)
	,LongActing								= ISNULL(rv.LongActing			,0)
	,NonChronicShortActing					= ISNULL(rv.NonChronicShortActing,0)
	,MostRecentPrescriber					= ISNULL(rv.MostRecentPrescriber,0)
	,MostRecentPrescriberSID				= ISNULL(rv.MostRecentPrescriberSID,0)
	,Hospice								= ISNULL(rv.Hospice				,0)
	,Bowel_Rx								= ISNULL(rv.Bowel_Rx			,0)
	,Anxiolytics_Rx							= ISNULL(rv.Anxiolytics_Rx		,0)
	,Age30									= ISNULL(rv.Age30				,0)
	,Age3150								= ISNULL(rv.Age3150				,0)
	,Age5165								= ISNULL(rv.Age5165				,0)	
	,Age66									= ISNULL(rv.Age66				,0)	
	,GenderMale								= ISNULL(rv.GenderMale			,0)
	,GenderFemale							= CASE WHEN d.Gender = 'F' THEN 1 ELSE 0 END
	,InteractionOverdoseOtherAE				= CASE WHEN (rv.Overdose_Suicide = 1) THEN 1 ELSE 0 END --should this be AND rv.AnySAE = 1 ?
	,InteractionOverdoseMHInpat				= CASE WHEN (rv.Overdose_Suicide = 1 AND rv.MHInpat = 1) THEN 1 ELSE 0 END  
	,InteractionOverdoseOUD					= CASE WHEN (rv.Overdose_Suicide = 1 AND rv.OUD = 1) THEN 1 ELSE 0 END
	,InteractionOUDAnySAE					= CASE WHEN (rv.AnySAE = 1 AND rv.OUD = 1) THEN 1 ELSE 0 END
	,InteractionOUDMHInpat					= CASE WHEN (rv.MHInpat = 1 AND rv.OUD = 1) THEN 1 ELSE 0 END
	,InteractionAnySAEMHInpat				= CASE WHEN (rv.AnySAE = 1 AND rv.MHInpat = 1) THEN 1 ELSE 0 END 
	,RiskScore								= NULL
	,RiskScore10							= NULL
	,RiskScore50							= NULL
	,RiskScoreNoSed							= NULL
	,RiskScoreAny							= NULL
	,RiskScoreAny10							= NULL
	,RiskScoreAny50							= NULL
	,RiskScoreAnyNoSed		 				= NULL
	,RiskScoreAnyHypothetical10				= NULL
	,RiskScoreAnyHypothetical50				= NULL
	,RiskScoreAnyHypothetical90				= NULL
	,RiskScoreHypothetical10				= NULL
	,RiskScoreHypothetical50				= NULL
	,RiskScoreHypothetical90				= NULL
	,RiskCategory							= NULL
	,RiskAnyCategory						= NULL
	,RiskCategory_Hypothetical90			= NULL
	,RiskCategory_Hypothetical50			= NULL
	,RiskCategory_Hypothetical10			= NULL
	,RiskAnyCategory_Hypothetical90			= NULL
	,RiskAnyCategory_Hypothetical50			= NULL
	,RiskAnyCategory_Hypothetical10			= NULL
	,RiskAnyCategoryLabel					= NULL
	,RiskCategoryLabel						= NULL
	,RiskCategoryLabel_Hypothetical90		= NULL
	,RiskCategoryLabel_Hypothetical50		= NULL
	,RiskCategorylabel_Hypothetical10		= NULL
	,RiskAnyCategoryLabel_Hypothetical90	= NULL
	,RiskAnyCategoryLabel_Hypothetical50	= NULL
	,RiskAnyCategorylabel_Hypothetical10	= NULL
INTO #Stage_ORM_RiskScore
FROM #DemogWithPrescriber d
LEFT JOIN #RiskVariables rv on rv.MVIPersonSID=d.MVIPersonSID

	DROP TABLE #RiskVariables,#DemogWithPrescriber

EXEC [Maintenance].[PublishTable] 'ORM.RiskScore', '#Stage_ORM_RiskScore'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END
;