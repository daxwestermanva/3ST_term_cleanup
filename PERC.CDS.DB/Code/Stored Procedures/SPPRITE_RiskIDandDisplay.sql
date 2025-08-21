
/*------------------------------------------------------------------------------------------------------------------------------
DESCRIPTION: SPPRITE code that determines who is included in the cohort and at which stations they will display.

SPPRITE INCLUSION CRITERIA (2020-06-03, source: https://spsites.cdw.va.gov/sites/OMHO_PsychPharm/Pages/SPPRITE/Home.aspx)
	-- REACH Vet local facility 
		- Top 0.1% Currently
		- Top 0.1% Past Year
		- Current national risk tier very high (top 1%)
	-- High Risk for Suicide Flag (HRF)
			- Currently Active
			- Currently Inactive but active within the past year
			- Recently inactivated within the past 2 weeks
			- Caring Contacts in past year
	-- Behavioral Risk Flag in past 6 months
	-- STORM 
			- High, Very High and OUD elevated risk levels (current) 
			- Very High risk recently discontinued
	-- Suicide Risk Screening and Evaluation
			- Positive secondary suicide risk screens (C-SSRS) within the past 6 months
			- Intermediate or high risk levels identified by the Comprehensive Suicide Risk Evaluation (CSRE) within the past 6 months
			- A reported suicide behavior (attempt and/or preparatory) within the past 12 months
			- Eligible for Safety Planning in Emergency Department/Urgent Care Center (SPED) within the past 6 months
	-- Mental Health Inpatient: current or discharged in past 90 days 
	-- Post-Discharge Engagement (PDE) patient at high risk for suicide: PDE Group 3 in past 90 days
	-- Somatic Tx: received somatic tx within the past 60 days; includes ECT, rTMS, and esketamine. Ketamine tx will be included in future
	-- VCL Caring Contacts in past year
	-- Outreach to Facilitate Return to Care (OFR Care) cohort: top 1% RV patients with no VHA care in prior 2 years
	-- SMI Re-Engage cohort: patients with an SMI dx with no VHA care in prior 2 years
	-- COMPACT ACT in past year
			- Currently Active
			- Currently Inactive but active within the past year

MODIFICATIONS:
	--2020-07-01	RAS	Added WITH(NOLOCK) to queries of PDW objects
	--2020-07-10    CMH Removed v02 from SP and table names
	--2020-08-10    CLB Modified CSRE high/intermed ('U') to reflect all encounters in past 6 mo. (to be compatible with SPED cohort)
	--2020-10-27    CLB Removed I9
	--2020-10-30	Get homeless cohort from Common.MasterPatient instead of Present.Homeless
	--2020-11-20    CLB Renamed high-risk MH Inpatient to PDE
	--2020-11-24    CMH Added OFR Care (aka SP NOW) cohort of top 1% RV patients with no VHA care in prior 2 years
	--2021-01-21	LM	Switched references from App.PDW_DWS_MasterPatient to Common.MasterPatient
	--2020-03-06	CMH Added SMI Re-Engage cohort of patients with an SMI dx with no VHA care in prior 2 years
	--2020-03-19    CMH Removed CNS Polypharm from Risk Factors parameter (was not in inclusion criteria) and added GEC HNHR (not for inclusion criteria)
	--2021-05-14    JEB Change Synonym DWS_ reference to proper PDW_ reference
	--2021-05-20    CMH Added No COVID Vaccine to parameter (not part of inclusion critera)
	--2021-05-27	LM Updated reference to MentalHealthAssistant_v02
	--2021-06-22    CMH Added behavioral risk flag in past 6 months (not part of inclusion criteria)
	--2021-07-15	JEB Enclave Refactoring - Counts confirmed
	--2021-08-24    CMH Added 'No COVID Vaccine AND Active HRF' (not part of inclusion criteria)
	--2021-09-17    JEB Enclave Refactoring -  Refactored comment
	--2021-09-21    CMH Added DMC data (not part of inclusion criteria)
	--2022-01-21	LM	Changed behavioral flag to point to PRF.BehavioralMissingPatient; changed PDW_DWS references to Common references
	--2022-03-23	LM	Added VCL caring letters extension
	--2022-07-08	JEB Updated Synonym references to point to Synonyms from Core
	--2022-07-11	JEB Updated more Synonym references to point to Synonyms from Core (missed some)
	--2022-07-12	JEB Updated	one last Synonym reference to point to Synonym from Core 
	--2023-03-14	CMH Added Compact Act data 
	--2023-04-20    CMH Removed STORM 90 day, including recently discontinued
	--2023-07-13    CMH Added HRF caring contacts in last year, changed VCL caring contacts to point to Present.CaringLetters
	--2023-11-28    CMH Changed Behavioral Risk Flag to be part of inclusion criteria
	--2024-04-02	CMH Taking all COVID-related data out of SPPRITE
	--2024-10-22    CMH Adding MST positive screens (not part of inclusion criteria)
	--2025-02-07	LM	Pointed to new SBOR view to assign patient to multiple facilites if event was reported at multiple facilities
------------------------------------------------------------------------------------------------------------------------------ */

