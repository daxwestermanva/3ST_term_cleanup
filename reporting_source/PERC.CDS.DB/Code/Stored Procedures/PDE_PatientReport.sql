


/*=============================================
-- Author:		Paty Henderson (modified by David Wright and Rebecca Stephens)
-- Create date: 2017-09
-- Description:	Daily PDE Tracking System. Here, we have adapted the PDE1 metric to run on a daily basis 
				and added variables similar to those previously available in the VSSC daily discharge dashboard.
			 --	Includes patients currently admitted or discharged in the past 30 days 
				who are required to have a certain number of follow-up visits within 
				30 days post discharge according to PDE1 metric. 
-- MODIFICATIONS: 
--	2018-01-30	RAS: Changed past 30 days to past 90 days to keep patients on dashboard longer
--	2018-06-21	RAS: Updated inpatient daily workload query to use lookup treating specialty instead of a previous dev table.
--	2019-01-16	JEB: Removed use of Patient table to use SPatient table
--	2019-01-30	RAS: Changed 30 days to 31 days in calculations using < to include all followup days
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--  2019-04-19  RAS: Removed PatientName, LastFour, and other demographics. Joined with StationAssignments in report App SP instead.
					 Implemented MVIPersonSID and cleaned up formatting.
--	2019-12-13	RAS: Changed DischargeDateTime to SpecialtyTransderDateTime in #LastDischBed.  
					 Added VisitSID and VProviderSID to partitions and order by to get consistent results.
--	2020-02-02	RAS: Changed VProviderSID to ProviderSID in #oprecs and PDE_FollowUpMHVisits.  VProviderSID was returning additional rows in table.
					 If VProviderSID makes more sense for partition ordering later in code then need to evaluate consequences of additional rows.
--	2020-03-25	RAS: Updated residential definition to be grouping of RRTP_TreatingSpecialty, Homeless_TreatingSpecialty AND 
					 added SpecialtyIEN 68 (MH SHort Stay Nursing Home) to align with PDE eTM definition.
--  2020-04-06	EC: Added DisDay to the partition in #nextappt for cases with multiple discharges
--  2020-04-13	EC: Removed SpecialtyIEN = 68 (MH SHort Stay Nursing Home) and SpecialtyIEN 75 (Halfway house). 68 was an error and 75 
					will be removed due to no recent usage.  eTM will be updated in future to exclude these (confirmed by Eric Schmidt).
--	2020-08-10	RAS: Pointed code to Inpatient.BedSection instead of doing separate computation.  Updated to use PRF_HRS.EpisodeDates to simplify RiskEpisode section.
--	2020-09-28	RAS: Added fix for discharge dates BETWEEN high risk flag episode dates when the patient is still admitted (ISNULL(i.DischargeDateTime,CAST(GETDATE() AS DATE))
--	2020-11-05	LM:	 New metric definition for PDE1 visits as of 10/1/20 - excluding CPT codes 98966 and 99441
--	2020-12-04	LM:  Dropped telephone visits with no CPT codes from appearing in final table
--	2020-12-16	RAS: Switched Homestation references to Homestation*
--	2021-02-17	LM:	 Updated CPT codes for telephone visits based on new metric definition
--  2021-05-18  JEB: Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
--  2021-09-13	AI:  Enclave Refactoring - Counts confirmed
--	2022-03-29	LM:  Removed e-consults with secondary stop code 697
--  2022-05-02	RAS: Switched reference to LookUp.CPT to Dim.CPT -- changing CPT lookup to List structure, this was a hard-coded definition
--  2022-05-26  EC: Added Cerner data to code
--	2022-06-15	LM:	 Fixed CPT code exclusions for Recurring encounters in Cerner
--  2022-08-15  SAA_JJR: Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data
--  2022-10-17	EC:	 Adding most recent BHIP Team info for patients
--	2022-10-25	LM:  Updated to use MHOC_MentalHealth and MHOC_Homeless stop codes to reflect change in metric definition
--  2022-03-21	EC:  Added cerner MedicalService and Accommodation columns and SUD_Dx column for highlighting info on dashboard
--  2023-09-21  EC:  Added PlaceOfDispositionCode = K (Community RRTP) to exclusions to match changes to PDE1 metric in FY23Q4
--  2024-01-17  EC:  Expanded suicide-related diagnosis patients to include SI-related diagnoses in ANY position in the Inpat.SpecialtyTransferDiagnosis view 
					 to match PDE metric (AnyBed_SuicidalitySelfHarmAnyIntent_idtx2_i3b) versus only the primary diagnosis
--  2024-01-24  EC:  Due to BHIP team definition narrowing/being more specific, switching from [Present].[Provider_BHIP] to [Present].[Provider_MHTeam] view instead to capture all MH team info
--  2024-05-21  EC:  Adding SuicideRelated_DX_Label column to concatenate suicide-related diagnosese for the inpatient admission to use on PDE dashboard.
--  2025-01-16  EC:  Adding new 2025 5-10 minute audio CPT code 98016 to visit exclusions
--	2025-03-26  EC:	 Matching definition of 'suicide-related behaviors and symptoms' from the metric and XLA variable 'AnyBed_PDEHarmIndicator_idtx2_i3b'; Added Overdose_Dx flag


  =============================================*/
CREATE   PROCEDURE [Code].[PDE_PatientReport]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PDE_PatientReport', @Description = 'Execution of Code.PDE_PatientReport SP'

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PDE_PatientReport Part 1', @Description = 'PDE InpatientRecords'

/*********************************************************************************
 Step 0 - Identify the past 30 days. Including census records
*********************************************************************************/  
DECLARE  @todaysdate datetime =  getdate()
DECLARE  @END_dt     datetime  = DATEADD(day, DATEDIFF(day, 0, @TodaysDate), 0)       /*Sets date to midnight */ 
DECLARE  @Begin_dt   datetime  = DateAdd(day,-91, @END_dt)                           /*Begin date will be 90 days prior to pull date*/     
SET      @END_dt             = DATEADD(ms, -3, @END_dt)                              /*day before first day of pull date month */          

PRINT  'Begin Date: ' + FORMAT (@begin_dt, 'MM/dd/yyyy hh:mm tt')
PRINT  'END Date: ' + FORMAT (@End_dt, 'MM/dd/yyyy hh:mm tt')

/*********************************************************************************
 Step 2 - create a daily inpatient workload file to use in this project
*********************************************************************************/  
DROP TABLE IF EXISTS #inpatient_dailyworkload;
SELECT i.MVIPersonSID 
	  ,i.InpatientEncounterSID
	  ,i.Sta3n_EHR
	  ,i.DischargeDateTime
	  ,i.AdmitDateTime
	  ,i.ICD10Code			--don't use PrincipalDiagnosisICD10SID because that is only available for VistA discharges. Using ICD10Code due to OracleHealth discharges.
	  ,i.PlaceOfDisposition
	  ,i.PlaceOfDispositionCode
	  ,i.AMA
	  ,i.AdmitDiagnosis
	  ,i.Sta6a
	  ,i.MedicalService		--Cerner
	  ,i.Accommodation		--Cerner
	  ,i.BedSection
	  ,i.BedSectionName
	  ,i.BsInDateTime
	  ,i.BsOutDateTime
	  ,i.ChecklistID
	  ,i.Census
	  ,i.RRTP_TreatingSpecialty
	  ,i.MentalHealth_TreatingSpecialty
	  ,i.MedSurgInpatient_TreatingSpecialty
	  ,i.NursingHome_TreatingSpecialty
	  ,DisDay=CONVERT(DATE,CASE WHEN i.DischargeDateTime IS NOT NULL THEN i.DischargeDateTime ELSE DATEADD(ms,-3,CONVERT(DATETIME,@end_dt)) END)
INTO #inpatient_dailyworkload
FROM [Inpatient].[BedSection] i WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] d WITH (NOLOCK)
ON d.MVIPersonSID=i.MVIPersonSID
WHERE d.DateOfDeath IS NULL 
	AND Veteran=1
	AND (
			(DischargeDateTime >= @Begin_dt and DischargeDateTime < @End_dt) /*Non-Census*/
		OR (
			(DischargeDateTime >= @End_dt or DischargeDateTime is null) 
			AND (AdmitDateTime <@End_dt)
			) /*Census*/
		)

----------------------------------------------------------------------------------------------------------------------------------------------
--  Find SI-related diagnoses in ANY position in the Inpat.SpecialtyTransfer view to match PDE metric (AnyBed_PDEHarmIndicator_idtx2_i3b)   --
----------------------------------------------------------------------------------------------------------------------------------------------

--Get latest FYQ to pull most recent PDE definition/ICD10 codes
DECLARE @FYQ VARCHAR(6) = 'FY25Q2'--(SELECT MAX(FYQ) FROM [XLA].[MDS_eTM] WITH (NOLOCK) WHERE VariableName='AnyBed_PDEHarmIndicator_idtx2_i3b' AND CodeSystem = 'ICD10CM')

--Pull most recent PDE definition/ICD10 codes from XLA MDS eTM table
DROP TABLE IF EXISTS #SIDX;
SELECT i.ICD10SID
	,'ICD10Code' = m.CodeValue
	,'ICD10Description' = m.CodeValueDescription
	,'Overdose_DX' = CASE WHEN m.CodeSet like '%Overdose%' THEN 1 ELSE 0 END
INTO #SIDX
FROM [Dim].[ICD10] as i WITH (NOLOCK)
INNER JOIN [XLA].[MDS_eTM] as m WITH (NOLOCK)
ON i.ICD10Code = m.CodeValue
WHERE 1=1
	AND m.VariableName = 'AnyBed_PDEHarmIndicator_idtx2_i3b'
	AND m.CodeSystem = 'ICD10CM'
	AND m.FYQ = @FYQ
