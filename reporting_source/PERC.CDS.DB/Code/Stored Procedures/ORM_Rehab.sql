-- =============================================
-- Author:		<OpioidRiskMitigationTeam><Susana Martins>
-- Create date: 1/8/2015
-- Description: Code for OpioidRiskMitigation Patient Report 
-- Modification: Combines basetable and patient report code
--	2/18/16 - SM updating to include ICD10proc codes
--	3/24/16 - ST added ICD10 Proc Codes for Chiropractic Care
--	12/18/2016 GS repointed lookup tables to OMHO_PER
--	2018-06-07	Jason Bacani - Removed hard coded database references
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--	2020-09-08	LM	- Switched health factors to use LookupList architecture
--	2020-09-18	LM - Simplified code in preparation for overlay; fixed issue with stop codes 
--	2020-10-13	LM - Overlay of Cerner data
--	2021-07-19	JEB - Enclave Refactoring - Counts confirmed
--	2022-05-02	RAS - Refactored to use LookUp.ListMember for CPT and then cleaned up formatting,
					-- many unnecessary subqueries and unions without "all"
--   2024-07-17  TG  - adding WorkloadLogicFlag = 'Y' to the visit filter to weed out non workload CIH therapies.
                    -- also changed the STORM cohort to SUD.Cohort and filtered for STORM
--	2025-01-06	LM - Switch Char4 lookup to use Lookup.ListMember
--  2025-03-13  TG - Reverting back to the original datasets (no more datasets from Whole Health)
--  2025-07-25  TG - Excluding unsigned, retracted, etc TIU notes 
-- =============================================
CREATE PROCEDURE [Code].[ORM_Rehab]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_Rehab', @Description = 'Execution of Code.ORM_Rehab SP'

/******************************************************** Codes for Rehab Med************************************************************/
--Get CAM from OpioidMET app.CAM..

--•	Code.LookUpCPT

----RM_ActiveTherapies_CPT	RehabilitationMedicine	Active Therapies
----RM_ChiropracticCare_CPT	RehabilitationMedicine	Chiropractic Care
----RM_OccupationalTherapy_CPT	RehabilitationMedicine	Occupational Therapy
----RM_OtherTherapy_CPT	RehabilitationMedicine	Other Therapy
----RM_PhysicalTherapy_CPT	RehabilitationMedicine	Physical Therapy
----RM_SpecialtyTherapy_CPT	RehabilitationMedicine	Specialty Therapy
----CAM_CPT

--•	Code.LookUpICD9Proc

----RM_ActiveTherapies_ICD9Proc	RehabilitationMedicine	Active Therapies
----RM_OccupationalTherapy_ICD9Proc	RehabilitationMedicine	Occupational Therapy
----RM_OtherTherapy_ICD9Proc	RehabilitationMedicine	Other Therapy
----CAM_ICD9Proc

--•	Code.LookupStopCode

----,[RM_PhysicalTherapy_Stop]
----,[RM_ChiropracticCare_Stop]
----,[RM_ActiveTherapies_Stop]
----,[RM_OccupationalTherapy_Stop]
----,[RM_SpecialtyTherapy_Stop]
----,[RM_OtherTherapy_Stop]
----,[RM_PainClinic_Stop]

;
------------------------------------------------------------------------------------------------------------------------------------
/**********STORM ALL COHORT**************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #STORM_ALLCohort
SELECT sc.MVIPersonSID --, pt.PatientPersonSID AS PatientSID
INTO #STORM_ALLCohort
FROM [SUD].[Cohort] AS sc
WHERE STORM = 1 or ODPastYear = 1 or CommunityCare_ODPastYear = 1 or RecentlyDiscontinuedOpioid_Rx = 1

------------------------------------------------------------------------------------------------------------------------------------
/**********RehabilitationMedicine**************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------

/**********CPT Codes****************/

