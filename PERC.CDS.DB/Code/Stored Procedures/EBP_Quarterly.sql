
/****** Object:  StoredProcedure [Code].[EBP_Quarterly]    Script Date: 9/13/2021 10:57:23 PM ******/
CREATE PROCEDURE [Code].[EBP_Quarterly]

AS
BEGIN

-- ---------------------------------------------------------
-- AUTHOR:	Elena Cherkasova
-- CREATE DATE: 2023-03-23
-- DESCRIPTION:	Code for counting quarterly EBP patient and visit data for EBPTemplates_QuarterlySummary report
-- appends to	[EBP].[Quarterly]
-- publishes to [EBP].[QuarterlySummary]            
--
-- MODIFICATIONS:
----20231201	EC:	Redesigned code to remove pivot/unpivot sections. Added Insomnia relevant population.
--
------------------------------------------------------------

DECLARE @QtrEndDate DATE = (
		SELECT DISTINCT TOP 1 CAST(DATE AS DATE)
		FROM (
			SELECT DATEADD(dd, 1, CAST(DATE AS DATE)) AS DATE
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY fiscalyear
						,fiscalquarter ORDER BY DATE DESC
						) AS lastdayofquarter
				FROM [Dim].[Date] WITH (NOLOCK)
				) AS a
			WHERE lastdayofquarter = 1
				AND calendaryear = (
					SELECT DISTINCT calendaryear
					FROM [Dim].[Date] WITH (NOLOCK)
					WHERE DATE = DATEADD(month, - 3, CAST(GETDATE() AS DATE))
					)
			) AS a
		WHERE DATE <= CAST(GETDATE() AS DATE)
		ORDER BY DATE DESC
		);

DECLARE @QtrStartDate DATE = DATEADD(mm, DATEDIFF(mm, 0, @QtrEndDate) - 12, 0);

