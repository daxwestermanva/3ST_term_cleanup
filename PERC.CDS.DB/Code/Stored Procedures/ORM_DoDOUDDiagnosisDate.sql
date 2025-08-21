

/* =============================================
-- Author: Tolessa Gurmessa
-- Creation date: 2/12/2024
-- This code is adopted from Code.Present_Diagnosis
--2024-03-08   TG added CAST as datetime because datetime2 is incompatible with NULL
--2024-04-16   TG adding F11.9* codes to OUD because it's included on the DoD side
--2025-05-15   TG Fixing a bug that affecting diagnosis dates on VistA side
--2025-06-10   TG Adding DoD care type (Direct care vs Community care)
--2025-06-11   TG Fixing a bug that broke FYQ in the patient report
--============================================= */
CREATE PROCEDURE [Code].[ORM_DoDOUDDiagnosisDate]
-- Add the parameters for the stored procedure here

AS
BEGIN

--DoD OUD cohort
DROP TABLE IF EXISTS #cohort;
SELECT a.MVIPersonSID
	,mvi.PatientPersonSID
INTO #cohort
FROM SUD.Cohort a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.MVIPersonSID = mvi.MVIPersonSID AND a.OUD_DoD = 1

CREATE CLUSTERED INDEX CIX_cohort on #cohort(MVIPersonSID)



  ------------------------------------------------------------------------------------------------------
  /****************************************VistA OUTPATIENT DIAGNOSIS****************************************/
  ------------------------------------------------------------------------------------------------------
  --Gets outpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10


  DROP TABLE IF EXISTS #OutpatVDiagnosis;
  SELECT
		c.MVIPersonSID
		,a.Sta3n
		,a.VisitDateTime
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO  #OutpatVDiagnosis 
  FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND (b.DxCategory = 'OUD' OR b.ICD10Code LIKE 'F11.9%')
  WHERE a.WorkloadLogicFlag = 'Y'
 
  --------------------------------------------------------------------------------------------------------
  /****************************************VistA INPATIENT DIAGNOSIS*******************************************/
  --------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  

  -- 20190319 - RAS - Q: Should we use discharge dates or transfer dates instead of admit date?  Use later for most recent date?

  DROP TABLE IF EXISTS #InpatientDiagnosis;
  SELECT
		c.MVIPersonSID
		,a.Sta3n
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #InpatientDiagnosis 
  FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND (b.DxCategory = 'OUD' OR b.ICD10Code LIKE 'F11.9%')
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.DischargeDateTime  IS NULL

  DROP TABLE IF EXISTS #InpatientDischargeDiagnosis;
  SELECT
		c.MVIPersonSID
		,a.Sta3n
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #InpatientDischargeDiagnosis
  FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND (b.DxCategory = 'OUD' OR b.ICD10Code LIKE 'F11.9%')
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.DischargeDateTime  IS NULL

  DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis;
  SELECT
		c.MVIPersonSID
		,a.Sta3n
		,d.AdmitDateTime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #SpecialtyTransferDiagnosis 
  FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND (b.DxCategory = 'OUD' OR b.ICD10Code LIKE 'F11.9%')
  INNER JOIN [Inpat].[Inpatient] d WITH(NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.SpecialtyTransferDateTime  IS NULL

  DROP TABLE IF EXISTS #InpatDiagnosisAll;
  SELECT MVIPersonSID,Sta3n,AdmitDateTime,ICD10SID,ICD10Code,DxCategory
  INTO #InpatDiagnosisAll
  FROM (
	  SELECT MVIPersonSID,Sta3n,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #InpatientDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Sta3n,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #InpatientDischargeDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Sta3n,AdmitDateTime,ICD10SID,ICD10Code,DxCategory 
	  FROM #SpecialtyTransferDiagnosis
	) u

  --------------------------------------------------------------------------------------------------------------
  /****************************************VistA PROBLEM LIST DIAGNOSIS**********************************************/
  --------------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  

  DROP TABLE IF EXISTS #ProblemList;
  SELECT DISTINCT 
		c.MVIPersonSID
		,a.Sta3n
		,a.LastModifiedDatetime 
		,b.ICD10SID
		,b.ICD10Code
		,b.DxCategory
  INTO #ProblemList
  FROM [Outpat].[ProblemList] a WITH(NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10_VerticalSID] b WITH (NOLOCK) 
		ON a.[ICD10SID] = b.[ICD10SID] AND (b.DxCategory = 'OUD' OR b.ICD10Code LIKE 'F11.9%')
  WHERE [ActiveFlag] = 'A' 
	  AND ProblemListCondition <> 'H' --excludes "history of"
  ;
  

--------------------------------------------------------------------------------------------------------------
/****************************************CERNER DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MillDiagnosis
SELECT c.MVIPersonSID
	  ,Sta3n=200
	  ,c.SourceIdentifier as ICD10Code
	  ,c.TZDerivedDiagnosisDateTime AS DiagnosisDateTime
	  ,l.DxCategory
	  ,CASE WHEN c.EncounterType = 'Inpatient' THEN 'I' ELSE 'O' END AS Source
INTO #MillDiagnosis
FROM [Cerner].[FactDiagnosis] c WITH (NOLOCK)
INNER JOIN [LookUp].[ICD10_VerticalSID] l WITH (NOLOCK)  
	ON l.ICD10SID=c.NomenclatureSID AND (l.DxCategory = 'OUD' OR l.ICD10Code LIKE 'F11.9%')
INNER JOIN #cohort co WITH(NOLOCK)
	ON co.PatientPersonSID=c.PersonSID
WHERE c.SourceVocabulary = 'ICD-10-CM' --needed?
	AND c.MVIPersonSID>0

--------------------------------------------------------------------------------------------------------------
/****************************************COMMUNITY CARE DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #CommunityCareDiagnosis
SELECT MVIPersonSID
	  ,a.Sta3n
	  ,d.ICD10Code
	  ,b.InitialTreatmentDateTime
	  ,DxCategory
INTO #CommunityCareDiagnosis 
FROM [Fee].[FeeServiceProvided] a WITH (NOLOCK)
INNER JOIN [Fee].[FeeInitialTreatment] b WITH (NOLOCK)
	ON a.FeeInitialTreatmentSID = b.FeeInitialTreatmentSID
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10_VerticalSID] d WITH (NOLOCK)  
		ON a.[ICD10SID] = d.[ICD10SID] AND (d.DxCategory = 'OUD' OR d.ICD10Code LIKE 'F11.9%')

UNION ALL

SELECT MVIPersonSID
	  ,a.Sta3n
	  ,d.ICD10Code
	  ,a.TreatmentFromDateTime
	  ,DxCategory
FROM [Fee].[FeeInpatInvoice] a WITH (NOLOCK)
INNER JOIN [Fee].[FeeInpatInvoiceICDDiagnosis] b WITH (NOLOCK)
	ON a.FeeInpatInvoiceSID = b.FeeInpatInvoiceSID  
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10_VerticalSID] d WITH (NOLOCK)  
		ON b.[ICD10SID] = d.[ICD10SID] AND (d.DxCategory = 'OUD' OR d.ICD10Code LIKE 'F11.9%')



--------------------------------------------------------------------------------------------------------------
/****************************************MOST RECENT DIAGNOSIS DATE******************************************/
--------------------------------------------------------------------------------------------------------------
-- Get the most recent date for each diagnosis category
DROP TABLE IF EXISTS #DiagnosisDateWithCategory;
SELECT
	  MVIPersonSID
	  ,MAX(CAST(VisitDateTime AS datetime)) as MostRecentDate
	  ,DxCategory
INTO #DiagnosisDateWithCategory
FROM (
	SELECT MVIPersonSID,VisitDateTime,DxCategory
	FROM #OutpatVDiagnosis  
	UNION ALL   
	SELECT MVIPersonSID,AdmitDateTime AS VisitDateTime,DxCategory
	FROM #InpatDiagnosisAll 
	UNION ALL 
	SELECT MVIPersonSID,LastModifiedDateTime AS VisitDateTime,DxCategory 
	FROM #ProblemList
	UNION ALL 
	SELECT MVIPersonSID,DiagnosisDateTime AS VisitDateTime,DxCategory 
	FROM #MillDiagnosis
	UNION ALL
	SELECT MVIPersonSID,InitialTreatmentDateTime AS VisitDateTime,DxCategory 
	FROM #CommunityCareDiagnosis) a
GROUP BY MVIPersonSID,DxCategory

DROP TABLE IF EXISTS #VADiagnosisDate
SELECT DISTINCT MVIPersonSID
	  ,MostRecentDate AS LastVADiagnosisDate
INTO #VADiagnosisDate
FROM #DiagnosisDateWithCategory

--Most recent instance date for DoD OUD cohort
DROP TABLE IF EXISTS #MostRecentDoDdate;
SELECT
	  MVIPersonSID
	  ,MAX(CAST(instance_date AS datetime)) as MostRecentDate
INTO #MostRecentDoDdate
FROM [ORM].[dod_oud]
GROUP BY MVIPersonSID

--Pull in the Care Type
DROP TABLE IF EXISTS #CareType
SELECT a.MVIPersonSID
       ,CASE WHEN CareType = 'DIRECT CARE' THEN 'DIRECT'
	         WHEN CareType = 'NETWORK OR COMMUNITY CARE' THEN 'COMMUNITY'
	      ELSE CareType END AS CareType
	  ,MostRecentDate
INTO #CareType
FROM #MostRecentDoDdate a
     LEFT JOIN [ORM].[dod_oud] b
	 ON a.MVIPersonSID = b.MVIPersonSID 
	 AND a.MostRecentDate = CAST(b.instance_date AS datetime)


DROP TABLE IF EXISTS #DoDDiagnosisDate
SELECT DISTINCT a.MVIPersonSID
	   ,a.MostRecentDate AS LastDoDDiagnosisDate 
	  ,a.CareType
	  ,b.LastVADiagnosisDate
INTO #DoDDiagnosisDate
FROM  #CareType as a 
     left JOIN #VADiagnosisDate as b
	  on a.MVIPersonSID = b.MVIPersonSID


DROP TABLE IF EXISTS #StageDiagnosisDate
SELECT MVIPersonSID
       ,MAX(CareType) AS CareType
       ,MAX(LastDoDDiagnosisDate) AS LastDoDDiagnosisDate
	   ,MAX(LastVADiagnosisDate) AS LastVADiagnosisDate
INTO #StageDiagnosisDate
FROM #DoDDiagnosisDate
GROUP BY MVIPersonSID

EXEC [Maintenance].[PublishTable] 'ORM.DoDOUDDiagnosisDate','#StageDiagnosisDate';

DROP TABLE 
	 #OutpatVDiagnosis
	,#InpatDiagnosisAll
	,#ProblemList
	,#CommunityCareDiagnosis

END