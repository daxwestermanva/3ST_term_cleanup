/****** Object:  StoredProcedure [Code].[EBP_DashboardBaseTable]    Script Date: 9/13/2021 10:57:23 PM ******/
CREATE PROCEDURE [Code].[EBP_DashboardBaseTable]

AS
BEGIN

-- ---------------------------------------------------------
-- AUTHOR:	Elena Cherkasova
-- CREATE DATE: 2021-12-03
-- DESCRIPTION:	Base table code for all EBP dashboard reports
--              
--
-- MODIFICATIONS: 
-- 04-27-2015 HES: Remove SUD from code (No longer required per Tracey Smith)
-- 1/5/15 SM updated to dim.division; previously dim.location
-- 1/7/2017 GS Added table compression
-- 3/14/2017 GS Repointed Present objects to PERC
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
-- 20180906 RAS: Refactored to use HealthFactor LookUp table instead of hard-coded names
-- 20190314: Elena added Contingency Management (CM) health factors and SUD-related codes
-- 20200206	RAS: Replaced diagnosis query using IndicatorICD9ICD10 with Present.Diagnosis
-- 20200407 RAS: Updated diagnosis count section to get unique patient count at facility, VISN, and national levels.
-- 20210914 BTW: Enclave Refactoring - Counts Confirmed.
-- 20210924 EC: Added 2 new EBP Templates: CBT-SP and DBT
-- 20211201 EC: Combining Basetable, Clinician, and Monthly codes into one
-- 20220121 EC: Adding Problem Solving Therapy (PST) templates and switching from using ChecklistID to StaPA
-- 20220127	RAS: Replacing LookUp.HealthFactor with LookUp.ListMember
-- 20220622 EC: Adding patient level EBP table to identify patients receiving EBP thereapy for various reports/metrics
-- 20220705 EC: Expanding initial cohort to 3 year lookback period; Integrating Quarterly calculations code into this code. 
--				Only publishes quarterly data once on the 10th or later after the end of the quarter.
--20220722	EC: Added CB-SUD Templates
--20230323  EC: Separated out Quarterly Code into separate code [Code].[EBP_Quarterly]
--20230714	EC: Added a condition to prevent NULL or missing VISN or StaPa values since these are used for grouping and unmatched values cause extra rows and dashboard problems
--20231027	EC:	Redesigned code to remove pivot/unpivot sections. Added Cerner Staff data.
--20240102	EC: Increased clinician monthly look back period from 12 months to 24 months.
--20240815	LM:	 Updated ChecklistID value for Lexington 596
--20240821  EC: Added EMDR and WET/WNE Vista PTSD Tracker and OracleHealth PowerForms
-- ---------------------------------------------------------

	--EBP_ACT_Template 
	--EBP_BFT_Template
	--EBP_CBSUD_Template
	--EBP_CBTD_Template 
	--EBP_CBTI_Template
	--EBP_CBTSP_Template
	--EBP_CM_Template
	--EBP_CPT_Template 
	--EBP_DBT_Template
	--EBP_EMDR_Template
	--EBP_EMDR_Tracker
	--EBP_IBCT_Template 
	--EBP_IPT_Template 
	--EBP_PEI_Template 
	--EBP_PST_Template
	--EBP_SST_Template 
	--EBP_WET_Tracker
	--EBP_WNE_Template

/*--TABLE OF CODE CONTENTS
DECLARE CODE START/STOP DATES
SECTION I: EBP VISIT COHORT
SECTION II: YTD FACILITY AND DX COUNTS FOR MONTHLY SUMMARY REPORT
   *publishes to [EBP].[DashboardBaseTableSummary]
SECTION III: MONTHLY FACILITY COUNTS
   *publishes to [EBP].[FacilityMonthly]
SECTION IV: CLINICIAN REPORTS
  *publishes to [EBP].[Clinician]
SECTION V: QUARTERLY REPORTS  --04/23 MOVED TO Code.EBP_Quarterly
  *appends to [EBP].[Quarterly]  --04/23 MOVED TO Code.EBP_Quarterly
  *publishes to [EBP].[QuarterlySummary]  --04/23 MOVED TO Code.EBP_Quarterly
*/
-----------------------------------
-- DECLARE CODE START/STOP DATES --
-----------------------------------
-- lookback 3 years for monthly and quarterly facility data for patients with any visits
-- lookback for 1 year for YTD national/VISN/facility counts for patients with 2 or more visits
-- lookback 2 year for clinician and clinician detail data for patients with any visits

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

DECLARE @ClinicianStartDate DATE = DATEADD(yy,-2,@EndDate);
PRINT @ClinicianStartDate;

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;

--Adds new monthly reporting period to [App].[EBP_ReportingPeriodID] which is used by code below and the report stored procedures
DELETE FROM [App].[EBP_ReportingPeriodID] WHERE ReportingPeriodShort= @EndDate;

DECLARE @ReportingPeriodID FLOAT = (SELECT MAX(ReportingPeriodID)+1 FROM [App].[EBP_ReportingPeriodID] WITH (NOLOCK) );
PRINT @ReportingPeriodID;

INSERT INTO [App].[EBP_ReportingPeriodID]
SELECT @ReportingPeriodID,Date,CONCAT(MonthName,'-',CalendarYear)
				FROM [Dim].[Date] WITH (NOLOCK) 
				WHERE DATE = @EndDate;

------------------------------------------
-- SECTION I: EBP VISIT COHORT --
------------------------------------------
--Distinct visits using EBP Health Factors from EBP.TemplateVisits table which is updated nightly and looks back 3 years from the beginning of this month.
--(still multiple VisitSIDs b/c very rarely a visit has 2 different template types attached)
DROP TABLE IF EXISTS #DistinctVisits;
SELECT DISTINCT PatientICN
	,MVIPersonSID
	,PatientSID
	,VisitSID
	,LocationSID
	,VisitDateTime
	,EncounterStaffSID
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,TemplateGroup = CASE WHEN TemplateGroup='EBP_EMDR_Tracker' THEN 'EBP_EMDR_Template'
						WHEN TemplateGroup ='EBP_WET_Tracker' then 'EBP_WNE_Template' ELSE TemplateGroup END
	,DiagnosticGroup
	,Cerner
INTO #DistinctVisits
FROM [EBP].[TemplateVisits] WITH (NOLOCK)
WHERE 1=1
	AND VISN IS NOT NULL		--because used for grouping purposes and null values cause problems
	AND StaPa IS NOT NULL		--because used for grouping purposes and null values cause problems
	AND StaPa NOT LIKE '%*%'	--because used for grouping purposes and null values cause problems
	AND TemplateGroup not like 'EBP_BET%'			-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_CBTPTSD%'		-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_CPT_Tracker'	-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_PE_Tracker'		-- not being displayed on the dashboard yet
;

------------------------------------------
-- SECTION II: YTD FACILITY AND DX COUNTS FOR MONTHLY SUMMARY REPORT  --
------------------------------------------
	/* ---------
	FILTER TO PAST YEAR AND 2 OR MORE VISITS
	 ---------*/

/* for testing code
DECLARE @EndDate DATE = (
		SELECT (CAST([DATE] AS DATE)) AS DATE
		FROM [Dim].[Date]
		WHERE DayofMonth=1
			AND CalendarYear = (
				SELECT DISTINCT CalendarYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				)
			AND MonthOfYear = (
				SELECT DISTINCT MonthOfYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				));
PRINT @EndDate

--DECLARE @EndDate DATE;
--SET @EndDate = '2023-10-01'

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;
--*/

-- Filter and clean data to include only patients who have 2 or more sessions (VisitSID) of a template in the past year
DROP TABLE IF EXISTS #TwoOrMore;
SELECT MVIPersonSID
	,PatientSID
	,COUNT(DISTINCT VisitSID) AS 'TotalSessions'
	,TemplateGroup
INTO #TwoOrMore
FROM #DistinctVisits
WHERE VisitDateTime >= @OneYearAgo and VisitDateTime<@EndDate
GROUP BY PatientSID, MVIPersonSID, TemplateGroup
HAVING COUNT(DISTINCT VisitSID) >= 2
ORDER BY COUNT(DISTINCT VisitSID) DESC
;

-- Create new visit-level table with patients who have 2 or more visits in the past year
DROP TABLE IF EXISTS #2VisitsCohort;
SELECT DISTINCT PatientICN
	,a.MVIPersonSID
	,a.PatientSID
	,VisitSID
	,VisitDateTime
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,a.TemplateGroup
	,a.DiagnosticGroup
INTO #2VisitsCohort
FROM #DistinctVisits AS a
INNER JOIN #TwoOrMore b	ON a.PatientSID = b.PatientSID AND a.TemplateGroup=b.TemplateGroup
WHERE VisitDateTime >= @OneYearAgo and VisitDateTime<@EndDate
;

	/* ---------
	ROLL UP DATA FROM PATIENT-LEVEL TO FACILITY LEVEL
	 ---------*/

