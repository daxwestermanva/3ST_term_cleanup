
-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 4/17/2024
-- Description: Getting Long Term (current) use of opiate information for ORM DoD OUD Patient Report 

-- =============================================
CREATE PROCEDURE [Code].[ORM_DoDOUDZ79891]
	-- Add the parameters for the stored procedure here
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.ORM_DoDOUDZ79891','Execution of SP Code.ORM_ORM_DoDOUDZ79891'

--DoD OUD Cohort
DROP TABLE IF EXISTS #Cohort;
SELECT a.[MVIPersonSID]
      ,mvi.PatientPersonSID
      ,[EDIPI]
      ,[LastName]
      ,[FirstName]
      ,[MiddleName]
      ,[NameSuffix]
      ,[DateofBirth]
      ,[age]
      ,[Gender]
	  ,d.LastDoDDiagnosisDate
	  ,d.LastVADiagnosisDate
	  ,c.VisitDateTime
	  ,a.MaxDoDEncounter
INTO #Cohort 
FROM [ORM].[dod_oud] AS a
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.MVIPersonSID = mvi.MVIPersonSID 
LEFT JOIN ORM.DoDOUDDiagnosisDate AS d
      ON a.MVIPersonSID = d.MVIPersonSID
LEFT JOIN ORM.DoDOUDVAContact AS c
     ON a.MVIPersonSID = c.MVIPersonSID AND c.MostRecent_ICN = 1




  DROP TABLE IF EXISTS #OutpatVDiagnosis;
  SELECT
		c.MVIPersonSID
		,1 AS Z79891
  INTO  #OutpatVDiagnosis 
  FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
  INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].ICD10 b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND b.ICD10Code in ('Z79.891')
  WHERE a.WorkloadLogicFlag = 'Y'
 

  --------------------------------------------------------------------------------------------------------
  /****************************************VistA INPATIENT DIAGNOSIS*******************************************/
  --------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  

  -- 20190319 - RAS - Q: Should we use discharge dates or transfer dates instead of admit date?  Use later for most recent date?

  DROP TABLE IF EXISTS #InpatientDiagnosis;
  SELECT c.MVIPersonSID
		,1 AS Z79891
  INTO #InpatientDiagnosis 
  FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND b.ICD10Code in ('Z79.891')
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.DischargeDateTime  IS NULL


  DROP TABLE IF EXISTS #InpatientDischargeDiagnosis;
  SELECT
		c.MVIPersonSID
		,1 AS Z79891
  INTO #InpatientDischargeDiagnosis
  FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND b.ICD10Code in ('Z79.891')
  INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.DischargeDateTime  IS NULL


  DROP TABLE IF EXISTS #SpecialtyTransferDiagnosis;
  SELECT
		c.MVIPersonSID
		,1 AS Z79891
  INTO #SpecialtyTransferDiagnosis 
  FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK)
		ON a.[ICD10SID] = b.[ICD10SID] AND b.ICD10Code in ('Z79.891')
  INNER JOIN [Inpat].[Inpatient] d WITH(NOLOCK)
		ON a.InpatientSID = d.InpatientSID
  WHERE  a.SpecialtyTransferDateTime  IS NULL


  DROP TABLE IF EXISTS #InpatDiagnosisAll;
  SELECT MVIPersonSID,Z79891
  INTO #InpatDiagnosisAll
  FROM (
	  SELECT MVIPersonSID,Z79891 
	  FROM #InpatientDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Z79891 
	  FROM #InpatientDischargeDiagnosis
		UNION ALL
	  SELECT MVIPersonSID,Z79891
	  FROM #SpecialtyTransferDiagnosis
	) u


  --------------------------------------------------------------------------------------------------------------
  /****************************************VistA PROBLEM LIST DIAGNOSIS**********************************************/
  --------------------------------------------------------------------------------------------------------------
  --Gets inpatient visit diagnoses, limiting to any diagnosis category we have defined in LookUp ICD10
  

  DROP TABLE IF EXISTS #ProblemList;
  SELECT DISTINCT 
		c.MVIPersonSID
		,1 AS Z79891
  INTO #ProblemList
  FROM [Outpat].[ProblemList] a WITH(NOLOCK)
 INNER JOIN #cohort c WITH (NOLOCK)
		ON c.PatientPersonSID = a.PatientSID --"Active" patients
  INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.[ICD10SID] = b.[ICD10SID] AND b.ICD10Code in ('Z79.891')
  WHERE [ActiveFlag] = 'A' 
	  AND ProblemListCondition <> 'H' --excludes "history of"
  ;
  

--------------------------------------------------------------------------------------------------------------
/****************************************CERNER DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MillDiagnosis
SELECT c.MVIPersonSID
	  ,1 AS Z79891
INTO #MillDiagnosis
FROM [Cerner].[FactDiagnosis] c WITH (NOLOCK)
INNER JOIN [LookUp].[ICD10] l WITH (NOLOCK)  
	ON l.ICD10SID=c.NomenclatureSID AND l.ICD10Code in ('Z79.891')
INNER JOIN #cohort co WITH(NOLOCK)
	ON co.PatientPersonSID=c.PersonSID
WHERE c.SourceVocabulary = 'ICD-10-CM' --needed?
	AND c.MVIPersonSID>0


--------------------------------------------------------------------------------------------------------------
/****************************************COMMUNITY CARE DIAGNOSIS**********************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #CommunityCareDiagnosis
SELECT MVIPersonSID
	  ,1 AS Z79891
INTO #CommunityCareDiagnosis 
FROM [Fee].[FeeServiceProvided] a WITH (NOLOCK)
INNER JOIN [Fee].[FeeInitialTreatment] b WITH (NOLOCK)
	ON a.FeeInitialTreatmentSID = b.FeeInitialTreatmentSID
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10] d WITH (NOLOCK)  
		ON a.[ICD10SID] = d.[ICD10SID] AND d.ICD10Code in ('Z79.891')

UNION ALL

SELECT MVIPersonSID
	  ,1 AS Z79891
FROM [Fee].[FeeInpatInvoice] a WITH (NOLOCK)
INNER JOIN [Fee].[FeeInpatInvoiceICDDiagnosis] b WITH (NOLOCK)
	ON a.FeeInpatInvoiceSID = b.FeeInpatInvoiceSID  
INNER JOIN #cohort c WITH (NOLOCK)  
	ON c.PatientPersonSID = a.PatientSID --"Active" patients
INNER JOIN [LookUp].[ICD10_VerticalSID] d WITH (NOLOCK)  
		ON b.[ICD10SID] = d.[ICD10SID] AND d.ICD10Code in ('Z79.891')

--------------------------------------------------------------------------------------------------------------
/****************************************UNION ALL******************************************/
--------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #LongTermOpiate;
SELECT
	  MVIPersonSID
	  ,Z79891
INTO #LongTermOpiate
	FROM #OutpatVDiagnosis  
	UNION ALL   
	SELECT MVIPersonSID,Z79891
	FROM #InpatDiagnosisAll 
	UNION ALL 
	SELECT MVIPersonSID,Z79891 
	FROM #ProblemList
	UNION ALL 
	SELECT MVIPersonSID,Z79891 
	FROM #MillDiagnosis
	UNION ALL
	SELECT MVIPersonSID,Z79891 
	FROM #CommunityCareDiagnosis

EXEC [Maintenance].[PublishTable] 'ORM.ORM_DoDOUDZ79891', '#LongTermOpiate'

EXEC [Log].[ExecutionEnd] 

END