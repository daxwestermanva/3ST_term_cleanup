--use OMHSP_PERC_CDSTest
/* =============================================
-- Author: Rebecca Stephens
-- Modifications:
	--2020-08-03 RAS	Branched from Present_Diagnosis and added SourceEHR column and code to include data from Cerner as well as VistA.
	--2020-11-03 RAS	Updated LookUp.ICD10 join to use ICD10SID for Millenium data (instead of ICD10Code). Changed SourceEHR to VARCHAR.
	--2021-05-13 PS		Added past-year DoD data, and a new SourceEHR ('D')
	--2021-09-13 AI		Enclave Refactoring - Counts confirmed
	--2021-10-08 LM		Added past-year community care data, and added columns for diagnosis location (outpatient, inpatient, etc.)
	--2022-05-18 RAS	Refactored SourceEHR to be "V," "M," or "O" for "other" per discussions a long time ago.
	--2024-06-10 CW     Adding ChecklistID into Present.DiagnosisDate

-- Questions:	
	-- Is ICD10 going to be the only diagnosis vocab in the Millenium data we will use?
	-- Does the DiagnosisType (e.g., Working, Discharge) matter?
	-- DiagnosisDateTime -- Should we align with CDWWork visit date/inpatient date logic?
		-- Should we align the inpatient logic with the PA environment code using AdmitDateTime and DischargeDateTime
		-- then also update Cerner logic to do the same thing?
--============================================= */
CREATE PROCEDURE [Code].[Present_Diagnosis]
-- Add the parameters for the stored procedure here

AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.Present_Diagnosis','Execution of SP Code.Present_Diagnosis'

--TO DO: Replace #cohort with correct patient list (Present.SPatient?) 
DROP TABLE IF EXISTS #cohort;
SELECT a.MVIPersonSID
	,mvi.PatientPersonSID
INTO #cohort
FROM [Present].[SPatient] a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.MVIPersonSID = mvi.MVIPersonSID

CREATE CLUSTERED INDEX CIX_cohort on #cohort(MVIPersonSID)

