
-- =============================================
-- Author:	<Shalini Gupta>
-- Original code from Sara T
-- Create date: <11/27/2017>
-- Description:	Creating STORM MetricTable
--	2/15/2017	GS added App.Tool_DoBackup
--	2018-06-07	Jason Bacani - Removed hard coded database references
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--  2019-10-23  SG Limiting RiskCategory to (1,2,3,4,5,9)
--  2020-10-06  CLB - Simplified code based on RAS refactor 
--  2023-01-11	CW reverting back to original code before recent TG/CW changes to Anxiolytic Measure (MeasureID=16), per conversation with Jodie
--  2024-06-05  CW incorporating cc overdose cohort
-- =============================================
CREATE PROCEDURE [Code].[ORM_MetricTable]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_MetricTable', @Description = 'Execution of Code.ORM_MetricTable SP'

/**************************************************************************************************************/	
/****************************** Prepare patient counts and reference tables ***********************************/
/**************************************************************************************************************/	
 
--Get all ORM patients and their facility/group/provider assignments from PatientReport
DROP TABLE IF EXISTS #PatientReport_GroupAssignmentsSTORM
SELECT ga.MVIPersonSID
	  ,pr.VISN 
      ,pr.ChecklistID
	  ,ga.GroupID
	  ,ga.GroupType
	  ,ga.ProviderSID
	  ,ProviderName=MAX(ISNULL(ga.ProviderName, 'Unassigned'))
	  ,RiskCategory= MAX(pr.RiskCategory) 
	  ,OpioidForPain_Rx= MAX(pr.OpioidForPain_Rx)
	  ,OUD= MAX(pr.OUD)
	  ,SUDdx_poss=MAX(pr.SUDdx_poss)
	  ,Anxiolytics_Rx= MAX(pr.Anxiolytics_Rx)
	  ,MAX(CAST(pr.ODPastYear AS int)) AS ODPastYear  
INTO #PatientReport_GroupAssignmentsSTORM
FROM [ORM].[PatientReport] as pr WITH (NOLOCK)
INNER JOIN [Present].[GroupAssignments_STORM] as ga  WITH (NOLOCK)
		ON ga.MVIPersonSID=pr.MVIPersonSID-- get GroupID for everybody
WHERE pr.RiskCategory in (1,2,3,4,5,9,10,11) --NOT including those that recently discontinued opioids in metrics
GROUP BY ga.MVIPersonSID
	  ,pr.VISN 
      ,pr.ChecklistID
	  ,ga.GroupID
	  ,ga.GroupType
	  ,ga.ProviderSID;


DROP TABLE IF EXISTS #PatientReport_CC 
SELECT ga.MVIPersonSID
	  ,VISN=ISNULL(pr.VISN,0)
      ,ChecklistID=ISNULL(pr.ChecklistID,0)
	  ,GroupID=ISNULL(ga.GroupID,0)
	  ,GroupType=ISNULL(ga.GroupType,0)
	  ,ProviderSID=ISNULL(ga.ProviderSID,0)
	  ,ProviderName=MAX(ISNULL(ga.ProviderName, 'Unassigned'))
	  ,RiskCategory= MAX(pr.RiskCategory) 
	  ,OpioidForPain_Rx= MAX(pr.OpioidForPain_Rx)
	  ,OUD= MAX(pr.OUD)
	  ,SUDdx_poss=MAX(pr.SUDdx_poss)
	  ,Anxiolytics_Rx= MAX(pr.Anxiolytics_Rx)
	  ,MAX(CAST(pr.ODPastYear AS int)) AS ODPastYear  
INTO #PatientReport_CC
FROM [ORM].[PatientReport] as pr  WITH (NOLOCK)
LEFT JOIN [Present].[GroupAssignments_STORM] as ga  WITH (NOLOCK)
		ON ga.MVIPersonSID=pr.MVIPersonSID 
WHERE pr.RiskCategory in (12)
AND ga.MVIPersonSID IS NOT NULL
GROUP BY ga.MVIPersonSID
	  ,pr.VISN 
      ,pr.ChecklistID
	  ,ga.GroupID
	  ,ga.GroupType
	  ,ga.ProviderSID;


