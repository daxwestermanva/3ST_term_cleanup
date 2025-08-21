

-- =============================================
-- Author:	<Tolessa Gurmessa>
-- Based on Shalini G's ORM_MetricTable code
-- Create date: <02/14/2022>
-- Description:	FPPE/OPPE measure for Opioid Safety - Dashboard for Primary Care Leaders
-- 2022-03-08  - TG changed risk mitigation reference to the separate dataset created for this report
-- 2022-03-29 - TG querying for all providers, instead of just PCP
-- 2024-06-13 - TG adding the number of patients due in 90 days for each risk mitigation
-- 2024-06-24 - TG a due in 90 days bug
-- 2024-09-30 - LM Adding WITH (NOLOCK)
-- =============================================
CREATE PROCEDURE [Code].[ORM_OPPEMetric] 
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_OPPEMetric', @Description = 'Execution of Code.OPPEMetric SP'

/**************************************************************************************************************/	
/****************************** Prepare patient counts and reference tables ***********************************/
/**************************************************************************************************************/	
 
--Get all ORM patients and their facility/group/provider assignments
--from PatientReport
--1770173
DROP TABLE IF EXISTS #PatientReport_GroupAssignments
SELECT ga.MVIPersonSID
	  ,pr.VISN 
      ,pr.ChecklistID
	  ,ga.GroupID
	  ,ga.GroupType
	  ,ga.ProviderSID
	  ,ProviderName=MAX(ISNULL(ga.ProviderName, 'Unassigned'))
	  ,ChronicOpioid = MAX(o.ChronicOpioid) 
INTO #PatientReport_GroupAssignments
FROM [ORM].[PatientReport] as pr WITH(NOLOCK)
     INNER JOIN (
	    SELECT MVIPersonSID, ChronicOpioid
	    FROM [ORM].[OpioidHistory] WITH(NOLOCK)
		WHERE ActiveRxStatusVM=1 --WHERE RxStatus IN ('HOLD','SUSPENDED','ACTIVE','PROVIDER HOLD')
			AND ChronicOpioid = 1) AS o
	    ON pr.MVIPersonSID = o.MVIPersonSID 
	INNER JOIN [Present].[GroupAssignments_STORM] as ga WITH (NOLOCK)
		ON ga.MVIPersonSID=pr.MVIPersonSID AND ga.ChecklistID=pr.ChecklistID --AND ga.GroupID = 2 --PCP
--WHERE pr.RiskCategory in (1,2,3,4,5,9,10,11) --NOT including those that recently discontinued opioids in metrics
GROUP BY ga.MVIPersonSID
	  ,pr.VISN 
      ,pr.ChecklistID
	  ,ga.GroupID
	  ,ga.GroupType
	  ,ga.ProviderSID