;

--Get diagnoses for all inpatients discharging during the time period of interest
DROP TABLE IF EXISTS #inp1_dx;
SELECT inp1.MVIPersonSID
		,inp1.InpatientEncounterSID
		,inp1.DisDay
		,STdx.ICD10SID
INTO #inp1_dx
FROM  #inpatient_dailyworkload as inp1
INNER JOIN [Inpat].[SpecialtyTransferDiagnosis] as STdx WITH (NOLOCK)
on inp1.InpatientEncounterSID = STdx.InpatientSID
;

--Identify which discharges had Suicide or Overdose-related diagnoses in [Inpat].[SpecialtyTransferDiagnosis]
DROP TABLE IF EXISTS #inp1_InpatSIdx;
SELECT  inp.MVIPersonSID
		,inp.InpatientEncounterSID
		,inp.DisDay
		,Overdose_DX = MAX(d.Overdose_DX)
		,d.ICD10SID
		,d.ICD10Code
		,MAX(d.ICD10Description) as ICD10Description
		,DxSource='ST'
INTO #inp1_InpatSIdx
FROM  #inp1_dx as inp
INNER JOIN #SIDX as d		----List of Suicide and overdose related diagnoses
ON inp.ICD10SID = d.ICD10SID
WHERE d.ICD10SID IS NOT NULL	
GROUP BY inp.MVIPersonSID, inp.InpatientEncounterSID,inp.DisDay,d.ICD10SID,d.ICD10Code
;

--Identify which discharges had Suicide or Overdose-related diagnoses as a Primary Dx 
DROP TABLE IF EXISTS #inp1_PrimarySIdx;
SELECT inp.MVIPersonSID
	  ,inp.InpatientEncounterSID
	  ,inp.DisDay
	  ,d.ICD10Code
	  ,MAX(d.ICD10Description) AS ICD10Description
	  ,Overdose_DX = MAX(d.Overdose_DX)
	  ,DXSource='PD'
INTO #inp1_PrimarySIdx
FROM #inpatient_dailyworkload AS inp 
INNER JOIN #SIDX as d		----List of Suicide and overdose related diagnoses
ON d.ICD10Code=inp.ICD10Code
GROUP BY inp.MVIPersonSID, inp.InpatientEncounterSID,inp.DisDay,d.ICD10Code
;

DROP TABLE IF EXISTS #inp1_SIdx;
SELECT DISTINCT MVIPersonSID
		,InpatientEncounterSID
		,DisDay
		,ICD10Code
		,ICD10Description
		,ICD10Label = ICD10Code + ': ' + ICD10Description
		,Overdose_DX
		,DxSource
INTO #inp1_SIdx
FROM  #inp1_InpatSIdx
UNION ALL
SELECT DISTINCT MVIPersonSID
		,InpatientEncounterSID
		,DisDay
		,ICD10Code
		,ICD10Description
		,ICD10Label = ICD10Code + ': ' + ICD10Description
		,Overdose_Dx
		,DxSource
FROM #inp1_PrimarySIdx
;

EXEC [Maintenance].[PublishTable] 'PDE_Daily.Diagnoses', '#inp1_SIdx'

DROP TABLE IF EXISTS #inp1_SIdx_uniq;
SELECT DISTINCT MVIPersonSID
		,InpatientEncounterSID
		,DisDay
		,ICD10Code
		,MAX(ICD10Label) as ICD10Label
		,Overdose_DX
INTO #inp1_SIdx_uniq
FROM #inp1_SIdx
GROUP BY MVIPersonSID
		,InpatientEncounterSID
		,DisDay
		,ICD10Code
		,Overdose_DX
;

DROP TABLE IF EXISTS #inp1_SIdx_agg;
SELECT DISTINCT MVIPersonSID
		,InpatientEncounterSID
		,DisDay
		,'SuicideRelated_DX_Label' = STRING_AGG(ICD10Label,';')
		,Overdose_DX = MAX(Overdose_DX)
INTO #inp1_SIdx_agg
FROM #inp1_SIdx_uniq
GROUP BY MVIPersonSID
		,InpatientEncounterSID
		,DisDay
;

/*********************************************************************************
 Step 3 - group up to inpatient stay, check all bedsections
*********************************************************************************/  

DROP TABLE IF EXISTS #inp1_raw;
SELECT inp.mvipersonsid,
       Group2_High_Den =Max(CASE
                              WHEN inp.MentalHealth_TreatingSpecialty = 1 THEN 1
                              ELSE 0
                            END),
       Group1_Low_Den =Max(CASE
                             WHEN inp.RRTP_TreatingSpecialty = 1
                                   OR (inp.MedSurgInpatient_TreatingSpecialty = 1
                                        AND (d.MHSUDDX_POSS=1 OR dx.InpatientEncounterSID IS NOT NULL)) THEN 1
                             ELSE 0
                           END),
       SuicideRelated_DX =Max(CASE
                                WHEN dx.InpatientEncounterSID IS NOT NULL THEN 1
                                ELSE 0
                              END),
	   SuicideRelated_DX_Label =Max(CASE
                                WHEN  dx.InpatientEncounterSID IS NOT NULL THEN dx.SuicideRelated_Dx_Label
                                ELSE NULL
                              END),
       G1_MH =Max(CASE
                    WHEN inp.RRTP_TreatingSpecialty = 1 THEN 1
                    ELSE 0
                  END),
       G1_NMH =Max(CASE
                     WHEN inp.MedSurgInpatient_TreatingSpecialty = 1
                          AND (d.MHSUDDX_POSS=1 OR dx.InpatientEncounterSID IS NOT NULL) THEN 1
                     ELSE 0
                   END), 
	MedicalService					=MAX(inp.MedicalService),
	Accommodation					=MAX(inp.Accommodation),
	Bedsecn							=MAX(inp.BedSection),
	BedSecnName						=MAX(inp.BedSectionName),
	MentalHealth_TreatingSpecialty  =MAX(inp.MentalHealth_TreatingSpecialty),
	RRTP_TreatingSpecialty			=MAX(inp.RRTP_TreatingSpecialty),
	MedSurgInpatient_TreatingSpecialty=MAX(inp.MedSurgInpatient_TreatingSpecialty),
	InpatientEncounterSID			=MAX(inp.InpatientEncounterSID),						
	Sta3n_EHR						=MAX(inp.Sta3n_EHR),
	Census                          =MAX(inp.Census),								
	DisDay							=MAX(inp.DisDay),	
	DischargeDateTime               =MAX(inp.DischargeDateTime),
	AdmitDateTime					=MAX(inp.AdmitDateTime),	
	AdmitDiagnosis					=MAX(inp.AdmitDiagnosis),
	PrincipalDiagnosisICD10Desc     =MAX(d.ICD10Description),
	PrincipalDiagnosisICD10Code     =MAX(inp.ICD10Code),
	PlaceOfDispositionCode          =MAX(inp.PlaceOfDispositionCode),
	Discharge_Sta6a                 =MAX(inp.Sta6a),	
	AMADischarge		            =MAX(inp.AMA),
	SUD_Dx							=MAX(CASE WHEN d.SUDdx_poss = 1 THEN 1 ELSE 0 END),
	SUD_Dx_Label					=MAX(CASE WHEN d.SUDdx_poss = 1 THEN d.ICD10Description ELSE NULL END),
	Overdose_DX						=MAX(CASE WHEN dx.Overdose_DX = 1 THEN 1 ELSE 0 END)
INTO #inp1_raw
FROM   #inpatient_dailyworkload AS inp
LEFT JOIN #inp1_SIdx_agg AS dx
ON inp.inpatientencountersid = dx.inpatientencountersid 
LEFT JOIN (
	SELECT 
		 ICD10Code
		,ICD10Description		= MAX(ICD10Description)
		,MHSUDdx_poss			= MAX(CAST(MHSUDdx_poss AS INT))
		,SUDdx_poss				= MAX(CAST(SUDdx_poss AS INT))
	FROM [Lookup].[ICD10] WITH (NOLOCK)
	GROUP BY ICD10Code	
	) as d ON d.ICD10Code=inp.ICD10Code
GROUP BY inp.MVIPersonSID, inp.DisDay
;

---------------------------------
 --pull last discharge bedescn info for distinct MVIPersonSID, DisDay