DROP TABLE IF EXISTS #PatientReport_GroupAssignments
SELECT * INTO #PatientReport_GroupAssignments FROM #PatientReport_GroupAssignmentsSTORM
UNION
SELECT * FROM #PatientReport_CC;


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
	  ,ISNULL(RiskCategory,0) RiskCategory
	  --count of all patients
	  ,COUNT(DISTINCT p.MVIPersonSID) AllOpioidPatient
	  --count of patients with opioid rx (pills on hand?)
	  ,COUNT(DISTINCT(CASE WHEN p.OpioidForPain_Rx=1 THEN p.MVIPersonSID END)) AllOpioidRXCount
	  --count of patients with opioid use disorder diagnosis
	  ,COUNT(DISTINCT(CASE WHEN p.OUD=1 THEN p.MVIPersonSID END)) AllOUDCount
	  --count of patients with substance use disorder diagnosis
	  ,COUNT(DISTINCT(CASE WHEN p.SUDdx_poss=1 THEN p.MVIPersonSID END)) AllOpioidSUDCount
	  --Overdose in the past year
	  ,COUNT(DISTINCT(CASE WHEN p.ODPastYear=1 THEN p.MVIPersonSID END)) AllPastYearODCount
INTO #PatientCounts
FROM #PatientReport_GroupAssignments p
GROUP BY GROUPING SETS (
	(VISN,ChecklistID,GroupID,GroupType,ProviderSID,RiskCategory)
	,(VISN,ChecklistID,GroupID,ProviderSID)
	,(VISN,ChecklistID,GroupID,RiskCategory)
	,(VISN,ChecklistID,GroupID)
	,(VISN,ChecklistID,RiskCategory)
	,(VISN,ChecklistID)
	,(VISN,RiskCategory)
	,(VISN)
	,(RiskCategory) --National
	,() --National
	);


--SELECT top 100 * FROM #PatientCounts ORDER BY VISN,ChecklistID,GroupID,ProviderSID,RiskCategory

CREATE NONCLUSTERED INDEX IX_groupings ON #PatientReport_GroupAssignments(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,RiskCategory)

--Count the total number of VA patients at the ProviderSID, GroupID, and
--facility levels 
DROP TABLE IF EXISTS #AllTxPatients;
SELECT ISNULL(VISN,0) VISN
      ,CASE WHEN ChecklistID IS NULL AND VISN IS NULL THEN '0'
			WHEN ChecklistID IS NULL THEN CAST(VISN as VARCHAR)
			ELSE ChecklistID END ChecklistID
	  ,ISNULL(GroupID,0) GroupID
	  ,ISNULL(ProviderSID,0) ProviderSID
	  ,COUNT(DISTINCT MVIPersonSID) AllTxPatients
INTO #AllTxPatients
FROM [Present].[GroupAssignments_STORM]  WITH (NOLOCK)
GROUP BY GROUPING SETS (
	(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName)
	,(VISN,ChecklistID,GroupID,GroupType)
	,(VISN,ChecklistID)
	,(VISN)
	,() --National
	);


/**************************************************************************************************************/	
/******************************************* Prepare Measure Computation **************************************/
/**************************************************************************************************************/	
 
--Get measure data from risk mitigation
DROP TABLE IF EXISTS #RM_Measures  
SELECT   rm.MVIPersonSID
		,rm.MitigationID as MeasureID
		,MAX(rm.Checked) as MeasureMet
INTO #RM_Measures
FROM [ORM].[RiskMitigation] rm  WITH (NOLOCK)
WHERE MetricInclusion=1
GROUP BY rm.MVIPersonSID,rm.MitigationID


--Add Anxiolytic OD Risk Measure
INSERT INTO #RM_Measures (MVIPersonSID,MeasureID,MeasureMet)
SELECT MVIPersonSID
	  ,MeasureID=16
	  ,MeasureMet=MAX(CASE WHEN Anxiolytics_Rx=0 THEN 1 ELSE 0 END)