-- Sum counts of TEMPLATES by FACILITY for the past year
DROP TABLE IF EXISTS #EBPTemplateFacility;
SELECT DISTINCT  
     VISN
	,StaPa
	,AdmParent_FCDM = MAX(AdmParent_FCDM)
	,TemplateGroup
	,DiagnosticGroup 
    ,TemplateCount = COUNT(DISTINCT PatientSID)
INTO #EBPTemplateFacility
FROM #2VisitsCohort
GROUP BY VISN
	,StaPa
	,TemplateGroup
	,DiagnosticGroup
;

-- Sum counts of TEMPLATES by VISN for the past year
DROP TABLE IF EXISTS #EBPTemplateVISN;
SELECT DISTINCT  
     VISN
	,StaPa = VISN
	,AdmParent_FCDM = CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,TemplateGroup
	,DiagnosticGroup 
    ,TemplateCount = COUNT(DISTINCT PatientSID)
INTO #EBPTemplateVISN
FROM #2VisitsCohort
GROUP BY VISN
	,TemplateGroup
	,DiagnosticGroup
;

-- Sum counts by DIAGNOSIS by FACILITY for the past year
DROP TABLE IF EXISTS #DXgroupFacility;
SELECT DISTINCT  
     VISN
	,StaPa
	,AdmParent_FCDM = MAX(AdmParent_FCDM)
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
	,DiagnosticGroup 
    ,TemplateCount =SUM(TemplateCount)
INTO #DXgroupFacility
FROM #EBPTemplateFacility
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family' --only one template per category so don't need AnyTemplate grouping
GROUP BY VISN
	,StaPa
	,DiagnosticGroup
;

-- Sum counts by DIAGNOSIS by VISN for the past year
DROP TABLE IF EXISTS #DXgroupVISN;
SELECT DISTINCT  
     VISN
	,StaPa = VISN
	,AdmParent_FCDM = CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
	,DiagnosticGroup 
    ,TemplateCount = SUM(TemplateCount)
INTO #DXgroupVISN
FROM #EBPTemplateVISN
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family'	--only one template per category so don't need AnyTemplate grouping
GROUP BY VISN
	,DiagnosticGroup
;

-- Sum counts of ALL TEMPLATES by FACILITY 
DROP TABLE IF EXISTS #EBPTemplateFacilityAny;
SELECT DISTINCT  
     VISN
	,StaPa
	,AdmParent_FCDM = MAX(AdmParent_FCDM)
	,TemplateGroup = 'AnyEBPTemplate'
    ,TemplateCount = SUM(TemplateCount)
INTO #EBPTemplateFacilityAny
FROM #EBPTemplateFacility
GROUP BY VISN
	,StaPa
;

-- Sum counts of ALL TEMPLATES by VISN 
DROP TABLE IF EXISTS #EBPTemplateVISNAny;
SELECT DISTINCT  
     VISN
	,StaPa = VISN
	,AdmParent_FCDM = CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,TemplateGroup = 'AnyEBPTemplate'
    ,TemplateCount = SUM(TemplateCount)
INTO #EBPTemplateVISNAny
FROM #EBPTemplateVISN
GROUP BY VISN
;

--Sum counts of TEMPLATES for NATIONAL 
DROP TABLE IF EXISTS #EBPTemplateNational;
SELECT DISTINCT  
     VISN = 0
	,StaPa = 0
	,AdmParent_FCDM = 'National'
	,TemplateGroup 
    ,TemplateCount = SUM(TemplateCount)
INTO #EBPTemplateNational
FROM #EBPTemplateFacility
GROUP BY TemplateGroup
;

-- Sum counts by DIAGNOSIS for NATIONAL
DROP TABLE IF EXISTS #DXgroupNational;
SELECT DISTINCT  
     VISN = 0
	,StaPa = 0
	,AdmParent_FCDM = 'National'
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
    ,TemplateCount = SUM(TemplateCount)
INTO #DXgroupNational
FROM #EBPTemplateFacility
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family'		--only one template per category so don't need AnyTemplate grouping
GROUP BY DiagnosticGroup
;

-- Sum counts of ALL TEMPLATES for NATIONAL 
DROP TABLE IF EXISTS #EBPTemplateNationalAny;
SELECT DISTINCT  
     VISN = 0
	,StaPa = 0
	,AdmParent_FCDM = 'National'
	,TemplateGroup = 'AnyEBPTemplate'
    ,TemplateCount = SUM(TemplateCount)
INTO #EBPTemplateNationalAny
FROM #EBPTemplateFacility
;

/*
SELECT * FROM #EBPTemplateFacility order by Stapa	--Sum counts of TEMPLATES by FACILITY 
SELECT * FROM #EBPTemplateVISN order by Stapa		--Sum counts of TEMPLATES by VISN 

SELECT * FROM #DXgroupFacility order by Stapa		--Sum counts by DIAGNOSIS by FACILITY 
SELECT * FROM #DXgroupVISN order by Stapa			--Sum counts by DIAGNOSIS by VISN 

SELECT * FROM #EBPTemplateFacilityAny				--Sum counts of ALL TEMPLATES by FACILITY 
SELECT * FROM #EBPTemplateVISNAny					--Sum counts of ALL TEMPLATES by VISN 

SELECT * FROM #EBPTemplateNational					--Sum counts of TEMPLATES for NATIONAL 
SELECT * FROM #DXgroupNational						--Sum counts by DIAGNOSIS for NATIONAL
SELECT * FROM #EBPTemplateNationalAny				--Sum counts of ALL TEMPLATES for NATIONAL 
--*/

-- *** COMBINE ALL LEVELS ***
DROP TABLE IF EXISTS #AllLevels;
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount INTO #AllLevels FROM #EBPTemplateFacility	--1485
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #EBPTemplateVISN		--241
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #DXgroupFacility		--612
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #DXgroupVISN			--90
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #EBPTemplateFacilityAny	--138
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #EBPTemplateVISNAny		--18
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #EBPTemplateNational		--14
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #DXgroupNational		--5
UNION ALL
SELECT VISN,StaPa=CAST(StaPa as varchar),AdmParent_FCDM,TemplateGroup,TemplateCount FROM #EBPTemplateNationalAny	--1
;

-- *** Pull in any facilities with no data and asign them a zero (otherwise those facilities would drop off from the list entirely) ***

--All possible combinations of Facility/VISN/National and Template Type/Diagnostic Groups/AnyEBPTemplate
DROP TABLE IF EXISTS #comb;
SELECT DISTINCT VISN
	,StaPa
	,AdmParent_FCDM
	,a.TemplateGroup
	,LocationOfFacility =  c.[LOCATION OF FACILITY]
INTO #comb
FROM [LookUp].[ChecklistID] as b  WITH (NOLOCK)
LEFT JOIN  [LookUp].[SpatialData] as c WITH (NOLOCK)
ON b.ChecklistID = c.ChecklistID,(SELECT DISTINCT TemplateGroup FROM #2VisitsCohort			--14 Templates
											UNION
											SELECT DISTINCT TemplateGroup FROM #DXgroupFacility			--5 Dx Groups
											UNION
											SELECT DISTINCT TemplateGroup FROM #EBPTemplateFacilityAny	--1 AnyEBPTemplate 
											) AS a 
ORDER BY StaPa, TemplateGroup
--3180 = (140 facilities + 18 VISN + 1 National) * 20 Template Groups
--select * FROM #comb ORDER BY StaPa
;

DROP TABLE IF EXISTS #FinalAllLevels;
SELECT a.VISN
	,a.StaPa
	,a.AdmParent_FCDM
	,a.LocationOfFacility
	,a.TemplateGroup
	,TemplateCount=ISNULL(TemplateCount,0)
INTO #FinalAllLevels
FROM #comb AS a
LEFT JOIN #AllLevels AS b 
	ON a.StaPa = b.StaPa
	AND a.TemplateGroup = b.TemplateGroup
; --3180

	/* ---------
   COUNT YTD PATIENTS WITH EBP-RELEVANT DX 
		-----------*/

		
-- ***INSOMNIA POPULATION

DROP TABLE IF EXISTS #cohort;
SELECT a.MVIPersonSID
	,mvi.PatientPersonSID
INTO #cohort
FROM [Present].[SPatient] a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.MVIPersonSID = mvi.MVIPersonSID
;

CREATE CLUSTERED INDEX CIX_cohort on #cohort(MVIPersonSID)

  ---Set begin and end dates to look for diagnoses in past year
