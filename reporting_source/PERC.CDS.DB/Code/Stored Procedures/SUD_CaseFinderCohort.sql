
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3-7-2024
-- Description:	Dataset for SUPMT Power BI report. Data source for the following tables:
--					** [SUD].[CaseFinderCohort]
--					** [SUD].[CaseFinderRisk]
--
-- Denominator Cohort compiled of the following (past year):
--		1. Health factor indicating detox/withdrawal	OR
--		2. Note mentions for detox/withdrawal			OR 
--		3. Note mentions for ivdu						OR 
--		4. Positive Audit-C								OR
--		5. CIWA recorded								OR
--		6. COWS recorded								OR
--		7. Positive drug screen							OR
--		8. Overdose past year							OR
--		9. Confirmed IVDU								OR
--		10. SUD Dx past 5 years
--
-- Modifications:
--   2024-03-18  CW  Adding IDU note mentions to denominator cohort. Updating semantics re
--					 RiskTypes.
--   2024-03-20  CW  Adding additional RiskTypes.
--   2024-04-11  CW  Updates following initial validation; re-architecting procedure for
--					 run time
--   2024-04-15  CW  Fixing bug to ensure MHA surveys are all within past year
--   2024-04-29  CW  Adding EventType='Suicide Event' for SDV criteria
--   2024-05-08  CW  Re-configuring method for pulling VJO Cerner encounters; consolidating
--					 method in which denominator #Cohort is established; updating language 
--					 for IPV.
--   2024-06-10  CW  Updating ChecklistID source data
--   2024-10-08  CW  Taking out evidence portion of the code; not needed anymore
--					 Removing NLP from denominator until we have patient level NLP report
--				     (SSRS).
--					 Adding Intermed/High acute risk CSRE for decomp tree re: high risk
--					 behaviors.
--   2024-12-30  CW  Adding NLP back into the dataset 
--   2025-01-22  CW  Limiting OD cohorts to past year only; updating constraints on #DxDetails
--   2025-02-11  CW  Ensuring constraints are all using >= @PastYear consistently
--   2025-05-07  CW  Incorporating ChecklistID throughout the entire dataset. Will be used for 
--					 any instances of NULL values where patients may be in the CaseFinder cohort
--					 but not assigned to a provider/team (See View: App.SUDCaseFinder_Providers_PBI)
--   2025-05-08  CW  Additional clean up; removing unneeded objects based on the new report model
--					 and consolidating queries where possible
--=======================================================================================================
CREATE PROCEDURE [Code].[SUD_CaseFinderCohort]
AS
BEGIN

	DECLARE @PastYear Date	SET @PastYear=DATEADD(year,-1,GETDATE())

---------------------------------------------------------------
-- Starting cohort
---------------------------------------------------------------
	DROP TABLE IF EXISTS #MasterPatient
	SELECT DISTINCT MVIPersonSID
	INTO #MasterPatient
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE DateOfDeath IS NULL AND TestPatient=0;

---------------------------------------------------------------
-- Diagnoses
---------------------------------------------------------------
	DROP TABLE IF EXISTS #Dx 
	SELECT d.MVIPersonSID
		,d.DxCategory
		,c.Category
	INTO #Dx
	FROM [Present].[Diagnosis] d WITH(NOLOCK)
	INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK)
		ON d.DxCategory = c.ColumnName
	INNER JOIN [LookUp].[ICD10_Display] dis WITH (NOLOCK)
		ON c.ColumnName=dis.DxCategory
	WHERE dis.ProjectType='CRISTAL' AND c.TableName IN ('ICD10')
	AND (Outpat=1 OR Inpat=1 OR DoD=1 OR CommCare=1);

	DROP TABLE IF EXISTS #DxDetails 
	SELECT dd.ChecklistID
		,d.MVIPersonSID
		,d.Category
		,dd.MostRecentDate
	INTO #DxDetails
	FROM #Dx d
	INNER JOIN LookUp.ICD10_Vertical as v  WITH (NOLOCK) 
		ON d.DxCategory=v.DxCategory
	INNER JOIN Present.DiagnosisDate as dd WITH (NOLOCK) 
		ON v.ICD10Code=dd.ICD10Code AND d.MVIPersonSID=dd.MVIPersonSID
	WHERE Category IN ('Adverse Event','Substance Use Disorder')
	AND MostRecentDate >= DATEADD(year,-5,GETDATE()) --Past 5 years is relevant when compiling the #Cohort

	DROP TABLE IF EXISTS #Adverse 
	SELECT MVIPersonSID, ChecklistID, MostRecentDate=MAX(MostRecentDate), [>2Adverse]=1
	INTO #Adverse
	FROM (	SELECT DISTINCT MVIPersonSID, ChecklistID, MostRecentDate, Details=COUNT(*) OVER (PARTITION BY MVIPersonSID)
			FROM #DxDetails
			WHERE Category='Adverse Event' AND MostRecentDate >= @PastYear) Src
	WHERE Details > 2
	GROUP BY MVIPersonSID, ChecklistID

	--DROP TABLE IF EXISTS #CommunityCareDiagnosis
	--USE CC OVERDOSE DATA FROM CORE

	--Patients with SUDDx in past year
	DROP TABLE IF EXISTS #SUDDxPastYear 
	SELECT DISTINCT MVIPersonSID, ChecklistID, MostRecentDate=MAX(MostRecentDate), SUDDxPastYear=1
	INTO #SUDDxPastYear
	FROM #DxDetails
	WHERE Category='Substance Use Disorder'
	AND MostRecentDate >= @PastYear
	GROUP BY MVIPersonSID, ChecklistID;
  	  