---------------------------------
	DROP TABLE IF EXISTS #LastDischBed;
	SELECT MVIPersonSID
			,DisDay
			,MedicalService
			,Accommodation
			,BedSection
			,BedSectionName
			,MentalHealth_TreatingSpecialty
			,RRTP_TreatingSpecialty
			,MedSurgInpatient_TreatingSpecialty  
	INTO #LastDischBed 
	FROM (
		SELECT MVIPersonSID
			,DisDay
			,MedicalService
			,Accommodation
			,BedSection
			,BedSectionName
			,MentalHealth_TreatingSpecialty
			,RRTP_TreatingSpecialty
			,MedSurgInpatient_TreatingSpecialty 
			,RN = ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,DisDay ORDER BY BsInDateTime DESC, AdmitDateTime)
		FROM #inpatient_dailyworkload 
		) as a
	WHERE RN = 1

	DROP TABLE IF EXISTS #LastDischBed2;
	SELECT a.*
		  ,DischBed_MH_acute=MentalHealth_TreatingSpecialty
		  ,DischBed_MH_res=RRTP_TreatingSpecialty
		  ,DischBed_NMH=MedSurgInpatient_TreatingSpecialty
	INTO #LastDischBed2
	FROM #LastDischBed as a

	--Join back with table so have discharge beds except for those not discharged yet
	DROP TABLE IF EXISTS #inp2_raw;
	SELECT a.MVIPersonSID
		  ,a.AdmitDateTime
		  ,a.AdmitDiagnosis
		  ,a.AMADischarge
		  ,a.MedicalService
		  ,a.Accommodation
		  ,a.Bedsecn
		  ,a.BedSecnName
		  ,a.Census
		  ,a.Discharge_Sta6a
		  ,a.DischargeDateTime
		  ,a.DisDay
		  ,a.G1_MH
		  ,a.G1_NMH
		  ,a.Group1_Low_Den
		  ,a.Group2_High_Den
		  ,a.InpatientEncounterSID
		  ,a.Sta3n_EHR
		  ,a.MedSurgInpatient_TreatingSpecialty
		  ,a.MentalHealth_TreatingSpecialty
		  ,a.PlaceOfDispositionCode
		  ,a.PrincipalDiagnosisICD10Code
		  ,a.PrincipalDiagnosisICD10Desc
		  ,a.RRTP_TreatingSpecialty
		  ,a.SuicideRelated_DX
		  ,a.SuicideRelated_DX_Label
		  ,a.SUD_Dx
		  ,a.SUD_Dx_Label
		  ,a.Overdose_DX
		  ,Disch_bedsecn=b.BedSection 
		  ,Disch_bedsecname=b.BedSectionName
		  ,b.DischBed_MH_acute
		  ,b.DischBed_MH_res
		  ,b.DischBed_NMH
	INTO #inp2_raw
	FROM #inp1_raw as a
	LEFT JOIN #LastDischBed2 as b ON
		a.MVIPersonSID = b.MVIPersonSID
		AND a.DisDay=b.DisDay	

/*********************************************************************************
 Step 4 - Mark if current episode is less than 30 days before next admission. Process risk flag information
*********************************************************************************/  
DROP TABLE IF EXISTS #inp1;
SELECT *,
	Exclusion30=CASE WHEN DateDIFF(dd, Disday,Lead(AdmitDateTime) OVER(PARTITION BY MVIPersonSID ORDER BY DisDay)) <31 
					 THEN 1 ELSE 0 END
INTO #INP1
FROM #inp2_raw
--DROP TABLE #inp2_raw

--20170104 RAS: Added all diagnosis codes and descriptions
UPDATE #inp1
SET PrincipalDiagnosisICD10DESC = i.ICD10Description
FROM #inp1 as a 
INNER JOIN (
	SELECT 
		ICD10Code
		,ICD10Description = MAX(ICD10Description) 
	FROM [Lookup].[ICD10] WITH (NOLOCK)
	GROUP BY ICD10Code
	) i ON i.ICD10Code = a.PrincipalDiagnosisICD10Code

---------------------------------
 --RISK FLAG INFORMATION
---------------------------------
DROP TABLE IF EXISTS #RiskEpisodes;
SELECT i.MVIPersonSID
	  ,i.AdmitDateTime
	  ,i.DischargeDateTime
	  ,i.DisDay
	  ,hrf.EpisodeBeginDateTime
	  ,hrf.EpisodeEndDateTime
INTO #RiskEpisodes
FROM #INP1 i
INNER JOIN [PRF_HRS].[EpisodeDates] hrf WITH (NOLOCK)
	ON 	i.MVIPersonSID=hrf.MVIPersonSID
	AND CAST(ISNULL(i.DischargeDateTime,GETDATE()) AS DATE) BETWEEN CAST(hrf.EpisodeBeginDateTime AS DATE) AND CAST(ISNULL(hrf.EpisodeEndDateTime,GETDATE()) AS DATE)
	--compared as dates above to get all instances where discharge ocurred on same day as activation

---------------------------------
 --Combine inpatients all together:
---------------------------------
	DROP TABLE IF EXISTS #DistinctInpatients;
	SELECT AMADischarge			=	MAX(inp.AMADischarge)
		  ,inp.MVIPersonSID
		  ,Census				=	MAX(inp.Census)
		  ,inp.DisDay
		  ,DischargeDateTime	=	MAX(inp.DischargeDateTime)
		  ,AdmitDateTime		=	MAX(inp.AdmitDateTime)
		  ,POD					=	MAX(inp.PlaceOfDispositionCode)
		  ,Exclusion30			=	MAX(inp.Exclusion30)
		  ,RF_DisDay			=	MAX(rf.DisDay)
		  ,Group2_High_Den		=	MAX(inp.Group2_High_Den)
		  ,Group1_Low_Den		=	MAX(inp.Group1_Low_Den)
		  ,Group3_HRF			=	MAX(
				CASE WHEN (rf.DisDay is not null AND
							(inp.RRTP_TreatingSpecialty=1 
							or inp.MentalHealth_TreatingSpecialty=1 
							or inp.MedSurgInpatient_TreatingSpecialty=1 
							)
						) /*3a*/   
					 or inp.SuicideRelated_DX=1  /*3b*/ 
					THEN 1 ELSE 0 END
				) --Why does above case need the and statement for bedsections?
		  ,G1_MH			=	MAX(inp.G1_MH)
		  ,G1_NMH			=	MAX(inp.G1_NMH)
		  ,MedicalService	=	MAX(inp.MedicalService)
		  ,Accommodation	=	MAX(inp.Accommodation)
		  ,Disch_BedSecn	=	MAX(inp.Disch_BedSecn)
		  ,Disch_BedSecName	=	MAX(inp.Disch_BedSecName)
		  ,DischBed_MH_Acute=	MAX(inp.DischBed_MH_Acute)
		  ,DischBed_MH_Res	=	MAX(inp.DischBed_MH_Res)
		  ,DischBed_NMH		=	MAX(inp.DischBed_NMH)
		  ,Discharge_Sta6a	=	MAX(inp.Discharge_Sta6a)
		  ,PrincipalDiagnosisICD10Desc=MAX(inp.PrincipalDiagnosisICD10Desc)
		  ,PrincipalDiagnosisICD10Code=MAX(inp.PrincipalDiagnosisICD10Code)
		  ,AdmitDiagnosis	=	MAX(inp.AdmitDiagnosis)
		  ,SUD_Dx			=	MAX(inp.SUD_Dx)
		  ,SUD_Dx_Label		=	MAX(inp.SUD_Dx_label)
		  ,Overdose_Dx		=	MAX(inp.Overdose_Dx)
		  ,SI_Dx			=	MAX(inp.SuicideRelated_Dx)
		  ,SuicideRelated_DX_Label=MAX(inp.SuicideRelated_Dx_Label)
	INTO #DistinctInpatients
	FROM #inp1 as inp   
	LEFT JOIN #RiskEpisodes as rf ON 
		inp.MVIPersonSID=rf.MVIPersonSID 
		and inp.DisDay=rf.DisDay
	GROUP BY inp.MVIPersonSID
		,inp.DisDay

	DROP TABLE IF EXISTS #pde_grp;
	SELECT *
		  ,PostDisch_30days=Dateadd(day,30,DischargeDateTime)
		  ,PDE_GRP=CASE 
				WHEN Group3_HRF = 1 THEN 3
		  		WHEN Group3_HRF = 0 and Group2_High_Den = 1 THEN 2
		  		WHEN Group3_HRF = 0 and Group2_High_Den = 0 and Group1_Low_Den = 1 THEN 1 
		  		ELSE 0 END 
		  ,HRF=CASE WHEN RF_DisDay is not null THEN 1 ELSE 0 END
	INTO #pde_grp 
	FROM #DistinctInpatients 

	DROP TABLE IF EXISTS #G1_MH_Final;
	SELECT *   
		,G1_MH_Final=CASE
			WHEN PDE_GRP=1 and G1_MH=1 THEN 1 
			WHEN PDE_GRP=1 and G1_MH=0 THEN 0 
			ELSE null END 
	INTO #G1_MH_Final
	FROM #pde_grp

---------------------------------
 --CREATE PERMANENT TABLE FOR INPATIENT STAY INFORMATION
---------------------------------
--dropping records where patients discharged to long term care, another facility, jail, etc.
DROP TABLE IF EXISTS #PDE_Daily_InpatientRecs_Stage;
SELECT AMADischarge
	,MVIPersonSID
	,Census
	,DisDay
	,DischargeDateTime
	,AdmitDateTime
	,POD
	,Exclusion30
	,RF_DisDay
	,Group2_High_Den
	,Group1_Low_Den
	,Group3_HRF
	,G1_MH
	,G1_NMH
	,MedicalService
	,Accommodation
	,Disch_BedSecn
	,Disch_BedSecName
	,DischBed_MH_Acute
	,DischBed_MH_Res
	,DischBed_NMH
	,Discharge_Sta6a
	,PrincipalDiagnosisICD10Desc
	,PrincipalDiagnosisICD10Code
	,AdmitDiagnosis
	,PostDisch_30days
	,PDE_GRP
	,HRF
	,G1_MH_Final
	,SUD_Dx
	,SUD_Dx_Label
	,Overdose_Dx
	,SI_Dx
	,SuicideRelated_Dx_Label
INTO #PDE_Daily_InpatientRecs_Stage
FROM #G1_MH_Final
WHERE PDE_GRP <> 0 AND (POD not in('0','1','2','3','4','5','7','9','A','B','C','D','J','K') or POD is NULL)

EXEC [Maintenance].[PublishTable] 'PDE_Daily.InpatientRecs', '#PDE_Daily_InpatientRecs_Stage'
EXEC [Log].[ExecutionEnd] --Part 1