--Get overall patient counts by type of patient before joining #PatientReport_GroupAssignments 
--(e.g., with #RM_Measures later in SP) because this is fewer rows over which to count 
--distinct patients
DROP TABLE IF EXISTS #PatientCounts
SELECT ISNULL(VISN,0) VISN
	  ,CASE WHEN ChecklistID IS NULL AND VISN IS NULL THEN '0'
			WHEN ChecklistID IS NULL AND VISN IS NOT NULL THEN CAST(VISN AS VARCHAR)
			ELSE ChecklistID END ChecklistID
	  ,ISNULL(GroupID,0) GroupID
	  ,ISNULL(ProviderSID,0) ProviderSID
	  --count of patients on LTOT
	  ,COUNT(DISTINCT(CASE WHEN p.ChronicOpioid=1 THEN p.MVIPersonSID END)) AllLTOTCount
INTO #PatientCounts
FROM #PatientReport_GroupAssignments p
GROUP BY GROUPING SETS (
	(VISN,ChecklistID,GroupID,ProviderSID)
	,(VISN,ChecklistID,GroupID)
	,(VISN,ChecklistID)
	,(VISN)
	,() --National
	)

--SELECT top 100 * FROM #PatientCounts ORDER BY VISN,ChecklistID,GroupID,ProviderSID,RiskCategory

CREATE NONCLUSTERED INDEX IX_groupings ON #PatientReport_GroupAssignments(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName)

--Count the total number of VA patients at the ProviderSID, GroupID, and
--facility levels 
DROP TABLE IF EXISTS #AllTxPatients
SELECT ISNULL(VISN,0) VISN
      ,CASE WHEN ChecklistID IS NULL AND VISN IS NULL THEN '0'
			WHEN ChecklistID IS NULL THEN CAST(VISN as VARCHAR)
			ELSE ChecklistID END ChecklistID
	  ,ISNULL(GroupID,0) GroupID
	  ,ISNULL(ProviderSID,0) ProviderSID
	  ,COUNT(DISTINCT MVIPersonSID) AllTxPatients
INTO #AllTxPatients
FROM [Present].[GroupAssignments_STORM] WITH (NOLOCK)
GROUP BY GROUPING SETS (
	(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName)
	,(VISN,ChecklistID,GroupID,GroupType)
	,(VISN,ChecklistID)
	,(VISN)
	,() --National
	)

/**************************************************************************************************************/	
/******************************************* Prepare Measure Computation **************************************/
/**************************************************************************************************************/	
 
--Get measure data from risk mitigation
DROP TABLE IF EXISTS #RM_Measures
SELECT rm.MVIPersonSID
	  ,rm.MitigationID as MeasureID
	  ,MAX(rm.Checked) as MeasureMet
	  ,MAX(rm.DueNinetyDays) as DueNinetyDays
INTO #RM_Measures
FROM [ORM].[OPPERiskMitigation] rm WITH (NOLOCK)
GROUP BY rm.MVIPersonSID,rm.MitigationID


CREATE NONCLUSTERED INDEX IX_prga ON #PatientReport_GroupAssignments(MVIPersonSID)
CREATE NONCLUSTERED INDEX IX_RMMeasures ON #RM_Measures(MVIPersonSID)

--Compute measure numerator and denominator at the provider, 
--group, checklistID, VISN, and national levels. At each level,
--break down by risk category and also get a count over all
--risk categories.
DROP TABLE IF EXISTS #Measures
SELECT ISNULL(p.VISN,0) VISN
      ,CASE WHEN p.ChecklistID IS NULL AND p.VISN IS NULL THEN '0'
			WHEN p.ChecklistID IS NULL THEN CAST(p.VISN as VARCHAR)
			ELSE p.ChecklistID END ChecklistID
	  ,ISNULL(p.GroupID,0) GroupID
	  ,ISNULL(p.GroupType,'All Provider Groups') GroupType
	  ,ISNULL(p.ProviderSID,0) ProviderSID
	  ,ISNULL(p.ProviderName,'All Providers') ProviderName	 
	  ,m.MeasureID
	  --Measure computation: count of patients who met measure/count of patients eligible
	  ,COUNT(DISTINCT p.MVIPersonSID) as Denominator
	  ,COUNT(DISTINCT(CASE WHEN m.MeasureMet = 1 THEN p.MVIPersonSID END)) as Numerator
	  ,COUNT(DISTINCT(CASE WHEN m.DueNinetyDays = 1 THEN p.MVIPersonSID END)) as DueNinetyDays
INTO #Measures
FROM #PatientReport_GroupAssignments p
	LEFT JOIN #RM_Measures m 
		ON m.MVIPersonSID=p.MVIPersonSID
GROUP BY GROUPING SETS (
	--Providers
	(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID)
	--Groups
	,(VISN,ChecklistID,GroupID,GroupType,MeasureID)
	--ChecklistID
	,(VISN,ChecklistID,MeasureID)
	--VISN
	,(VISN,MeasureID)
	--National
	,(MeasureID)
	)

--SELECT * FROM #Measures ORDER BY VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,RiskCategory

/**************************************************************************************************************/	
/************************************************ Stage Table *******************************************/
/**************************************************************************************************************/	
 
DROP TABLE IF EXISTS #StageORMMetric;
WITH Ntl AS (
	SELECT MeasureID
		,Numerator/(CAST(Denominator AS DECIMAL)) NatScore
	FROM #Measures
	WHERE VISN=0
	)
SELECT m.VISN
	  ,m.ChecklistID
	  ,sta.ADMParent_FCDM
	  ,m.GroupID
	  ,m.GroupType
	  ,m.ProviderSID
	  ,m.ProviderName
	  ,pc.AllLTOTCount
	  ,m.MeasureID
	  ,Permeasure = 'MeasureID_' + CAST(m.MeasureID AS VARCHAR)
	  ,md.PrintName
	  ,m.Numerator
	  ,m.Denominator
	  ,m.Numerator/(CAST(m.Denominator AS DECIMAL)) Score
	  ,m.DueNinetyDays
	  ,ntl.NatScore
	  ,atp.AllTxPatients
	  ,MetricDate = GETDATE()
INTO #StageORMMetric 
FROM #Measures m
	INNER JOIN [ORM].[MeasureDetails] md WITH (NOLOCK) 
		ON md.MeasureID=m.MeasureID
	INNER JOIN #PatientCounts pc 
		ON m.VISN=pc.VISN
			AND m.ChecklistID=pc.ChecklistID
			AND m.GroupID=pc.GroupID
			AND m.ProviderSID=pc.ProviderSID
	INNER JOIN Ntl as ntl 
		ON ntl.MeasureID=m.MeasureID
	INNER JOIN #AllTxPatients atp 
		ON m.VISN=atp.VISN
			AND m.ChecklistID=atp.ChecklistID
			AND m.GroupID=atp.GroupID
			AND m.ProviderSID=atp.ProviderSID
	LEFT JOIN [LookUp].[ChecklistID] as sta WITH (NOLOCK) 
		ON m.ChecklistID=sta.ChecklistID

--SELECT TOP 1000 * FROM #StageORMMetric ORDER BY VISN,ChecklistID,GroupID,ProviderSID,RiskCategory

EXEC [Maintenance].[PublishTable] 'ORM.OPPEMetric','#StageORMMetric' --Change this to insert

EXEC [Log].[ExecutionEnd]

END