DECLARE @EndDate2 DATE = GetDate();
DECLARE @StartDate2 DATE = CAST(DateAdd(d,-366,@EndDate2) as date);

  --VistA OUTPATIENT DIAGNOSIS (borrowed code from Present.Diagnosis)
  DROP TABLE IF EXISTS #OutpatVDiagnosis;
  SELECT DISTINCT c.MVIPersonSID
  INTO  #OutpatVDiagnosis 
  FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN (SELECT DISTINCT ICD10SID, ICD10Code
				FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
				WHERE ICD10Code like 'F51.0%' OR ICD10Code like 'G47.0%') b 
		ON a.[ICD10SID] = b.[ICD10SID]
  WHERE (a.[VisitDateTime] >= @StartDate2 AND a.[VisitDateTime] < @EndDate2)
      AND a.WorkloadLogicFlag = 'Y'
;

--INPATIENT VISTA DIAGNOSIS  (borrowed code from Present.Diagnosis)
  DROP TABLE IF EXISTS #InpatientDiagnosis;
  SELECT DISTINCT c.MVIPersonSID
  INTO #InpatientDiagnosis 
  FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN (SELECT DISTINCT ICD10SID, ICD10Code
				FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
				WHERE ICD10Code like 'F51.0%' OR ICD10Code like 'G47.0%') b 
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.DischargeDateTime >= @StartDate2 AND a.DischargeDateTime < @EndDate2)
		OR a.DischargeDateTime  IS NULL
;	

  DROP TABLE IF EXISTS #InpatientDischargeDiagnosis;
  SELECT DISTINCT c.MVIPersonSID
  INTO #InpatientDischargeDiagnosis
  FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN (SELECT DISTINCT ICD10SID, ICD10Code
				FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
				WHERE ICD10Code like 'F51.0%' OR ICD10Code like 'G47.0%') b 
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.DischargeDateTime >= @StartDate2 AND a.DischargeDateTime < @EndDate2)
		OR a.DischargeDateTime  IS NULL
;	

  DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis;
  SELECT c.MVIPersonSID
  INTO #SpecialtyTransferDiagnosis 
  FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN (SELECT DISTINCT ICD10SID, ICD10Code
				FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
				WHERE ICD10Code like 'F51.0%' OR ICD10Code like 'G47.0%') b 
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH(NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.SpecialtyTransferDateTime >= @StartDate2 AND a.SpecialtyTransferDateTime < @EndDate2)
		OR a.SpecialtyTransferDateTime  IS NULL
; 

--CERNER DIAGNOSIS
DROP TABLE IF EXISTS #MillDiagnosis
SELECT DISTINCT c.MVIPersonSID
INTO #MillDiagnosis
FROM [Cerner].[FactDiagnosis] c WITH (NOLOCK)
INNER JOIN  (SELECT DISTINCT ICD10SID, ICD10Code
				FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
				WHERE ICD10Code like 'F51.0%' OR ICD10Code like 'G47.0%') l 
	ON l.ICD10SID=c.NomenclatureSID 
INNER JOIN #cohort co WITH(NOLOCK)
	ON co.PatientPersonSID=c.PersonSID
WHERE c.SourceVocabulary = 'ICD-10-CM' --needed?
	AND c.MVIPersonSID>0
	AND (TZDerivedDiagnosisDateTime >= @StartDate2 AND TZDerivedDiagnosisDateTime < @EndDate2)
	;	

  DROP TABLE IF EXISTS #AllInsomniaDX;
    SELECT MVIPersonSID
	INTO #AllInsomniaDX
	FROM #OutpatVDiagnosis
	UNION
	SELECT MVIPersonSID
	FROM #InpatientDiagnosis
	UNION
	SELECT MVIPersonSID
	FROM #InpatientDischargeDiagnosis
	UNION
	SELECT MVIPersonSID
	FROM #SpecialtyTransferDiagnosis
	UNION
	SELECT MVIPersonSID
	FROM #MillDiagnosis
;


	DROP TABLE IF EXISTS #InsomniaPatientCount;
	SELECT VISN = ISNULL(c.VISN,0)
		  ,StaPa = ISNULL(s.ChecklistID, ISNULL(CAST(c.VISN AS VARCHAR),'0'))
		  ,DxCategory = 'Insomnia'
		  ,DistinctCount = COUNT(DISTINCT d.MVIPersonSID)
	INTO  #InsomniaPatientCount
	FROM #AllInsomniaDX AS d WITH (NOLOCK) --only goes back 366 days from today
	INNER JOIN [Present].[StationAssignments] AS s WITH (NOLOCK) ON d.MVIPersonSID = s.MVIPersonSID
	INNER JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK) ON c.ChecklistID = s.ChecklistID
	GROUP BY GROUPING SETS (
		 (c.VISN, s.ChecklistID) --Unique patient count by diagnosis at facility level
		,(VISN) --Unique patient count by diagnosis at VISN level
		,() --Unique patient count by diagnosis at national level
		);
	--159

--Get unique patient count by relevant diagnosis (need unique count at facility, VISN, and national levels)
--Using Present.Diagnosis results in slight mismatch of dates e.g. EBP Cohort Dates 6/01/21 to 6/30/22, but code runs on 7/10/22 and DX data goes from 07/10/21 to 7/10/22. 
--Still display a full year of Dx data, but 10 days later than the facility cohort.

DROP TABLE IF EXISTS #DiagnosisPatientCount;
SELECT VISN = ISNULL(c.VISN,0)
	  ,StaPa = ISNULL(s.ChecklistID, ISNULL(CAST(c.VISN AS VARCHAR),'0'))
	  ,d.DxCategory
	  ,DistinctCount = COUNT(DISTINCT d.MVIPersonSID)
INTO #DiagnosisPatientCount
FROM [Present].[Diagnosis] AS d WITH (NOLOCK) --only goes back 366 days from today
INNER JOIN [Present].[StationAssignments] AS s WITH (NOLOCK) ON d.MVIPersonSID = s.MVIPersonSID
INNER JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK) ON c.ChecklistID = s.ChecklistID
WHERE DxCategory IN ('PTSD', 'Depress', 'SMI', 'SUDDx_poss')
AND (d.Outpat = 1 OR d.Inpat = 1 OR d.DoD = 1)
GROUP BY GROUPING SETS (
	 (c.VISN, s.ChecklistID, d.DxCategory) --Unique patient count by diagnosis at facility level
	,(VISN, DxCategory) --Unique patient count by diagnosis at VISN level
	,(DxCategory) --Unique patient count by diagnosis at national level
	);

DROP TABLE IF EXISTS #CombinedPatientCount;
SELECT VISN 
	  ,StaPa 
	  ,DxCategory
	  ,DistinctCount
INTO  #CombinedPatientCount
FROM #InsomniaPatientCount
UNION ALL
SELECT VISN 
	  ,StaPa 
	  ,DxCategory
	  ,DistinctCount
FROM  #DiagnosisPatientCount
;	--795

--Pivot data to have each patient-diagnosis count in 1 row per facility/visn/national
DROP TABLE IF EXISTS #FacilityDx;
SELECT VISN
	  ,StaPa
	  ,PTSD
	  ,Depress
	  ,SMI
	  ,SUDDx_poss AS SUD
	  ,Insomnia
INTO #FacilityDX
FROM (
	SELECT VISN
	,StaPa
	,DxCategory
	,DistinctCount
	FROM #CombinedPatientCount
	) AS SourceTable
PIVOT (MAX(DistinctCount)
	FOR DxCategory IN ([PTSD], [Depress], [SMI], [SUDDx_poss],[Insomnia])  
	) pvt
	;	--159

-- Join EBP template, PTSD, Depression & SMI Facility Tables
DROP TABLE IF EXISTS #EBP_DashboardBaseTable;
SELECT DISTINCT a.StaPa
	,a.VISN
	,TemplateGroup =CASE WHEN a.TemplateGroup like 'AnyDepressionTemplate' THEN 'AnyDepTemplate' --FOR NOW SO I DON'T HAVE TO UPDATE SSRS REPORT
						WHEN a.TemplateGroup like 'AnySuicidePreventionTemplate' THEN 'AnySPTemplate' 
						WHEN a.TemplateGroup like 'EBP_ACT_Template' THEN 'MH_ACT_Template' 
						WHEN a.TemplateGroup like 'EBP_BFT_Template' THEN 'MH_BFT_Template' 
						WHEN a.TemplateGroup like 'EBP_CBSUD_Template' THEN 'MH_CB_SUD_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTD_Template' THEN 'MH_CBT_D_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTI_Template' THEN 'MH_CBT_I_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTSP_Template' THEN 'MH_CBTSP_Template' 
						WHEN a.TemplateGroup like 'EBP_CM_Template' THEN 'MH_CM_Template' 
						WHEN a.TemplateGroup like 'EBP_CPT_Template' THEN 'MH_CPT_Template' 
						WHEN a.TemplateGroup like 'EBP_DBT_Template' THEN 'MH_DBT_Template' 
						WHEN a.TemplateGroup like 'EBP_EMDR_Template' THEN 'MH_EMDR_Template' 
						WHEN a.TemplateGroup like 'EBP_IBCT_Template' THEN 'MH_IBCT_Template' 
						WHEN a.TemplateGroup like 'EBP_IPT_Template' THEN 'MH_IPT_For_Depression' 
						WHEN a.TemplateGroup like 'EBP_PEI_Template' THEN 'MH_PEI_Template' 
						WHEN a.TemplateGroup like 'EBP_PST_Template' THEN 'MH_PST_Template' 
						WHEN a.TemplateGroup like 'EBP_SST_Template' THEN 'MH_SST_Template'
						WHEN a.TemplateGroup like 'EBP_WNE_Template' THEN 'MH_WET_Template'
						ELSE a.TemplateGroup END	
	,a.TemplateCount
	,b.PTSD AS PTSDKey
	,b.Depress AS DepKey
	,b.SMI AS SMIKey
	,b.SUD AS SUDKey
	,b.Insomnia AS InsomniaKey
	,a.LocationOfFacility
	,c.AdmParent_FCDM