CREATE PROCEDURE [Code].[SPPRITE_RiskIDandDisplay]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.SPPRITE_RiskIDandDisplay','Execution of Code.SPPRITE_RiskIDandDisplay SP'


---------------------------------------------------------------
-- Get all patients matching inclusion criteria
---------------------------------------------------------------
DROP TABLE IF EXISTS #SPPRITE_InclusionCriteria
CREATE TABLE #SPPRITE_InclusionCriteria (
	 MVIPersonSID INT NOT NULL
	,RiskFactorID CHAR(1)
	,ChecklistID varchar(5)
	)

---------------------------------------------------------------
--REACH VET
---------------------------------------------------------------
DECLARE @RVVH CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'REACH VET Nat''l Risk Tier - Very High')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
		,@RVVH
		,ChecklistID=NULL -- Don't include facility for NationalTier cohort since this may not correspond to their actual RV facility
FROM [REACH].[NationalTiers] WITH(NOLOCK)
WHERE RiskTier = 'Very High'

DECLARE @REACH_Local001 CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'REACH VET - Top Risk Tier Currently')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@REACH_Local001
	  ,ChecklistID
FROM [REACH].[PatientReport] WITH(NOLOCK)
WHERE Top01Percent = 1

DECLARE @REACH_LocalPast CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'REACH VET - Past Year Top Risk Tier')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT rh.MVIPersonSID
	  ,@REACH_LocalPast as RiskID
	  ,rpt.ChecklistID
FROM [REACH].[History] rh WITH(NOLOCK)
LEFT JOIN  [REACH].[PatientReport] rpt WITH(NOLOCK) on rpt.MVIPersonSID=rh.MVIPersonSID
WHERE rh.Top01Percent=0 
	AND rh.MonthsIdentified12 IS NOT NULL
	--NOTE: REACH.History include decedents (will be excluded later in code). 
	----REACH.PatientReport should have the most recent ChecklistID for any patient ever displayed on REACH VET

---------------------------------------------------------------
--HRF (Clinical High Risk Flag) 
---------------------------------------------------------------
DECLARE @PRF_HRS_Active CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'HRF for Suicide - Active Currently')
DECLARE @PRF_HRS_Past CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'HRF for Suicide - Active in past year')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,case when LastActionType in ('1','2','4') then @PRF_HRS_Active
			when LastActionType in ('3') then @PRF_HRS_Past
			end 
	  ,OwnerChecklistID
FROM [PRF_HRS].[PatientReport_v02] as hrf WITH(NOLOCK) 

--Pull in recently inactivated separately from active in past year because they could be included under both
DECLARE @HRF_RecentInx CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'HRF for Suicide - Recently Inactivated')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@HRF_RecentInx
	  ,ChecklistID=Null
FROM [PRF_HRS].[PatientReport_v02] as hrf WITH(NOLOCK)
WHERE LastActionType='3' and LastActionDateTime >= DATEADD(day,-15,CAST(GETDATE() AS DATE))


--------------------------------------------------------------
--HRF Caring Contacts 
--------------------------------------------------------------
DECLARE @HRF_Letter CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'HRF for Suicide - Caring Contacts')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	MVIPersonSID
	,@HRF_Letter
	,ChecklistID
FROM [Present].[CaringLetters] WITH(NOLOCK)
WHERE Program='HRF Caring Letters' and (CurrentEnrolled=1 or PastYearEnrolled=1) and (DoNotSend_Reason <> 'Reported deceased' or DoNotSend_Reason is null)