/*********************************************************************************
 Step 5 - Pull outpatient visit information
 --Starting in Oct 2020, telephone visits with CPT codes 98966, 99441, 99211, or 99212 are excluded, unless the visit also has CPT code 90833, 90836, or 90838
*********************************************************************************/  


EXEC [Log].[ExecutionBegin] @Name = 'Code.PDE_PatientReport Part 2', @Description = 'PDE FollowUpMHVisits'

	DROP TABLE IF EXISTS #cohort;
	SELECT DISTINCT MVIPersonSID 
	INTO #cohort
	FROM [PDE_Daily].[InpatientRecs] WITH (NOLOCK)

	EXEC [Tool].[CIX_CompressTemp] '#Cohort','MVIPersonSID'
 
/*DECLARE  @todaysdate datetime =  getdate()
DECLARE  @END_dt     datetime  = DATEADD(day, DATEDIFF(day, 0, @TodaysDate), 0)       /*Sets date to midnight */ 
DECLARE  @Begin_dt   datetime  = DateAdd(day,-91, @END_dt)                           /*Begin date will be 90 days prior to pull date*/     
SET      @END_dt             = DATEADD(ms, -3, @END_dt)                              /*day before first day of pull date month */          
--*/

----VISTA VISITS
DROP TABLE IF EXISTS #workload;
SELECT DISTINCT
	pt.MVIPersonSID
	,ov.VisitDateTime
	,ov.VisitSID
	,ChecklistID = ISNULL(s.ChecklistID,ck.ChecklistID)
	,cl.StopCodeSID as PrimaryStopCodeSID
	,cl.StopCode AS cl
	,cl.StopCodeName AS ClName
	,clc.StopCode AS clc
	,clc.StopCodeName AS ClcName
	,ov.WorkloadLogicFlag
INTO #workload
FROM [Outpat].[Visit] ov WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	ON ov.PatientSID = mvi.PatientPersonSID
INNER JOIN #cohort pt WITH (NOLOCK)
	ON pt.MVIPersonSID = mvi.MVIPersonSID
LEFT JOIN [Lookup].[StopCode] clc WITH (NOLOCK)
	ON clc.StopCodeSID = ov.SecondaryStopCodeSID
LEFT JOIN [Lookup].[StopCode] cl WITH (NOLOCK)
	ON cl.StopCodeSID = ov.PrimaryStopCodeSID
LEFT JOIN [LookUp].[DivisionFacility] s WITH (NOLOCK)
	ON s.DivisionSID = ov.DivisionSID 
LEFT JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON 
	ck.Sta3n = ov.Sta3n 
	AND ck.Sta3nFlag = 1
WHERE ov.VisitDateTime BETWEEN @Begin_dt AND @END_dt 
	AND (cl.MHOC_MentalHealth_Stop = 1 OR cl.MHOC_Homeless_Stop = 1 OR clc.MHOC_MentalHealth_Stop = 1 OR clc.MHOC_Homeless_Stop = 1)

DELETE FROM #workload
WHERE clc = '697'

DROP TABLE IF EXISTS #outpats;
SELECT inp.MVIPersonSID
	  ,inp.PrincipalDiagnosisICD10Desc
	  ,inp.PrincipalDiagnosisICD10Code
	  ,inp.Discharge_Sta6a
	  ,AMADischarge   
	  ,Census            
	  ,DisDay
	  ,AdmitDateTime	
	  ,Exclusion30
	  ,Group3_HRF        
	  ,Group2_high_Den   
	  ,Group1_low_Den    
	  ,VisitDateTime
	  ,VisitSID
	  ,PrimaryStopCodeSID
	  ,cl
	  ,clname
	  ,clc
	  ,clcname
	  ,WorkloadLogicFlag
	  ,FollowUpDays=DateDiff(d,DisDay,VisitDateTime)
	  ,FollowUp=CASE WHEN (wk.VisitDateTime > inp.DischargeDateTime AND wk.VisitDateTime <= DateAdd(day,31,DisDay) AND AMADischarge=1) --RAS changed to dischargedate time and greater than
					OR (DateDiff(d,inp.DisDay,wk.VisitDateTime)>0 AND wk.VisitDateTime <= DateAdd(day,31,DisDay) AND AMADischarge=0) 
				THEN 1 ELSE 0 END      
INTO #outpats
FROM [PDE_Daily].[InpatientRecs] as inp WITH(NOLOCK)
LEFT JOIN #workload as wk
	ON  wk.MVIPersonSID=inp.MVIPersonSID 
	and wk.VisitDateTime>=inp.DisDay 
	and wk.VisitDateTime<= DateAdd(day,31,DisDay)
WHERE Census=0 --exclude current inpatients so IP workload does not appear as followup

/*keeping raw inpatient OP visit information.*/
--get cpt code sids for < 10 minute cpt code to exclude (effective as of 10/1)
	DROP TABLE IF EXISTS #cptexclude;
	SELECT CPTSID,CPTCode
	INTO #cptexclude
	FROM [LookUp].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('98966', '99441', '99211', '99212','98016')
	
	EXEC [Tool].[CIX_CompressTemp] '#cptexclude','cptsid'

--get cpt code sids for add-on codes that can be used with excluded CPT codes (effective as of 10/1)
	DROP TABLE IF EXISTS #cptinclude;
	SELECT CPTSID,CPTCode
	INTO #cptinclude
	FROM [LookUp].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('90833','90836','90838')

	EXEC [Tool].[CIX_CompressTemp] '#cptinclude','cptsid'

	DROP TABLE IF EXISTS #CPToutpat;
	SELECT DISTINCT v.VisitSID
		,i.CPTCode AS IncludeCPT
		,e.CPTCode AS ExcludeCPT
		,sc.Telephone_MH_Stop
		,CASE 
			WHEN sc.Telephone_MH_Stop=1 AND e.CPTCode='98016' THEN NULL --exclude all phone encounters with this CPT code regardless of any add-on codes
			WHEN sc.Telephone_MH_Stop=1 AND i.CPTSID IS NOT NULL 
				THEN i.CPTCode -- if one of these CPT codes is used, the visit counts even if an excluded code is also used
			WHEN sc.Telephone_MH_Stop=1 AND e.CPTSID IS NOT NULL 
				THEN NULL	--exclude visits with these CPT codes (unless they have one of the included codes accounted for above)
			ELSE 999999		--999999 => that there is no procedure code requirement 
		END AS CPTCode 
	INTO #CPToutpat
	FROM  [Outpat].[VProcedure] as v WITH(NOLOCK) --workloadVprocedure as v
	INNER JOIN #Outpats as o ON v.VisitSID=o.VisitSID
	INNER JOIN [Lookup].[StopCode] as sc WITH (NOLOCK) ON o.PrimaryStopCodeSID = sc.StopCodeSID
	LEFT JOIN (
		SELECT p.VisitSID, e.CPTSID, e.CPTCode 
		FROM #cptexclude AS e
		INNER JOIN [Outpat].[VProcedure] AS p WITH(NOLOCK) ON e.CPTSID=p.CPTSID
		) AS e ON v.VisitSID=e.VisitSID
	LEFT JOIN #cptinclude AS i ON i.CPTSID=v.CPTSID

--only allow these followups if they have a cpt code
	DROP TABLE IF EXISTS #VisitsVistA;
	SELECT MVIPersonSID
		  ,DisDay
		  ,Exclusion30
		  ,Group3_HRF
		  ,Group2_High_Den
		  ,Group1_Low_Den
		  ,Followup
		  ,FollowUpDays
		  ,VisitSID
		  ,Cl
		  ,Clc
		  ,Clname
		  ,Clcname
		  ,WorkloadLogicFlag
		  ,CAST(NULL AS VARCHAR) AS ActivityType
		  ,VisitDateTime=CASE WHEN FollowUp=1 THEN VisitDateTime ELSE NULL END
		  ,DropVisit
	INTO #VisitsVistA
	FROM (
		SELECT a.MVIPersonSID
			  ,a.DisDay
			  ,a.Census
			  ,a.PrincipalDiagnosisICD10Code
			  ,a.PrincipalDiagnosisICD10Desc
			  ,a.Discharge_Sta6a
			  ,a.Exclusion30
			  ,a.Group3_HRF
			  ,a.Group2_high_Den
			  ,a.Group1_low_Den
			  ,a.Followup
			  ,a.FollowUpDays
			  ,a.VisitSID
			  ,a.cl
			  ,a.clc
			  ,a.ClName
			  ,a.ClcName
			  ,a.WorkloadLogicFlag
			  ,VisitDateTime = 
				CASE
				WHEN a.cl in(527, 528, 530, 536, 537, 542,545, 546, 579, 584 , 597)
					AND b.CPTCode IS NULL THEN NULL
				ELSE a.VisitDateTime END 
			 ,CASE WHEN a.cl in(527, 528, 530, 536, 537, 542,545, 546, 579, 584 , 597)
					AND a.WorkloadLogicFlag='N' AND p.VisitSID IS NULL 
					THEN 1 ELSE 0 END AS DropVisit
		FROM #outpats as a
		LEFT JOIN #CPToutpat as b on a.VisitSID=b.VisitSID
		LEFT JOIN [Outpat].[VProcedure] as p WITH(NOLOCK) on a.VisitSID=p.VisitSID
	  ) AS X

	DELETE #VisitsVistA
	WHERE DropVisit=1

	EXEC [Tool].[CIX_CompressTemp] '#VisitsVistA','visitsid'
	