--DECLARE VARIABLES
---Set begin and end dates to look for diagnoses in past year
DECLARE @EndDate DATE = GetDate() --DateAdd(d,DateDiff(d,0,GetDate()),0)
PRINT @EndDate
DECLARE @StartDate DATE = CAST(DateAdd(d,-366,@EndDate) as date)
PRINT @StartDate

  ------------------------------------------------------------------------------------------------------
  /****************************************VistA OUTPATIENT DIAGNOSIS****************************************/
  ------------------------------------------------------------------------------------------------------
  --Gets outpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  EXEC [Log].[ExecutionBegin] 'Code.Present_Diagnosis OP','Code.Present_Diagnosis section: Outpatient Diagnosis'

  DROP TABLE IF EXISTS #OutpatVDiagnosis
  SELECT
		 c.MVIPersonSID
		,a.Sta3n
		,cl.ChecklistID
		,a.VisitDateTime
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO  #OutpatVDiagnosis 
  FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
  INNER JOIN App.vwCDW_Outpat_Workload w WITH (NOLOCK)
	ON a.VisitSID=w.VisitSID
  INNER JOIN Dim.Institution i
	ON w.InstitutionSID=i.InstitutionSID
  INNER JOIN LookUp.ChecklistID cl
	ON i.StaPa=cl.StaPa
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID]
  WHERE (a.[VisitDateTime] >= @StartDate AND a.[VisitDateTime] < @EndDate)
  AND (w.[VisitDateTime] >= @StartDate AND w.[VisitDateTime] < @EndDate);

  PRINT '#OutpatVDiagnosis'
  
  EXEC [Log].[ExecutionEnd]
  --------------------------------------------------------------------------------------------------------
  /****************************************VistA INPATIENT DIAGNOSIS*******************************************/
  --------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  EXEC [Log].[ExecutionBegin] 'Code.Present_Diagnosis IP','Code.Present_Diagnosis section: Inpatient Diagnosis'

  -- 20190319 - RAS - Q: Should we use discharge dates or transfer dates instead of admit date?  Use later for most recent date?

  DROP TABLE IF EXISTS #InpatientDiagnosis;
  SELECT
		 c.MVIPersonSID
		,a.Sta3n
		,a.InpatientSID
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #InpatientDiagnosis 
  FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.DischargeDateTime >= @StartDate AND a.DischargeDateTime < @EndDate)
		OR a.DischargeDateTime IS NULL
  ;
  DROP TABLE IF EXISTS #InpatientDischargeDiagnosis;
  SELECT
		 c.MVIPersonSID
		,a.Sta3n
		,a.InpatientSID
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #InpatientDischargeDiagnosis
  FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.DischargeDateTime >= @StartDate AND a.DischargeDateTime < @EndDate)
		OR a.DischargeDateTime IS NULL
  ;
  DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis;
  SELECT
		 c.MVIPersonSID
		,a.Sta3n
		,a.InpatientSID
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #SpecialtyTransferDiagnosis 
  FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID]
  INNER JOIN [Inpat].[Inpatient] d WITH(NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE (a.SpecialtyTransferDateTime >= @StartDate AND a.SpecialtyTransferDateTime < @EndDate)
		OR a.SpecialtyTransferDateTime IS NULL

  DROP TABLE IF EXISTS #InpatDiagnosisAllPrep;
  SELECT a.MVIPersonSID,a.Sta3n,a.AdmitDateTime,a.ICD10SID,a.ICD10Code,a.DxCategory,ISNULL(dw.Sta6a, aw.Sta6a) AS Sta6a
  INTO #InpatDiagnosisAllPrep
  FROM (
	  SELECT MVIPersonSID,Sta3n,InpatientSID,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #InpatientDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Sta3n,InpatientSID,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #InpatientDischargeDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Sta3n,InpatientSID,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #SpecialtyTransferDiagnosis
	) a
  INNER JOIN [Inpat].[Inpatient] i
	ON a.InpatientSID=i.InpatientSID
  LEFT JOIN [Dim].[WardLocation] dw WITH (NOLOCK)
	ON i.DischargeWardLocationSID = dw.WardLocationSID
  LEFT JOIN [Dim].[WardLocation] aw WITH (NOLOCK)
	ON i.AdmitWardLocationSID = aw.WardLocationSID

  DROP TABLE IF EXISTS #InpatDiagnosisAll;
  SELECT a.*, ChecklistID = ISNULL(s.ChecklistID,convert(varchar,a.Sta3n))
  INTO #InpatDiagnosisAll
  FROM #InpatDiagnosisAllPrep a
  LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
	ON a.Sta6a=s.Sta6a
  ;
  PRINT '#InpatDiagnosisAll'

  EXEC [Log].[ExecutionEnd]

  --------------------------------------------------------------------------------------------------------------
  /****************************************VistA PROBLEM LIST DIAGNOSIS**********************************************/
  --------------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  EXEC [Log].[ExecutionBegin] 'Code.Present_Diagnosis PL','Code.Present_Diagnosis section: Problem List Diagnosis'

  DROP TABLE IF EXISTS #ProblemList;
  SELECT DISTINCT 
		c.MVIPersonSID
		,a.Sta3n
		,cl.ChecklistID
		,a.LastModifiedDatetime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #ProblemList
  FROM [Outpat].[ProblemList] a WITH(NOLOCK)
  INNER JOIN Dim.Institution i WITH (NOLOCK)
	ON a.InstitutionSID=i.InstitutionSID
  INNER JOIN LookUp.ChecklistID cl WITH (NOLOCK)
	ON i.StaPa=cl.StaPa
  INNER JOIN #cohort c WITH (NOLOCK)
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK) 
	ON a.[ICD10SID] = b.[ICD10SID]
  WHERE [ActiveFlag] = 'A' 
	  AND ProblemListCondition <> 'H' --excludes "history of"
  ;
  PRINT '#ProblemList'

  EXEC [Log].[ExecutionEnd]