INTO #EBP_DashboardBaseTable
FROM #FinalAllLevels AS a
INNER JOIN #FacilityDX AS b ON a.StaPa = b.StaPa
INNER JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK) ON c.StaPa = a.StaPa
;

	/*-----------
	Unpivot format for final staging table/dashboard display
		-----------*/
		
DROP TABLE IF EXISTS #StageEBP;
SELECT  d.StaPa
	,d.[VISN]
	,d.[PTSDKey]
	,d.[DepKey]
	,d.[SMIKey]
	,d.[SUDKey]
	,d.[InsomniaKey]
	,d.AdmParent_FCDM
	,LocationOfFacility = CASE WHEN d.LocationOfFacility IS NULL THEN d.AdmParent_FCDM ELSE LTRIM(d.LocationOfFacility) END
	,TemplateName 					
	,TemplateValue = d.TemplateCount
	,l.TemplateNameClean
	,l.TemplateNameShort
	,UpdateDate = CONVERT(VARCHAR(10),GETDATE(),110)
INTO #StageEBP 
FROM #EBP_DashboardBaseTable AS d
LEFT JOIN [Config].[EBP_TemplateLookUp] AS l WITH (NOLOCK) ON l.TemplateName = d.TemplateGroup
;

EXEC [Maintenance].[PublishTable] '[EBP].[DashboardBaseTableSummary]','#StageEBP';

/* FINAL CHECKS

Last 12 Months: includes unique patients whose care was documented using indicated template with 2+ sessions documented. 

Counts should match
select * from #StageEBP where stapa like '517' and TemplateName like 'AnyEBP%'
select count(distinct patientsid) from #2visitscohort where stapa like '517' and visitdatetime >= '2021-07-01 00:00:00'

select count(distinct stapa) from #StageEBP
--159

*/

------------------------------------------
-- SECTION III: MONTHLY FACILITY COUNTS --
------------------------------------------
--Monthly patient counts do not require 2+ visits

-----------------------------------------------------
--ROLL UP TO CHECKLIST ID LEVEL
-----------------------------------------------------
/* for testing code
DECLARE @EndDate DATE = (
		SELECT (CAST([DATE] AS DATE)) AS DATE
		FROM [Dim].[Date]
		WHERE DayofMonth=1
			AND CalendarYear = (
				SELECT DISTINCT CalendarYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				)
			AND MonthOfYear = (
				SELECT DISTINCT MonthOfYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				));
PRINT @EndDate

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;
--*/

--Select distinct patients, by facility, by year, by month
DROP TABLE IF EXISTS #DistinctPatientsByMonth;
SELECT DISTINCT PatientICN
	,MVIPersonSID
	,PatientSID
	,VISN
	,Sta3n
	,Sta6a
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,TemplateGroup = CASE WHEN TemplateGroup='EBP_EMDR_Tracker' THEN 'EBP_EMDR_Template'
						WHEN TemplateGroup ='EBP_WET_Tracker' then 'EBP_WNE_Template' ELSE TemplateGroup END
	,DiagnosticGroup
	,AnyEBPTemplate = 1
INTO #DistinctPatientsByMonth
FROM [EBP].[TemplateVisits] WITH (NOLOCK)
WHERE 1=1
	AND VisitDateTime >= @OneYearAgo and VisitDateTime<@EndDate
	AND VISN IS NOT NULL		--because used for grouping purposes and null values cause problems
	AND StaPa IS NOT NULL		--because used for grouping purposes and null values cause problems
	AND StaPa NOT LIKE '%*%'	--because used for grouping purposes and null values cause problems
	AND TemplateGroup not like 'EBP_BET%'			-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_CBTPTSD%'		-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_CPT_Tracker'	-- not being displayed on the dashboard yet
	AND TemplateGroup not like 'EBP_PE_Tracker'		-- not being displayed on the dashboard yet

----Sum counts of patients by TEMPLATE, by FACILITY, by year, by month
DROP TABLE IF EXISTS #FacilityMonth;
SELECT VISN
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,TemplateGroup
	,DiagnosticGroup
	,PatientCount = COUNT(DISTINCT MVIPersonSID)
INTO #FacilityMonth
FROM #DistinctPatientsByMonth
GROUP BY StaPa,TemplateGroup,DiagnosticGroup,AdmParent_FCDM, VISN, [Month], [Year]
;	

----Sum counts of patients by TEMPLATE, by VISN, by year, by month
DROP TABLE IF EXISTS #VISNmonth;
SELECT VISN
	,StaPa = CAST(VISN as varchar)
	,AdmParent_FCDM =  CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,[Month]
	,[Year]
	,TemplateGroup
	,DiagnosticGroup
	,PatientCount = COUNT(DISTINCT MVIPersonSID)
INTO #VISNmonth
FROM #DistinctPatientsByMonth
GROUP BY VISN,TemplateGroup,DiagnosticGroup, [Month], [Year]
;	

----Sum counts of patients by DIAGNOSIS, by FACILITY, by year, by month
DROP TABLE IF EXISTS #FacilityMonthDX;
SELECT VISN
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
	,PatientCount = SUM(PatientCount)
INTO #FacilityMonthDX
FROM #FacilityMonth
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family'
GROUP BY StaPa,DiagnosticGroup,AdmParent_FCDM, VISN, [Month], [Year]
;

----Sum counts of patients by DIAGNOSIS, by VISN, by year, by month
DROP TABLE IF EXISTS #VISNMonthDX;
SELECT VISN
	,StaPa = CAST(VISN as varchar)
	,AdmParent_FCDM = CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,[Month]
	,[Year]
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
	,PatientCount = SUM(PatientCount)
INTO #VISNMonthDX
FROM #VISNMonth
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family'
GROUP BY VISN,DiagnosticGroup, [Month], [Year]
;	

----Sum counts of patients by TEMPLATE, NATIONAL, by year, by month
DROP TABLE IF EXISTS #NatMonth;
SELECT VISN = 0
	,StaPa = '0'
	,AdmParent_FCDM = 'National'
	,[Month]
	,[Year]
	,TemplateGroup
	,PatientCount = SUM(PatientCount)
INTO #NatMonth
FROM #FacilityMonth
GROUP BY TemplateGroup,[Month], [Year]
;	

DROP TABLE IF EXISTS #NatMonthDX;
SELECT VISN = 0
	,StaPa = '0'
	,AdmParent_FCDM = 'National'
	,[Month]
	,[Year]
	,TemplateGroup = CONCAT('Any',DiagnosticGroup,'Template')
	,PatientCount = SUM(PatientCount)
INTO #NatMonthDX
FROM #FacilityMonth
WHERE DiagnosticGroup NOT LIKE 'Insomnia' AND DiagnosticGroup NOT LIKE 'Family'
GROUP BY DiagnosticGroup, [Month], [Year]
;

-- Sum counts of ALL TEMPLATES by FACILITY 
DROP TABLE IF EXISTS #AnyFacilityMonth;
SELECT VISN
	,StaPa
	,AdmParent_FCDM
	,[Month]
	,[Year]
	,TemplateGroup = 'AnyEBPTemplate'
	,PatientCount = SUM(PatientCount)
INTO #AnyFacilityMonth
FROM #FacilityMonth
GROUP BY StaPa,AdmParent_FCDM, VISN, [Month], [Year]
;

-- Sum counts of ALL TEMPLATES by VISN 
DROP TABLE IF EXISTS #AnyVISNmonth;
SELECT VISN
	,StaPa = CAST(VISN as varchar)
	,AdmParent_FCDM =  CASE WHEN VISN <10 THEN CONCAT('V0',VISN) WHEN VISN >9 THEN CONCAT('V',VISN) ELSE NULL END
	,[Month]
	,[Year]
	,TemplateGroup = 'AnyEBPTemplate'
	,PatientCount = SUM(PatientCount)