DECLARE @FiscalQuarter VARCHAR(8) = (
		SELECT fiscalquarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FiscalYear INT = (
		SELECT fiscalyear
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FYQ VARCHAR(8) = (
		SELECT 'FY' + RIGHT(fiscalyear,2) + 'Q' + @FiscalQuarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @MHIS_FYQ VARCHAR(8) = (
		SELECT MAX(FYQ)
		FROM XLA.MHIS_Summary
		);

PRINT @QtrStartDate;
PRINT @QtrEndDate;
PRINT @FiscalQuarter;
PRINT @FiscalYear;
PRINT @FYQ;
PRINT @MHIS_FYQ;
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
-- SECTION II: YTD FACILITY AND DX COUNTS FOR QUARTERLY REPORT  --
------------------------------------------
	/* ---------
	FILTER TO PAST 4 QUARTERS AND 2 OR MORE VISITS
	 ---------*/

-- Filter and clean data to include only patients who have 2 or more sessions (VisitSID) of a template group in the past 4 quarters
DROP TABLE IF EXISTS #TwoOrMoreQTR;
	SELECT	MVIPersonSID
			,PatientSID
			,COUNT(DISTINCT VisitSID) AS 'TotalSessions'
			,TemplateGroup
	INTO #TwoOrMoreQTR
	FROM #DistinctVisits
	WHERE VisitDateTime >= @QtrStartDate 
			AND VisitDateTime < @QtrEndDate
	GROUP BY PatientSID
			,MVIPersonSID
			,TemplateGroup
	HAVING COUNT(DISTINCT VisitSID) >= 2
	ORDER BY COUNT(DISTINCT VisitSID) DESC;

-- Create new visit-level table with patients who have 2 or more visits per template group in the past 4 quarters
DROP TABLE IF EXISTS #2VisitsCohortQTR;
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
	INTO #2VisitsCohortQTR
	FROM #DistinctVisits AS a
	INNER JOIN #TwoOrMoreQTR b	ON a.PatientSID = b.PatientSID 
			AND a.TemplateGroup=b.TemplateGroup
	WHERE VisitDateTime >= @QtrStartDate 
			AND VisitDateTime < @QtrEndDate;

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
FROM #2VisitsCohortQTR
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
FROM #2VisitsCohortQTR
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
ON b.ChecklistID = c.ChecklistID,(SELECT DISTINCT TemplateGroup FROM #2VisitsCohortQTR			--14 Templates
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
	,TemplateCount=ISNULL(TemplateCount,0)
INTO #FinalAllLevels
FROM #comb AS a
LEFT JOIN #AllLevels AS b 
	ON a.StaPa = b.StaPa
	AND a.TemplateGroup = b.TemplateGroup
; --3180

/*DECLARE @QtrEndDate DATE = (
		SELECT DISTINCT TOP 1 CAST(DATE AS DATE)
		FROM (
			SELECT DATEADD(dd, 1, CAST(DATE AS DATE)) AS DATE
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY fiscalyear
						,fiscalquarter ORDER BY DATE DESC
						) AS lastdayofquarter
				FROM [Dim].[Date] WITH (NOLOCK)
				) AS a
			WHERE lastdayofquarter = 1
				AND calendaryear = (
					SELECT DISTINCT calendaryear
					FROM [Dim].[Date] WITH (NOLOCK)
					WHERE DATE = DATEADD(month, - 3, CAST(GETDATE() AS DATE))
					)
			) AS a
		WHERE DATE <= CAST(GETDATE() AS DATE)
		ORDER BY DATE DESC
		);

DECLARE @QtrStartDate DATE = DATEADD(mm, DATEDIFF(mm, 0, @QtrEndDate) - 12, 0);

DECLARE @FiscalQuarter VARCHAR(8) = (
		SELECT fiscalquarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FiscalYear INT = (
		SELECT fiscalyear
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FYQ VARCHAR(8) = (
		SELECT 'FY' + RIGHT(fiscalyear,2) + 'Q' + @FiscalQuarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

PRINT @QtrStartDate;
PRINT @QtrEndDate;
PRINT @FiscalQuarter;
PRINT @FiscalYear;
PRINT @FYQ;
--*/

DECLARE @RowCount INT = (SELECT COUNT(*) FROM #FinalAllLevels)
	IF @RowCount > 0
	BEGIN 

			DELETE FROM [EBP].[Quarterly]
			WHERE [FiscalYear]= @FiscalYear
				AND [FiscalQuarter]= @FiscalQuarter;

			INSERT INTO [EBP].[Quarterly]
			SELECT DISTINCT a.StaPa as ChecklistID
				  ,a.AdmParent_FCDM
				  ,a.VISN
				  ,CAST(StaPa AS NVARCHAR(255)) AS Sta6aID
				  ,AdmParent_FCDM as LocationOfFacility
				  ,t.TemplateName
				  ,TemplateValue = a.TemplateCount--a.UniquePatients
				  ,[Date] = @QtrEndDate
				  ,FiscalQuarter= @FiscalQuarter
				  ,FiscalYear = @FiscalYear
				  ,t.TemplateNameClean
				  ,t.TemplateNameShort
			FROM #FinalAllLevels AS a
			LEFT JOIN [Config].[EBP_TemplateLookUp] AS t ON t.TemplateName=a.TemplateGroup
		;
			EXEC [Log].[PublishTable] 'EBP','Quarterly','#FinalAllLevels','Append',@RowCount
	END

----Create Facility, VISN and National Diagnoses Counts for Most recent fiscal year based on IRA file----

/*DECLARE @QtrEndDate DATE = (
		SELECT DISTINCT TOP 1 CAST(DATE AS DATE)
		FROM (
			SELECT DATEADD(dd, 1, CAST(DATE AS DATE)) AS DATE
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY fiscalyear
						,fiscalquarter ORDER BY DATE DESC
						) AS lastdayofquarter
				FROM [Dim].[Date] WITH (NOLOCK)
				) AS a
			WHERE lastdayofquarter = 1
				AND calendaryear = (
					SELECT DISTINCT calendaryear
					FROM [Dim].[Date] WITH (NOLOCK)
					WHERE DATE = DATEADD(month, - 3, CAST(GETDATE() AS DATE))
					)
			) AS a
		WHERE DATE <= CAST(GETDATE() AS DATE)
		ORDER BY DATE DESC
		);

DECLARE @QtrStartDate DATE = DATEADD(mm, DATEDIFF(mm, 0, @QtrEndDate) - 12, 0);

DECLARE @FiscalQuarter VARCHAR(8) = (
		SELECT fiscalquarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FiscalYear INT = (
		SELECT fiscalyear
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FYQ VARCHAR(8) = (
		SELECT 'FY' + RIGHT(fiscalyear,2) + 'Q' + @FiscalQuarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);


DECLARE @MHIS_FYQ VARCHAR(8) = (
		SELECT MAX(FYQ)
		FROM XLA.MHIS_Summary
		);

--*/

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
PRINT @QtrStartDate;
PRINT @QtrEndDate;
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
  WHERE (a.[VisitDateTime] >= @QtrStartDate AND a.[VisitDateTime] < @QtrEndDate)
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
  WHERE (a.DischargeDateTime >= @QtrStartDate AND a.DischargeDateTime < @QtrEndDate)
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
  WHERE (a.DischargeDateTime >= @QtrStartDate AND a.DischargeDateTime < @QtrEndDate)
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
  WHERE (a.SpecialtyTransferDateTime >= @QtrStartDate AND a.SpecialtyTransferDateTime < @QtrEndDate)
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
	AND (TZDerivedDiagnosisDateTime >= @QtrStartDate AND TZDerivedDiagnosisDateTime < @QtrEndDate)
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

	/*
	DECLARE @QtrEndDate DATE = (
		SELECT DISTINCT TOP 1 CAST(DATE AS DATE)
		FROM (
			SELECT DATEADD(dd, 1, CAST(DATE AS DATE)) AS DATE
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY fiscalyear
						,fiscalquarter ORDER BY DATE DESC
						) AS lastdayofquarter
				FROM [Dim].[Date] WITH (NOLOCK)
				) AS a
			WHERE lastdayofquarter = 1
				AND calendaryear = (
					SELECT DISTINCT calendaryear
					FROM [Dim].[Date] WITH (NOLOCK)
					WHERE DATE = DATEADD(month, - 3, CAST(GETDATE() AS DATE))
					)
			) AS a
		WHERE DATE <= CAST(GETDATE() AS DATE)
		ORDER BY DATE DESC
		);

DECLARE @QtrStartDate DATE = DATEADD(mm, DATEDIFF(mm, 0, @QtrEndDate) - 12, 0);

DECLARE @FiscalQuarter VARCHAR(8) = (
		SELECT fiscalquarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FiscalYear INT = (
		SELECT fiscalyear
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FYQ VARCHAR(8) = (
		SELECT 'FY' + RIGHT(fiscalyear,2) + 'Q' + @FiscalQuarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @MHIS_FYQ VARCHAR(8) = (
		SELECT MAX(FYQ)
		FROM XLA.MHIS_Summary
		);
--*/

DROP TABLE IF EXISTS #XLA_Dx;
	SELECT DISTINCT a.MVIPersonSID
		,ChecklistID = CASE WHEN b.HomeStation = '596A4' THEN '596' ELSE b.HomeStation END
		,VISN  = CASE WHEN b.HomeStation = '596A4' THEN '9' ELSE c.VISN END
		,CASE 
			WHEN a.VariableName LIKE 'MajorDepression_dx1_p2b'
				OR a.VariableName LIKE 'DepressionOther_dx1_p2b'
				THEN 1
			ELSE NULL
			END AS Depression
		,CASE 
			WHEN a.VariableName LIKE 'PTSD_dx1_p2b'
				THEN 1
			ELSE NULL
			END AS PTSD
		,CASE 
			WHEN a.VariableName LIKE 'PsychosesAndBipolar_dx1_p2b'
				THEN 1
			ELSE NULL
			END AS SMI
		,CASE 
			WHEN a.VariableName LIKE 'SUD_dx1_p2b'
				THEN 1
			ELSE NULL
			END AS SUD
	INTO #XLA_Dx
	FROM [XLA].[MHIS_Summary] AS a WITH (NOLOCK)
	LEFT JOIN [XLA].[MHIS_Cohort] AS b WITH (NOLOCK) ON a.MVIPersonSID = b.MVIPersonSID
		AND a.FYQ = b.FYQ
	LEFT JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK) ON b.HomeStation = c.ChecklistID
	WHERE a.FYQ = @MHIS_FYQ
	;


DROP TABLE IF EXISTS #Diagnoses;
SELECT DISTINCT ChecklistID 
	,VISN
	,SUM(CASE WHEN Depression=1 THEN 1 ELSE NULL END) OVER (PARTITION BY ChecklistID) AS DepKey
	,SUM(CASE WHEN PTSD=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY ChecklistID) AS PTSDKey
	,SUM(CASE WHEN SMI=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY ChecklistID) AS SMIKey
	,SUM(CASE WHEN SUD=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY ChecklistID) AS SUDKey          
INTO #Diagnoses
FROM #XLA_Dx

UNION

SELECT DISTINCT CAST(VISN AS VARCHAR(5)) AS ChecklistID 
	,VISN
	,SUM(CASE WHEN Depression=1 THEN 1 ELSE NULL END) OVER (PARTITION BY VISN) AS DepKey
	,SUM(CASE WHEN PTSD=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY VISN) AS PTSDKey
	,SUM(CASE WHEN SMI=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY VISN) AS SMIKey
	,SUM(CASE WHEN SUD=1 THEN 1 ELSE NULL END)  OVER (PARTITION BY VISN) AS SUDKey          
FROM #XLA_Dx

UNION

SELECT DISTINCT ChecklistID = '0' 
	,VISN = '0'
	,SUM(CASE WHEN Depression=1 THEN 1 ELSE NULL END) AS DepKey
	,SUM(CASE WHEN PTSD=1 THEN 1 ELSE NULL END) AS PTSDKey
	,SUM(CASE WHEN SMI=1 THEN 1 ELSE NULL END) AS SMIKey
	,SUM(CASE WHEN SUD=1 THEN 1 ELSE NULL END) AS SUDKey         
FROM #XLA_Dx
;
--SELECT count(*) FROM #Diagnoses --order by checklistid
--SELECT count(*) FROM #InsomniaPatientCount --order by checklistid

DROP TABLE IF EXISTS #FinalDiagnoses;
SELECT DISTINCT a.ChecklistID 
	,a.VISN
	,a.DepKey
	,a.PTSDKey
	,a.SMIKey
	,a.SUDKey     
	,b.DistinctCount as InsomniaKey
INTO #FinalDiagnoses
FROM #Diagnoses as a
INNER JOIN #InsomniaPatientCount as b
on a.ChecklistID = b.StaPa

/*************Pull in all quarterly data and union with most recent quarter. Add national data for most recent quarter as columns preceded by "National"***************/
--------------------------------------------------------------------

DROP TABLE IF EXISTS #stagingQTR;
SELECT a.ChecklistID
	,a.AdmParent_FCDM
	,a.VISN
	,a.Sta6aID
	,LocationOfFacility
	,a.TemplateName
	,a.TemplateValue
	,a.Date2
	,a.Date
	,a.Quarter
	,a.Year
	,a.TemplateNameShort
	,a.TemplateNameClean
	,PTSDKey
	,DepKey
	,SMIKey
	,SUDKey
	,InsomniaKey
	,MostRecentValue
	,NationalTemplateValue
	,NationalPTSDkey
	,NationalDepkey
	,NationalSMIkey
	,NationalSUDKey
	,NationalInsomniaKey
	,CASE WHEN [TemplateNameClean] like 'Any EBP%' THEN 1 WHEN 
		[TemplateNameClean] like 'Any PTSD%' THEN 2 WHEN 
		[TemplateNameClean] like 'CPT%' THEN 3 WHEN
		[TemplateNameClean] like 'PE%' THEN 4 WHEN
		[TemplateNameClean] like 'EMDR%' THEN 5 WHEN
		[TemplateNameClean] like 'WET%' THEN 6 WHEN
		[TemplateNameClean] like 'Any Dep%' THEN 7 WHEN
		[TemplateNameClean] like 'ACT%' THEN 8 WHEN
		[TemplateNameClean] like 'CBT-D%' THEN 9 WHEN
		[TemplateNameClean] like 'IPT-D%' THEN 10 WHEN
		[TemplateNameClean] like 'Any SMI%' THEN 11 WHEN
		[TemplateNameClean] like 'BFT%' THEN 12 WHEN
		[TemplateNameClean] like 'SST%' THEN 13 WHEN
		[TemplateNameClean] like 'Any SP%' THEN 14 WHEN
		[TemplateNameClean] like 'CBT-SP%' THEN 15 WHEN
		[TemplateNameClean] like 'DBT%' THEN 16 WHEN 
		[TemplateNameClean] like 'PST%' THEN 17 WHEN 
		[TemplateNameClean] like 'Any SUD%' THEN 18 WHEN
		[TemplateNameClean] like 'CB-SUD%' THEN 19 WHEN
		[TemplateNameClean] like 'CM%' THEN 20 WHEN
		[TemplateNameClean] like 'CBT-I%' THEN 21 WHEN
		[TemplateNameClean] like 'IBCT%' THEN 22 ELSE 0 END AS TemplateOrder
		,Temp = 1         
INTO #stagingQTR
FROM (
	SELECT a.ChecklistID
		  ,a.AdmParent_FCDM
		  ,VISN
		  ,Sta6aID
		  ,LocationOfFacility
		  ,a.TemplateName
		  ,a.TemplateValue
		  ,CONCAT(LEFT(FiscalQuarter, 3), ' ', FiscalYear) AS Date2
		  ,[Date]
		  ,CAST(FiscalQuarter AS VARCHAR(10)) AS Quarter
		  ,CAST(FiscalYear AS VARCHAR(10)) AS Year
		  ,TemplateNameShort  
		  ,TemplateNameClean
		  ,b.PTSDKey
		  ,b.DepKey
		  ,b.SMIKey
		  ,b.SUDKey  
		  ,b.InsomniaKey
		  ,b.MostRecentValue
		  FROM [EBP].[Quarterly] as a WITH (NOLOCK) --Make this temp
 
	LEFT JOIN (
		  SELECT DISTINCT a.ChecklistID 
			,AdmParent_FCDM
			,TemplateName
			,TemplateValue as MostRecentValue
			,PTSDKey
			,DepKey
			,SMIKey
			,SUDKey   
			,InsomniaKey
		  FROM [EBP].[Quarterly] as a  WITH (NOLOCK) 
		  LEFT JOIN #FinalDiagnoses as b on a.ChecklistID=b.ChecklistID
		 WHERE Date = (SELECT DISTINCT MAX(Date) FROM [EBP].[Quarterly] WITH (NOLOCK))) as b on a.TemplateName=b.TemplateName and a.ChecklistID=b.ChecklistID
	) as a

	LEFT JOIN (
		SELECT DISTINCT a.ChecklistID
		  ,TemplateName
		  ,TemplateValue as NationalTemplateValue
		  ,PTSDkey as NationalPTSDkey
		  ,DEPkey as NationalDepkey 
		  ,SMIkey as NationalSMIkey
		  ,SUDkey as NationalSUDKey
		  ,InsomniaKey as NationalInsomniaKey

		FROM [EBP].[Quarterly] as a  WITH (NOLOCK) 
		LEFT JOIN #FinalDiagnoses as b
		  on a.checklistid=b.checklistid
		WHERE a.checklistid like '0' and Date = (SELECT DISTINCT MAX(Date) FROM [EBP].[Quarterly] WITH (NOLOCK))
	) as b on a.templatename=b.templatename
	;


			EXEC [Maintenance].[PublishTable] '[EBP].[QuarterlySummary]','#stagingQTR'


-----

/* CHECKS
select * from #stagingqtr where checklistid like '596%' and year like '2022' and quarter like '1' order by templatename
select * from EBP.Quarterly where checklistid like '612%' order by date desc and fiscalyear like '2022' and fiscalquarter like '1' order by templatename
select * from EBP.QuarterlySummary where checklistid like '517' and year like '2022' and quarter like '1' order by templatename

DROP TABLE IF EXISTS #DoubleCheck;
SELECT DISTINCT MVIPersonSID
	,TemplateGroup
	,COUNT(DISTINCT MVIPersonsid) as 'TotalPatients'
INTO #DoubleCheck
FROM  [EBP].[TemplateVisits]
WHERE Stapa like '517' and visitdatetime >='2021-06-01' and visitdatetime <'2022-07-01'
GROUP BY MVIPersonSID,TemplateGroup
HAVING COUNT(DISTINCT VisitSID) >= 2
ORDER BY TemplateGroup 

--run next 3 at once
select * from #EBPTemplateFacilityAllLevels
where stapa like '517' and templategroup not like 'Any%'
ORDER BY TemplateGroup

SELECT DISTINCT TemplateGroup
	,COUNT(DISTINCT MVIPersonsid) as 'TotalPatients'
FROM #DoubleCheck
GROUP BY TemplateGroup
ORDER BY TemplateGroup 

select * from #StageEBP 
where stapa like '517' and TemplateName not like 'Any%'
ORDER BY TemplateNameShort*/

END