--CERNER VISITS
--DECLARE  @todaysdate datetime =  getdate()
--DECLARE  @END_dt     datetime  = DATEADD(day, DATEDIFF(day, 0, @TodaysDate), 0)       /*Sets date to midnight */ 
--DECLARE  @Begin_dt   datetime  = DateAdd(day,-91, @END_dt)                           /*Begin date will be 90 days prior to pull date*/     
--SET      @END_dt             = DATEADD(ms, -3, @END_dt)                              /*day before first day of pull date month */          


	DROP TABLE IF EXISTS #VisitsCerner;
	SELECT co.MVIPersonSID
		,co.DisDay
		,co.Exclusion30
		,co.Group3_HRF
		,co.Group2_High_Den
		,co.Group1_Low_Den
		,v.TZDerivedVisitDateTime AS VisitDateTime
		,v.EncounterSID AS VisitSID
		,CAST(NULL AS VARCHAR) AS Cl
		,CAST(NULL AS VARCHAR) AS ClName
		,CAST(NULL AS VARCHAR) AS Clc
		,CAST(NULL AS VARCHAR) AS ClcName
		,CAST('Y' AS VARCHAR) AS WorkloadLogicFlag
		,v.ActivityType
		,v.EncounterType --for validation
		,ce.CPTCode AS CPTExclude --for validation
		,ci.CPTCode AS CPTInclude --for validation
		,CASE WHEN v.EncounterType='Telephone' AND ce.CPTCode='98016' THEN NULL --exclude all phone encounters with this CPT code regardless of any add-on codes
			WHEN v.EncounterType='Telephone' AND ci.CPTSID IS NOT NULL THEN ci.CPTCode
			WHEN v.EncounterType='Telephone' AND ce.CPTSID IS NOT NULL THEN NULL
			WHEN ce.CPTCode IN ('98966','99441') AND ci.CPTCode IS NULL THEN NULL --telephone CPT codes, may have been used in non-telephone encounter types before Telephone encounter type existed
			ELSE 999999		--999999 => that there is no procedure code requirement
			END AS CPTCode 
		,FollowUpDays=DateDiff(d,DisDay,v.TZDerivedVisitDateTime )
		,FollowUp=CASE WHEN (v.TZDerivedVisitDateTime > co.Disday AND v.TZDerivedVisitDateTime <= DateAdd(day,31,DisDay) AND AMADischarge=1) --RAS changed to dischargedate time and greater than
					OR (DateDiff(d,DisDay,v.TZDerivedVisitDateTime)>0 AND v.TZDerivedVisitDateTime <= DateAdd(day,31,DisDay) AND AMADischarge=0) 
				THEN 1 ELSE 0 END  
		 INTO #VisitsCerner
	FROM [Cerner].[FactUtilizationOutpatient] AS v WITH(NOLOCK)
	INNER JOIN [PDE_Daily].[InpatientRecs] AS co WITH(NOLOCK)
		ON co.MVIPersonSID=v.MVIPersonSID 
		AND v.TZDerivedVisitDateTime > co.DisDay
	-- Get mental health encounters from activity type
	INNER JOIN [LookUp].[ListMember] AS lm WITH(NOLOCK) 
		ON v.ActivityTypeCodeValueSID=lm.ItemID
	-- then get all procedure codes related to that encounter
	--INNER JOIN [Cerner].[FactProcedure] as p WITH(NOLOCK) 
	--	ON v.EncounterSID=p.EncounterSID
	-- and check if those procedure codes are included or excluded from qualifying telephone
	LEFT JOIN (
		SELECT DISTINCT  
			p.EncounterSID
			,p.EncounterType
			,CASE WHEN EncounterTypeClass = 'Recurring' OR EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
			,i.CPTCode
			,i.CPTSID 
		FROM #cptinclude AS i
		INNER JOIN [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
			ON i.CPTSID = p.NomenclatureSID
			AND p.SourceVocabulary = 'CPT4'
		) ci ON v.EncounterSID = ci.EncounterSID AND (ci.TZDerivedProcedureDateTime IS NULL OR ci.TZDerivedProcedureDateTime = v.TZDerivedVisitDateTime)
	LEFT JOIN (
		SELECT DISTINCT  
			p.EncounterSID
			,p.EncounterType
			,CASE WHEN EncounterTypeClass = 'Recurring' OR EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
			,e.CPTCode
			,e.CPTSID 
		FROM #cptexclude AS e
		INNER JOIN [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
			ON e.CPTSID = p.NomenclatureSID
			AND p.SourceVocabulary = 'CPT4'
		) AS ce ON v.EncounterSID = ce.EncounterSID  AND (ce.TZDerivedProcedureDateTime IS NULL OR ce.TZDerivedProcedureDateTime = v.TZDerivedVisitDateTime)
	INNER JOIN [Cerner].[DimLocations] as cg WITH(NOLOCK) ON 
		v.OrganizationNameSID = cg.OrganizationNameSID
		AND v.TZDerivedVisitDateTime >= cg.IOCDate
	WHERE  1=1
		AND	(v.TZDerivedVisitDateTime >= co.DisDay 
		AND v.TZDerivedVisitDateTime <= DateAdd(day,31,co.DisDay))
		AND lm.Domain='ActivityType' 
		AND lm.List IN ('MHOC_MH','MHOC_Homeless')  
	;		

	DELETE #VisitsCerner WHERE CPTcode IS NULL;

---------------------------------
 --ADD PROVIDER INFORMATION
---------------------------------
/*DECLARE  @todaysdate datetime =  getdate()
DECLARE  @END_dt     datetime  = DATEADD(day, DATEDIFF(day, 0, @TodaysDate), 0)       /*Sets date to midnight */ 
DECLARE  @Begin_dt   datetime  = DateAdd(day,-91, @END_dt)                           /*Begin date will be 90 days prior to pull date*/     
SET      @END_dt             = DATEADD(ms, -3, @END_dt)                              /*day before first day of pull date month */          
--*/

DROP TABLE IF EXISTS #oprecs;
SELECT * 
INTO #oprecs
FROM (
	SELECT DISTINCT 
		a.MVIPersonSID
		,a.DisDay
		,a.Exclusion30
		,a.Group3_HRF
		,a.Group2_High_Den
		,a.Group1_Low_Den
		,a.VisitDateTime
		,a.VisitSID
		,a.Cl
		,a.Clname
		,a.Clc
		,a.Clcname
		,a.WorkloadLogicFlag
		,a.FollowUpDays
		,a.FollowUp
		,pt.ProviderType
		,ss.StaffName AS ProviderName
		,pr.ProviderSID
	FROM #VisitsVistA AS a 
	LEFT JOIN [Outpat].[VProvider] as pr WITH (NOLOCK)
		ON a.VisitSID = pr.VisitSID 
	LEFT JOIN [Dim].[ProviderType] as pt WITH (NOLOCK)
		ON pt.ProviderTypeSID = pr.ProviderTypeSID
	LEFT JOIN  [SStaff].[SStaff] as ss WITH (NOLOCK)
		ON pr.ProviderSID=ss.StaffSID
	
	UNION ALL
	
	SELECT DISTINCT 
		v.MVIPersonSID
		,v.DisDay
		,v.Exclusion30
		,v.Group3_HRF
		,v.Group2_High_Den
		,v.Group1_Low_Den
		,v.VisitDateTime
		,v.VisitSID
		,v.cl
		,v.ActivityType AS Clname
		,v.Clc
		,v.Clcname
		,v.WorkloadLogicFlag
		,v.FollowUpDays
		,v.FollowUp
		,p.PositionTask AS ProviderType 
		,p.NameFullFormatted AS ProviderName
		,p.PersonStaffSID AS ProviderSID
    FROM #VisitsCerner v 
	LEFT JOIN [Cerner].[FactUtilizationOutpatient] o WITH (NOLOCK)
		ON v.VisitSID = o.EncounterSID 
		AND v.VisitDateTime = o.TZDerivedVisitDateTime
	LEFT JOIN [Cerner].[FactStaffDemographic] p WITH (NOLOCK) 
		ON o.DerivedPersonStaffSID = p.PersonStaffSID
	) AS U

/*********************************************************************************
 Step 6 - ID PDE met/not met records. Create permanent pde pt level and visit level information. 
*********************************************************************************/  
--Include census pts and add appointment information (when available) for those with census = 0 and followup = 0
DROP TABLE IF EXISTS #visitcount;
SELECT MVIPersonSID
      ,DisDay
	  ,Exclusion30		=MAX(Exclusion30)			   
	  ,Group3_HRF		=CASE WHEN MAX(Group3_HRF) =  1 THEN 1 ELSE 0 END
	  ,Group2_High_Den	=CASE WHEN MAX(Group3_HRF) <> 1 AND MAX(Group2_High_Den)=1 THEN 1 ELSE 0 END
	  ,Group1_Low_Den	=CASE WHEN MAX(GRoup3_HRF) <> 1 and MAX(Group2_High_Den) <> 1 AND MAX(Group1_Low_Den )=1 THEN 1 ELSE 0 END
	  ,VisitCount		=COUNT(DISTINCT CAST(VisitDateTime AS DATE))
INTO #visitcount
FROM #oprecs 
WHERE WorkloadLogicFlag='Y'
GROUP BY MVIPersonSID, DisDay  

DROP TABLE IF EXISTS #visittotal;
SELECT MVIPersonSID
	  ,DisDay
	  ,Exclusion30
	  ,Group3_HRF
	  ,Group2_High_Den
	  ,Group1_Low_Den
	  ,VisitCount
	  ,NumberOfMentalHealthVisits = CASE WHEN VisitCount > 0 THEN VisitCount ELSE 0 END  
INTO #visittotal
FROM #visitcount

--ADDING COUNTS FOR VISITS NOT MEETING WORKLOAD CRITERIA
DROP TABLE IF EXISTS #noncount;
SELECT MVIPersonSID
      ,DisDay
	  ,NonCountTotal=Count(DISTINCT Cast(VisitDateTime AS DATE))
INTO #noncount
FROM #oprecs where WorkloadLogicFlag<>'Y' 
GROUP BY MVIPersonSID,DisDay ; 

DROP TABLE IF EXISTS #noncounttotal;
SELECT MVIPersonSID
	  ,DisDay
	  ,NonCountTotal
	  ,CASE WHEN NonCountTotal > 0 
			THEN NonCountTotal ELSE 0 
			END as NonCountVisits
INTO #noncounttotal
FROM #noncount

DROP TABLE IF EXISTS #pde1_ind;
SELECT Exclusion30 
	  ,MVIPersonSID
	  ,DisDay
	  ,Group1_Low_Den
	  ,Group2_High_Den
	  ,Group3_HRF
	  ,NumberOfMentalHealthVisits
	  ,NonCountVisits
	  ,PDE1 
	  ,ExcludeRuleVSSC
INTO #PDE1_ind
FROM (
	SELECT Exclusion30 
		  ,MVIPersonSID
		  ,DisDay
		  ,Group1_Low_Den
		  ,Group2_High_Den
		  ,Group3_HRF
		  ,NumberOfMentalHealthVisits
		  ,NonCountVisits
		  ,PDE1 
		  ,ExcludeRuleVSSC=CASE WHEN PDE1 <> 1 THEN Exclusion30 ELSE 0 END
	FROM (
		SELECT Exclusion30 
			  ,o.MVIPersonSID
			  ,o.DisDay
			  ,Group1_Low_Den
			  ,Group2_High_Den
			  ,Group3_HRF
			  ,NumberOfMentalHealthVisits
			  ,NonCountVisits
			  ,PDE1 = CASE 
						WHEN Group1_Low_Den=1  AND NumberofMentalHealthVisits >=2 
						  OR Group2_High_Den=1 AND NumberofMentalHealthVisits >=3 
						  OR Group3_HRF=1     AND NumberofMentalHealthVisits >=4 
						THEN 1 ELSE 0 END
		  FROM #visittotal as o
		  LEFT JOIN #noncounttotal as n on 
			n.MVIPersonSID=o.MVIPersonSID 
			AND o.DisDay=n.DisDay
		  WHERE (Group1_Low_Den=1 or Group2_High_Den=1 or Group3_HRF=1) 
		) AS ss 
	) AS s
WHERE ExcludeRuleVSSC <>1 --get rid of about 30 episodes that are within 30 days of next as long as they don't meet the measure 

---------------------------------
 --CREATE PERMANENT MH VISIT FILE FOR PDE DAILY DASHBOARD
---------------------------------
DROP TABLE IF EXISTS #PDE_Daily_PDE_FollowUpMHVisits_Stage
SELECT a.MVIPersonSID
	,a.DisDay
	,a.Exclusion30
	,a.Group3_HRF
	,a.Group2_High_Den
	,a.Group1_Low_Den
	,a.Followup
	,a.FollowUpDays
	,a.VisitSID
	,a.Cl
	,a.Clc
	,a.Clname
	,a.Clcname
	,a.WorkloadLogicFlag
	,a.VisitDateTime
	,a.ProviderType
	,a.ProviderName
	,b.ExcludeRuleVSSC
	,b.NumberOfMentalHealthVisits
	,b.NonCountVisits
	,b.PDE1
	,a.ProviderSID
INTO #PDE_Daily_PDE_FollowUpMHVisits_Stage
FROM #PDE1_ind as b 
LEFT JOIN #oprecs as a 
	ON a.MVIPersonSID = b.MVIPersonSID 
	AND a.DisDay = b.DisDay
WHERE a.VisitDateTime IS NOT NULL;

EXEC [Maintenance].[PublishTable] 'PDE_Daily.PDE_FollowUpMHVisits', '#PDE_Daily_PDE_FollowUpMHVisits_Stage'
EXEC [Log].[ExecutionEnd] --Part 2

	/* Something to think about for later:
	--or sub report from the followup visit table?
	---------------------------------
	--VISIT DISTRIBUTION
	---------------------------------
		IF Object_Id('tempdb..#weeklycount') IS NOT NULL DROP TABLE #weeklycount

		Select MVIPersonSID,DisDay,Week1Count=sum(Week1Count),Week2Count=sum(Week2Count)
			  ,Week3Count=sum(Week3Count),Week4Count=sum(Week4Count)
		INTO #weeklycount
		FROM (
			SELECT DISTINCT MVIPersonSID,DisDay,cast(VisitDateTime as date) as VisitDate
			,Week1Count=case when VisitDateTime between DateAdd(d,1,DisDay) and DateAdd(d,7,DisDay) 
				then 1 else 0 end 
			,Week2Count=case when VisitDateTime between DateAdd(d,8,DisDay) and DateAdd(d,14,DisDay) 
				then 1 else 0 end 
			,Week3Count=case when VisitDateTime between DateAdd(d,15,DisDay) and DateAdd(d,21,DisDay) 
				then 1 else 0 end 
			,Week4Count=case when VisitDateTime between DateAdd(d,22,DisDay) and DateAdd(d,30,DisDay) 
				then 1 else 0 end 
			FROM PDE_Daily.PDE_FollowUpMHVisits --#outpatwithcpt
		  ) as a
		GROUP BY MVIPersonSID,DisDay
	*/
---------------------------------
--FUTURE APPOINTMENT INFORMATION
---------------------------------
	EXEC [Log].[ExecutionBegin] @Name = 'Code.PDE_PatientReport Part 3', @Description = 'PDE Final PatientLevel Table'

/*DECLARE  @todaysdate datetime =  getdate()
DECLARE  @END_dt     datetime  = DATEADD(day, DATEDIFF(day, 0, @TodaysDate), 0)       /*Sets date to midnight */ 
DECLARE  @Begin_dt   datetime  = DateAdd(day,-91, @END_dt)                           /*Begin date will be 90 days prior to pull date*/     
SET      @END_dt             = DATEADD(ms, -3, @END_dt)                              /*day before first day of pull date month */          
--*/

	--VISTA
	DROP TABLE IF EXISTS #PDE_ptlevel;
	SELECT fi.*
		  ,NumberOfMentalHealthVisits=
				CASE WHEN B.NumberOfMentalHealthVisits is null 
					 THEN 0 
					 ELSE b.NumberOfMentalHealthVisits 
				END
		  ,B.PDE1
		  ,B.Group1_low_den as PDE1_GRP1
		  ,B.Group2_High_den as PDE1_GRP2
		  ,B.Group3_HRF as PDE1_GRP3
	INTO #PDE_ptlevel
	FROM [PDE_Daily].[InpatientRecs] as fi WITH (NOLOCK)
	LEFT JOIN #PDE1_ind as B on 
		fi.MVIPersonSID = b.MVIPersonSID 
		AND fi.DisDay = b.DisDay  

 	DROP TABLE IF EXISTS #appt;
	SELECT DISTINCT 
		 pt.MVIPersonSID
		,pt.DisDay
		,appt.AppointmentDateTime
		,loc.LocationName
		,loc.LocationType
		,s.Facility AS ApptFacility
		,s.DivisionName AS ApptDivision
		,psc.StopCode AS PrimaryStopCode
		,psc.StopCodeName AS P_StopCodeName
		,ssc.StopCode AS SecondaryStopCode
		,ssc.StopCodeName AS S_StopCodeName
		,appt.AppointmentSID
		,appt.AppointmentStatus
	INTO #appt
	FROM #PDE_ptlevel pt
	INNER JOIN ([Appt].[Appointment] appt WITH (NOLOCK)
				INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
					ON appt.PatientSID = mvi.PatientPersonSID)
		ON pt.MVIPersonSID = mvi.MVIPersonSID 
			AND appt.AppointmentDateTime >= @END_dt 
	LEFT JOIN [Dim].[Location] loc WITH (NOLOCK)
		ON loc.LocationSID = appt.LocationSID
	LEFT JOIN [Dim].[Division] div WITH (NOLOCK)
		ON div.DivisionSID = loc.DivisionSID
	LEFT JOIN [LookUp].[DivisionFacility] s WITH (NOLOCK)
		ON s.Sta6a = div.Sta6a
	LEFT JOIN [Lookup].[StopCode] psc WITH (NOLOCK)
		ON loc.PrimaryStopCodeSID = psc.StopCodeSID
	LEFT JOIN [Lookup].[StopCode] ssc WITH (NOLOCK)
		ON loc.SecondaryStopCodeSID = ssc.StopCodeSID
	WHERE (	
		appt.AppointmentStatus IS NULL 
		OR (
			appt.AppointmentStatus NOT IN  ('C','CA','DEL','I','N','NA','NC','PC','PCA')
			)	
		)
		AND (
			psc.MHOC_MentalHealth_Stop = 1 OR psc.MHOC_Homeless_Stop = 1 OR ssc.MHOC_MentalHealth_Stop = 1 OR ssc.MHOC_Homeless_Stop = 1
			)
		;

	DROP TABLE IF EXISTS #MillAppt;
	SELECT DISTINCT 
		 c.MVIPersonSID
		,DisDay
		,appt.PersonSID
		,appt.TZBeginDateTime AS AppointmentDateTime
		,appt.ScheduleState
		,appt.StaPa -- checklistID
		,appt.Sta6a -- sta6aid
		,CASE 
			WHEN ScheduleState <> 'Canceled' AND TZBeginDateTime >= GETDATE() THEN 'FUT'
			WHEN ScheduleState = 'No Show' THEN 'N'
			WHEN ScheduleState = 'Checked Out' THEN 'CO'
			WHEN ScheduleState = 'Checked In' THEN 'CI'
			WHEN ScheduleState = 'Canceled' THEN 'C'
		END AS AppointmentStatusAbbrv
		,CancelTiming=DateDiff(d,appt.TZBeginDateTime,appt.TZDerivedCancelDateTime)
		,CancelDateTime = appt.TZDerivedCancelDateTime
		,appt.DerivedCancelReason as CancelReason
		,appt.EncounterType
		,appt.EncounterTypeClass
		,appt.EncounterSID
		,appt.DerivedActivityType
		,appt.OrganizationNameSID AS DivisionSID
		,appt.AppointmentType
		,s.Facility AS ApptFacility
		,s.DivisionName AS ApptDivision
	INTO #MillAppt
	FROM #PDE_ptlevel as c
	INNER JOIN [Cerner].[FactAppointment] appt WITH (NOLOCK) 
		ON appt.MVIPersonSID = c.MVIPersonSID 
	LEFT JOIN (
		SELECT DISTINCT AttributeValue
		FROM [Lookup].[ListMember] WITH (NOLOCK) 
		WHERE Domain = 'ActivityType'
			AND List IN ('MHOC_MH','MHOC_Homeless') 
		) lm ON appt.DerivedActivityType = lm.AttributeValue 
	INNER JOIN [Cerner].[DimLocations] i WITH (NOLOCK) 
		ON appt.OrganizationNameSID = i.OrganizationNameSID
		AND appt.TZBeginDateTime >= i.IOCDate
	LEFT JOIN [LookUp].[DivisionFacility] s WITH (NOLOCK) 
		ON s.Sta6a = appt.Sta6a
	WHERE appt.TZBeginDateTime >= @END_dt
		AND ScheduleState not like '%Canceled%'
		AND (
			lm.AttributeValue IS NOT NULL --For cancelled past visits -- should add equivalent stop code 156, 157 when it becomes available
			OR appt.AppointmentType LIKE 'MH%'--use appointmenttype for future appts/no-shows since there is no activity type? Guessing on this for now.
			)
	;

	DROP TABLE IF EXISTS #CombinedAppts;
	SELECT MVIPersonSID
		,DisDay
		,AppointmentDateTime
		,LocationName
		,LocationType
		,ApptFacility
		,ApptDivision
		,PrimaryStopCode
		,P_StopCodeName
		,SecondaryStopCode
		,S_StopCodeName
		,AppointmentSID
	INTO #CombinedAppts
	FROM #appt
	
	UNION ALL
	
	SELECT MVIPersonSID
		,DisDay
		,AppointmentDateTime
		,AppointmentType AS LocationName
		,EncounterType as LocationType
		,ApptFacility
		,ApptDivision
		,CAST(NULL AS VARCHAR) AS PrimaryStopCode
		,DerivedActivityType AS P_StopCodeName
		,CAST(NULL AS VARCHAR) AS SecondaryStopCode
		,CAST(NULL AS VARCHAR) AS S_StopCodeName
		,EncounterSID AS AppointmentSID
	FROM #MillAppt
	;

---------------------------------
--FIRST, LAST, AND NEXT APPTS
---------------------------------
	DROP TABLE IF EXISTS #nextappt;
	SELECT MVIPersonSID
		,DisDay
		,AppointmentDateTime
		,rownum
	INTO #nextappt
	FROM (
		SELECT MVIPersonSID
			  ,DisDay
			  ,AppointmentDateTime
			  ,rownum=row_number() OVER(PARTITION BY MVIPersonSID,DisDay ORDER BY AppointmentDateTime,AppointmentSID) 
		FROM #CombinedAppts
		) as a
	WHERE rownum = 1

	DROP TABLE IF EXISTS #PDE_ptlevel2;
	SELECT a.*
		  ,b.AppointmentDateTime as FutureApptDate
	INTO #PDE_ptlevel2
	FROM #PDE_ptlevel as a
	LEFT JOIN #nextappt as b
		on a.MVIPersonSID = b.MVIPersonSID 
		and a.DisDay = b.DisDay  

	DROP TABLE IF EXISTS #firstvisit;
	SELECT * 
	INTO #firstvisit
	FROM (
		SELECT MVIPersonSID
			  ,DisDay
			  ,VisitDateTime as FirstVisitDateTime
			  ,Cl as firstCl
			  ,ClName as firstClName
			  ,Clc as firstClc
			  ,ClcName as firstClcName
			  ,ProviderName as FirstProviderName
			  ,RN=Row_number() OVER(PARTITION BY MVIPersonSID,DisDay ORDER BY VisitDateTime,VisitSID,ProviderSID)
		FROM [PDE_Daily].[PDE_FollowUpMHVisits] WITH (NOLOCK)
		WHERE WorkloadLogicFlag='Y' 
		) as a
	WHERE RN=1 

	DROP TABLE IF EXISTS #lastvisit;
	SELECT * 
	INTO #lastvisit
	FROM (
		SELECT MVIPersonSID
			  ,DisDay
			  ,VisitDateTime as LastVisitDateTime
			  ,Cl as LastCl
			  ,ClName as LastClName
			  ,Clc as LastClc
			  ,ClcName as LastClcName
			  ,ProviderName as LastProviderName
			  ,RN=Row_number() OVER(PARTITION BY MVIPersonSID,DisDay ORDER BY VisitDateTime DESC,VisitSID DESC,ProviderSID DESC)
		FROM [PDE_Daily].[PDE_FollowUpMHVisits] WITH (NOLOCK)
		WHERE WorkloadLogicFlag='Y' 
		) as a
	WHERE RN=1
;

	DROP TABLE IF EXISTS #noncountsum;
	SELECT MVIPersonSID
		  ,DisDay
		  ,COUNT(DISTINCT CAST(VisitDateTime AS DATE)) as NonCountSum
	INTO #noncountsum
	FROM [PDE_Daily].[PDE_FollowUpMHVisits] WITH (NOLOCK)
	WHERE WorkloadLogicFlag<>'Y' and FollowUp=1
	GROUP BY MVIPersonSID,DisDay
;
---------------------------------
--REMAINING APPTS
---------------------------------

	--# of appts scheduled in the remaining actionable period
	DROP TABLE IF EXISTS #remain_appt;
	SELECT MVIPersonSID
		,DisDay
		,AppointmentSID
		,AppointmentDateTime
		,AppointmentDate = CAST(AppointmentDateTime AS DATE)
		,LocationName
		,ApptFacility
		,ApptDivision
		,PrimaryStopCode
		,P_StopCodeName
		,SecondaryStopCode
		,S_StopCodeName
		,RowNum=row_number() OVER(PARTITION BY MVIPersonSID,DisDay ORDER BY AppointmentDateTime) 
	INTO #remain_appt
	FROM #CombinedAppts
	WHERE CAST(AppointmentDateTime AS DATE)>=CAST(GETDATE() AS DATE) AND CAST(AppointmentDateTime AS DATE)<= DATEADD(Day,30,DisDay)
;

	DROP TABLE IF EXISTS #remain_appt_sum;
	SELECT MVIPersonSID
		,DisDay
		,ApptDays = COUNT(DISTINCT AppointmentDate)
	INTO #remain_appt_sum
	FROM #remain_appt
	GROUP BY MVIPersonSID, DisDay
;

EXEC [Maintenance].[PublishTable] 'PDE_Daily.FutureAppts', '#remain_appt'

---------------------------------
--ADD IN ALL APPT DETAILS TO PATIENT LEVEL TABLE
---------------------------------
DROP TABLE IF EXISTS #PDE_ptlevel3;
SELECT a.*
	  ,FirstVisitDateTime
	  ,FirstCL
	  ,FirstClName
	  ,FirstClc
	  ,FirstClcName
	  ,FirstProviderName
	  ,LastVisitDateTime
	  ,LastCL
	  ,LastClName
	  ,LastClc
	  ,LastClcName
	  ,LastProviderName
	  ,NonCountSum
	  ,ApptDays = ISNULL(r.ApptDays,0)
INTO #PDE_ptlevel3
FROM #PDE_ptlevel2 as a
LEFT JOIN #firstvisit as b on a.MVIPersonSID = b.MVIPersonSID 
	AND a.DisDay = b.DisDay  
LEFT JOIN #lastvisit as c on a.MVIPersonSID = c.MVIPersonSID 
	AND a.DisDay = c.DisDay  
LEFT JOIN #noncountsum as n on a.MVIPersonSID = n.MVIPersonSID 
	AND a.DisDay = n.DisDay  
LEFT JOIN #remain_appt_sum as r on a.MVIPersonSID = r.MVIPersonSID 
	AND a.DisDay = r.DisDay  
--LEFT JOIN #weeklycount as w on a.MVIPersonSID = w.MVIPersonSID and a.DisDay = w.DisDay  

/*********************************************************************************
 Step 7 - Add homestation information and provider info
*********************************************************************************/  
---------------------------------
 --QUARTERLY MH TREATMENT FACILITY (METRIC HOMESTATION)
---------------------------------
--This is the facililty assigned as homestation AT THE BEGINNING of the discharge FYQ
	
	--create cohort list with FYQ to match to quarterly station
	DROP TABLE IF EXISTS #quarter;	
	SELECT * 
		  ,DischargeFYQ=
			CONCAT(LEFT(FYM,4),'Q',(CASE WHEN month(DisDay) in (10,11,12) THEN 1
				WHEN month(DisDay) in (1,2,3) THEN 2
				WHEN month(DisDay) in (4,5,6) THEN 3
				WHEN month(DisDay) in (7,8,9) THEN 4
				END))
	INTO #quarter 
	FROM (
		SELECT MVIPersonSID
			  ,DisDay
			  ,DischargeDateTime
			  ,Discharge_Sta6a
			  ,FYM=CONCAT('FY',CASE WHEN month(DisDay)>9 THEN right(year(DisDay),2)+1 
				ELSE right(year(DisDay),2) 
				END,'M', CASE WHEN month(DisDay)>9 THEN month(DisDay)-9 
				ELSE month(DisDay)+3 END)
		FROM #PDE_ptlevel3 
		) as a

	DROP TABLE IF EXISTS #metric;	
	SELECT q.MVIPersonSID
		  ,DisDay
		  ,DischargeDateTime
		  ,Discharge_Sta6a
		  ,hq.ChecklistID as ChecklistID_Metric
		  ,hq.UpdateDate as MetricHomeUpdate
		  ,c.Facility as Facility_Metric
		  ,q.DischargeFYQ
	INTO #metric
	FROM #quarter as q
	INNER JOIN [Present].[HomestationQuarterly] as hq  WITH (NOLOCK)
		ON hq.MVIPersonSID=q.MVIPersonSID 
		and hq.FYQ=q.DischargeFYQ
	INNER JOIN [Lookup].[ChecklistID] as c  WITH (NOLOCK)
	ON c.ChecklistID=hq.ChecklistID
	;
---------------------------------
 --CURRENT MH TREATMENT FACILITY (MONTHLY HOMESTATION)
---------------------------------
--This is the facility assigned as homestation AS OF THE CURRENT MONTH
	DROP TABLE IF EXISTS #home;	
	SELECT DISTINCT 
		 cohort.MVIPersonSID
		,h.Checklistid as ChecklistID_Home
		,c.Facility as Facility_Home
	INTO #home
	FROM [Present].[HomestationMonthly] as h WITH (NOLOCK)
	INNER JOIN #cohort as cohort 
	ON cohort.MVIPersonSID=h.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] as c WITH (NOLOCK)
	ON c.ChecklistID=h.ChecklistID
	;
---------------------------------
 --PCP (MOST RECENT)
---------------------------------
	DROP TABLE IF EXISTS #PCP;
	SELECT cohort.MVIPersonSID
		  ,pcp.StaffName as StaffName_PCP
		  ,pcp.DivisionName as DivisionName_PCP
		  ,pcp.ChecklistID as ChecklistID_PCP
	INTO #PCP
	FROM #cohort as cohort 
	INNER JOIN [Present].[Provider_PCP_ICN] as pcp on pcp.MVIPersonSID=cohort.MVIPersonSID
	;
---------------------------------
 --MHTC (MOST RECENT)
---------------------------------
	DROP TABLE IF EXISTS #mhtc;
	SELECT cohort.MVIPersonSID
		  ,mhtc.StaffName as StaffName_MHTC
		  ,CASE WHEN mhtc.ProviderSID IS NULL THEN mhtc.ProviderEDIPI ELSE mhtc.ProviderSID END as ProviderSID_MHTC
		  ,DivisionName as DivisionName_MHTC
		  ,ChecklistId as ChecklistID_MHTC
	INTO #mhtc
	FROM #cohort as cohort 
	INNER JOIN [Present].[Provider_MHTC_ICN] as mhtc on mhtc.MVIPersonSID=cohort.MVIPersonSID
	;

---------------------------------
 --BHIP (MOST RECENT)
---------------------------------

	DROP TABLE IF EXISTS #bhip_all;
	SELECT cohort.MVIPersonSID
		  ,bhip.Team as TeamName_BHIP
		  ,bhip.TeamSID as TeamSID_BHIP
		  ,bhip.RelationshipStartDate as RelationshipStartDate
		  ,DivisionName as DivisionName_BHIP
		  ,ChecklistId as ChecklistID_BHIP
	INTO #bhip_all
	FROM #cohort as cohort 
	INNER JOIN [Present].[Provider_MHTeam] as bhip on bhip.MVIPersonSID=cohort.MVIPersonSID
	;

	DROP TABLE IF EXISTS #bhip;
	WITH ranked_bhip AS (
	SELECT m.MVIpersonSID,m.TeamName_BHIP,m.TeamSID_BHIP,m.RelationshipStartDate,m.DivisionName_BHIP,m.ChecklistID_BHIP,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY RelationshipStartDate DESC) AS rn
	FROM 	#bhip_all AS m
	)
	SELECT MVIPersonSID
		  ,TeamName_BHIP
		  ,TeamSID_BHIP
		  ,DivisionName_BHIP
		  ,ChecklistID_BHIP
	INTO #bhip
	FROM ranked_bhip WHERE rn = 1;
	