--------------------------------------------------------------
-- Behavioral Risk Flag - Active currently
--------------------------------------------------------------
DECLARE @Behavior CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'Behavioral PRF Status - Currently Active')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	 MVIPersonSID
	,@Behavior 
	,OwnerChecklistID
FROM [PRF].[BehavioralMissingPatient] WITH(NOLOCK)
WHERE NationalPatientRecordFlag = 'BEHAVIORAL'
		AND ActiveFlag='Y'


--------------------------------------------------------------
--VCL Caring Contacts 
--------------------------------------------------------------
--Assign homestation from StationAssignments; for those without a homestation, retain their nearest VA facility from the VCL data
DECLARE @VCL CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'VCL Caring Contacts')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	MVIPersonSID
	,@VCL
	,ChecklistID
FROM [Present].[CaringLetters] WITH(NOLOCK)
WHERE Program='VCL Caring Letters' and (CurrentEnrolled=1 or PastYearEnrolled=1) and (DoNotSend_Reason <> 'Reported deceased' or DoNotSend_Reason is null)


---------------------------------------------------------------
--STORM
---------------------------------------------------------------
--Get STORM lead facilites (prescribing facility) 
DROP TABLE IF EXISTS #ORM_ChecklistID
SELECT DISTINCT MVIPersonSID
	  ,ChecklistID
INTO #ORM_ChecklistID
FROM [ORM].[OpioidHistory]  WITH(NOLOCK)
WHERE DATEADD(DAY,DaysSupply,ReleaseDateTime)>=DATEADD(DAY,-90,CAST(GETDATE() AS DATE))

DECLARE @ORM_VH CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'STORM Very High Risk - Active or Recent Discontd')
DECLARE @ORM_H CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'STORM High Risk - Active')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT orm.MVIPersonSID
	  ,CASE WHEN orm.RiskCategory in (4,9) THEN @ORM_VH --very high-active or very high-recently discontinued
			WHEN orm.RiskCategory=3 THEN @ORM_H --high-active
			END
	  ,c.ChecklistID
FROM [ORM].[PatientReport] orm WITH(NOLOCK)
LEFT JOIN #ORM_ChecklistID c on c.MVIPersonSID=orm.MVIPersonSID
WHERE RiskCategory IN (3,4,9)
	AND orm.MVIPersonSID > 0 

DECLARE @ORM_OUD CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'STORM OUD - Elevated Risk')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@ORM_OUD
	  ,ChecklistID=NULL --Is there a "lead station" for OUD only patients?
FROM [ORM].[PatientReport] WITH(NOLOCK) 
WHERE RiskCategory=5


---------------------------------------------------------------
--SUICIDE PREVENTION: Suicide Risk Screening and Evaluation
---------------------------------------------------------------

--C-SSRS in past 6 months --------------------------------------------
	--A positive secondary (C-SSRS aka Columbia) suicide screen within the past 6 months
DECLARE @CSSRS CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'C-SSRS Positive - Past 6 mos')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@CSSRS
	  ,ChecklistID
FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH(NOLOCK)
WHERE display_CSSRS=1
	AND SurveyGivenDateTime>dateadd(month,-6,cast(getdate() as date))


--CSRE in past 6 months --------------------------------------------
	--A high or intermediate chronic or a high or intermediate acute risk level in a CSRE on a new or updated evaluation
DECLARE @CSRE CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'CSRE High or Intermed - Past 6 mos')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT MVIPersonSID
	  ,@CSRE
	  ,ChecklistID
FROM [OMHSP_Standard].[CSRE] WITH(NOLOCK)
	WHERE (EvaluationType='New CSRE' or EvaluationType='Updated CSRE') 
		and (AcuteRisk in ('High','Intermediate') or ChronicRisk in ('High','Intermediate'))
		and ISNULL(EntryDateTime,VisitDateTime) > dateadd(month,-6,cast(getdate() as date))


--SBOR: Suicide behavior (attempt and/or preparatory) reported within the past 12 months --------------------------------------------
DECLARE @SuicideEvent CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH(NOLOCK) WHERE Label = 'Suicide Event - Past Year')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@SuicideEvent
	  ,ChecklistID
FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] WITH(NOLOCK)
WHERE (		
		(EventDateFormatted >= dateadd(year,-1,cast(getdate() as date))
			OR (EventDateFormatted IS NULL and EntryDateTime is NOT NULL AND EntryDateTime >= dateadd(year,-1,cast(getdate() as date))))
		AND UndeterminedSDV=0 
		AND (SuicidalSDV=1 or PreparatoryBehavior=1)
		)
	AND EventType NOT IN ('Ideation','Non-Suicidal SDV')
	AND MVIPersonSID IS NOT NULL

--SPED Cohort (Safety Planning in Emergency Department/Urgent Care Center) --------------------------------------------
DECLARE @SPED CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'SPED - Eligible Past 6 Months')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT p.MVIPersonSID
	  ,@SPED
	  ,l.ChecklistID
FROM [PDW].[VSSC_Out_DOEx_SPEDCohort] v WITH(NOLOCK) 
INNER JOIN [Common].[MasterPatient] p WITH(NOLOCK) on p.PatientICN=v.PatientICN
INNER JOIN [LookUp].[Sta6a] l WITH(NOLOCK) on l.Sta6a=v.Station
WHERE v.TimeIn >= dateadd(month,-6,cast(getdate() as date))
	AND dispDesc='Home'
	AND (CSRE_Chronic_Level='Chronic-Intermediate' or CSRE_Chronic_Level = 'Chronic-High'
		or CSRE_Acute_Level='Acute-Intermediate' or CSRE_Acute_Level = 'Acute-High')
	AND DOM_BedSectionName is null


-----------------------------------------------------------------------
--Inpatient Mental Health in past 90 days
--PDE (Post Discharge Engagement) patient at high risk for suicide
-----------------------------------------------------------------------
--Retain most recent ChecklistID for patients with more than one IP stay in past 90 days
DECLARE @PDE1 CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'MH-related Inpat - Past 90 Days')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@PDE1
	  ,ChecklistID
FROM (
	SELECT a.MVIPersonSID
	,a.ChecklistID
	,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY Census desc,DischargeDateTime desc) 
	FROM [Inpatient].[BedSection] a WITH(NOLOCK) 
	LEFT JOIN Lookup.ICD10 b WITH (NOLOCK) on a.PrincipalDiagnosisICD10SID=b.ICD10SID
	WHERE (Census=1 or DischargeDateTime>DateAdd(d,-91,cast(getdate() as date)))
		AND 
		(1 IN (a.MentalHealth_TreatingSpecialty,a.RRTP_TreatingSpecialty)
		 OR b.MHSUDDX_POSS=1 
		 OR b.PDE_SuicideRelated=1 
		 OR b.PDE_ExternalCauses=1 
		 OR b.PDE_OverDoseAndPoison=1
		 )
	) a
WHERE RN=1

-- Post-Discharge Engagement Measure (PDE)
	--PDE_Grp 3 = Highest Risk
DECLARE @PDE2 CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'PDE - High Risk Pts Past 90 Days')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@PDE2
	  ,ChecklistID
FROM (
	SELECT MVIPersonSID
		  ,CAST(ChecklistID_Discharge as VARCHAR(5)) as ChecklistID_Discharge
		  ,CAST(ChecklistID_Home as VARCHAR(5)) as ChecklistID_Home
		  ,CAST(ChecklistID_Metric as VARCHAR(5)) as ChecklistID_Metric
	FROM (
		SELECT MVIPersonSID
			  ,ChecklistID_Discharge
			  ,ChecklistID_Home
			  ,ChecklistID_Metric
			  ,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY ISNULL(DischargeDateTime,'2050-01-01') DESC) 
		FROM [PDE_Daily].[PDE_PatientLevel] WITH(NOLOCK)
		WHERE PDE_GRP=3 
			AND Exclusion30=0
		) mx  
	WHERE RN=1
	) A
UNPIVOT (ChecklistID FOR ChecklistIDType IN (
	ChecklistID_Discharge
	,ChecklistID_Home
	,ChecklistID_Metric
	)	) B


--------------------------------------------------------------
--Somatic Tx – past 60 days 
--------------------------------------------------------------
--Note: code for this created in [SPPRITE].[SomaticTx] view
DECLARE @somatic CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'Somatic Tx in Past 60 Days')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT MVIPersonSID
	  ,@somatic
	  ,ChecklistID
FROM [SPPRITE].[SomaticTx] WITH(NOLOCK)
WHERE TxOrderDesc = 1


