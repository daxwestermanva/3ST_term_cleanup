

-- =============================================
-- Author:		<Sara Tavakoli
-- Create date: 2.10.16
-- Description: Redo of Patient Visits 
-- Modification: Reduced query time 
--	2.22.16 added ICD10 proc codes to psych therapy
--	12/18/2016 GS repointed lookup tables to OMHO_PERC
--	2018-06-07	Jason Bacani - Removed hard coded database references
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--	2020-10-05	LM - Overlay of Cerner data
--	2021-07-20	Jason Bacani - Enclave Refactoring - Counts confirmed
--	2022-05-02	RAS - Refactored to use Lookup ListMember instead of LookUp CPT. 
					--Removed unneccesary distincts, subqueries, and added "all" to unions
-- 2022-05-07	RAS - Refactored LookUp ICD10Proc to Lookup ListMember, refactored to use unpivoted structure until final staging.
-- =============================================
CREATE PROCEDURE [Code].[ORM_Visits]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_Visits', @Description = 'Execution of Code.ORM_Visits SP'

------------------------------------------------------------------------------------------------------------------------------------
/**********  STORM  ALL COHORT**************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #AllPatient_Cohort
SELECT MVIPersonSID
INTO #AllPatient_Cohort
FROM [Present].[Spatient]

CREATE NONCLUSTERED INDEX III_Hypothetical_cohort
      ON #AllPatient_Cohort (MVIPersonSID); 

------------------------------------------------------------------------------------------------------------------------------------
/**********Psychosocial Tx**************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------

/**********CPT Codes****************/
DROP TABLE IF EXISTS #CPT
SELECT co.MVIPersonSID
	,lc.List
	,vp.VisitDateTime
INTO #CPT
FROM #AllPatient_Cohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON co.MVIPersonSID = mvi.MVIPersonSID 
INNER JOIN [Outpat].[VProcedure] vp WITH (NOLOCK) ON vp.PatientSID = mvi.PatientPersonSID
INNER JOIN [LookUp].[ListMember] lc WITH (NOLOCK) ON vp.CPTSID = lc.ItemID
WHERE vp.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
	AND lc.List IN ('Psych_Therapy','Psych_Assessment')
	AND lc.Domain = 'CPT'

UNION ALL

SELECT co.MVIPersonSID
	,lc.List
	,fp.DerivedProcedureDateTime as ProcedureDateTime
FROM #AllPatient_Cohort co
INNER JOIN [Cerner].[FactProcedure]  as fp on co.MVIPersonSID=fp.MVIPersonSID
INNER JOIN [LookUp].[ListMember] lc WITH (NOLOCK) ON fp.NomenclatureSID = lc.ItemID
WHERE fp.DerivedProcedureDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	AND fp.SourceVocabulary in ('CPT4','HCPCS')
	AND lc.List IN ('Psych_Therapy','Psych_Assessment')
	AND lc.Domain = 'CPT'
	
/**********Procedure Codes****************/
DROP TABLE IF EXISTS #ICDProc
SELECT 
	co.MVIPersonSID
	,l.List
	,ipp.ICDProcedureDateTime
INTO #ICDProc
FROM #AllPatient_Cohort co
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON mvi.MVIPersonSID = co.MVIPersonSID
INNER JOIN [Inpat].[InpatientICDProcedure] ipp WITH (NOLOCK) ON ipp.PatientSID = mvi.PatientPersonSID
INNER JOIN [LookUp].[ListMember] l WITH (NOLOCK) ON ipp.ICD10ProcedureSID = l.ItemID 
WHERE ipp.ICDProcedureDateTime >= CAST(DATEADD(DAY, -366, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	AND l.List IN ('Psych_Therapy')
	AND l.Domain = 'ICD10PCS'

UNION ALL

SELECT
	co.MVIPersonSID
	,l.List
	,fp.DerivedProcedureDateTime as ProcedureDateTime
FROM #AllPatient_Cohort co
INNER JOIN [Cerner].[FactProcedure] fp WITH (NOLOCK) 
	ON co.MVIPersonSID = fp.MVIPersonSID 
	AND DerivedProcedureDateTime >= CAST(DATEADD(DAY, -366, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
INNER JOIN [LookUp].[ListMember] l WITH (NOLOCK) ON fp.NomenclatureSID = l.ItemID
WHERE fp.SourceVocabulary = 'ICD-10-PCS' 
	AND l.List IN ('Psych_Therapy')
	AND l.Domain = 'ICD10PCS'

------------------------------------------------------------------------------------------------------------------------------------
/**********ALL TOGETHER AND PIVOT *************************************************************************/
------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ORM_Visit;
WITH PersonListRollUp AS (
	SELECT MVIPersonSID
		,List
		,MaxDate = MAX(VisitDateTime) 
	FROM (
		SELECT MVIPersonSID
			,List
			,VisitDateTime
		FROM #CPT
		UNION ALL
		SELECT MVIPersonSID
			,List
			,ICDProcedureDateTime
		FROM #ICDProc
		) u
	GROUP BY MVIPersonSID,List
	)
SELECT MVIPersonSID
	,Psych_Therapy_Key		= MAX(CASE WHEN Psych_Therapy IS NULL THEN 0 ELSE 1 END)
	,Psych_Therapy_Date		= MAX(Psych_Therapy)
	,Psych_Assessment_Key	= MAX(CASE WHEN Psych_Assessment IS NULL THEN 0 ELSE 1 END)
	,Psych_Assessment_Date	= MAX(Psych_Assessment)
INTO #ORM_Visit
FROM (
	SELECT MVIPersonSID,List,MaxDate
	FROM PersonListRollUp
	) r
PIVOT (MAX(MaxDate) FOR List IN (Psych_Therapy,Psych_Assessment)
	) p
GROUP BY MVIPersonSID


EXEC [Maintenance].[PublishTable] 'ORM.Visit', '#ORM_Visit'


EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