INTO #AnyVISNmonth
FROM #VISNMonth
GROUP BY VISN, [Month], [Year]
;

DROP TABLE IF EXISTS #NatMonthAny;
SELECT VISN = 0
	,StaPa = '0'
	,AdmParent_FCDM = 'National'
	,[Month]
	,[Year]
	,TemplateGroup = 'AnyEBPTemplate'
	,PatientCount = SUM(PatientCount)
INTO #NatMonthAny
FROM #FacilityMonth
GROUP BY [Month], [Year]
;

--Combine all monthly levels
DROP TABLE IF EXISTS #AllMonthLevels;
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount INTO #AllMonthLevels FROM #FacilityMonth
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #VISNmonth
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #FacilityMonthDX
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #VISNMonthDX
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #NatMonth
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #NatMonthDX
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #AnyFacilityMonth
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #AnyVISNMonth
UNION ALL
SELECT VISN,StaPa,AdmParent_FCDM,[Month],[Year],TemplateGroup,PatientCount FROM #NatMonthAny
--

----Pull in any facilities with no data and asign them a zero 

	--Get every possible combination of StaPa, Month, Year to join in next step
	DROP TABLE IF EXISTS #combMonth;
	SELECT DISTINCT d.VISN
		,d.StaPa
		,d.AdmParent_FCDM
		,a.TemplateGroup
		,d.LocationOfFacility
		,f.[Month]
		,f.[Year]
	INTO #combMonth
	FROM (SELECT b.VISN,b.StaPa,b.AdmParent_FCDM,c.[LOCATION OF FACILITY] as LocationOfFacility
			FROM [LookUp].[ChecklistID] as b  WITH (NOLOCK)
	LEFT JOIN  [LookUp].[SpatialData] as c WITH (NOLOCK)
	ON b.ChecklistID = c.ChecklistID) AS d
		,(SELECT DISTINCT TemplateGroup FROM #2VisitsCohort			--14 Templates
		UNION
		SELECT DISTINCT TemplateGroup FROM #DXgroupFacility			--5 Dx Groups
		UNION
		SELECT DISTINCT TemplateGroup FROM #EBPTemplateFacilityAny	--1 AnyEBPTemplate 
		) AS a 
		,(SELECT DISTINCT [Month], [Year] 
		  FROM #DistinctPatientsByMonth) AS f --13 months
;
	--38,160 = (140 facilities + 18 VISN + 1 National) * 20 Template Groups * 12 months
	--select * FROM #combMonth ORDER BY StaPa

DROP TABLE IF EXISTS #FinalMonth;
SELECT DISTINCT 
	 a.VISN
	,a.StaPa
	,a.AdmParent_FCDM
	,a.LocationOfFacility
	,a.[Month]
	,a.[Year]
	,TemplateGroup = 	CASE WHEN a.TemplateGroup like 'AnyDepressionTemplate' THEN 'AnyDepTemplate' --FOR NOW SO I DON'T HAVE TO UPDATE SSRS REPORT
						WHEN a.TemplateGroup like 'AnySuicidePreventionTemplate' THEN 'AnySPTemplate' 
						WHEN a.TemplateGroup like 'EBP_ACT_Template' THEN 'MH_ACT_Template' 
						WHEN a.TemplateGroup like 'EBP_BFT_Template' THEN 'MH_BFT_Template' 
						WHEN a.TemplateGroup like 'EBP_CBSUD_Template' THEN 'MH_CB_SUD_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTD_Template' THEN 'MH_CBT_D_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTI_Template' THEN 'MH_CBT_I_Template' 
						WHEN a.TemplateGroup like 'EBP_CBTSP_Template' THEN 'MH_CBTSP_Template' 
						WHEN a.TemplateGroup like 'EBP_CM_Template' THEN 'MH_CM_Template' 
						WHEN a.TemplateGroup like 'EBP_CPT_Template' THEN 'MH_CPT_Template' 
						WHEN a.TemplateGroup like 'EBP_DBT_Template' THEN 'MH_DBT_Template' 
						WHEN a.TemplateGroup like 'EBP_EMDR_Template' THEN 'MH_EMDR_Template' 
						WHEN a.TemplateGroup like 'EBP_IBCT_Template' THEN 'MH_IBCT_Template' 
						WHEN a.TemplateGroup like 'EBP_IPT_Template' THEN 'MH_IPT_For_Depression' 
						WHEN a.TemplateGroup like 'EBP_PEI_Template' THEN 'MH_PEI_Template' 
						WHEN a.TemplateGroup like 'EBP_PST_Template' THEN 'MH_PST_Template' 
						WHEN a.TemplateGroup like 'EBP_SST_Template' THEN 'MH_SST_Template' 
						WHEN a.TemplateGroup like 'EBP_WNE_Template' THEN 'MH_WET_Template'
						ELSE a.TemplateGroup END	
	,TemplateCount=ISNULL(b.PatientCount,0)
INTO #FinalMonth
FROM #combMonth AS a
LEFT JOIN #AllMonthLevels AS b 
	ON a.StaPa = b.StaPa
	AND a.[Month] = b.[Month] AND a.[Year] = b.[Year] 
	AND a.TemplateGroup = b.TemplateGroup
 ;
 --select * FROM #FinalMonth ORDER BY StaPa

-----------------------------------------------------
--PIVOT FINAL TABLE
-----------------------------------------------------

-- Fill in missing Locations and add fields for Template Names

DROP TABLE IF EXISTS #complete;
SELECT 
     u.VISN
	,u.StaPa
    ,u.AdmParent_FCDM
	,LocationOfFacility = CASE WHEN u.LocationOfFacility IS NULL THEN u.ADMPARENT_FCDM 
		ELSE LTRIM(u.LocationOfFacility) END
	,Year = CAST([Year] AS VARCHAR(4))
	,Month = CAST(DATENAME(mm, DATEADD(mm, [Month]-1,0)) AS VARCHAR(10))
	,[Date]=DATEFROMPARTS([Year],[Month],1)
	,TemplateName = u.TemplateGroup
	,TemplateValue = u.TemplateCount
	,t.TemplateNameClean
	,t.TemplateNameShort
INTO #complete
FROM #FinalMonth AS u
LEFT JOIN [Config].[EBP_TemplateLookUp] AS t WITH (NOLOCK) ON t.TemplateName = u.TemplateGroup
;
--select distinct month from #complete order by stapa, TemplateName

EXEC [Maintenance].[PublishTable] '[EBP].[FacilityMonthly]','#complete';

-----------------------------------
--SECTION IV: CLINICIAN REPORTS --
-----------------------------------
/*DECLARE @EndDate DATE = (
		SELECT (CAST([DATE] AS DATE)) AS DATE
		FROM [Dim].[Date]
		WHERE DayofMonth=1
			AND CalendarYear = (
				SELECT DISTINCT CalendarYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				)
			AND MonthOfYear = (
				SELECT DISTINCT MonthOfYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				));
PRINT @EndDate

DECLARE @ClinicianStartDate DATE = DATEADD(yy,-2,@EndDate);
PRINT @ClinicianStartDate;

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;
--*/ -- for testing code

--Adds additional provider info from Outpat tables to distinct visits from initial visit cohort so none are lost due to unknown provider info
DROP TABLE IF EXISTS #ClinicianCohort;
SELECT DISTINCT a.PatientICN
	,a.MVIPersonSID
	,a.PatientSID
	,a.Sta3n
	,a.VisitSID
	,a.VisitDateTime
	,DATENAME(MONTH,a.VisitDateTime) AS [Month]
	,YEAR(a.VisitDateTime) AS [Year]
	,ReportingPeriod=CONCAT(DATENAME(MONTH,a.VisitDateTime),'-',YEAR(a.VisitDateTime))
	,a.EncounterStaffSID
	,'EncounterStaffSIDExists' = CASE WHEN EncounterStaffSID = -1 THEN 0 ELSE 1 END
	,p.ProviderSID
	,'ProviderSIDExists' = CASE WHEN p.ProviderSID IS NULL THEN 0 ELSE 1 END
	,v.CreatedByStaffSID  --always exists for every VisitSID
	,a.TemplateGroup
	,a.DiagnosticGroup
	,a.LocationSID
	,a.Sta6a
	,a.StaPa
	,a.VISN
	,a.AdmParent_FCDM
INTO #ClinicianCohort
FROM #DistinctVisits AS a
LEFT JOIN  [Outpat].[VProvider] AS p WITH (NOLOCK) ON a.VisitSID = p.VisitSID
LEFT JOIN  [Outpat].[Visit] AS v WITH (NOLOCK) ON a.VisitSID = v.VisitSID
WHERE 1=1
		AND a.VisitDateTime >= @ClinicianStartDate and a.VisitDateTime<@EndDate
		AND Cerner = 0
;		

/*Assigns StaffSID to Visit in the following order: 
1) ProviderSID from Outpat.VProvider if exists, 
2) EncounterStaffSID from HF.HealthFactor if exists, 
3) CreatedbyStaffSID from Outpat.Visit otherwise (always exists)*/
DROP TABLE IF EXISTS #ClinicianSID;
SELECT PatientICN
	,MVIPersonSID
	,PatientSID
	,Sta3n 
	,VisitSID
	,VisitDateTime
	,[Month]
	,[Year]
	,ReportingPeriod
	,StaffSID = CASE WHEN ProviderSIDExists=0 AND EncounterStaffSIDExists=0 THEN CreatedByStaffSID
					 WHEN  ProviderSIDExists=0 AND EncounterStaffSIDExists=1 THEN EncounterStaffSID
					 WHEN ProviderSIDExists=1 THEN ProviderSID END
	,StaffSIDType = CASE WHEN ProviderSIDExists=0 AND EncounterStaffSIDExists=0 THEN 'CreatedByStaffSID'
						 WHEN ProviderSIDExists=0 AND EncounterStaffSIDExists=1 THEN 'EncounterStaffSID'
						 WHEN ProviderSIDExists=1 THEN 'ProviderSID' END
	,TemplateGroup
	,DiagnosticGroup
	,LocationSID
	,Sta6a
	,StaPa
	,VISN
	,AdmParent_FCDM
INTO #ClinicianSID
FROM #ClinicianCohort
;

--adds Clinician Info
DROP TABLE IF EXISTS #ClinicianCumulative;
SELECT a.*
	,e.StaffSSN
	,'ClinicianLastName' = CASE WHEN e.LastName IS NULL OR (e.LastName LIKE 'POSTMASTER' AND e.FirstName IS NULL) THEN 'UNKNOWN' ELSE e.LastName END
	,'ClinicianFirstName' = CASE WHEN e.FirstName IS NULL THEN 'UNKNOWN' ELSE e.FirstName END
	,e.MiddleName AS 'ClinicianMiddleName'
	,e.PositionTitle
INTO #ClinicianCumulative
FROM #ClinicianSID AS a
INNER JOIN [SStaff].[SStaff] e WITH (NOLOCK) ON a.StaffSID = e.StaffSID
;

DROP TABLE IF EXISTS #CernerClinicianCohort;
SELECT DISTINCT a.PatientICN
	,a.MVIPersonSID
	,a.PatientSID
	,a.Sta3n
	,a.VisitSID
	,a.VisitDateTime
	,DATENAME(MONTH,a.VisitDateTime) AS [Month]
	,YEAR(a.VisitDateTime) AS [Year]
	,ReportingPeriod=CONCAT(DATENAME(MONTH,a.VisitDateTime),'-',YEAR(a.VisitDateTime))
	,StaffSID = v.ResultPerformedPersonStaffSID
	,StaffSIDType = 'Cerner'
	,a.TemplateGroup
	,a.DiagnosticGroup
	,a.LocationSID
	,a.Sta6a
	,a.StaPa
	,a.VISN
	,a.AdmParent_FCDM
	,StaffSSN = p.PersonSSN
	,'ClinicianLastName' = p.NameLast--CASE WHEN p.NameLast IS NULL OR (p.NameLast LIKE 'POSTMASTER' AND e.FirstName IS NULL) THEN 'UNKNOWN' ELSE e.LastName END
	,'ClinicianFirstName' = p.NameFirst--CASE WHEN e.FirstName IS NULL THEN 'UNKNOWN' ELSE e.FirstName END
	,'ClinicianMiddleName' = NULL
	,PositionTitle = t.Classification
INTO #CernerClinicianCohort
FROM #DistinctVisits AS a
LEFT JOIN (SELECT p.EncounterSID, p.ResultPerformedPersonStaffSID, p.TZFormUTCDateTime ,l.List,p.StaPa
			FROM [Cerner].[FactPowerForm] p WITH (NOLOCK) 
			INNER JOIN Lookup.ListMember l WITH (NOLOCK)  
				ON p.DerivedDtaEventCodeValueSID = l.ItemID
				AND p.DerivedDtaEventResult = l.AttributeValue
	)AS v 
		ON a.VisitSID = v.EncounterSID 
 		AND a.VisitDateTime=v.TZFormUTCDateTime
		AND v.List = a.TemplateGroup
LEFT JOIN  [Cerner].[FactStaffDemographic] AS p WITH (NOLOCK) 
		ON v.ResultPerformedPersonStaffSID = p.PersonStaffSID
LEFT JOIN [Cerner].[FactStaffProviderType] as t WITH (NOLOCK) 
		ON v.ResultPerformedPersonStaffSID = t.PersonStaffSID
		AND a.VisitDateTime BETWEEN t.BeginEffectiveDateTime AND ISNULL(t.EndEffectiveDateTime,getdate())
WHERE 1=1
		AND a.VisitDateTime >= @ClinicianStartDate and a.VisitDateTime<@EndDate
		AND Cerner = 1	

--COMBINE CERNER AND VISTA DATA
--Clinician info, Patients for each clinician and number of sessions by template
DROP TABLE IF EXISTS #ClinicianCumulative_VM;
SELECT PatientICN
	,MVIPersonSID
	,StaffSSN
	,StaffSID
	,VisitSID
	,VisitDateTime
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName = CAST(ClinicianMiddleName AS VARCHAR)
	,PositionTitle
	,TemplateGroup
	INTO #ClinicianCumulative_VM
	FROM #ClinicianCumulative

	UNION ALL

SELECT PatientICN
	,MVIPersonSID
	,StaffSSN
	,StaffSID
	,VisitSID
	,VisitDateTime
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName = CAST(ClinicianMiddleName AS VARCHAR)
	,PositionTitle
	,TemplateGroup
	FROM #CernerClinicianCohort
;

--Clinician info, Patients for each clinician and number of sessions by template
DROP TABLE IF EXISTS #CliniciansMasterFile;
SELECT PatientICN
	,MVIPersonSID
	,StaffSSN
	,StaffSID
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,'TotalSessions' = COALESCE(COUNT(CASE WHEN VisitSID IS NOT NULL THEN 1 END), 0)
INTO #CliniciansMasterFile
FROM #ClinicianCumulative_VM
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,MVIPersonSID
	,PatientICN
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
ORDER BY ClinicianLastName
;

---------------------
-- 	Clinicians info with total # SESSIONS & total PATIENTS using any EBP template type
---------------------
DROP TABLE IF EXISTS #MonthlyTotalSessionsAndPatients;	
SELECT StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
	,'TotalSessions' = COALESCE(SUM(CASE WHEN TotalSessions IS NOT NULL THEN TotalSessions END), 0)
	,'TotalPatients' = COUNT(MVIPersonSID)
INTO #MonthlyTotalSessionsAndPatients
FROM #CliniciansMasterFile
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
ORDER BY ClinicianLastName
;	


-- 	Clinicians info with # SESSIONS for EACH kind of EBP Template
---------------------
DROP TABLE IF EXISTS #SessionsAndPatientsByEBPType;	
SELECT StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
	,'TotalSessions' = COALESCE(SUM(CASE WHEN TotalSessions IS NOT NULL THEN TotalSessions END), 0) 
	,'TotalPatients' = COUNT(MVIPersonSID)
INTO #SessionsAndPatientsByEBPType
FROM #CliniciansMasterFile 
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,[Month]
	,[Year]
	,ReportingPeriod
ORDER BY ClinicianLastName
;	

---------------------
-- 	Monthly Summary table 
---------------------
DROP TABLE IF EXISTS #StageClinicianMonthly;
SELECT DISTINCT
	 b.ClinicianLastName
	,b.ClinicianFirstName
	,b.ClinicianMiddleName
	,c.StaffSID
	,c.StaffSSN
	,b.VISN
	,b.AdmParent_FCDM
	,b.Sta3n
	,b.StaPa
	,b.ReportingPeriod
	,b.[Month]
	,b.[Year]
	,'TotalSessionsAllEBPs' = b.TotalSessions
	,'TotalPatientsAllEBPs' = b.TotalPatients
	,'MH_ACT_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_ACT_Template' THEN a.TotalSessions	ELSE 0 END)
	,'MH_ACT_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_ACT_Template' THEN a.TotalPatients	ELSE 0 END)
	,'MH_BFT_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_BFT_Template' THEN a.TotalSessions	ELSE 0 END)
	,'MH_BFT_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_BFT_Template' THEN a.TotalPatients	ELSE 0 END)
	,'MH_CB_SUD_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBSUD_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_CB_SUD_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBSUD_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_CBT_D_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTD_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_CBT_D_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTD_Template' THEN a.TotalPatients	ELSE 0 END)
	,'MH_CBT_I_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTI_Template' THEN a.TotalSessions	ELSE 0 END)
	,'MH_CBT_I_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTI_Template' THEN a.TotalPatients	ELSE 0 END)
	,'MH_CBTSP_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTSP_Template' THEN a.TotalSessions	ELSE 0 END) 
	,'MH_CBTSP_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CBTSP_Template' THEN a.TotalPatients ELSE 0 END) 
	,'MH_CM_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CM_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_CM_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CM_Template' THEN a.TotalPatients ELSE 0 END) 
	,'MH_CPT_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CPT_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_CPT_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_CPT_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_DBT_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_DBT_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_DBT_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_DBT_Template' THEN a.TotalPatients ELSE 0 END) 
	,'MH_EMDR_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_EMDR_Template' THEN a.TotalSessions ELSE 0 END)	
	,'MH_EMDR_Patients' = MAX(CASE WHEN a.TemplateGroup like 'EBP_EMDR_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_IBCT_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_IBCT_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_IBCT_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_IBCT_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_IPT_For_Dep_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_IPT_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_IPT_For_Dep_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_IPT_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_PEI_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_PEI_Template' THEN a.TotalSessions	ELSE 0 END)
	,'MH_PEI_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_PEI_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_PST_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_PST_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_PST_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_PST_Template' THEN a.TotalPatients ELSE 0 END) 
 	,'MH_SST_Sessions' = MAX(CASE WHEN a.TemplateGroup = 'EBP_SST_Template' THEN a.TotalSessions	ELSE 0 END)
	,'MH_SST_Patients' = MAX(CASE WHEN a.TemplateGroup = 'EBP_SST_Template' THEN a.TotalPatients ELSE 0 END)
	,'MH_WET_Sessions' = MAX(CASE WHEN a.TemplateGroup like 'EBP_WNE_Template' THEN a.TotalSessions ELSE 0 END)
	,'MH_WET_Patients' = MAX(CASE WHEN a.TemplateGroup like 'EBP_WNE_Template' THEN a.TotalPatients ELSE 0 END) 
	,Clinician = CONCAT(b.ClinicianLastName, ', ',  b.ClinicianFirstName, ' ' , b.ClinicianMiddleName)