--------------------------------------------------------------------------------------------------------------------------
--Outreach to Facilitate Return to Care (OFR Care) cohort: top 1% RV patients with no VHA care in prior 2 years
	--Prior but not recent Veteran VHA Users – Veterans without VHA care in the prior 2 years and with VHA care in the prior 2-4 years. 
	--Veterans are stratified by their local suicide risk tier in the month after the last VHA use.
--------------------------------------------------------------------------------------------------------------------------
DECLARE @SPNOW CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'OFR Care')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	b.MVIPersonSID
	,@SPNOW
	,a.ChecklistID
FROM [PDW].[SMITR_SMITREC_DOEx_SPNowPlank3_PBNRVets] a WITH(NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] b WITH(NOLOCK) on a.PatientICN=b.PatientICN
INNER JOIN [Config].[SPPRITE_OFRCare] c WITH(NOLOCK) on a.ChecklistID=c.ChecklistID
WHERE a.Top1_RiskTier=1 
		and a.FirstTop1_Date > DATEADD(year,-1,getdate()) 
		and c.StartDate is not NULL 
		and c.EndDate is NULL
		and a.FirstTop1_Date > DATEADD(month,-3,c.StartDate) 
		and a.FirstTop1_Date >= a.PilotStart_Date

--------------------------------------------------------------------------------------------------------------------------
--SMI Re-engage cohort (updated quarterly)
--------------------------------------------------------------------------------------------------------------------------
DECLARE @SMI CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'SMI Re-Engage')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	b.MVIPersonSID
	,@SMI
	,c.ChecklistID
FROM [PDW].[SMITR_SMITREC_DOEx_ReEngage_SPPRITE] a WITH(NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] b WITH(NOLOCK) on a.PatientICN=b.PatientICN
INNER JOIN [Lookup].[Sta6a] c WITH (NOLOCK) on a.LRC_Facility=c.Sta6a


--------------------------------------------------------------------------------------------------------------------------
--COMPACT ACT
--------------------------------------------------------------------------------------------------------------------------
DECLARE @CompactConfirmedCurrent CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'COMPACT Act - Current Confirmed Episode')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	 MVIPersonSID
	,@CompactConfirmedCurrent
	,ChecklistID_EpisodeBegin
FROM [COMPACT].[Episodes] WITH (NOLOCK)
WHERE ActiveEpisode=1 and ConfirmedStart=1 and EpisodeRankDesc=1

DECLARE @CompactConfirmedYear CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'COMPACT Act - Inactive, Past Year Confirmed Episode')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	 MVIPersonSID
	,@CompactConfirmedYear
	,ChecklistID_EpisodeBegin
FROM [COMPACT].[Episodes] WITH (NOLOCK)
WHERE (EpisodeBeginDate >= dateadd(YEAR,-1,cast(getdate() as date)) or (EpisodeEndDate >= dateadd(YEAR,-1,cast(getdate() as date)) and EpisodeEndDate < cast(getdate() as date)))
		and ActiveEpisode=0
		and MVIPersonSID not in (select distinct MVIPersonSID from COMPACT.Episodes where ActiveEpisode=1)
		and ConfirmedStart=1
		and EpisodeRankDesc=1

DECLARE @CompactUnconfirmedCurrent CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'COMPACT Act - Current Unconfirmed Episode')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	 MVIPersonSID
	,@CompactUnconfirmedCurrent
	,ChecklistID_EpisodeBegin
FROM [COMPACT].[Episodes] WITH (NOLOCK)
WHERE ActiveEpisode=1 and ConfirmedStart=0 and EpisodeRankDesc=1

DECLARE @CompactUnconfirmedYear CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = 'COMPACT Act - Inactive, Past Year Unconfirmed Episode')
INSERT INTO #SPPRITE_InclusionCriteria
SELECT DISTINCT 
	 MVIPersonSID
	,@CompactUnconfirmedYear
	,ChecklistID_EpisodeBegin
FROM [COMPACT].[Episodes] WITH (NOLOCK)
WHERE (EpisodeBeginDate >= dateadd(YEAR,-1,cast(getdate() as date)) or (EpisodeEndDate >= dateadd(YEAR,-1,cast(getdate() as date)) and EpisodeEndDate < cast(getdate() as date)))
		and ActiveEpisode=0
		and MVIPersonSID not in (select distinct MVIPersonSID from COMPACT.Episodes where ActiveEpisode=1)
		and ConfirmedStart=0
		and EpisodeRankDesc=1

