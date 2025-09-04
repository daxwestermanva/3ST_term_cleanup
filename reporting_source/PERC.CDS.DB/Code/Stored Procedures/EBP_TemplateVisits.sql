

/****** Object:  StoredProcedure [Code].[EBP_TemplateVisits]    Script Date: 9/13/2021 10:57:23 PM ******/
CREATE PROCEDURE [Code].[EBP_TemplateVisits]

AS
BEGIN

-- ---------------------------------------------------------
-- AUTHOR:	Elena Cherkasova
-- CREATE DATE: 2022-07-13
-- DESCRIPTION:	Nightly code for creating a table of EBP Template visits and a table of related HealthFactorTypeSID
--              
--
-- MODIFICATIONS: 
-- 2022-07-22	EC	Added CB-SUD Templates
-- 2023-07-14	EC	Changed to pull StaPa from Dim.Institution instead of Lookup.Sta6a. Made a fix for sta3n 612/ stapa 612A4
-- 2023-09-22	EC  Added Cerner CPT and PE templates
-- 2023-10-05	EC	Switched from creating a wide lookup HF table to a tall and skinny lookup table for all EBP Health Factors and DTAs. 
--					As a result all new Cerner EBP templates will be added to the resulting table.
-- 2024-03-19	EC  Added Cerner CM template
--  2024-06-21  EC  Removed TemplateCategory column 
-- ---------------------------------------------------------

 /*TABLE OF CODE CONTENTS:
	DECLARE CODE START/STOP DATES
	SECTION I: CREATE TEMP HF and DTA LIST
	SECTION II: EBP VISITS COHORT
		*publishes to [EBP].[TemplateVisits]
		*publishes to [EBP].[TemplateVisitsHF]
*/

-----------------------------------
-- DECLARE CODE START/STOP DATES --
-----------------------------------
-- lookback 3 years for monthly and quarterly facility data for patients with any visits
-- lookback for 1 year for YTD national/VISN/facility counts for patients with 2 or more visits
-- lookback 1 year for clinician and clinician detail data for patients with any visits

DECLARE @EndDate DATE = (
		SELECT (CAST([DATE] AS DATE)) AS DATE
		FROM [Dim].[Date] WITH (NOLOCK) 
		WHERE DayofMonth=1
			AND CalendarYear = (
				SELECT DISTINCT CalendarYear
				FROM [Dim].[Date] WITH (NOLOCK) 
				WHERE DATE = CAST(GETDATE() AS DATE)
				)
			AND MonthOfYear = (
				SELECT DISTINCT MonthOfYear
				FROM [Dim].[Date] WITH (NOLOCK) 
				WHERE DATE = CAST(GETDATE() AS DATE)
				));
PRINT @EndDate;

DECLARE @MonthlyStartDate DATE = DATEADD(yy,-3,@EndDate);
PRINT @MonthlyStartDate;

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;

--------------------------------------
-- SECTION I: CREATE TEMP HF and DTA LIST
-------------------------------------

DROP TABLE IF EXISTS #TemplateInfo
SELECT   
		 lm.List
		,Cerner = CASE WHEN lm.Domain like 'HealthFactorType' THEN 0 
						WHEN lm.Domain like 'PowerForm' THEN 1 
						ELSE lm.Domain END
		--,TemplateCategory = CASE WHEN lm.Domain like 'HealthFactorType' THEN hfc.HealthFactorType
		--				WHEN lm.List like 'EBP_CBSUD%' AND lm.Domain like 'PowerForm' THEN 'SUD Cognitive Behavioral Interventions'
		--				WHEN lm.ItemID LIKE '1800323066' THEN 'PTSD Psychotherapy Session'
		--				WHEN lm.ItemID like '1800277086' THEN 'Contingency Mangement - Abstinence'
		--				ELSE lm.Attribute END 
		,CategoryHealthFactorTypeSID = CASE WHEN lm.Domain like 'HealthFactorType' THEN hfc.HealthFactorTypeSID
						ELSE NULL END 
		,lm.ItemID
		,TemplateItem = CASE WHEN lm.Attribute like 'HealthFactorCategory' THEN hft.HealthFactorType ELSE lm.AttributeValue END
		,DiagnosticGroup = CASE WHEN lm.List like 'EBP_BET%' OR lm.List like 'EBP_CBTPTSD%' OR lm.List like 'EBP_CPT%' OR lm.List like 'EBP_EMDR%' 
							OR lm.List like 'EBP_NET%' OR lm.List like 'EBP_Other%' OR lm.List like 'EBP_PE%' OR lm.List like 'EBP_WET%' OR lm.List like 'EBP_WNE%' THEN 'PTSD'
					 WHEN lm.List like 'EBP_ACT%' OR lm.List like 'EBP_CBTD%' OR lm.List like 'EBP_IPT%' THEN 'Depression' 
					 WHEN lm.List like 'EBP_BFT%' OR lm.List like 'EBP_SST%' THEN 'SMI' 
					 WHEN lm.List like 'EBP_CBTSP%' OR lm.List like 'EBP_DBT%' OR lm.List like 'EBP_PST%' THEN 'SuicidePrevention' 
					 WHEN lm.List like 'EBP_CBSUD%' OR lm.List like 'EBP_CM%' THEN 'SUD'
					 WHEN lm.List like 'EBP_CBTI%' THEN 'Insomnia'
					 WHEN lm.List like 'EBP_IBCT%' THEN 'Family'
					 ELSE NULL END