INTO #StageClinicianMonthly
FROM #SessionsAndPatientsByEBPType AS a 
LEFT JOIN #MonthlyTotalSessionsAndPatients AS b ON a.StaffSID = b.StaffSID and a.StaPa=b.StaPa 
INNER JOIN #ClinicianCumulative_VM AS c ON a.StaffSID = c.StaffSID AND a.ReportingPeriod=b.ReportingPeriod
GROUP BY 
	b.ClinicianLastName
	,b.ClinicianFirstName
	,b.ClinicianMiddleName
	,c.StaffSID
	,c.StaffSSN
	,b.Totalpatients
	,b.TotalSessions
	,b.VISN
	,b.admparent_fcdm
	,b.Sta3n
	,b.StaPa
	,b.Reportingperiod
	,b.[Month]
	,b.[Year]
;

---------------------
-- 	YTD Summary table
---------------------
/*DECLARE @EndDate DATE = (
		SELECT (CAST([DATE] AS DATE)) AS DATE
		FROM [Dim].[Date]
		WHERE DayofMonth=1
			AND CalendarYear = (
				SELECT DISTINCT CalendarYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				)
			AND MonthOfYear = (
				SELECT DISTINCT MonthOfYear
				FROM [Dim].[Date]
				WHERE DATE = CAST(GETDATE() AS DATE)
				));
PRINT @EndDate

DECLARE @ClinicianStartDate DATE = DATEADD(yy,-2,@EndDate);
PRINT @ClinicianStartDate;

DECLARE @OneYearAgo DATE;
SET @OneYearAgo  = DATEADD(mm, -12, @EndDate);
PRINT @OneYearAgo;
--*/ -- for testing code