--------------------------------------------------------------
--Clean Up (dedupe)
--------------------------------------------------------------
DROP TABLE IF EXISTS #SPPRITE_InclusionCriteriaFinal
SELECT DISTINCT MVIPersonSID
		,RiskFactorID
		,ChecklistID
INTO #SPPRITE_InclusionCriteriaFinal
FROM #SPPRITE_InclusionCriteria

DROP TABLE #SPPRITE_InclusionCriteria


---------------------------------------------------------------
-- Add other display factors and report filter criteria
-- NOTE: These are NOT part of the cohort inclusion critera 
-- Homeless services or dx
-- Naloxone candidates from STORM
-- Geriatric Extended Care HNHR (High Needs High Risk)
-- DMC debt data 
---------------------------------------------------------------

DROP TABLE IF EXISTS #Cohort
SELECT DISTINCT MVIPersonSID 
INTO #Cohort
FROM #SPPRITE_InclusionCriteriaFinal

DROP TABLE IF EXISTS #OtherPatientFactors
CREATE TABLE #OtherPatientFactors (
	 MVIPersonSID INT NOT NULL
	,ChecklistID VARCHAR(5)
	,ID CHAR(1)
	)


-- No suicide screen (C-SSRS or CSRE) in past year --------------------------------------------
DROP TABLE IF EXISTS #CSSRS_pastyear 
SELECT DISTINCT MVIPersonSID
INTO #CSSRS_pastyear
FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (NOLOCK)
WHERE display_CSSRS<>-1 
	AND Surveyname<>'PHQ9'
	AND SurveyGivenDateTime>dateadd(year,-1,cast(getdate() as date))

DROP TABLE IF EXISTS #CSRE_pastyear
SELECT DISTINCT MVIPersonSID
INTO #CSRE_pastyear
FROM [OMHSP_Standard].[CSRE] WITH (NOLOCK)
WHERE ISNULL(EntryDateTime,VisitDateTime) > dateadd(year,-1,cast(getdate() as date))

DECLARE @NoSuicideScreen CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*No C-SSRS or CSRE in past year')
INSERT INTO #OtherPatientFactors (MVIPersonSID,ID)
SELECT a.MVIPersonSID
	  ,@NoSuicideScreen
FROM #Cohort a
LEFT JOIN #CSSRS_pastyear b ON a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN #CSRE_pastyear c ON a.MVIPersonSID=c.MVIPersonSID
WHERE b.MVIPersonSID is NULL and c.MVIPersonSID is NULL


--Homeless --------------------------------------------
DECLARE @Homeless CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*Homeless Svcs or Dx')
INSERT INTO #OtherPatientFactors (MVIPersonSID,ID)
SELECT DISTINCT co.MVIPersonSID
	  ,@Homeless
FROM [Common].[MasterPatient] m WITH(NOLOCK)
INNER JOIN #Cohort co on co.MVIPersonSID=m.MVIPersonSID
WHERE Homeless=1


--Naloxone Candidates from STORM --------------------------------------------
DECLARE @naloxone CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*STORM Naloxone Candidates')
INSERT INTO #OtherPatientFactors (MVIPersonSID,ID)
SELECT DISTINCT c.MVIPersonSID
	,@naloxone
FROM [ORM].[RiskMitigation] orm WITH(NOLOCK)
INNER JOIN #SPPRITE_InclusionCriteriaFinal c on c.MVIPersonSID=orm.MVIPersonSID
WHERE MitigationID = 2
	AND MetricInclusion = 1 
	AND Red=1 
	AND Checked=0
	AND c.RiskFactorID in ('K','L','N') -- only want to retain this for STORM patients


-- GEC HNHR --------------------------------------------
DECLARE @HNHR CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*GEC HNHR')
INSERT INTO #OtherPatientFactors (MVIPersonSID,ID)
SELECT c.MVIPersonSID
	  ,@HNHR 
FROM [PDW].[GEC_GECDACA_DOEx_HBPCExp_HNHR_list] h WITH(NOLOCK)
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] p WITH(NOLOCK) on p.PatientPersonSID=h.PatientSID 
INNER JOIN #Cohort c on p.MVIPersonSID=c.MVIPersonSID
--for now there are no patients in the HNHR list who are only Cerner patients but we may need to revisit this join later on