INTO #TemplateInfo
FROM [LookUp].[ListMember] as lm  WITH (NOLOCK)
LEFT JOIN [Dim].[HealthFactorType] as hft  WITH (NOLOCK)
	ON lm.ItemID = hft.HealthFactorTypeSID 
LEFT JOIN [Dim].[HealthFactorType] as hfc  WITH (NOLOCK)
	ON hfc.HealthFactorTypeSID = hft.CategoryHealthFactorTypeSID  
WHERE 1=1
	AND (lm.List LIKE 'EBP_%_Template' or lm.List LIKE 'EBP_%_Tracker')
	AND lm.Domain <> 'HealthFactorCategory'
;

CREATE CLUSTERED INDEX CIX_TemplateInfo ON #TemplateInfo(ItemID);
--select * from #TemplateInfo where cerner=1

--------------------------------------
-- SECTION II: EBP VISITS COHORT --		
-------------------------------------
--NOTES: Do NOT use HealthFactorDateTime b/c it is not as reliable as VisitDateTime. It seems to attach at the time the Health Factor is added to the note/visit, which can even be years before or after the visit.
--For templates/visits missing detailed location info (sta6a/DivisionSID/LocationSID/InstitutionSID), visits will be credited to sta3n. No way to distinguish integrated stations, so primary sta3n will be given credit.


--VISTA VISITS COHORT
DROP TABLE IF EXISTS #VisitsCohort;
SELECT DISTINCT sp.PatientICN
	,sp.MVIPersonSID
	,hf.PatientSID
	,hf.VisitSID
	,ov.LocationSID
	,hf.Sta3n
	,d.Sta6a --leaving missing sta6a missing
	,StaPa = CASE WHEN (i.StaPa IS NULL or  i.StaPa like '*') AND hf.sta3n='612' THEN '612A4'--fix for missing StaPa specifically for sta3n 612 / stapa 612A4
				  WHEN i.StaPa IS NULL or  i.StaPa like '*' THEN CAST(hf.Sta3n AS NVARCHAR(50)) ELSE i.StaPa END --deals with for missings and unknown StaPa-
	,hf.VisitDateTime
	,hf.HealthFactorDateTime
	,MONTH(hf.VisitDateTime) AS [Month]
	,YEAR(hf.VisitDateTime) AS [Year]
	,hf.EncounterStaffSID
	,l.CategoryHealthFactorTypeSID
	,l.List
	,l.DiagnosticGroup
	,l.Cerner
INTO #VisitsCohort
FROM #TemplateInfo AS l
INNER JOIN [HF].[HealthFactor] AS hf WITH (NOLOCK) ON l.ItemID = hf.HealthFactorTypeSID
LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK) ON hf.PatientSID = mvi.PatientPersonSID 
LEFT JOIN [Common].[MasterPatient] AS sp WITH (NOLOCK) ON sp.MVIPersonSID = mvi.MVIPersonSID
LEFT JOIN [Outpat].[Visit] AS ov  WITH (NOLOCK) ON hf.VisitSID = ov.VisitSID
LEFT JOIN [Dim].[Division] AS d  WITH (NOLOCK) ON ov.DivisionSID = d.DivisionSID
LEFT JOIN [Dim].[Institution] AS i WITH (NOLOCK) ON ov.InstitutionSID = i.InstitutionSID
WHERE 1 = 1 
	AND hf.VisitDateTime >= @MonthlyStartDate 
	AND hf.VisitDateTime < CAST(GetDate() AS Date)--@EndDate
	AND sp.TestPatient=0
	AND l.Cerner=0
;


DROP TABLE IF EXISTS #VisitsCohortFacility;
SELECT a.*
	,b.VISN
	,b.AdmParent_FCDM
INTO #VisitsCohortFacility
FROM #VisitsCohort AS a WITH (NOLOCK)
LEFT JOIN [Lookup].[ChecklistID] AS b WITH (NOLOCK) 
ON a.StaPa = b.StaPa
;