--YTD Clinician info, Patients for each clinician and number of sessions by template
DROP TABLE IF EXISTS #YTDCliniciansMasterFile;
SELECT PatientICN
	,MVIPersonSID
	,StaffSSN
	,StaffSID
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,'TotalSessions' = COALESCE(COUNT(CASE WHEN VisitSID IS NOT NULL THEN 1 END), 0)
INTO #YTDCliniciansMasterFile
FROM #ClinicianCumulative_VM
WHERE VisitDateTime >= @OneYearAgo and VisitDateTime<@EndDate
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,MVIPersonSID
	,PatientICN
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
ORDER BY ClinicianLastName
;

DROP TABLE IF EXISTS #YTDTotalSessionsAndPatients;	
SELECT StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,'TotalSessions' = COALESCE(SUM(CASE WHEN TotalSessions IS NOT NULL THEN TotalSessions END), 0)
	,'TotalPatients' = COUNT(DISTINCT(MVIPersonSID))
INTO #YTDTotalSessionsAndPatients
FROM #YTDCliniciansMasterFile
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
ORDER BY ClinicianLastName
;	--8714

DROP TABLE IF EXISTS #YTDSessionsAndPatientsByEBPType;	
SELECT StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
	,'TotalSessions' = COALESCE(SUM(CASE WHEN TotalSessions IS NOT NULL THEN TotalSessions END), 0) 
	,'TotalPatients' = COUNT(MVIPersonSID)
INTO #YTDSessionsAndPatientsByEBPType
FROM #YTDCliniciansMasterFile 
GROUP BY StaffSSN
	,StaffSID
	,ClinicianLastName
	,ClinicianFirstName
	,ClinicianMiddleName
	,PositionTitle
	,TemplateGroup
	,VISN
	,AdmParent_FCDM
	,Sta3n
	,StaPa
ORDER BY ClinicianLastName
;

DROP TABLE IF EXISTS #EBP_DashboardBaseTable_Clinician;
SELECT DISTINCT 
	 a.ClinicianLastName
	,a.ClinicianFirstName
	,a.ClinicianMiddleName
	,a.StaffSSN
	,c.StaffSID
	,a.VISN
	,a.AdmParent_FCDM
	,a.Sta3n
	,a.StaPa
	,ReportingPeriod = 'YTD'
	,[Month] = 'null'
	,[Year] = NULL
	,'TotalSessionsAllEBPs' = a.TotalSessions
	,'TotalPatientsAllEBPs' = a.TotalPatients
	,'MH_ACT_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_ACT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_ACT_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_ACT_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_BFT_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_BFT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_BFT_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_BFT_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_CB_SUD_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBSUD_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CB_SUD_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBSUD_Template' THEN b.TotalPatients  ELSE 0 END)
	,'MH_CBT_D_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTD_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CBT_D_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTD_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_CBT_I_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTI_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CBT_I_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTI_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_CBTSP_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTSP_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CBTSP_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CBTSP_Template' THEN b.TotalPatients  ELSE 0 END)
	,'MH_CM_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CM_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CM_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CM_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_CPT_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CPT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_CPT_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_CPT_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_DBT_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_DBT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_DBT_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_DBT_Template' THEN b.TotalPatients  ELSE 0 END)
	,'MH_EMDR_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_EMDR_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_EMDR_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_EMDR_Template' THEN b.TotalPatients  ELSE 0 END)
	,'MH_IBCT_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_IBCT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_IBCT_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_IBCT_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_IPT_For_Dep_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_IPT_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_IPT_For_Dep_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_IPT_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_PEI_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_PEI_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_PEI_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_PEI_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_PST_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_PST_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_PST_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_PST_Template' THEN b.TotalPatients  ELSE 0 END)
	,'MH_SST_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_SST_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_SST_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_SST_Template' THEN b.TotalPatients ELSE 0 END)
	,'MH_WET_Sessions' = MAX(CASE WHEN b.TemplateGroup = 'EBP_WNE_Template' THEN b.TotalSessions ELSE 0 END)
	,'MH_WET_Patients' = MAX(CASE WHEN b.TemplateGroup = 'EBP_WNE_Template' THEN b.TotalPatients  ELSE 0 END)
	,Clinician = 'TempClinicianNameToBeUpdatedLater'
INTO #EBP_DashboardBaseTable_Clinician
FROM #YTDTotalSessionsAndPatients AS a
INNER JOIN #YTDSessionsAndPatientsByEBPType AS b ON a.StaffSID = b.StaffSID and a.StaPa=b.StaPa
INNER JOIN #ClinicianCumulative_VM AS c ON a.StaffSID = c.StaffSID
GROUP BY 
	 a.ClinicianLastName
	,a.ClinicianFirstName
	,a.ClinicianMiddleName
	,a.StaffSSN
	,c.StaffSID
	,a.VISN
	,a.AdmParent_FCDM
	,a.Sta3n
	,a.StaPa
	,a.TotalSessions
	,a.TotalPatients