DROP TABLE IF EXISTS #RM_CPT;
WITH LookUpCPT AS (
	SELECT List,ItemID,AttributeValue FROM [LookUp].[ListMember]
	WHERE Domain = 'CPT'
		AND List IN (
			'RM_ActiveTherapies'
			,'RM_ChiropracticCare'
			,'RM_OccupationalTherapy'
			,'RM_OtherTherapy'
			,'RM_PhysicalTherapy'
			,'RM_SpecialtyTherapy'
			,'CAM'
			)
		)
SELECT co.MVIPersonSID
	,MAX(CASE WHEN List = 'RM_ActiveTherapies'		THEN 1 ELSE 0 END) AS RM_ActiveTherapies_CPT_Key
	,MAX(CASE WHEN List = 'RM_ChiropracticCare'		THEN 1 ELSE 0 END) AS RM_ChiropracticCare_CPT_Key
	,MAX(CASE WHEN List = 'RM_OccupationalTherapy' 	THEN 1 ELSE 0 END) AS RM_OccupationalTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_OtherTherapy'			THEN 1 ELSE 0 END) AS RM_OtherTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_PhysicalTherapy'		THEN 1 ELSE 0 END) AS RM_PhysicalTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_SpecialtyTherapy'		THEN 1 ELSE 0 END) AS RM_SpecialtyTherapy_CPT_Key
	,MAX(CASE WHEN List = 'CAM'						THEN 1 ELSE 0 END) AS CAM_CPT_Key
	,vp.VisitDateTime
INTO #RM_CPT
FROM #STORM_ALLCohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON co.MVIPersonSID = mvi.MVIPersonSID
INNER JOIN [Outpat].[VProcedure] vp WITH (NOLOCK) 
	ON vp.PatientSID = mvi.PatientPersonSID AND WorkloadLogicFlag = 'Y'
INNER JOIN LookUpCPT l ON l.ItemID = vp.CPTSID
WHERE vp.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
GROUP BY co.MVIPersonSID
	,vp.VisitDateTime

UNION ALL
-- The Visit dataset from Whole Health has Cerner records. I'm not sure about the completeness, so I am keeping the Cerner queries as they are.
SELECT co.MVIPersonSID
	,MAX(CASE WHEN List = 'RM_ActiveTherapies'		THEN 1 ELSE 0 END) AS RM_ActiveTherapies_CPT_Key
	,MAX(CASE WHEN List = 'RM_ChiropracticCare'		THEN 1 ELSE 0 END) AS RM_ChiropracticCare_CPT_Key
	,MAX(CASE WHEN List = 'RM_OccupationalTherapy'	THEN 1 ELSE 0 END) AS RM_OccupationalTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_OtherTherapy'			THEN 1 ELSE 0 END) AS RM_OtherTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_PhysicalTherapy'		THEN 1 ELSE 0 END) AS RM_PhysicalTherapy_CPT_Key
	,MAX(CASE WHEN List = 'RM_SpecialtyTherapy'		THEN 1 ELSE 0 END) AS RM_SpecialtyTherapy_CPT_Key
	,MAX(CASE WHEN List = 'CAM'						THEN 1 ELSE 0 END) AS CAM_CPT_Key
	,TZDerivedProcedureDateTime AS VisitDateTime
FROM #STORM_ALLCohort co
INNER JOIN [Cerner].[FactProcedure]  as fp on co.MVIPersonSID=fp.MVIPersonSID 
	AND fp.TZDerivedProcedureDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
INNER JOIN LookUpCPT as l ON fp.NomenclatureSID = l.ItemID 
WHERE fp.SourceVocabulary IN ('CPT4','HCPCS')
GROUP BY co.MVIPersonSID
	,TZDerivedProcedureDateTime

CREATE NONCLUSTERED INDEX III_RM_CPT
      ON #RM_CPT (MVIPersonSID); 


/**********Procedure Codes****************/