FROM #PatientReport_GroupAssignments
GROUP BY MVIPersonSID


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
	  ,ISNULL(p.RiskCategory,0) RiskCategory
	  ,m.MeasureID
	  --Measure computation: count of patients who met measure/count of patients eligible
	  ,COUNT(DISTINCT p.MVIPersonSID) as Denominator
	  ,COUNT(DISTINCT(CASE WHEN m.MeasureMet = 1 THEN p.MVIPersonSID END)) as Numerator
INTO #Measures
FROM #PatientReport_GroupAssignments p
	LEFT JOIN #RM_Measures m 
		ON m.MVIPersonSID=p.MVIPersonSID
GROUP BY GROUPING SETS (
	--Providers
	(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,RiskCategory,MeasureID)
	,(VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID)
	--Groups
	,(VISN,ChecklistID,GroupID,GroupType,RiskCategory,MeasureID)
	,(VISN,ChecklistID,GroupID,GroupType,MeasureID)
	--ChecklistID
	,(VISN,ChecklistID,RiskCategory,MeasureID)
	,(VISN,ChecklistID,MeasureID)
	--VISN
	,(VISN,RiskCategory,MeasureID)
	,(VISN,MeasureID)
	--National
	,(RiskCategory,MeasureID)
	,(MeasureID)
	)

/*
-- Validation for denominator aggregate
SELECT distinct p.MVIPersonSID, mp.PatientName, ChecklistID, VISN, RiskCategory, MeasureID, MeasureMet
FROM #PatientReport_GroupAssignments p
LEFT JOIN #RM_Measures m 
	ON m.MVIPersonSID=p.MVIPersonSID
INNER JOIN Common.MasterPatient mp 
	ON p.MVIPersonSID=mp.MVIPersonSID
WHERE ChecklistID='640' and VISN=21 and MeasureID=18 and RiskCategory=5 
ORDER BY PatientName
*/

/**************************************************************************************************************/	
/************************************************ Stage Table *******************************************/
/**************************************************************************************************************/	
 
DROP TABLE IF EXISTS #StageORMMetric;
WITH Ntl AS (
	SELECT MeasureID,RiskCategory
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
	  ,m.RiskCategory
	  ,pc.AllOpioidPatient
	  ,pc.AllOpioidRXCount as AllOpioidRXPatient
	  ,pc.AllOUDCount as AllOUDPatient
	  ,pc.AllOpioidSUDCount as AllOpioidSUDPatient
	  ,pc.AllPastYearODCount as AllPastYearODCount
	  ,m.MeasureID
	  ,Permeasure = 'MeasureID_' + CAST(m.MeasureID AS VARCHAR)
	  ,md.PrintName
	  ,m.Numerator
	  ,m.Denominator
	  ,m.Numerator/(CAST(m.Denominator AS DECIMAL)) Score
	  ,ntl.NatScore 
	  ,atp.AllTxPatients
INTO #StageORMMetric 
FROM #Measures m
	INNER JOIN [ORM].[MeasureDetails] md  WITH (NOLOCK)
		ON md.MeasureID=m.MeasureID
	INNER JOIN #PatientCounts pc 
		ON m.VISN=pc.VISN
			AND m.ChecklistID=pc.ChecklistID
			AND m.GroupID=pc.GroupID
			AND m.ProviderSID=pc.ProviderSID
			AND m.RiskCategory=pc.RiskCategory
	INNER JOIN Ntl as ntl 
		ON ntl.MeasureID=m.MeasureID
			AND ntl.RiskCategory=m.RiskCategory
	INNER JOIN #AllTxPatients atp 
		ON m.VISN=atp.VISN
			AND m.ChecklistID=atp.ChecklistID
			AND m.GroupID=atp.GroupID
			AND m.ProviderSID=atp.ProviderSID
	LEFT JOIN [LookUp].[ChecklistID] as sta  WITH (NOLOCK)
		ON m.ChecklistID=sta.ChecklistID

--SELECT TOP 1000 * FROM #StageORMMetric ORDER BY VISN,ChecklistID,GroupID,ProviderSID,RiskCategory

EXEC [Maintenance].[PublishTable] 'ORM.MetricTable','#StageORMMetric'

EXEC [Log].[ExecutionEnd]

END

GO