;


---------------------
-- 	Final Summary table includes both YTD and monthly
---------------------
DROP TABLE IF EXISTS #StageClinician
	SELECT ClinicianLastName
		  ,ClinicianFirstName
		  ,ClinicianMiddleName
		  ,StaffSSN
		  ,StaffSID
		  ,VISN
		  ,Admparent_FCDM
		  ,Sta3n
		  ,StaPa
		  ,ReportingPeriod
		  ,[Month]
		  ,[Year]
		  ,'DATE' = CAST(NULL AS DATE)
		  ,TotalSessionsAllEBPs
		  ,TotalPatientsAllEBPs
		  ,MH_ACT_Sessions
		  ,MH_ACT_Patients
		  ,MH_BFT_Sessions
		  ,MH_BFT_Patients
		  ,MH_CB_SUD_Sessions
		  ,MH_CB_SUD_Patients
		  ,MH_CBT_D_Sessions
		  ,MH_CBT_D_Patients
		  ,MH_CBT_I_Sessions
		  ,MH_CBT_I_Patients
		  ,MH_CBTSP_Sessions          
		  ,MH_CBTSP_Patients
		  ,MH_CM_Sessions          
		  ,MH_CM_Patients 
		  ,MH_CPT_Sessions
		  ,MH_CPT_Patients
		  ,MH_DBT_Sessions          
		  ,MH_DBT_Patients
		  ,MH_EMDR_Sessions          
		  ,MH_EMDR_Patients
		  ,MH_IBCT_Sessions
		  ,MH_IBCT_Patients
		  ,MH_IPT_For_Dep_Sessions
		  ,MH_IPT_For_Dep_Patients
		  ,MH_PEI_Sessions
		  ,MH_PEI_Patients
		  ,MH_PST_Sessions
		  ,MH_PST_Patients
		  ,MH_SST_Sessions
		  ,MH_SST_Patients
		  ,MH_WET_Sessions
		  ,MH_WET_Patients
		  ,Clinician
	INTO #StageClinician
	FROM #StageClinicianMonthly AS a
	UNION ALL
	SELECT ClinicianLastName
		  ,ClinicianFirstName
		  ,ClinicianMiddleName
		  ,StaffSSN
		  ,StaffSID
		  ,VISN
		  ,Admparent_FCDM
		  ,Sta3n
		  ,StaPa
		  ,ReportingPeriod
		  ,[Month]
		  ,[Year]
		  ,'DATE' = CAST(NULL AS DATE)
		  ,TotalSessionsAllEBPs
		  ,TotalPatientsAllEBPs
		  ,MH_ACT_Sessions
		  ,MH_ACT_Patients
		  ,MH_BFT_Sessions
		  ,MH_BFT_Patients
		  ,MH_CB_SUD_Sessions
		  ,MH_CB_SUD_Patients
		  ,MH_CBT_D_Sessions
		  ,MH_CBT_D_Patients
		  ,MH_CBT_I_Sessions
		  ,MH_CBT_I_Patients
		  ,MH_CBTSP_Sessions          
		  ,MH_CBTSP_Patients
		  ,MH_CM_Sessions          
		  ,MH_CM_Patients 
		  ,MH_CPT_Sessions
		  ,MH_CPT_Patients
		  ,MH_DBT_Sessions          
		  ,MH_DBT_Patients
		  ,MH_EMDR_Sessions     
		  ,MH_EMDR_Patients
		  ,MH_IBCT_Sessions
		  ,MH_IBCT_Patients
		  ,MH_IPT_For_Dep_Sessions
		  ,MH_IPT_For_Dep_Patients
		  ,MH_PEI_Sessions
		  ,MH_PEI_Patients
		  ,MH_PST_Sessions
		  ,MH_PST_Patients
		  ,MH_SST_Sessions
		  ,MH_SST_Patients
		  ,MH_WET_Sessions
		  ,MH_WET_Patients
		  ,Clinician 
FROM #EBP_DashboardBaseTable_Clinician AS a
;

/* CHECKS
select top 100 * from #stageclinician --for staffsid to enter below

select * from #StageClinician where staffsid='12901616' and reportingperiod like 'April-2022'
select * from #ClinicianSID where staffsid='12901616' and visitdatetime> '2022-04-01 00:00:00' and VisitDateTime < '2022-05-01'
*/

EXEC [Maintenance].[PublishTable] 'EBP.Clinician','#StageClinician';

UPDATE EBP.Clinician
SET Clinician = CONCAT(ClinicianLastName, ', ',  ClinicianFirstName, ' ' , ClinicianMiddleName )  
;
UPDATE EBP.Clinician
SET [Date] = DATEFROMPARTS([Year],MONTH(CONCAT(1,[MONTH],0)),1)
WHERE [Year] IS NOT NULL
;
UPDATE EBP.Clinician
SET [Date] = '2099-12-31'
WHERE ReportingPeriod LIKE 'YTD'
;


/*****************FINAL CHECKS****************
select * from #2VisitsCohort --2 or more visits in past year
select * from #StageEBP --ytd count, left side of dashboard

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients with 2 or more visits in past year
select TemplateGroup, stapa, count(distinct mvipersonsid) as count from #2VisitsCohort where stapa like '613' group by TemplateGroup, stapa
order by templategroup, stapa 

--STaging Facility YTD totals
select * from #StageEBP where stapa like '613' and templatename not like 'any%' order by templatename, stapa 

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients with 2 or more visits in past year
select TemplateGroup, count(distinct mvipersonsid) as count from #2VisitsCohort where visn like '5' group by TemplateGroup, visn
order by templategroup

--STaging VISN YTD totals
select * from #StageEBP where stapa like '5' and templatename not like 'any%' order by templatename, stapa 

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients with 2 or more visits in past year
select DiagnosticGroup, count(distinct mvipersonsid) as count from #2VisitsCohort where visn like '5' group by DiagnosticGroup, visn
order by DiagnosticGroup

--STaging VISN YTD totals
select * from #StageEBP where stapa like '5' and templatename like 'any%' order by templatename, stapa 


select * from #DistinctPatientsByMonth --past year of unique patients by month
select * from #Complete --monthly counts, right side of dashboard

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients by month
select TemplateGroup, stapa,count(distinct MVIPersonSID) as patients from #DistinctPatientsByMonth  
where VISN like '20' and stapa >'20' and month like '8' and year like '2023' group by TemplateGroup, stapa
order by templategroup, stapa

--Staging table monthly VISN 20 facility counts
select * from #Complete where visn like '20' and StaPa > '20' and date like '2023-08-01' and templatevalue >0 and templatename not like 'Any%' order by templatename, stapa

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients by month
select DiagnosticGroup, stapa,count(distinct MVIPersonSID) as patients from #DistinctPatientsByMonth  
where VISN like '20' and stapa >'20' and month like '8' and year like '2023' and diagnosticgroup not like 'family' and DiagnosticGroup not like 'insomnia' group by DiagnosticGroup, stapa
order by DiagnosticGroup, stapa

--Staging table monthly VISN 20 facility counts
select * from #Complete where visn like '20' and StaPa > '20' and date like '2023-08-01' and templatevalue >0 and templatename like 'Any%' order by templatename, stapa


--RUN NEXT 2 TOGETHER TO COMPARE

--Raw table of past year of unique patients by month
select TemplateGroup, stapa,count(distinct MVIPersonSID) as patients from #DistinctPatientsByMonth  
where VISN like '20' and stapa >'20' and month like '8' and year like '2023' group by TemplateGroup, stapa
order by templategroup, stapa

--Staging table monthly VISN 20 counts
select * from #Complete where StaPa like '20' and date like '2023-08-01' order by templatename, stapa

--RUN NEXT 2 TOGETHER TO COMPARE
--Raw table of past year of unique patients by month
select TemplateGroup,DiagnosticGroup,count(distinct MVIPersonSID) as patients from #DistinctPatientsByMonth  
where VISN like '20' and month like '8' and year like '2023' group by TemplateGroup,DiagnosticGroup, visn
order by templategroup, visn

--Staging table monthly VISN 20 counts
select * from #Complete where StaPa like '20' and date like '2023-08-01' order by templatename, stapa


select * from #CernerClinicianCohort where ClinicianLastName like 'blunt'
--select * from #YTDCliniciansMasterFile where ClinicianLastName like 'blunt' order by templategroup
select * from #YTDSessionsAndPatientsByEBPType where ClinicianLastName like 'blunt' --order by templategroup, month
select * from #EBP_DashboardBaseTable_Clinician where ClinicianLastName like 'blunt' 
select * from #StageClinicianmonthly where ClinicianLastName like 'blunt'
select * from #StageClinician where ClinicianLastName like 'blunt'

*********************/


END