--CERNER VISITS COHORT
DROP TABLE IF EXISTS #CernerVisitsCohort;
SELECT DISTINCT sp.PatientICN
	,hf.MVIPersonSID
	,hf.PersonSID AS PatientSID
	,hf.EncounterSID as VisitSID
	,LocationSID = NULL
	,Sta3n = '200'
	,hf.Sta6a 
	,hf.StaPa/* = CASE WHEN (i.StaPa IS NULL or  i.StaPa like '*') AND hf.sta3n='612' THEN '612A4'--fix for missing StaPa specifically for sta3n 612 / stapa 612A4
				  WHEN i.StaPa IS NULL or  i.StaPa like '*' THEN CAST(hf.Sta3n AS NVARCHAR(50)) ELSE i.StaPa END --deals with for missings and unknown StaPa-*/
	,hf.TZFormUTCDateTime as VisitDateTime
	,CONVERT(VARCHAR(16),hf.TZFormUTCDateTime) AS HealthFactorDateTime 
	,MONTH(hf.TZFormUTCDateTime) AS [Month]
	,YEAR(hf.TZFormUTCDateTime) AS [Year]
	,hf.ResultPerformedPersonStaffSID AS EncounterStaffSID
	,l.CategoryHealthFactorTypeSID
	,l.List
	,l.DiagnosticGroup
	,l.Cerner
	,b.VISN
	,b.AdmParent_FCDM
INTO #CernerVisitsCohort
FROM #TemplateInfo AS l
INNER JOIN  [Cerner].[FactPowerForm] AS hf WITH (NOLOCK) 
	ON l.ItemID = hf.DerivedDtaEventCodeValueSID 
	and l.TemplateItem = hf.DerivedDtaEventResult
LEFT JOIN [Common].[MasterPatient] AS sp WITH (NOLOCK) 
	ON sp.MVIPersonSID = hf.MVIPersonSID
LEFT JOIN [Lookup].[ChecklistID] AS b WITH (NOLOCK)
	ON hf.StaPa = b.StaPa
/*LEFT JOIN [Cerner].[FactUtilizationOutpatient] s2 WITH (NOLOCK) ON hf.EncounterSID  = s2.EncounterSID 
			and cast(hf.tzformutcdatetime as date) = cast(s2.tzderivedvisitdatetime as date)			leaving in case I need to join to in the future*/
WHERE 1 = 1 
	AND hf.TZFormUTCDateTime >= @MonthlyStartDate 
	AND hf.TZFormUTCDateTime < CAST(GetDate() AS Date)
	AND (hf.DocFormDescription like '%PTSD Psychotherapy Session%' or hf.DocFormDescription like '%SUD Cognitive Behavioral Interventions%' or hf.DocFormDescription like '%Contingency Mangement - Abstinence%')
	AND sp.TestPatient=0
	AND l.Cerner=1
;

-- UNION VISTA AND CERNER VISITS DATA TOGETHER  
DROP TABLE IF EXISTS #UnionVisits;
SELECT PatientICN
	,MVIPersonSID
	,PatientSID
	,VisitSID
	,LocationSID
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,VisitDateTime
	,HealthFactorDateTime
	,[Month]
	,[Year]
	,EncounterStaffSID
	,CategoryHealthFactorTypeSID
	,List as TemplateGroup
	,DiagnosticGroup
	,Cerner
	INTO #UnionVisits
FROM #VisitsCohortFacility

UNION ALL

SELECT PatientICN
	,MVIPersonSID
	,PatientSID
	,VisitSID
	,LocationSID
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,VisitDateTime
	,HealthFactorDateTime
	,[Month]
	,[Year]
	,EncounterStaffSID
	,CategoryHealthFactorTypeSID
	,List as TemplateGroup
	,DiagnosticGroup
	,Cerner
FROM #CernerVisitsCohort


--EBP Visits Table 
DROP TABLE IF EXISTS #StageVisits;
SELECT DISTINCT PatientICN
	,MVIPersonSID
	,PatientSID
	,VisitSID
	,LocationSID
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,VisitDateTime
	,HealthFactorDateTime
	,[Month]
	,[Year]
	,EncounterStaffSID
	,TemplateGroup
	,DiagnosticGroup
	,Cerner
INTO #StageVisits
FROM #UnionVisits
;
 
EXEC [Maintenance].[PublishTable] 'EBP.TemplateVisits','#StageVisits';

--EBP Visit Health Factor table (for those looking to identify specific EBP health factors)

DROP TABLE IF EXISTS #stageHF;
SELECT DISTINCT v.MVIPersonSID
	,v.VisitSID
	,v.CategoryHealthFactorTypeSID
	,hf.HealthFactorTypeSID
INTO #StageHF
FROM #UnionVisits AS v
INNER JOIN [HF].[HealthFactor] AS hf WITH (NOLOCK) ON v.visitsid = hf.visitsid
WHERE Cerner=0
;

EXEC [Maintenance].[PublishTable] 'EBP.TemplateVisitsHF','#StageHF';

/* FINAL CHECKS

both counts should match
select count(distinct mvipersonsid) from #UnionVisits
select count(distinct mvipersonsid) from [EBP].[TemplateVisits]

select count(distinct patientsid) from #UnionVisits
select count(distinct patientsid) from [EBP].[TemplateVisits]

select count(distinct visitsid) from #UnionVisits
select count(distinct visitsid) from [EBP].[TemplateVisits]
*/

END