--------------------------------------------------------------------------------------------------------------
/****************************************CERNER DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MillDiagnosis
SELECT c.MVIPersonSID
	  ,Sta3n=200
	  ,cl.ChecklistID
	  ,c.SourceIdentifier as ICD10Code
	  ,c.TZDerivedDiagnosisDateTime AS DiagnosisDateTime
	  ,l.DxCategory
	  ,CASE WHEN c.EncounterType = 'Inpatient' THEN 'I' ELSE 'O' END AS Source
INTO #MillDiagnosis
FROM [Cerner].[FactDiagnosis] c WITH (NOLOCK)
INNER JOIN LookUp.ChecklistID cl
	ON c.STAPA=cl.StaPa
INNER JOIN [LookUp].[ICD10_VerticalSID] l WITH (NOLOCK)  
	ON l.ICD10SID=c.NomenclatureSID 
INNER JOIN #cohort co WITH(NOLOCK)
	ON co.PatientPersonSID=c.PersonSID
WHERE c.SourceVocabulary = 'ICD-10-CM' --needed?
	AND c.MVIPersonSID>0
	AND (TZDerivedDiagnosisDateTime >= @StartDate AND TZDerivedDiagnosisDateTime < @EndDate)

--------------------------------------------------------------------------------------------------------------
/****************************************DOD DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #DoDDiagnosis 
SELECT a.MVIPersonSID
	  ,Sta3n=NULL
	  ,ChecklistID=CONVERT(varchar,NULL)
	  ,'' as ICD10Code
	  ,'' as DiagnosisDateTime
	  ,DxCategory
INTO #DoDDiagnosis 
FROM [ORM].[vwDOD_DxVertical] a WITH(NOLOCK)
INNER JOIN #cohort c WITH(NOLOCK) 
	ON a.MVIPersonSID = c.MVIPersonSID
INNER JOIN (
	SELECT ColumnName,PrintName 
	FROM [LookUp].[ColumnDescriptions] WITH (NOLOCK)  
	WHERE TableName = 'ICD10'
	) as d on a.DxCategory = d.ColumnName

--------------------------------------------------------------------------------------------------------------
/****************************************COMMUNITY CARE DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #CommunityCareDiagnosis
SELECT MVIPersonSID
	  ,a.Sta3n
	  ,cl.ChecklistID
	  ,d.ICD10Code
	  ,b.InitialTreatmentDateTime
	  ,DxCategory
INTO #CommunityCareDiagnosis 
FROM [Fee].[FeeServiceProvided] a WITH (NOLOCK)
LEFT JOIN Dim.Institution i WITH (NOLOCK)
	ON a.PrimaryServiceInstitutionSID=i.InstitutionSID
LEFT JOIN LookUp.ChecklistID cl WITH (NOLOCK)
	ON i.StaPa=cl.StaPa
INNER JOIN [Fee].[FeeInitialTreatment] b WITH (NOLOCK)
	ON a.FeeInitialTreatmentSID = b.FeeInitialTreatmentSID
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10_VerticalSID] d WITH (NOLOCK)  
		ON a.[ICD10SID] = d.[ICD10SID]
WHERE (InitialTreatmentDateTime >= @StartDate AND InitialTreatmentDateTime < @EndDate)

UNION ALL

SELECT MVIPersonSID
	  ,a.Sta3n
	  ,cl.ChecklistID
	  ,d.ICD10Code
	  ,a.TreatmentFromDateTime
	  ,DxCategory
FROM [Fee].[FeeInpatInvoice] a WITH (NOLOCK)
LEFT JOIN Dim.Institution i WITH (NOLOCK)
	ON a.PrimaryServiceInstitutionSID=i.InstitutionSID
LEFT JOIN LookUp.ChecklistID cl WITH (NOLOCK)
	ON i.StaPa=cl.StaPa
INNER JOIN [Fee].[FeeInpatInvoiceICDDiagnosis] b WITH (NOLOCK)
	ON a.FeeInpatInvoiceSID = b.FeeInpatInvoiceSID  
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10_VerticalSID] d WITH (NOLOCK)  
		ON b.[ICD10SID] = d.[ICD10SID]
WHERE (TreatmentFromDateTime >= @StartDate);

--------------------------------------------------------------------------------------------------------------
/****************************************MOST RECENT DIAGNOSIS DATE******************************************/
--------------------------------------------------------------------------------------------------------------
-- Get the most recent date for each diagnosis category
DROP TABLE IF EXISTS #DiagnosisDateWithCategory;
SELECT
	   MVIPersonSID
	  ,Sta3n
	  ,ChecklistID
	  ,ICD10Code
	  ,MAX(VisitDateTime) as MostRecentDate
	  ,DxCategory