---------------------------------
 --COMBINE ALL DEMOGRAPHICS ETC.
---------------------------------
DROP TABLE IF EXISTS #DemosStations;
SELECT DISTINCT 
	 a.*
	,PDE1_Met=CASE WHEN PDE1=1 then 1
		WHEN PDE1=0 then 0
		WHEN PDE1 is null and census=1 then 3 
		ELSE NULL 
		END
	,NumberOfVisits=ISNULL(NumberOfMentalHealthVisits,0)
	,Facility as Facility_Discharge
	,ChecklistID as ChecklistID_Discharge
	,ChecklistID_Metric
	,Facility_Metric=CASE WHEN ChecklistID_Metric is null THEN 'Unassigned as of beginning of the FYQ'
						  ELSE Facility_Metric END
	,MetricHomeUpdate = cast(NULL as date)
	,ChecklistID_Home
	,Facility_Home
	,StaffName_MHTC = CASE WHEN m.StaffName_MHTC IS NULL THEN '*No MHTC Assigned' ELSE m.StaffName_MHTC END
	,ProviderSID_MHTC = CASE WHEN m.ProviderSID_MHTC IS NULL THEN '-1' ELSE m.ProviderSID_MHTC END
	,DivisionName_MHTC
	,ChecklistID_MHTC
	,StaffName_PCP
	,DivisionName_PCP
	,ChecklistID_PCP
	,TeamName_BHIP = CASE WHEN b.TeamName_BHIP IS NULL THEN '*No MH Team Assigned' ELSE b.TeamName_BHIP END
	,TeamSID_BHIP = CASE WHEN b.TeamSID_BHIP IS NULL THEN '-1' ELSE b.TeamSID_BHIP END
	,DivisionName_BHIP
	,ChecklistID_BHIP
	,PatientRecordFlagHistoryAction=ActionType
	,ActionDateTime as HRF_ActionDate