---------------------------------------------------------------
-- Health factors indicating Detox, Withdrawal
---------------------------------------------------------------
	--NEED CONSULT/SIGN-OFF FROM SMEs FOR THIS PORTION; THEN WILL NEED TO GET INTO LOOKUP.LIST FORMAT
	--Detox, Withdrawal health factors
	DROP TABLE IF EXISTS #HF 
	SELECT DISTINCT HealthFactorType 
		,Detox=CASE WHEN HealthFactorType IN ('ALTERATION: SUB ABUSE/DETOX','GO SAFE DETOXIFICATION FROM ALCOHOL','INTOXICATION/DETOX CODE','OUTPT ALCOHOL DETOX - UNABLE TO REACH PT','PATIENT ADMITTED FOR ALCOHOL DETOX','SSP0030 RES ED DETOX','STORMHISTORY OF DETOXIFICATION') THEN 1 ELSE 0 END
		,Withdrawal=CASE WHEN HealthFactorType IN ('COWS 25-36 MODERATELY SEVERE WITHDRAWAL:','COWS 5-12 MILD WITHDRAWAL:','ETOH WITHDRAWAL','ETOH WITHDRAWAL RESOLVED','ETOH WITHDRAWAL SYMPTOMS','MEDICALLY MANAGED ETOH/DRUG WITHDRAWAL','PATIENT HAS HAD WITHDRAWAL SEIZURES','RN PROBLEM:ALCOHOL WITHDRAWAL','VA-MH OUD ASSESS DSM 5-11 WITHDRAWAL','VA-MH OUD DEPENDENCE ICD10-3 WITHDRAWAL','VA-OVERDOSE CONS PROFOUND WITHDRAWAL','WITHDRAWAL') THEN 1 ELSE 0 END
		,HealthFactorTypeSID
	INTO #HF
	FROM Dim.HealthFactorType WITH (NOLOCK)
	WHERE HealthFactorType IN (
		--Detox
		'ALTERATION: SUB ABUSE/DETOX',
		'GO SAFE DETOXIFICATION FROM ALCOHOL',
		'INTOXICATION/DETOX CODE',
		'OUTPT ALCOHOL DETOX - UNABLE TO REACH PT',
		'PATIENT ADMITTED FOR ALCOHOL DETOX',
		'SSP0030 RES ED DETOX',
		'STORMHISTORY OF DETOXIFICATION',
		--Withdrawal
		'COWS 25-36 MODERATELY SEVERE WITHDRAWAL:',
		'COWS 5-12 MILD WITHDRAWAL:', 
		'ETOH WITHDRAWAL', 
		'ETOH WITHDRAWAL RESOLVED', 
		'ETOH WITHDRAWAL SYMPTOMS', 
		'MEDICALLY MANAGED ETOH/DRUG WITHDRAWAL', 
		'PATIENT HAS HAD WITHDRAWAL SEIZURES', 
		'RN PROBLEM:ALCOHOL WITHDRAWAL', 
		'VA-MH OUD ASSESS DSM 5-11 WITHDRAWAL', 
		'VA-MH OUD DEPENDENCE ICD10-3 WITHDRAWAL', 
		'VA-OVERDOSE CONS PROFOUND WITHDRAWAL', 
		'WITHDRAWAL');

	DROP TABLE IF EXISTS #HealthFactor  
	SELECT ck.ChecklistID
		,p.MVIPersonSID
		,HealthFactorType
		,Detox
		,Withdrawal
		,MostRecentDateTime=MAX(HealthFactorDateTime)
	INTO #HealthFactor
	FROM HF.HealthFactor a WITH (NOLOCK)
	INNER JOIN #HF as b 
		ON a.HealthFactorTypeSID = b.HealthFactorTypeSID
	INNER JOIN Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) 
		ON a.PatientSID = p.PatientPersonSID
	INNER JOIN App.vwCDW_Outpat_Workload o WITH (NOLOCK)
		ON a.VisitSID=o.VisitSID
	INNER JOIN Dim.Institution i WITH (NOLOCK)
		ON o.InstitutionSID=i.InstitutionSID
	INNER JOIN [LookUp].[ChecklistID] as ck WITH (NOLOCK) 
		ON i.StaPa=ck.StaPa
	where HealthFactorDateTime >= @PastYear
	group by p.MVIPersonSID, ChecklistID, HealthFactorType, Detox, Withdrawal

---------------------------------------------------------------
-- NLP extractions
---------------------------------------------------------------
	DROP TABLE IF EXISTS #NLP  
	SELECT DISTINCT ChecklistID
		,n.MVIPersonSID
		,MostRecentDateTime=MAX(ReferenceDateTime)
		,Concept
		,NLP_Detox= CASE WHEN Concept='Detox' THEN 1 ELSE 0 END
		,NLP_IDU= CASE WHEN Concept='IDU' THEN 1 ELSE 0 END
	INTO #NLP
	FROM Present.NLP_Variables n WITH (NOLOCK)
	WHERE (Concept='Detox' OR Concept='IDU')
	AND ReferenceDateTime >= @PastYear
	GROUP BY ChecklistID, MVIPersonSID, Concept

---------------------------------------------------------------
-- MHA Surveys - Audit-C, CIWA, COWS
---------------------------------------------------------------
	DROP TABLE IF EXISTS #MHASurveys 
	SELECT TOP (1) WITH TIES *
	INTO #MHASurveys
	FROM (
	SELECT DISTINCT mha.MVIPersonSID
		,mha.ChecklistID
		,mha.SurveyGivenDatetime
		,mha.SurveyName
		,SurveyIndicator=
			CASE WHEN display_AUDC>=1 THEN 'AuditC'
				 WHEN display_CIWA=1  THEN 'CIWA'
				 WHEN display_COWS=1  THEN 'COWS' 
				 END
		,AuditC	=CASE WHEN display_AUDC>=1 THEN 1 ELSE 0 END
		,CIWA	=CASE WHEN display_CIWA=1 THEN 1 ELSE 0 END
		,COWS	=CASE WHEN display_COWS=1 THEN 1 ELSE 0 END
		,Score = RawScore
	FROM OMHSP_Standard.MentalHealthAssistant_v02 as mha WITH (NOLOCK)
	WHERE (display_AUDC>=1 OR display_CIWA=1 OR display_COWS=1)
	AND mha.SurveyGivenDatetime >= @PastYear) Src
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, ChecklistID, SurveyIndicator ORDER BY SurveyGivenDatetime DESC);