INTO #DiagnosisDateWithCategory
FROM (
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,VisitDateTime,DxCategory
	FROM #OutpatVDiagnosis  
	UNION ALL   
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,AdmitDateTime,DxCategory
	FROM #InpatDiagnosisAll 
	UNION ALL 
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,LastModifiedDateTime,DxCategory 
	FROM #ProblemList
	UNION ALL 
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,DiagnosisDateTime,DxCategory 
	FROM #MillDiagnosis
	UNION ALL
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,DiagnosisDateTime,DxCategory 
	FROM #DoDDiagnosis
	UNION ALL
	SELECT MVIPersonSID,Sta3n,ChecklistID,ICD10Code,InitialTreatmentDateTime,DxCategory 
	FROM #CommunityCareDiagnosis) a
GROUP BY MVIPersonSID,Sta3n,ChecklistID,ICD10Code,DxCategory;

DROP TABLE IF EXISTS #StageDiagnosisDate;
SELECT DISTINCT MVIPersonSID
	  ,Sta3n
	  ,ChecklistID
	  ,ICD10Code
	  ,MostRecentDate
INTO #StageDiagnosisDate
FROM #DiagnosisDateWithCategory;

EXEC [Maintenance].[PublishTable] 'Present.DiagnosisDate','#StageDiagnosisDate';
--------------------------------------------------------------------------------------------------------------
/****************************************MAX DIAGNOSIS PER PATIENT******************************************/
--------------------------------------------------------------------------------------------------------------
-- Roll up to MVIPersonSID for each diagnosis category
DROP TABLE IF EXISTS #StageDx;
WITH DxV AS	( --VistA/CDW
	SELECT MVIPersonSID
		  ,DxCategory
		  ,Outpat=1
		  ,Inpat=NULL
		  ,SourceEHR='V'
	FROM #OutpatVDiagnosis
	UNION 
	SELECT MVIPersonSID
		  ,DxCategory
		  ,Outpat=NULL
		  ,Inpat=1
		  ,SourceEHR='V'
	FROM #InpatDiagnosisAll
	)
,DxC AS ( --Cerner/CDW2
	SELECT DISTINCT 
		  MVIPersonSID
		  ,DxCategory
		  ,Outpat=CASE WHEN Source='O' THEN 1 ELSE NULL END
		  ,Inpat=CASE WHEN Source='I' THEN 1 ELSE NULL END
		  ,SourceEHR='M'
	FROM #MillDiagnosis
	)
,DxD AS ( --DoD
	SELECT DISTINCT
		  MVIPersonSID
		  ,DxCategory
		  ,DoD=1
		  ,SourceEHR='O'
	FROM #DoDDiagnosis
	)
,DxCo AS (--Community Care
	SELECT DISTINCT
		  MVIPersonSID
		  ,DxCategory
		  ,CommCare=1
		  ,SourceEHR='O'
	FROM #CommunityCareDiagnosis
	)
,PL AS ( --Problem List
	SELECT DISTINCT
		  MVIPersonSID
		  ,DxCategory
		  ,PL=1
		  ,SourceEHR='V'
	FROM #ProblemList
	)
SELECT DISTINCT a.MVIPersonSID 
	,a.DxCategory 
	,SourceEHR = CONCAT(COALESCE(v1.SourceEHR,v2.SourceEHR,p.SourceEHR),COALESCE(d.SourceEHR,co.SourceEHR),COALESCE(c1.SourceEHR,c2.SourceEHR),'')
	,Outpat = COALESCE(v1.Outpat,c1.Outpat,0)
	,Inpat = COALESCE(v2.Inpat,c2.Inpat,0)
	,DoD = ISNULL(d.DoD,0)
	,CommCare = ISNULL(co.CommCare,0)
	,PL = ISNULL(p.PL,0)
INTO #StageDx
FROM #DiagnosisDateWithCategory a
LEFT JOIN (SELECT * FROM DxV WHERE Outpat=1) v1
	ON a.MVIPersonSID=v1.MVIPersonSID
	AND a.DxCategory=v1.DxCategory
LEFT JOIN (SELECT * FROM DxV WHERE Inpat=1) v2 ON 
	a.MVIPersonSID=v2.MVIPersonSID
	AND a.DxCategory=v2.DxCategory
LEFT JOIN (SELECT * FROM DxC WHERE Outpat=1) c1 ON 
	a.MVIPersonSID=c1.MVIPersonSID
	AND a.DxCategory=c1.DxCategory
LEFT JOIN (SELECT * FROM DxC WHERE Inpat=1) c2 ON 
	a.MVIPersonSID=c2.MVIPersonSID
	AND a.DxCategory=c2.DxCategory
LEFT JOIN DxD d ON
	a.MVIPersonSID=d.MVIPersonSID
	AND a.DxCategory=d.DxCategory
LEFT JOIN DxCo co ON 
	a.MVIPersonSID=co.MVIPersonSID
	AND a.DxCategory=co.DxCategory
LEFT JOIN PL p ON 
	a.MVIPersonSID=p.MVIPersonSID
	AND a.DxCategory=p.DxCategory

EXEC [Maintenance].[PublishTable] 'Present.Diagnosis','#StageDx'

PRINT 'Present.Diagnosis published'

DROP TABLE 
	 #OutpatVDiagnosis
	,#InpatDiagnosisAll
	,#ProblemList
	,#DoDDiagnosis
	,#CommunityCareDiagnosis
	,#StageDx

 EXEC [Log].[ExecutionEnd]

END