DROP TABLE IF EXISTS #RM_ICDProc
SELECT co.MVIPersonSID
	,CASE WHEN l.RM_ActiveTherapies_ICD10Proc = 1		THEN 1 ELSE 0 END AS RM_ActiveTherapies_ICDProc_Key
	,CASE WHEN l.RM_ChiropracticCare_ICD10Proc = 1		THEN 1 ELSE 0 END AS RM_ChiropracticCare_ICDProc_Key
	,CASE WHEN l.RM_OccupationalTherapy_ICD10Proc = 1	THEN 1 ELSE 0 END AS RM_OccupationalTherapy_ICDProc_Key
	,0 AS RM_OtherTherapy_ICDProc_Key
	,CASE WHEN l.CIH_ICD10Proc = 1						THEN 1 ELSE 0 END AS CIH_ICDProc_Key
	,ipp.ICDProcedureDateTime
INTO #RM_ICDProc
FROM #STORM_ALLCohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON mvi.MVIPersonSID = co.MVIPersonSID
INNER JOIN [Inpat].[InpatientICDProcedure] ipp WITH (NOLOCK) ON ipp.PatientSID = mvi.PatientPersonSID 
INNER JOIN [LookUp].[ICD10Proc] l WITH (NOLOCK) ON l.ICD10ProcedureSID = ipp.ICD10ProcedureSID 
WHERE ipp.ICDProcedureDateTime >= CAST(DATEADD(DAY, -366, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	AND (l.RM_ActiveTherapies_ICD10Proc = 1 
		OR l.RM_ChiropracticCare_ICD10Proc = 1 
		OR l.RM_OccupationalTherapy_ICD10Proc = 1 
		OR l.CIH_ICD10Proc = 1
		)

UNION ALL

SELECT co.MVIPersonSID
	,CASE WHEN l.RM_ActiveTherapies_ICD10Proc=1 THEN 1 ELSE 0 END AS RM_ActiveTherapies_ICDProc_Key
	,CASE WHEN l.RM_ChiropracticCare_ICD10Proc=1 THEN 1 ELSE 0 END AS RM_ChiropracticCare_ICDProc_Key
	,CASE WHEN l.RM_OccupationalTherapy_ICD10Proc=1 THEN 1 ELSE 0 END AS RM_OccupationalTherapy_ICDProc_Key
	,RM_OtherTherapy_ICDProc_Key=0
	,CASE WHEN CIH_ICD10Proc=1 THEN 1 ELSE 0 END AS CIH_ICDProc_Key
	,TZDerivedProcedureDateTime as TZProcedureDateTime
FROM #STORM_ALLCohort co
INNER JOIN [Cerner].[FactProcedure] AS fp WITH (NOLOCK) ON co.MVIPersonSID = fp.MVIPersonSID 
	AND fp.TZDerivedProcedureDateTime >= CAST(DATEADD(DAY, -366, GETDATE()) AS DATETIME2(0))
INNER JOIN [LookUp].[ICD10Proc] as l on fp.SourceIdentifier = l.ICD10ProcedureCode
WHERE fp.SourceVocabulary = 'ICD-10-PCS' 
	AND (RM_ActiveTherapies_ICD10Proc=1 
		OR RM_ChiropracticCare_ICD10Proc=1 
		OR RM_OccupationalTherapy_ICD10Proc=1 
		OR CIH_ICD10Proc=1
		)

CREATE NONCLUSTERED INDEX III_RM_ICDProc
      ON #RM_ICDProc (MVIPersonSID); 

/****************Stop Codes**************/
DROP TABLE IF EXISTS #RM_Stop
SELECT co.MVIPersonSID
  ,CASE WHEN ps.RM_ActiveTherapies_Stop = 1    THEN 1 ELSE 0 END AS RM_ActiveTherapies_Stop_Key
  ,CASE WHEN ps.RM_PhysicalTherapy_Stop = 1    THEN 1 ELSE 0 END AS RM_PhysicalTherapy_Stop_Key
  ,CASE WHEN ps.RM_ChiropracticCare_Stop = 1    THEN 1 ELSE 0 END AS RM_ChiropracticCare_Stop_Key
  ,CASE WHEN ps.RM_OccupationalTherapy_Stop = 1  THEN 1 ELSE 0 END AS RM_OccupationalTherapy_Stop_Key
  ,CASE WHEN ps.RM_SpecialtyTherapy_Stop = 1    THEN 1 ELSE 0 END AS RM_SpecialtyTherapy_Stop_Key
  ,CASE WHEN ps.RM_OtherTherapy_Stop = 1      THEN 1 ELSE 0 END AS RM_OtherTherapy_Stop_Key
  ,CASE WHEN ps.RM_PainClinic_Stop = 1      THEN 1 ELSE 0 END AS RM_PainClinic_Stop_Key
  ,CASE WHEN ps.ORM_CIH_Stop = 1          THEN 1 ELSE 0 END AS ORM_CIH_Stop_Key
  ,ov.VisitDateTime
INTO #RM_Stop
FROM #STORM_ALLCohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON mvi.MVIPersonSID = co.MVIPersonSID
INNER JOIN [Outpat].[Visit] ov WITH (NOLOCK) ON ov.PatientSID = mvi.PatientPersonSID
LEFT JOIN [LookUp].[StopCode] ps WITH (NOLOCK) ON ov.PrimaryStopCodeSID = ps.StopCodeSID 
WHERE ov.WorkloadLogicFlag = 'Y' 
	AND ov.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
  AND (ps.RM_ActiveTherapies_Stop = 1  
    OR ps.RM_PhysicalTherapy_Stop = 1
    OR ps.RM_ChiropracticCare_Stop = 1  
    OR ps.RM_OccupationalTherapy_Stop = 1  
    OR ps.RM_SpecialtyTherapy_Stop = 1  
    OR ps.RM_OtherTherapy_Stop = 1  
    OR ps.RM_PainClinic_Stop = 1  
    OR ps.ORM_CIH_Stop = 1  
    )

UNION 

SELECT co.MVIPersonSID
  ,CASE WHEN ss.RM_ActiveTherapies_Stop = 1    THEN 1 ELSE 0 END AS RM_ActiveTherapies_Stop_Key
  ,CASE WHEN ss.RM_PhysicalTherapy_Stop = 1    THEN 1 ELSE 0 END AS RM_PhysicalTherapy_Stop_Key
  ,CASE WHEN ss.RM_ChiropracticCare_Stop = 1    THEN 1 ELSE 0 END AS RM_ChiropracticCare_Stop_Key
  ,CASE WHEN ss.RM_OccupationalTherapy_Stop = 1  THEN 1 ELSE 0 END AS RM_OccupationalTherapy_Stop_Key
  ,CASE WHEN ss.RM_SpecialtyTherapy_Stop = 1    THEN 1 ELSE 0 END AS RM_SpecialtyTherapy_Stop_Key
  ,CASE WHEN ss.RM_OtherTherapy_Stop = 1      THEN 1 ELSE 0 END AS RM_OtherTherapy_Stop_Key
  ,CASE WHEN ss.RM_PainClinic_Stop = 1      THEN 1 ELSE 0 END AS RM_PainClinic_Stop_Key
  ,CASE WHEN ss.ORM_CIH_Stop = 1          THEN 1 ELSE 0 END AS ORM_CIH_Stop_Key
  ,ov.VisitDateTime
FROM #STORM_ALLCohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON mvi.MVIPersonSID = co.MVIPersonSID
INNER JOIN [Outpat].[Visit] ov WITH (NOLOCK) ON ov.PatientSID = mvi.PatientPersonSID
LEFT JOIN [LookUp].[StopCode] ss WITH (NOLOCK) ON ov.SecondaryStopCodeSID = ss.StopCodeSID 
WHERE ov.WorkloadLogicFlag = 'Y' 
AND ov.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
  AND (ss.RM_ActiveTherapies_Stop = 1 
    OR ss.RM_PhysicalTherapy_Stop = 1
    OR ss.RM_ChiropracticCare_Stop = 1
    OR ss.RM_OccupationalTherapy_Stop = 1
    OR ss.RM_SpecialtyTherapy_Stop = 1
    OR ss.RM_OtherTherapy_Stop = 1
    OR ss.RM_PainClinic_Stop = 1
    OR ss.ORM_CIH_Stop = 1
    )

UNION ALL

SELECT co.MVIPersonSID
  ,ps.RM_ActiveTherapies_Stop
  ,ps.RM_PhysicalTherapy_Stop
  ,ps.RM_ChiropracticCare_Stop
  ,ps.RM_OccupationalTherapy_Stop
  ,ps.RM_SpecialtyTherapy_Stop
  ,ps.RM_OtherTherapy_Stop
  ,ps.RM_PainClinic_Stop
  ,ps.ORM_CIH_Stop
  ,sc.TZServiceDateTime
FROM #STORM_ALLCohort co
INNER JOIN [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK) 
  ON co.MVIPersonSID = sc.MVIPersonSID
INNER JOIN [LookUp].[StopCode] ps WITH (NOLOCK) 
  ON sc.CompanyUnitBillTransactionAliasSID = ps.StopCodeSID 
WHERE sc.TZServiceDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
  AND (ps.RM_ActiveTherapies_Stop = 1   
    OR ps.RM_PhysicalTherapy_Stop = 1  
    OR ps.RM_ChiropracticCare_Stop = 1  
    OR ps.RM_OccupationalTherapy_Stop = 1
    OR ps.RM_SpecialtyTherapy_Stop = 1    
    OR ps.RM_OtherTherapy_Stop = 1    
    OR ps.RM_PainClinic_Stop = 1      
    OR ps.ORM_CIH_Stop = 1  
    )
	
CREATE NONCLUSTERED INDEX III_RM_Stop
      ON #RM_Stop (MVIPersonSID); 
	 
/*****************************CIH Health Factors***********************************/

-- Turns out, 'ORM_CIH_HF' lookup is empty. Until that is sorted out, I will leave the section as is.
DROP TABLE IF EXISTS #ORM_CIH_HF
SELECT mvi.MVIPersonSID
	,1 AS ORM_CIH_HF_Key 
	,MAX(hf.HealthFactorDateTime) AS ORM_CIH_Date
INTO #ORM_CIH_HF
FROM [HF].[HealthFactor] hf WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] lm WITH (NOLOCK) ON hf.HealthFactorTypeSID = lm.ItemID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON hf.PatientSID = mvi.PatientPersonSID 
INNER JOIN [Present].[SPatient] sp WITH (NOLOCK) ON mvi.MVIPersonSID = sp.MVIPersonSID 
WHERE lm.List = 'ORM_CIH_HF'
	AND hf.HealthFactorDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
GROUP BY mvi.MVIPersonSID

CREATE NONCLUSTERED INDEX III_ORM_CIH_HF
      ON #ORM_CIH_HF (MVIPersonSID);

/*****************************CIH TIU Note Titles***********************************/

DROP TABLE IF EXISTS #ORM_CIH_TIU
SELECT mvi.MVIPersonSID
	,1 AS ORM_CIH_Key
	,MAX(tiu.EntryDateTime) AS ORM_CIH_Date
INTO #ORM_CIH_TIU
FROM [TIU].[TIUDocument] tiu
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON tiu.PatientSID = mvi.PatientPersonSID 
INNER JOIN [Present].[SPatient] c WITH (NOLOCK) ON mvi.MVIPersonSID = c.MVIPersonSID 
INNER JOIN [LookUp].[ListMember] l WITH (NOLOCK) ON l.ItemID = tiu.TIUDocumentDefinitionSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON tiu.TIUStatusSID = ts.TIUStatusSID
WHERE tiu.EntryDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
	AND l.List='ORM_CIH_TIU'
	AND tiu.DeletionDateTime IS NULL
	AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
GROUP BY mvi.MVIPersonSID

CREATE NONCLUSTERED INDEX III_ORM_CIH_TIU
      ON #ORM_CIH_TIU (MVIPersonSID);

/*****************************CIH Char4***********************************/

DROP TABLE IF EXISTS #ORM_CIH_CHAR4
SELECT mvi.MVIPersonSID
	,1 AS ORM_CIH_Key
	,MAX(ov.VisitDateTime) AS ORM_CIH_Date
INTO #ORM_CIH_CHAR4
FROM [Outpat].[Visit] ov 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON ov.PatientSID = mvi.PatientPersonSID 
INNER JOIN [Present].[SPatient] c WITH (NOLOCK) ON mvi.MVIPersonSID = c.MVIPersonSID 
INNER JOIN [LookUp].[ListMember] l WITH (NOLOCK) ON ov.LocationSID = l.ItemID
WHERE ov.WorkloadLogicFlag = 'Y' AND l.List = 'CIH'
	AND ov.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
GROUP BY mvi.MVIPersonSID

CREATE NONCLUSTERED INDEX III_ORM_CIH_CHAR4
      ON #ORM_CIH_CHAR4 (MVIPersonSID);
	
/*************************All Together Active Therapies *************************/
DROP TABLE IF EXISTS  #RM_ActiveTherapies
SELECT MVIPersonSID
	,MAX(RM_ActiveTherapies_Key) as RM_ActiveTherapies_Key
	,MAX(RM_ActiveTherapies_Date) as RM_ActiveTherapies_Date 
INTO #RM_ActiveTherapies
FROM (
	SELECT MVIPersonSID
		,RM_ActiveTherapies_CPT_Key AS RM_ActiveTherapies_Key
		,VisitDateTime AS RM_ActiveTherapies_Date
	FROM #RM_CPT
	WHERE RM_ActiveTherapies_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_ActiveTherapies_ICDProc_Key 
		,ICDProcedureDateTime
	FROM #RM_ICDProc
	WHERE RM_ActiveTherapies_ICDProc_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_ActiveTherapies_Stop_Key 
		,VisitDateTime	
	FROM #RM_Stop
	WHERE  RM_ActiveTherapies_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_ActiveTherapies
      ON #RM_ActiveTherapies (MVIPersonSID); 

/*************************All Together Chiropractic Therapies *************************/
DROP TABLE IF EXISTS  #RM_ChiropracticCare
SELECT MVIPersonSID
	,MAX(RM_ChiropracticCare_Key) AS RM_ChiropracticCare_Key
	,MAX(RM_ChiropracticCare_Date) AS RM_ChiropracticCare_Date
INTO #RM_ChiropracticCare
FROM (
	SELECT MVIPersonSID
		,RM_ChiropracticCare_CPT_Key AS RM_ChiropracticCare_Key
		,VisitDateTime AS RM_ChiropracticCare_Date
	FROM #RM_CPT
	WHERE RM_ChiropracticCare_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_ChiropracticCare_ICDProc_Key 
		,ICDProcedureDateTime 
	FROM #RM_ICDProc
	WHERE RM_ChiropracticCare_ICDProc_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_ChiropracticCare_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE RM_ChiropracticCare_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_ChiropracticCare
      ON #RM_ChiropracticCare (MVIPersonSID); 

/*************************All Together Occupational Therapies *************************/
DROP TABLE IF EXISTS #RM_OccupationalTherapy
SELECT MVIPersonSID
	,MAX(RM_OccupationalTherapy_Key) AS RM_OccupationalTherapy_Key
	,MAX(RM_OccupationalTherapy_Date) AS RM_OccupationalTherapy_Date
INTO #RM_OccupationalTherapy
FROM (
	SELECT MVIPersonSID
		,RM_OccupationalTherapy_CPT_Key AS RM_OccupationalTherapy_Key
		,VisitDateTime AS RM_OccupationalTherapy_Date
	FROM #RM_CPT
	WHERE RM_OccupationalTherapy_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_OccupationalTherapy_ICDProc_Key
		,ICDProcedureDateTime
	FROM #RM_ICDProc
	WHERE RM_OccupationalTherapy_ICDProc_Key = 1
	UNION
	SELECT MVIPersonSID
		,RM_OccupationalTherapy_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE  RM_OccupationalTherapy_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_OccupationalTherapy
      ON #RM_OccupationalTherapy (MVIPersonSID); 

/*************************All Together Other Therapies *************************/
DROP TABLE IF EXISTS #RM_OtherTherapy
SELECT MVIPersonSID
	,MAX(RM_OtherTherapy_Key) AS RM_OtherTherapy_Key
	,MAX(RM_OtherTherapy_Date) AS RM_OtherTherapy_Date 
INTO #RM_OtherTherapy
FROM (
	SELECT MVIPersonSID
		,RM_OtherTherapy_CPT_Key AS RM_OtherTherapy_Key
		,VisitDateTime AS RM_OtherTherapy_Date
	FROM #RM_CPT
	WHERE RM_OtherTherapy_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_OtherTherapy_ICDProc_Key 
		,ICDProcedureDateTime
	FROM #RM_ICDProc
	WHERE RM_OtherTherapy_ICDProc_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_OtherTherapy_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE  RM_OtherTherapy_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_OtherTherapy
      ON #RM_OtherTherapy (MVIPersonSID); 

/*************************All Together Physical Therapies *************************/
DROP TABLE IF EXISTS  #RM_PhysicalTherapy
SELECT MVIPersonSID
	,MAX(RM_PhysicalTherapy_Key) AS RM_PhysicalTherapy_Key
	,MAX(RM_PhysicalTherapy_Date) AS RM_PhysicalTherapy_Date
INTO #RM_PhysicalTherapy
FROM (
	SELECT MVIPersonSID
		,RM_PhysicalTherapy_CPT_Key AS RM_PhysicalTherapy_Key
		,VisitDateTime AS RM_PhysicalTherapy_Date
	FROM #RM_CPT
	WHERE RM_PhysicalTherapy_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_PhysicalTherapy_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE RM_PhysicalTherapy_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_PhysicalTherapy
      ON #RM_PhysicalTherapy (MVIPersonSID); 

/*************************All Together Specialty Therapies *************************/
DROP TABLE IF EXISTS   #RM_SpecialtyTherapy
SELECT MVIPersonSID
	,MAX(RM_SpecialtyTherapy_Key) AS RM_SpecialtyTherapy_Key
	,MAX(RM_SpecialtyTherapy_Date) AS RM_SpecialtyTherapy_Date
INTO #RM_SpecialtyTherapy
FROM (
	SELECT MVIPersonSID
		,RM_SpecialtyTherapy_CPT_Key AS RM_SpecialtyTherapy_Key
		,VisitDateTime AS RM_SpecialtyTherapy_Date
	FROM #RM_CPT
	WHERE RM_SpecialtyTherapy_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,RM_SpecialtyTherapy_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE RM_SpecialtyTherapy_Stop_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_RM_SpecialtyTherapy
      ON #RM_SpecialtyTherapy (MVIPersonSID);

/*************************All together Pain Clinic *************************/

DROP TABLE IF EXISTS #RM_PainClinic_stop
Select MVIPersonSID
	,RM_PainClinic_Stop_Key AS RM_PainClinic_Key
	,max(a.VisitDateTime) AS RM_PainClinic_Date
INTO #RM_PainClinic_stop
FROM #RM_Stop a
WHERE RM_PainClinic_Stop_Key = 1
GROUP BY  MVIPersonSID, RM_PainClinic_Stop_Key

/**********All together CAM Therapies****************/
DROP TABLE IF EXISTS #CAM
SELECT MVIPersonSID
	,MAX(CAM_Key) AS CAM_Key
	,MAX(CAM_Date) AS CAM_Date 
INTO #CAM
FROM (
	SELECT MVIPersonSID
		,CAM_CPT_Key as CAM_Key
		,VisitDateTime as CAM_Date
	FROM #RM_CPT
	WHERE CAM_CPT_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,CIH_ICDProc_Key 
		,ICDProcedureDateTime
	FROM #RM_ICDProc
	WHERE CIH_ICDProc_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,ORM_CIH_Stop_Key 
		,VisitDateTime
	FROM #RM_Stop
	WHERE ORM_CIH_Stop_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,ORM_CIH_HF_Key 
		,ORM_CIH_Date
	FROM #ORM_CIH_HF
	WHERE ORM_CIH_HF_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,ORM_CIH_Key 
		,ORM_CIH_Date
	FROM #ORM_CIH_TIU
	WHERE ORM_CIH_Key = 1
	UNION ALL
	SELECT MVIPersonSID
		,ORM_CIH_Key
		,ORM_CIH_Date
	FROM #ORM_CIH_CHAR4
	WHERE ORM_CIH_Key = 1
	) AS a
GROUP BY MVIPersonSID

CREATE NONCLUSTERED INDEX III_CAM
      ON #CAM (MVIPersonSID);
	
------------------------------------------------------------------------------------------------------------------------------------
/**********ALL TOGETHER *************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ORM_Rehab
SELECT DISTINCT a.MVIPersonSID
	,ISNULL(AT.RM_ActiveTherapies_Key, 0) AS RM_ActiveTherapies_Key
	,AT.RM_ActiveTherapies_Date
	,ISNULL(CC.RM_ChiropracticCare_Key, 0) AS RM_ChiropracticCare_Key
	,CC.RM_ChiropracticCare_Date
	,ISNULL(OT.RM_OccupationalTherapy_Key, 0) AS RM_OccupationalTherapy_Key
	,OT.RM_OccupationalTherapy_Date
	,ISNULL(Oth.RM_OtherTherapy_Key, 0) AS RM_OtherTherapy_Key
	,Oth.RM_OtherTherapy_Date
	,ISNULL(PT.RM_PhysicalTherapy_Key, 0) AS RM_PhysicalTherapy_Key
	,PT.RM_PhysicalTherapy_Date
	,ISNULL(ST.RM_SpecialtyTherapy_Key, 0) AS RM_SpecialtyTherapy_Key
	,ST.RM_SpecialtyTherapy_Date
	,ISNULL(PC.RM_PainClinic_Key, 0) AS RM_PainClinic_Key
	,PC.RM_PainClinic_Date
	,ISNULL(CAM.CAM_Key, 0) as CAM_Key
	,CAM_Date 
INTO #ORM_Rehab
FROM #STORM_ALLCohort as a 
LEFT JOIN #RM_ActiveTherapies AS AT ON a.MVIPersonSID=AT.MVIPersonSID
LEFT JOIN #RM_ChiropracticCare AS CC ON a.MVIPersonSID=CC.MVIPersonSID
LEFT JOIN #RM_OccupationalTherapy AS OT ON a.MVIPersonSID=OT.MVIPersonSID
LEFT JOIN #RM_OtherTherapy AS Oth ON a.MVIPersonSID=Oth.MVIPersonSID
LEFT JOIN #RM_PhysicalTherapy AS PT ON a.MVIPersonSID=PT.MVIPersonSID
LEFT JOIN #RM_SpecialtyTherapy AS ST ON a.MVIPersonSID=ST.MVIPersonSID
LEFT JOIN #RM_PainClinic_stop AS PC ON a.MVIPersonSID=PC.MVIPersonSID
LEFT JOIN #CAM AS CAM ON a.MVIPersonSID=CAM.MVIPersonSID
WHERE RM_ActiveTherapies_Key = 1 
	OR RM_ChiropracticCare_Key = 1 
	OR RM_OccupationalTherapy_Key = 1 
	OR RM_OtherTherapy_Key = 1 
	OR RM_PhysicalTherapy_Key = 1 
	OR RM_SpecialtyTherapy_Key = 1 
	OR RM_PainClinic_Key = 1 
	OR CAM_Key = 1

EXEC [Maintenance].[PublishTable] 'ORM.Rehab', '#ORM_Rehab'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