---------------------------------------------------------------
-- Overdose recorded in past year (SBOR/CSRE or ICD10)
-- OUD from DoD included here as well
---------------------------------------------------------------
	DROP TABLE IF EXISTS #Overdose_OMHSP_Standard
	SELECT DISTINCT ChecklistID, s.MVIPersonSID, OD_OMHSP_Standard=1, [Date]=ISNULL(EventDateFormatted,EntryDateTime), MethodType1, MethodType2, MethodType3
	INTO #Overdose_OMHSP_Standard
	FROM [OMHSP_Standard].[SuicideOverdoseEvent] s WITH (NOLOCK)
	WHERE Overdose=1 AND PreparatoryBehavior = 0 AND Fatal = 0 AND 
		((EventDateFormatted >= @PastYear) OR 
		 (EventDateFormatted IS NULL AND EntryDateTime >= @PastYear));

	DROP TABLE IF EXISTS #Overdose_ICD10 
	SELECT DISTINCT dd.MVIPersonSID, dd.ChecklistID, dd.MostRecentDate, dd.ICD10Code, OD_ICD10=1
	INTO #Overdose_ICD10
	FROM Present.DiagnosisDate dd WITH (NOLOCK)
	INNER JOIN LookUp.ICD10 icd
		ON dd.ICD10Code=icd.ICD10Code
	WHERE (icd.ICD10Code LIKE 'T36%' or icd.ICD10Code LIKE 'T4%' OR icd.ICD10Code LIKE 'T50%')
		AND icd.ICD10Description NOT LIKE '%Adverse%' -- per Elizabeth research
		AND icd.ICD10Description NOT LIKE '%Assault%' 
		AND icd.ICD10Description NOT LIKE '%Underdosing%' 
		AND icd.ICD10Description NOT LIKE '%Sequela%'
		AND dd.MostRecentDate >= @PastYear;

	DROP TABLE IF EXISTS #OUD_DoD_Prep
	SELECT DISTINCT 
		 MVIPersonSID
		,OutpatientTx= CASE WHEN IDTYPE IN ('CaperSID','NetworkOutpatSID') THEN 1 ELSE 0 END
		,InpatientTx= CASE WHEN IDTYPE IN ('DirectInpatSID','NetworkInpatSID') THEN 1 ELSE 0 END
		,Instance_Date
		,OD_DoD=1
		,ICD10
		,OutpatientDirect_DxDate = CASE WHEN IDTYPE IN ('CaperSID') THEN Instance_Date ELSE NULL END
		,OutpatientNetwork_DxDate = CASE WHEN IDTYPE IN ('NetworkOutpatSID') THEN Instance_Date ELSE NULL END
		,InpatientDirect_DxDate = CASE WHEN IDTYPE IN ('DirectInpatSID') THEN Instance_Date ELSE NULL END
		,InpatientNetwork_DxDate = CASE WHEN IDTYPE IN ('NetworkInpatSID') THEN Instance_Date ELSE NULL END
		,ActiveDuty_PurchasedCare_Flag                           
	INTO #OUD_DoD_Prep
	FROM [ORM].[DoD_OUD] WITH (NOLOCK)
	WHERE instance_date >= @PastYear;

	DROP TABLE IF EXISTS #OUD_DoD
	SELECT DISTINCT o.MVIPersonSID
		,a.ChecklistID
		,OD_DoD
		,ICD10Code=ICD10
		,ODDate=Instance_Date
		,Details=CASE WHEN OutpatientTx=1 AND OutpatientDirect_DxDate IS NOT NULL THEN 'Outpatient Direct Dx'
			  WHEN OutpatientTx=1 AND OutpatientNetwork_DxDate IS NOT NULL THEN 'Outpatient Network Dx'
			  WHEN InpatientTx=1 AND InpatientDirect_DxDate IS NOT NULL THEN 'Inpatient Direct Dx'
			  WHEN InpatientTx=1 AND InpatientNetwork_DxDate IS NOT NULL THEN 'Inpatient Network Dx' END
	INTO #OUD_DoD
	FROM #OUD_DoD_Prep o
	INNER JOIN Present.ActivePatient a WITH (NOLOCK)
		ON a.MVIPersonSID=o.MVIPersonSID;

	DROP TABLE IF EXISTS #Overdose 
    SELECT MVIPersonSID
		,ChecklistID
		,max(OD_OMHSP_Standard) as OD_OMHSP_Standard
		,max(OD_ICD10) as OD_ICD10
		,max(OD_DoD) as OD_DOD
    INTO #Overdose
    FROM (
		SELECT MVIPersonSID, ChecklistID, OD_OMHSP_Standard, OD_ICD10=0, OD_DoD=0
		FROM #Overdose_OMHSP_Standard
		UNION 
		SELECT MVIPersonSID, ChecklistID, OD_OMHSP_Standard=0, OD_ICD10, OD_DoD=0
		FROM #Overdose_ICD10
		UNION 
		SELECT MVIPersonSID, ChecklistID, OD_OMHSP_Standard=0, OD_ICD10=0, OD_DoD
		FROM #OUD_DoD) a
	GROUP BY MVIPersonSID, ChecklistID

---------------------------------------------------------------
-- Confirmed IDVU
---------------------------------------------------------------
	DROP TABLE IF EXISTS #IVDUConfirmed
	SELECT DISTINCT MVIPersonSID, CheckListID, Confirmed
	INTO #IVDUConfirmed
	FROM SUD.IDUCohort 
	WHERE Confirmed=1;

---------------------------------------------------------------
-- Positive drug screen past year 
---------------------------------------------------------------
	--Positive drug screen
	DROP TABLE IF EXISTS #PositiveResults
	SELECT DISTINCT MVIPersonSID, ChecklistID, LabGroup, LabDate, PositiveResult=1
	INTO #PositiveResults
	FROM Present.UDSLabResults as u WITH (NOLOCK)  
	WHERE LabScore=1 AND LabDate >= @PastYear;

---------------------------------------------------------------
-- Cohort consolidation: Step 1
---------------------------------------------------------------
	DROP TABLE IF EXISTS #Cohort
	SELECT c.MVIPersonSID
	INTO #Cohort
	FROM (	SELECT MVIPersonSID FROM #HealthFactor --health factor indicate detox/withdrawal
			UNION
			SELECT MVIPersonSID FROM #NLP --snippets for detox/withdrawal or idu
			UNION
			SELECT MVIPersonSID FROM #MHASurveys --Audit-C, CIWA, COWS
			UNION
			SELECT MVIPersonSID FROM #PositiveResults --positive drug screen
			UNION
			SELECT MVIPersonSID FROM #Overdose --overdose past year 
			UNION
			SELECT MVIPersonSID FROM #IVDUConfirmed --confirmed IVDU
			UNION
			SELECT MVIPersonSID FROM #DxDetails WHERE Category='Substance Use Disorder' --Any SUD diagnosis Past 5 years
		) c
	INNER JOIN #MasterPatient p 
		ON c.MVIPersonSID=p.MVIPersonSID

---------------------------------------------------------------
-- CSRE: High or Intermediate Past Year
---------------------------------------------------------------
	DROP TABLE IF EXISTS #CSRE
	SELECT DISTINCT a.MVIPersonSID
		,a.ChecklistID
		,CSRERisk=1
	INTO #CSRE
	FROM [OMHSP_Standard].[CSRE] a  WITH(NOLOCK)
	INNER JOIN [Lookup].[ChecklistID] b WITH(NOLOCK) on a.ChecklistID=b.ChecklistID
	WHERE (EvaluationType='New CSRE' or EvaluationType='Updated CSRE') 
			AND (AcuteRisk in ('High','Intermediate'))
			AND ISNULL(EntryDateTime,VisitDateTime) >= @PastYear;

---------------------------------------------------------------
-- H/O SUD Dx, Not currently engaged in SUD Tx 
---------------------------------------------------------------
	--First, find anyone with SUD specialty encounter/therapy in past year.
	--Note: will use this information in a future steps so need to start with full cohort of anyone who's been engaged with SUD specialty in past year.

	--Vista encounters
	DROP TABLE IF EXISTS #VisitSSC
	SELECT DISTINCT 
		ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,ck.ChecklistID
		,b1.VisitDateTime
		,b1.VisitSID
		,b1.PrimaryStopCodeSID
	INTO #VisitSSC
	FROM App.vwCDW_Outpat_Workload b1 WITH (NOLOCK) 
	LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON b1.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #MasterPatient m
		ON mvi.MVIPersonSID=m.MVIPersonSID
	INNER JOIN [Outpat].[VDiagnosis] c WITH (NOLOCK) 
		ON c.VisitSID = b1.VisitSID
	INNER JOIN [LookUp].[ICD10] d WITH (NOLOCK) 
		ON c.ICD10SID = d.ICD10SID
	INNER JOIN Dim.Institution i
		ON b1.InstitutionSID=i.InstitutionSID
	INNER JOIN LookUp.ChecklistID as ck WITH (NOLOCK) 
		ON i.StaPa=ck.StaPa
	LEFT OUTER JOIN [LookUp].[StopCode] psc WITH (NOLOCK) 
		ON b1.PrimaryStopCodeSID = psc.StopCodeSID 
	LEFT OUTER JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) 
		ON b1.SecondaryStopCodeSID = ssc.StopCodeSID 
	WHERE b1.VisitDateTime >= @PastYear
		AND b1.VisitDateTime <= GETDATE()
		AND (	    ssc.SUDTx_NoDxReq_Stop = 1 
				OR (ssc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
				OR  psc.SUDTx_NoDxReq_Stop = 1
				OR (psc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
				--General MH stopcodes included as well, per JT 7/2020; we are encouraging BHIP
				--teams to offer SUD, so we are giving credit for GMH when the patient has SUD dx.
				OR (ssc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
				OR (psc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
			);

	--Get cpt code sids for < 10 minute cpt code to exclude (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptexclude
	SELECT CPTSID,CPTCode, CPTName, CPTExclude=1
	INTO #cptexclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('98966', '99441', '99211', '99212');
	
	--Get cpt code sids for add-on codes that can be used with excluded CPT codes (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptinclude;
	SELECT CPTSID,CPTCode, CPTInclude=1
	INTO #cptinclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('90833','90836','90838');
	
	--Get cpt codes for any visit from initial visit query that have phone stop code
	DROP TABLE IF EXISTS #SUD_Tx_VistA 
	SELECT
		v.*
		,CASE 
			WHEN sc.Telephone_MH_Stop=1 AND ci.CPTSID IS NOT NULL --MH_Telephone_Stop includes all MH and SUD telephone
				THEN ci.CPTCode -- if one of these CPT codes is used, the visit counts even if an excluded code is also used
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTSID IS NOT NULL 
				THEN NULL --exclude visits with these CPT codes (unless they have one of the included codes accounted for above)
			ELSE 999999 
		END AS CPTCode --999999 => that there is no procedure code requirement		
	INTO #SUD_Tx_VistA
	FROM #VisitSSC v
	INNER JOIN [Lookup].[StopCode] sc WITH (NOLOCK)
		ON v.PrimaryStopCodeSID = sc.StopCodeSID
	LEFT JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
		ON v.VisitSID = p.VisitSID 
	LEFT JOIN 
		(
			SELECT p.VisitSID, e.CPTSID, e.CPTCode 
			FROM #cptexclude e
			INNER JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
				ON e.CPTSID = p.CPTSID
		) ce 
		ON p.VisitSID = ce.VisitSID
	LEFT JOIN #cptinclude ci 
		ON ci.CPTSID = p.CPTSID;	

	DELETE #SUD_Tx_VistA WHERE CPTCode IS NULL;

	--Cerner encounters
	DROP TABLE IF EXISTS #SUD_Tx_Cerner;
	SELECT DISTINCT 
		 v.MVIPersonSID
		,ck.ChecklistID
		,v.TZDerivedVisitDateTime AS VisitDateTime
		,v.EncounterSID
		--,v.EncounterType --for validation
		--,ce.CPTCode AS CPTExclude --for validation
		--,ci.CPTCode AS CPTInclude --for validation
		,CASE WHEN v.EncounterType='Telephone' AND ci.CPTSID IS NOT NULL THEN ci.CPTCode
			WHEN v.EncounterType='Telephone' AND ce.CPTSID IS NOT NULL THEN NULL
			WHEN ce.CPTCode IN ('98966','99441') AND ci.CPTCode IS NULL THEN NULL --telephone CPT codes, may have been used in non-telephone encounter types before Telephone encounter type existed
			ELSE 999999 
			END AS CPTCode --999999 => that there is no procedure code requirement
	INTO #SUD_Tx_Cerner
	FROM [Cerner].[FactUtilizationOutpatient] AS v WITH(NOLOCK)
	INNER JOIN #MasterPatient mp
		ON v.MVIPersonSID=mp.MVIPersonSID
	INNER JOIN [Cerner].[FactDiagnosis] as fd WITH(NOLOCK) 
		ON v.EncounterSID = fd.EncounterSID
	INNER JOIN [LookUp].[ICD10] d WITH(NOLOCK) 
		ON fd.NomenclatureSID = d.ICD10SID
	INNER JOIN [LookUp].[ListMember] AS lm WITH(NOLOCK)
		ON v.ActivityTypeCodeValueSID=lm.ItemID
	INNER JOIN [Cerner].[FactProcedure] as p WITH(NOLOCK) 
		ON v.EncounterSID=p.EncounterSID
	INNER JOIN LookUp.ChecklistID as ck WITH (NOLOCK) 
		ON ck.StaPa=v.STAPA
	LEFT JOIN (	SELECT 
					 p.EncounterType
					,p.EncounterSID
					,CASE WHEN EncounterTypeClass = 'Recurring' OR EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
					,e.CPTCode
					,e.CPTSID FROM #cptexclude AS e
				INNER JOIN [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
					ON e.CPTCode=p.SourceIdentifier) AS ce 
		ON   p.EncounterSID=ce.EncounterSID 
		AND (ce.TZDerivedProcedureDateTime IS NULL OR ce.TZDerivedProcedureDateTime = v.TZDerivedVisitDateTime)
	LEFT JOIN #cptinclude AS ci ON p.SourceIdentifier=ci.CPTCode
	WHERE lm.domain='ActivityType' AND (lm.List='MHOC_SUD'	OR (lm.List='MHOC_GMH' AND d.SUDdx_poss=1))
	AND ((v.TZDerivedVisitDateTime >= @PastYear) AND v.TZDerivedVisitDateTime <= getdate());

	DELETE #SUD_Tx_Cerner WHERE CPTcode IS NULL;

	-- Union the VistA and Cerner data together
	DROP TABLE IF EXISTS #SUD_Tx
	-- VistA
	SELECT DISTINCT MVIPersonSID
			,ChecklistID
			,VisitDateTime
			--,VisitSID
	INTO #SUD_Tx
	FROM #SUD_Tx_VistA
	UNION ALL
	-- Cerner
	SELECT DISTINCT MVIPersonSID
			,ChecklistID
			,VisitDateTime
			--,EncounterSID
	FROM #SUD_Tx_Cerner;

	--Identify cases where there's a h/o SUD Dx in past year, but no SUD Tx in past 12 months
	DROP TABLE IF EXISTS #SUDDxNoTx 
	SELECT DISTINCT d.ChecklistID, d.MVIPersonSID, SUDDxNoTx=1
	INTO #SUDDxNoTx
	FROM #SUDDxPastYear d
	LEFT JOIN #SUD_Tx t ON d.MVIPersonSID=t.MVIPersonSID
	WHERE t.MVIPersonSID IS NULL;

---------------------------------------------------------------
-- Current Active HRF
---------------------------------------------------------------
	DROP TABLE IF EXISTS #HRF
	SELECT DISTINCT
		 h.MVIPersonSID
		,h.OwnerChecklistID
		,CurrentActiveFlag
	INTO #HRF
	FROM [PRF_HRS].[EpisodeDates] h WITH (NOLOCK)
	INNER JOIN LookUp.ChecklistID cl WITH (NOLOCK)
		ON h.OwnerChecklistID=cl.ChecklistID
	INNER JOIN [PRF_HRS].[PatientReport_v02] p WITH (NOLOCK)
		ON h.MVIPersonSID=p.MVIPersonSID
	WHERE h.CurrentActiveFlag=1;

---------------------------------------------------------------
-- Most Recent Suicide Event
---------------------------------------------------------------
	DROP TABLE IF EXISTS #SDV 
	SELECT TOP (1) WITH TIES a.MVIPersonSID
		,EvidenceDate = ISNULL(a.EventDateFormatted, a.EntryDateTime)
		,a.ChecklistID
		,SDV=1
	INTO #SDV
	FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK) 
	WHERE (a.EventType='Suicide Event')
		AND a.Fatal = 0
		AND ISNULL(a.EventDateFormatted, a.EntryDateTime) >= @PastYear
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, a.ChecklistID ORDER BY ISNULL(a.EventDateFormatted, a.EntryDateTime) DESC, EntryDateTime DESC);

---------------------------------------------------------------
-- VJO involvement
---------------------------------------------------------------
	DROP TABLE IF EXISTS #VJOStops
	SELECT DISTINCT StopCodeSID, StopCode, StopCodeName
	INTO #VJOStops
	FROM LookUp.StopCode WITH(NOLOCK) 
	WHERE Justice_Outreach_Stop=1 or Incarcerated_Stop=1;

	--Vista encounters
	DROP TABLE IF EXISTS #VistaStops
	SELECT 
		 c.MVIPersonSID
		,ch.ChecklistID
		,sc.StopCode as PrimaryStopCode
		,sc.StopCodeName as PrimaryStopCodeName
		,ssc.StopCode as SecondaryStopCode
		,ssc.StopCodeName as SecondaryStopCodeName
		,v.VisitDateTime
		,v.VisitSID
	INTO #VistaStops 
	FROM App.vwCDW_Outpat_Workload v
	INNER JOIN #Cohort c
		ON v.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #VJOStops sc
		ON v.PrimaryStopCodeSID=sc.StopCodeSID
	LEFT JOIN #VJOStops ssc
		ON v.SecondaryStopCodeSID=ssc.StopCodeSID
	LEFT JOIN Dim.Institution i WITH(NOLOCK) 
		ON v.InstitutionSID=i.InstitutionSID
	LEFT JOIN LookUp.ChecklistID ch WITH(NOLOCK) 
		ON i.StaPa=ch.StaPa
	WHERE v.VisitDateTime >= @PastYear
	AND (v.PrimaryStopCodeSID=sc.StopCodeSID
		OR v.SecondaryStopCodeSID=ssc.StopCodeSID);

	--Cerner encounters
    DROP TABLE IF EXISTS #VJOActivityTypes
    SELECT List, ItemID, AttributeValue
    INTO #VJOActivityTypes
    FROM Lookup.ListMember a WITH (NOLOCK)
    WHERE Domain='ActivityType'
    AND (AttributeValue LIKE '%Veterans Justice Outreach' OR AttributeValue LIKE '%ncarcerated Veterans Re-Entry');

    DROP TABLE IF EXISTS #CernerStops
    SELECT DISTINCT
            f.MVIPersonSID
            ,f.EncounterSID
            ,f.TZDerivedVisitDateTime
            ,ch.ChecklistID
            ,StopCode=NULL
            ,StopCodeName=f.ActivityType
    INTO #CernerStops
    FROM [Cerner].[FactUtilizationOutpatient] f WITH(NOLOCK)
    INNER JOIN #Cohort c
            ON f.MVIPersonSID=c.MVIPersonSID
    INNER JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
            ON f.StaPa = ch.StaPa
    INNER JOIN #VJOActivityTypes vjo
            ON vjo.ItemID=f.ActivityTypeCodeValueSID
    WHERE f.TZDerivedVisitDateTime >= @PastYear;

	--Combine
	DROP TABLE IF EXISTS #VJO
	SELECT c.MVIPersonSID, v.ChecklistID, MostRecentDateTime=MAX(v.VisitDateTime), VJO
	INTO #VJO
	FROM #Cohort c
	INNER JOIN (
		SELECT MVIPersonSID
			,ChecklistID
			,VisitSID
			,VisitDateTime
			,VJO=1
		FROM #VistaStops 
		UNION
			SELECT MVIPersonSID
			,ChecklistID
			,EncounterSID
			,TZDerivedVisitDateTime
			,VJO=1
		FROM #CernerStops) v
		ON v.MVIPersonSID=c.MVIPersonSID
	GROUP BY c.MVIPersonSID, v.ChecklistID, v.VJO

-----------------------------------------------------------------
---- SDH Surveys - limited to most recent screen
-----------------------------------------------------------------
	DROP TABLE IF EXISTS #SocialDeterminantsHealthFactors
		SELECT
			pat.MVIPersonSID
			,h.ChecklistID
			,Category = 'Homeless Screening'
	INTO #SocialDeterminantsHealthFactors
	FROM #Cohort AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID AND  h.Category IN ('Homeless Screen')
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime AND h.Category=s.Category
	WHERE h.HealthFactorDateTime >= @PastYear AND s.Score=1 --positive score
	UNION
	SELECT
		pat.MVIPersonSID
		,h.ChecklistID
		,Category =  'Food Insecurity Screening'
	FROM #Cohort AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID AND h.Category ='Food Insecurity Screen'
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime AND h.Category=s.Category
	WHERE h.HealthFactorDateTime >= @PastYear AND s.Score=1 --positive score
	UNION
	SELECT
		pat.MVIPersonSID
		,h.ChecklistID
		,Category = 'Relationship Health and Safety Screening'
	FROM #Cohort AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID  AND h.Category='IPV'
	LEFT JOIN [SDH].[IPV_Screen] AS i WITH (NOLOCK) ON h.MVIPersonSID = i.MVIPersonSID AND h.HealthFactorDateTime = i.ScreenDateTime
	WHERE h.HealthFactorDateTime >= @PastYear and (i.ScreeningScore>=7 or (i.ViolenceIncreased=1 OR i.Choked=1 OR i.BelievesMayBeKilled=1)); --positive score

-----------------------------------------------------------------
--Labs
-----------------------------------------------------------------
	--HIV
	DROP TABLE IF EXISTS #MostRecentHIV
	SELECT MVIPersonSID
		,s.CheckListID
		,HIV=1
	INTO #MostRecentHIV
	FROM (	SELECT a.* ,Max(LabChemSID) over (partition by m.MVIPersonSID,Test) as LastLabChemSID,m.MVIPersonSID
			FROM PDW.PCS_LABMed_DOEx_HIV as a WITH (NOLOCK) 
			INNER JOIN Common.MVIPersonSIDPatientPersonSID as m WITH (NOLOCK) on a.PatientSID = m.PatientPersonSID
			INNER JOIN #Cohort as c WITH (NOLOCK) on m.MVIPersonSID = c.MVIPersonSID
			WHERE LabChemCompleteDateTime >= @PastYear
	 	 ) as a 
	LEFT JOIN LookUp.Sta6a as s WITH (NOLOCK) ON a.Sta6a=s.Sta6a
	WHERE LastLabChemSID=LabChemSID;

	--HepC
	DROP TABLE IF EXISTS #MostRecentHep
	SELECT MVIPersonSID
		,CheckListID
		,HepC=1
	INTO #MostRecentHep
	FROM (	SELECT a.* ,Max(LabChemSID) over (partition by a.PatientICN,LabType) as LastLabChemSID,b.[Date],m.MVIPersonSid
			FROM PDW.SCS_HLIRC_DOEx_HepCLabAllPtAllTime as a WITH (NOLOCK) 
			INNER JOIN Dim.Date as b WITH (NOLOCK) on a.LabChemSpecimenDateSID = b.DateSID
			INNER JOIN Common.MasterPatient as m WITH (NOLOCK) on a.PatientICN = m.PatientICN
			INNER JOIN #Cohort as c WITH (NOLOCK) on m.MVIPersonSID = c.MVIPersonSID
	WHERE [Date] >= @PastYear
		 ) as a 
	INNER JOIN LookUp.ChecklistID as s WITH (NOLOCK) on cast(a.sta3n as varchar(5)) = s.CheckListID
	WHERE LastLabChemSID=LabChemSID;

------------------------------------------------------------------------
-- Simplify data into dimensional tables for joining with #DimCohort.
-- Locations (ChecklistIDs) will be extracted from these temp tables for each case factor (e.g., adverse events, SUD diagnoses, health factors).  
------------------------------------------------------------------------
	-- Get locations (ChecklistIDs) where more than 2 adverse events within past year
	DROP TABLE IF EXISTS #Dim_Adverse
	SELECT DISTINCT MVIPersonSID, [>2Adverse], ChecklistID
	INTO #Dim_Adverse
	FROM #Adverse

	-- Get locations (ChecklistIDs) where SUD dx past year
	DROP TABLE IF EXISTS #Dim_SUDDxPastYear
	SELECT DISTINCT MVIPersonSID, SUDDxPastYear, ChecklistID
	INTO #Dim_SUDDxPastYear
	FROM #SUDDxPastYear

	-- Get locations (ChecklistIDs) where SUD dx within five years
	DROP TABLE IF EXISTS #Dim_ConsecutiveSUD
	SELECT DISTINCT MVIPersonSID, SUDDx=1, ChecklistID
	INTO #Dim_ConsecutiveSUD
	FROM #DxDetails
	WHERE Category='Substance Use Disorder'
	AND MostRecentDate >= DATEADD(year,-5,GETDATE())


	-- Get locations (ChecklistIDs) where Health factors indicate withdrawal or detox within past year
	DROP TABLE IF EXISTS #Dim_HF
	SELECT DISTINCT MVIPersonSID, ChecklistID, Detox=MAX(Detox), Withdrawal=MAX(Withdrawal)
	INTO #Dim_HF
	FROM #HealthFactor  
	WHERE Withdrawal=1 or Detox=1
	GROUP BY MVIPersonSID, ChecklistID
	   
	-- Get locations (ChecklistIDs) where NLP indicates detox or idu within past year
	DROP TABLE IF EXISTS #Dim_NLP
	SELECT DISTINCT MVIPersonSID, ChecklistID, NLP_Detox=MAX(NLP_Detox), NLP_IDU=MAX(NLP_IDU)
	INTO #Dim_NLP
	FROM #NLP
	WHERE NLP_Detox=1 OR NLP_IDU=1
	GROUP BY MVIPersonSID, ChecklistID
	
	-- Get locations (ChecklistIDs) where MHA surveys indicate positive AuditC, CIWA, or COWS within past year
	DROP TABLE IF EXISTS #Dim_MHASurveys
	SELECT DISTINCT MVIPersonSID, ChecklistID, AuditC=MAX(AuditC), CIWA=MAX(CIWA), COWS=MAX(COWS)
	INTO #Dim_MHASurveys
	FROM #MHASurveys as  mha WITH (NOLOCK)
	WHERE AuditC=1 OR CIWA=1 OR COWS=1
	GROUP BY MVIPersonSID, ChecklistID;

	-- Get locations (ChecklistIDs) where Overdose occurred within past year
	DROP TABLE IF EXISTS #Dim_Overdose
	SELECT MVIPersonSID
		,ChecklistID
		,OD_OMHSP_Standard	=MAX(OD_OMHSP_Standard)
		,OD_ICD10			=MAX(OD_ICD10)
		,OD_DoD				=MAX(OD_DoD)
	INTO #Dim_Overdose
	FROM #Overdose
	GROUP BY MVIPersonSID, ChecklistID;

	-- Get locations (ChecklistIDs) where IVDU was confirmed (no date contraints at this time given the small cohort size; consider changing in the future)
	DROP TABLE IF EXISTS #Dim_IDVUConfirmed 
	SELECT DISTINCT MVIPersonSID, Confirmed, CheckListID
	INTO #Dim_IDVUConfirmed
	FROM #IVDUConfirmed

	-- Get locations (ChecklistIDs) where Positive drug screen within past year
	DROP TABLE IF EXISTS #Dim_PositiveResults
	SELECT DISTINCT MVIPersonSID, PositiveResult, ChecklistID
	INTO #Dim_PositiveResults 
	FROM #PositiveResults

	-- Get locations (ChecklistIDs) where CSRE: Intermediate or High Acute within past year
	DROP TABLE IF EXISTS #Dim_CSRE
	SELECT DISTINCT MVIPersonSID, CSRERisK, ChecklistID
	INTO #Dim_CSRE
	FROM #CSRE

	-- Get locations (ChecklistIDs) where SUD dx, no SUD tx within past year
	DROP TABLE IF EXISTS #Dim_SUDDxNoTx
	SELECT DISTINCT MVIPersonSID, SUDDxNoTx, ChecklistID
	INTO #Dim_SUDDxNoTx
	FROM #SUDDxNoTx

	-- Get locations (ChecklistIDs) where Active HRF (no time constraint; want any active flags included)
	DROP TABLE IF EXISTS #Dim_HRF
	SELECT DISTINCT MVIPersonSID, CurrentActiveFlag, ChecklistID=OwnerChecklistID
	INTO #Dim_HRF
	FROM #HRF

	-- Get locations (ChecklistIDs) where H/o SDV within past year
	DROP TABLE IF EXISTS #Dim_SDV
	SELECT MVIPersonSID, SDV, ChecklistID
	INTO #Dim_SDV
	FROM #SDV; 

	-- Get locations (ChecklistIDs) where Justice invovlement (VJO) within past year
	DROP TABLE IF EXISTS #Dim_VJO
	SELECT DISTINCT MVIPersonSID, VJO, ChecklistID
	INTO #Dim_VJO
	FROM #VJO

	-- Get locations (ChecklistIDs) where Social determinants indicate homeless, IPV, or FoodInsecure within past year
	DROP TABLE IF EXISTS #Dim_SDH
	SELECT MVIPersonSID
		,ChecklistID
		,Homeless		=MAX(CASE WHEN Category='Homeless Screening' THEN 1 ELSE 0 END)
		,IPV			=MAX(CASE WHEN Category='Relationship Health and Safety Screening' THEN 1 ELSE 0 END)
		,FoodInsecure	=MAX(CASE WHEN Category='Food Insecurity Screening' THEN 1 ELSE 0 END)
	INTO #Dim_SDH
	FROM #SocialDeterminantsHealthFactors 
	GROUP BY MVIPersonSID, ChecklistID;

	-- Get locations (ChecklistIDs) where Hep C within past year
	DROP TABLE IF EXISTS #Dim_HepC
	SELECT DISTINCT MVIPersonSID, HepC, ChecklistID
	INTO #Dim_HepC
	FROM #MostRecentHep;

	-- Get locations (ChecklistIDs) where HIV within past year
	DROP TABLE IF EXISTS #Dim_HIV --simplify for patient details table
	SELECT DISTINCT MVIPersonSID, HIV, ChecklistID
	INTO #Dim_HIV
	FROM #MostRecentHIV;

	--code clean up
	DROP TABLE IF EXISTS #Dx
	DROP TABLE IF EXISTS #DxDetails
	DROP TABLE IF EXISTS #HF
	DROP TABLE IF EXISTS #CSRE
	DROP TABLE IF EXISTS #Overdose_OMHSP_Standard
	DROP TABLE IF EXISTS #Overdose_ICD10
	DROP TABLE IF EXISTS #OUD_DoD_Prep
	DROP TABLE IF EXISTS #OUD_DoD
	DROP TABLE IF EXISTS #CohortS1
	DROP TABLE IF EXISTS #VisitSSC
	DROP TABLE IF EXISTS #SUD_Tx_VistA
	DROP TABLE IF EXISTS #SUD_Tx_Cerner
	DROP TABLE IF EXISTS #SUD_Tx
	DROP TABLE IF EXISTS #VistaStops
	DROP TABLE IF EXISTS #CernerStops

------------------------------------------------------------------------
-- Get every location for comprehensive slicer in Power BI report
/* 
Note: 
The prioritization of ChecklistID (Team/Provider location vs. case factor location)
is intentionally handled downstream in the View (App.SUDCaseFinder_Providers_PBI) 
because the provider information is not available during the upstream processes here. 
This ensures that each patient is mapped to a location, defaulting to case factor 
locations when provider/team data is null.
*/
------------------------------------------------------------------------
--Goal: Combine all locations related to every case factor.  
-- In the Power BI report (and specifically handled in the View App.SUDCaseFinder_Providers_PBI), the first priority for ChecklistID is the patient’s Team/Provider location.
-- If the patient is not assigned to a Team/Provider, the default is the ChecklistID where the case factor occurred.  
-- The table #AllLocations essentially represents an inner join between #Cohort and all locations where the Veteran has recorded a case factor within the dataset.
	DROP TABLE IF EXISTS #AllLocations
	SELECT DISTINCT c.MVIPersonSID, cl.ChecklistID
	INTO #AllLocations
	FROM #Cohort c
	INNER JOIN (
		SELECT MVIPersonSID, ChecklistID FROM #Dim_Adverse  
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #SUDDxPastYear  
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_ConsecutiveSUD 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_HF 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_NLP 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_MHASurveys 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_Overdose 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_IDVUConfirmed 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_PositiveResults 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_CSRE 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #SUDDxNoTx 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_HRF 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_SDV 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_VJO 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_SDH 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_HepC 
		UNION
		SELECT MVIPersonSID, ChecklistID FROM #Dim_HIV 
			) cl
		ON c.MVIPersonSID=cl.MVIPersonSID

		--There are a select few (mostly Cerner) patients that, for one reason or another, don't have adequate information to derive ChecklistID. 
		--As of 5/8/2025, out of 1,488,460 in the denominator cohort, 39 of them do not have a ChecklistID (and thus are being removed from the cohort)
		DELETE #AllLocations
		WHERE ChecklistID IS NULL

------------------------------------------------------------------------
-- Create single-row table with full cohort
------------------------------------------------------------------------
	DROP TABLE IF EXISTS #DimCohort
	SELECT DISTINCT c.MVIPersonSID
		,mp.PatientICN
		,mp.PatientName
		,mp.LastFour
		,ChecklistID=CASE WHEN c.ChecklistID = '612' THEN '612A4' ELSE c.ChecklistID END
		,DetoxHF			=CASE WHEN hf.Detox=1 THEN 1 ELSE 0 END
		,Withdrawal			=CASE WHEN hf.Withdrawal=1 THEN 1 ELSE 0 END
		,CSRE				=CASE WHEN csre.CSRERisk=1 THEN 1 ELSE 0 END
		,NLPDetox			=CASE WHEN nlp.NLP_Detox=1 THEN 1 ELSE 0 END
		,NLPIVDU			=CASE WHEN nlp.NLP_IDU=1 THEN 1 ELSE 0 END
		--,NLPXylazine		 
		,AuditC				=CASE WHEN mha.AuditC=1 THEN 1 ELSE 0 END
		,CIWA				=CASE WHEN mha.CIWA=1 THEN 1 ELSE 0 END
		,COWS				=CASE WHEN mha.COWS=1 THEN 1 ELSE 0 END
		,PositiveDS			=CASE WHEN P.PositiveResult=1 THEN 1 ELSE 0 END
		,OD					=CASE WHEN o.OD_OMHSP_Standard=1 OR o.OD_ICD10=1 OR o.OD_DoD=1 THEN 1 ELSE 0 END
		,OD_OMHSP_Standard	=CASE WHEN o.OD_OMHSP_Standard=1 THEN 1 ELSE 0 END
		,OD_ICD10			=CASE WHEN o.OD_ICD10=1 THEN 1 ELSE 0 END
		,OD_DoD				=CASE WHEN o.OD_DoD=1 THEN 1 ELSE 0 END
		,SUDDxNoTx			=CASE WHEN s.SUDDxNoTx=1 THEN 1 ELSE 0 END
		,VJO				=CASE WHEN vjo.VJO=1 THEN 1 ELSE 0 END
		,IVDU				=CASE WHEN iv.Confirmed=1 THEN 1 ELSE 0 END
		,Homeless			=CASE WHEN sdh.Homeless=1 THEN 1 ELSE 0 END
		,IPV				=CASE WHEN sdh.IPV=1 THEN 1 ELSE 0 END
		,FoodInsecure		=CASE WHEN sdh.FoodInsecure=1 THEN 1 ELSE 0 END
		,SUDDxPastYear		=CASE WHEN sud.SUDDxPastYear=1 THEN 1 ELSE 0 END
		,SUDDx				=CASE WHEN csud.SUDDx=1 THEN 1 ELSE 0 END
		,SDV				=CASE WHEN sdv.SDV=1 THEN 1 ELSE 0 END
		,HRFActive			=CASE WHEN hrf.CurrentActiveFlag=1 THEN 1 ELSE 0 END
		,AdverseEvnts		=CASE WHEN adv.[>2Adverse]=1 THEN 1 ELSE 0 END
		,HepC				=CASE WHEN hep.HepC=1 THEN 1 ELSE 0 END
		,HIV				=CASE WHEN hiv.HIV=1 THEN 1 ELSE 0 END
	INTO #DimCohort
	FROM #AllLocations c
	INNER JOIN Common.MasterPatient mp WITH (NOLOCK) on c.MVIPersonSID=mp.MVIPersonSID
	LEFT JOIN #Dim_HF hf on c.MVIPersonSID=hf.MVIPersonSID and c.ChecklistID=hf.ChecklistID
	LEFT JOIN #Dim_NLP nlp on c.MVIPersonSID=nlp.MVIPersonSID and c.ChecklistID=nlp.ChecklistID
	LEFT JOIN #Dim_MHASurveys mha on c.MVIPersonSID=mha.MVIPersonSID and c.ChecklistID=mha.ChecklistID
	LEFT JOIN #Dim_PositiveResults p on c.MVIPersonSID=p.MVIPersonSID and c.ChecklistID=p.ChecklistID
	LEFT JOIN #Dim_Overdose o on c.MVIPersonSID=o.MVIPersonSID and c.ChecklistID=o.ChecklistID
	LEFT JOIN #Dim_CSRE csre on c.MVIPersonSID=csre.MVIPersonSID and c.ChecklistID=csre.ChecklistID
	LEFT JOIN #Dim_SUDDxNoTx s on c.MVIPersonSID=s.MVIPersonSID and c.ChecklistID=s.ChecklistID
	LEFT JOIN #Dim_VJO vjo on c.MVIPersonSID=vjo.MVIPersonSID and c.ChecklistID=vjo.ChecklistID
	LEFT JOIN #Dim_IDVUConfirmed iv on c.MVIPersonSID=iv.MVIPersonSID and c.ChecklistID=iv.CheckListID
	LEFT JOIN #Dim_SUDDxPastYear sud on c.MVIPersonSID=sud.MVIPersonSID and c.ChecklistID=sud.ChecklistID
	LEFT JOIN #Dim_ConsecutiveSUD csud on c.MVIPersonSID=csud.MVIPersonSID and c.ChecklistID=csud.ChecklistID
	LEFT JOIN #Dim_SDV sdv on c.MVIPersonSID=sdv.MVIPersonSID and c.ChecklistID=sdv.ChecklistID
	LEFT JOIN #Dim_HRF hrf on c.MVIPersonSID=hrf.MVIPersonSID and c.ChecklistID=hrf.ChecklistID
	LEFT JOIN #Dim_Adverse adv on c.MVIPersonSID=adv.MVIPersonSID and c.ChecklistID=adv.ChecklistID
	LEFT JOIN #Dim_SDH sdh on c.MVIPersonSID=sdh.MVIPersonSID and c.ChecklistID=sdh.ChecklistID
	LEFT JOIN #Dim_HepC hep on c.MVIPersonSID=hep.MVIPersonSID and c.ChecklistID=hep.ChecklistID
	LEFT JOIN #Dim_HIV hiv on c.MVIPersonSID=hiv.MVIPersonSID and c.ChecklistID=hiv.ChecklistID;

EXEC [Maintenance].[PublishTable] 'SUD.CaseFinderCohort', '#DimCohort';

---------------------------------------------------------------
--Risk Factors - for PowerBI slicers and evidentiary joining
---------------------------------------------------------------
	DROP TABLE IF EXISTS #RiskFactors
		--Substance Use
	SELECT DISTINCT MVIPersonSID, RiskType='Confirmed IDU', SortKey=1
	INTO #RiskFactors
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE IVDU=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Positive Audit-C', SortKey=2
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE AuditC=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='CIWA', SortKey=3
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE CIWA=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='COWS', SortKey=4
	FROM SUD.CaseFinderCohort
	WHERE COWS=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Detox/Withdrawal Health Factor', SortKey=5
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE DetoxHF=1 OR Withdrawal=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Detox/Withdrawal Note Mentions', SortKey=6
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE NLPDetox=1

	UNION

	--SELECT DISTINCT MVIPersonSID, RiskType='Xylazine Note Mentions Past Year', SortKey=7
	--FROM SUD.CaseFinderCohort
	--WHERE NLPXylazine=1

	--UNION

	SELECT DISTINCT MVIPersonSID, RiskType='CSRE Acute Risk (Intermed/High)', SortKey=8
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE CSRE=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Positive Drug Screen', SortKey=9
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE PositiveDS=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Hx of SUD Dx | No SUD Tx', SortKey=10
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE SUDDxNoTx=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='IVDU Note Mentions', SortKey=11
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE NLPIVDU=1	

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='> 2 Adverse Events', SortKey=12
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE AdverseEvnts=1

	UNION

	--Overdose/Suicide Related Bx
	SELECT DISTINCT MVIPersonSID, RiskType='Overdose (SBOR/CSRE) - Past Year', SortKey=13
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE OD_OMHSP_Standard=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Overdose (VA ICD-10) - Past Year', SortKey=14
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE OD_ICD10=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Overdose (DoD ICD-10) - Past Year', SortKey=15
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE OD_DoD=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Overdose Event', SortKey=16
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE OD=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Suicide Event', SortKey=17
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE SDV=1 

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Current Active PRF - Suicide', SortKey=18
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE HRFActive=1

	UNION

	--Social Determinants
	SELECT DISTINCT MVIPersonSID, RiskType='Homeless - Positive Screen', SortKey=19
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE Homeless=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Food Insecurity - Positive Screen', SortKey=20
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE FoodInsecure=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Relationship Health and Safety - Positive Screen', SortKey=21
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE IPV=1

	UNION

	SELECT DISTINCT MVIPersonSID, RiskType='Justice Involvement', SortKey=22
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE VJO=1

	UNION

	--Labs
	SELECT DISTINCT MVIPersonSID, RiskType='Hep C Labs - Most Recent', SortKey=23
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE HepC=1

	UNION 

	SELECT DISTINCT MVIPersonSID, RiskType='HIV Labs - Most Recent', SortKey=24
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE HIV=1
	
	UNION 

	SELECT DISTINCT MVIPersonSID, RiskType='Substance Use Disorder', SortKey=25
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE SUDDx=1


EXEC [Maintenance].[PublishTable] 'SUD.CaseFinderRisk', '#RiskFactors';


END