INTO #DemosStations 
FROM #PDE_ptlevel3 as a
LEFT JOIN #pcp as p on p.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #mhtc as m on m.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #bhip as b on b.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #home as h on h.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #metric as q 
	on q.MVIPersonSID=a.MVIPersonSID
	AND q.DisDay=a.DisDay 
	AND q.Discharge_Sta6a=a.Discharge_Sta6a
LEFT JOIN (
	SELECT MVIPersonSID,EntryCountDesc,ActionType,ActionDateTime
	FROM [OMHSP_Standard].[PRF_HRS_CompleteHistory]  WITH (NOLOCK)
	WHERE EntryCountDesc=1
	) as rf on rf.MVIPersonSID=a.MVIPersonSID
LEFT JOIN [LookUp].[DivisionFacility] as d  WITH (NOLOCK)
ON d.Sta6a=a.Discharge_Sta6a
;  
--UPDATE #DemosStations
--SET NumberOfMentalHealthVisits=NumberOfVisits;
--ALTER TABLE #DemoStations
--DROP NumberOfVisits
;  
/*********************************************************************************
 Step 8 - Calculate visits required and needed to meet measure, compile final table
*********************************************************************************/  
DROP TABLE IF EXISTS #PDE_patientlevel;	
SELECT a.*
	 -- ,case when census = 1 then 3
		--when census = 0 and (NumberOfMentalHealthVisits = 0 or NumberofMentalHealthVisits is null) then 2
		--when census = 0 and NumberOfMentalHealthVisits > 0 then 1
		--else null end as Pt_Status
	  ,case when PDE_GRP = 1 then 2
		when PDE_GRP = 2 then 3
		when PDE_GRP = 3 then 4
		else null
		end as RNTMM
 INTO #PDE_patientlevel
 FROM #DemosStations as a  

 --Visits Needed to Meet Measure  
 DROP TABLE IF EXISTS #PDE_patientlevel2;
 SELECT *
	  ,case when PDE1_Met = 1 then 0
            when PDE1_Met = 0 then (RNTMM-(NumberOfMentalHealthVisits))
			else null
			end as VNTMM
	  --,case when pt_status =1 and PDE1 = 1 then 0
   --         when pt_status = 1 and PDE1 = 0 then (RNTMM-(NumberOfMentalHealthVisits))
			--when pt_status = 2 then (RNTMM)
			--else null
			--end as VNTMM
			, GETDATE() AS UpdateDate
  INTO #PDE_patientlevel2
  FROM #PDE_patientlevel

EXEC [Maintenance].[PublishTable] 'PDE_Daily.PDE_PatientLevel', '#PDE_patientlevel2'

--TEMPORARY FIX - NEED TO GO BACK AND MAKE SURE NO NULL VALUES FOR PDE1
UPDATE [PDE_Daily].[PDE_PatientLevel] 
SET VNTMM=RNTMM-NumberOfMentalHealthVisits
WHERE vntmm is null;

UPDATE [PDE_Daily].[PDE_PatientLevel]
SET PDE1=
	CASE WHEN DischargeDateTime is null OR DischargeDateTime > getdate() THEN 3
		 WHEN VNTMM <= 0 THEN 1
		 ELSE 0 END

	EXEC [Log].[ExecutionEnd] --Part 3 

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END