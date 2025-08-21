

/*-- =============================================
-- Author:		<Liam Mina>
-- Create date: <2022-08-12>
-- Description:	Health factors that relate to social determinants of health

-- Modifications:

-- Testing execution:
--		EXEC [Code].[Present_SPTelehealth]
--
-- =============================================*/
CREATE PROCEDURE [Code].[Present_SPTelehealth]
AS
BEGIN

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
EXEC [Log].[ExecutionBegin] @Name = 'Present_SPTelehealth', @Description = 'Execution of Code.Present_SPTelehealth'

DROP TABLE IF EXISTS #Intake
SELECT b.MVIPersonSID
	,a.VisitDateTime
	,a.VisitSID
	,c.HealthFactorType
	,ActionType = 1
INTO #Intake
FROM [HF].[HealthFactor] a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] b WITH (NOLOCK)
	ON a.PatientSID = b.PatientPersonSID
INNER JOIN [Dim].[HealthFactorType] c WITH (NOLOCK)
	ON a.HealthFactorTypeSID = c.HealthFactorTypeSID
INNER JOIN [Present].[SPatient] mp WITH (NOLOCK)
	ON b.MVIPersonSID = mp.MVIPersonSID
WHERE c.HealthFactorType LIKE 'VA-OSP TH INTAKE%'


DROP TABLE IF EXISTS #Discharge
SELECT b.MVIPersonSID
	,a.VisitDateTime
	,a.VisitSID
	,c.HealthFactorType
	,CASE WHEN c.HealthFactorType LIKE 'VA-OSP TH% PLANNED%' THEN 2
		WHEN c.HealthFactorType LIKE 'VA-OSP TH% UNPLANNED%' THEN 3
		END AS ActionType
	,CASE WHEN HealthFactorType LIKE '%DC PST%' THEN 'MH_PSTSP_Template'
		WHEN HealthFactorType lIKE '%DC CBT%' THEN 'MH_CBTSP_Template'
		WHEN HealthFactorType LIKE '%DC DBT%' THEN 'MH_DBTSP_Template'
		END AS TemplateGroup
INTO #Discharge
FROM [HF].[HealthFactor] a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] b WITH (NOLOCK)
	ON a.PatientSID = b.PatientPersonSID
INNER JOIN [Dim].[HealthFactorType] c WITH (NOLOCK)
	ON a.HealthFactorTypeSID = c.HealthFactorTypeSID
INNER JOIN [Present].[SPatient] mp WITH (NOLOCK)
	ON b.MVIPersonSID = mp.MVIPersonSID
WHERE c.HealthFactorType LIKE 'VA-OSP TH% PLANNED'
	OR c.HealthFactorType LIKE 'VA-OSP TH% UNPLANNED'

DROP TABLE IF EXISTS #FirstLast
SELECT a.MVIPersonSID
	,MIN(a.VisitDateTime) AS FirstSessionDate
	,MAX(a.VisitDateTime) AS MostRecentSessionDate
	,a.TemplateGroup
INTO #FirstLast
FROM [EBP].[TemplateVisits] a WITH (NOLOCK)
WHERE a.DiagnosticGroup = 'SuicidePrevention'
GROUP BY a.MVIPersonSID, a.TemplateGroup

DROP TABLE IF EXISTS #Combine
SELECT a.*
	,RowNum = ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ISNULL(IntakeDate,'1/1/1900'), DischargeDate DESC, MostRecentSessionDate DESC)
INTO #Combine
FROM (
	SELECT DISTINCT i.MVIPersonSID
		,MAX(i.VisitDateTime) OVER (PARTITION BY i.MVIPersonSID, v.TemplateGroup) AS IntakeDate
		,CASE WHEN ISNULL(v.TemplateGroup,d.TemplateGroup) LIKE '%CBT%' THEN 'Cognitive Behavioral Therapy for Suicide Prevention'
			WHEN ISNULL(v.TemplateGroup,d.TemplateGroup) LIKE '%DBT%' THEN 'Dialectical Behavioral Therapy for Suicide Prevention'
			WHEN ISNULL(v.TemplateGroup,d.TemplateGroup) LIKE '%PST%' THEN 'Problem-Solving Therapy for Suicide Prevention'
			END AS TemplateGroup
		,v.FirstSessionDate
		,v.MostRecentSessionDate
		,d.VisitDateTime AS DischargeDate
		,CASE WHEN d.ActionType=2 THEN 'Planned'
			WHEN d.ActionType=3 THEN 'Unplanned'
			ELSE NULL END AS DischargeType
		
	
	FROM #Intake i
	LEFT JOIN #FirstLast v
		ON v.MVIPersonSID = i.MVIPersonSID
		AND CAST(v.FirstSessionDate as date) >= CAST(i.VisitDateTime as date)
	LEFT JOIN #Discharge d
		ON i.MVIPersonSID = d.MVIPersonSID 
		AND (v.TemplateGroup = d.TemplateGroup or v.TemplateGroup is null)
		AND d.VisitDateTime > i.VisitDateTime
		AND (CAST(d.VisitDateTime as date) >= CAST(v.MostRecentSessionDate as date) OR v.MostRecentSessionDate IS NULL)
	) a
	
	EXEC [Maintenance].[PublishTable] 'Present.SPTelehealth', '#Combine' ;
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END