--DMC debt data --------------------------------------------
DECLARE @Debt CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*Debt Management Center (DMC)')
INSERT INTO #OtherPatientFactors 
	( MVIPersonSID, ID )
SELECT DISTINCT c.MVIPersonSID
				, @Debt
FROM #Cohort c
INNER JOIN [VBA].[DebtManagementCenter] d WITH (NOLOCK) on c.MVIPersonSID=d.MVIPersonSID


--MST positive screens --------------------------------------------
DECLARE @MST CHAR(1) = (SELECT ID FROM [Config].[SPPRITE_RiskFactors] WITH (NOLOCK) WHERE Label = '*Military Sexual Trauma (MST) Positive Screen')
INSERT INTO #OtherPatientFactors 
	( MVIPersonSID, ID )
SELECT DISTINCT c.MVIPersonSID
				, @MST
FROM #Cohort c
INNER JOIN [SDH].[ScreenResults] s WITH (NOLOCK) on c.MVIPersonSID=s.MVIPersonSID
WHERE Category IN ('MST Screen')
	AND Score=1
	AND ScreenDateTime > dateadd(year,-2,cast(getdate() as date))


--------------------------------------------------------------------------------------------------------
--Display at all relevant stations from Present.StationAssignments not accounted for in previous steps 
--------------------------------------------------------------------------------------------------------
INSERT INTO #OtherPatientFactors (MVIPersonSID,ChecklistID)
SELECT sa.MVIPersonSID
	  ,sa.ChecklistID
FROM [Present].[ActivePatient] sa WITH(NOLOCK)
INNER JOIN #Cohort c on c.MVIPersonSID=sa.MVIPersonSID
WHERE sa.RequirementID IN (
	SELECT apr.RequirementID --,apr.RequirementName
	FROM [Config].[Present_ActivePatientRequirement] apr WITH (NOLOCK)
	LEFT JOIN [Config].[Present_ProjectDisplayRequirement] pdr WITH (NOLOCK) ON pdr.RequirementID=apr.RequirementID
	WHERE pdr.ProjectName IN ('STORM','PDSI')
		OR apr.RequirementName IN ('PCP','PACT','MH/BHIP','MHTC','Rx')
	)
EXCEPT SELECT MVIPersonSID,ChecklistID FROM #SPPRITE_InclusionCriteriaFinal


----------------------------------------------------------------------
-- Final SPPRITE Cohort with Risk Factor and Facility Assignments
----------------------------------------------------------------------
DROP TABLE IF EXISTS #combine
SELECT u.MVIPersonSID
	  ,u.RiskFactorID
	  ,u.ChecklistID
INTO #combine
FROM (
	SELECT MVIPersonSID
		  ,RiskFactorID
		  ,ChecklistID
	FROM #SPPRITE_InclusionCriteriaFinal
	UNION
	SELECT MVIPersonSID
		  ,ID
		  ,ChecklistID
	FROM #OtherPatientFactors
	) u

DROP TABLE IF EXISTS #StageSPPRITEPatientRiskFactors
SELECT c.MVIPersonSID
	  ,c.RiskFactorID
	  ,c.ChecklistID
INTO #StageSPPRITEPatientRiskFactors
FROM #combine c
INNER JOIN [Common].[MasterPatient] d WITH(NOLOCK) on c.MVIPersonSID=d.MVIPersonSID
WHERE d.DateOfDeath IS NULL 

--DROP TABLE IF EXISTS #StageSPPRITEPatientRiskFactors
--SELECT c.MVIPersonSID
--	  ,c.RiskFactorID
--	  ,c.ChecklistID
--INTO #StageSPPRITEPatientRiskFactors
--FROM #combine c
--INNER JOIN (
--	SELECT MVIPersonSID,max(DeathDateTime) DateOfDeath
--	FROM [SPatient].[SPatient] WITH(NOLOCK)
--	GROUP BY MVIPersonSID
--	) d  on c.MVIPersonSID=d.MVIPersonSID
--WHERE d.DateOfDeath IS NULL 

EXEC [Maintenance].[PublishTable] 'SPPRITE.RiskIDandDisplay','#StageSPPRITEPatientRiskFactors'

EXEC [Log].[ExecutionEnd]

END