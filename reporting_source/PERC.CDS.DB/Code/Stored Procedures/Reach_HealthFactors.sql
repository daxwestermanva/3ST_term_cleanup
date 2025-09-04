

/***-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <8/15/2017>
-- Description: Health factors AND writeback to answer the REACH questions
-- =============================================
*/ 
/***-- =============================================
-- 20171213	TG	Minor modifications to Amy's Reach_Healthfactors stored procedure. Promoted to Production on 2/5/2018
-- 20171218	CB	Talked to AR and TG on 12/18/2017 about affixing a static date to begin health factor pull;
				AR suggested March 1, 2017 since it marks the officialbeginning of national Reach Vet. 
				Note, however, that the health factor data actually was not in usage until approximately July 2017 (I.e. the way data and dates were pulled changed in July 2017), 
				but we chose March 2017 as the uniform fixed date.
-- 20171218	CB	Set #TIU query to pull from fixed date fixed date; replace the old code: WHERE  EntryDateTime > getdate() - 366 ) AS a
-- 20190205 RAS: Formatting changes.  Replaced drop table with Maintenance PublishTable.
-- 20200415 RAS: Added code to update StationAssignments in the case that a patient transfers to a ChecklistID for which they do NOT have
				 an entry in StationAssignments (resulting in missing name on report).  Added logging.
-- 20200708	LM	Changed to pull health factors and note titles from Lookup.List architecture, for easier transition to Cerner down the road
-- 20200904	LM	Overlay of Cerner data
-- 20210715 JEB Enclave Refactoring - Counts confirmed
-- 20210913	LM	Removed deleted TIU documents
-- 20210923 JEB Enclave Refactoring - Removed use of Partition ID
-- 20221118	LM	Added new care evaluation health factors
-- 20221130 LM  Added new patient status health factors (inpatient/incarcerated disaggregated from outreach status) and removed duplicate rows
-- 20230106	LM	Restructured to better utilize list mapping structure
-- 20230711	LM	Added provider name and coordinator name to REACH.QuestionStatus
-- 20231026	LM	Added columns to indicate what requirements the health factor meets
-- 20250709	LM	Separated LastActivity column into two - one for last Coordinator activity and one for last Provider activity
-- =============================================
*/ 
CREATE PROCEDURE [Code].[Reach_HealthFactors]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Reach_HealthFactors','Execution of SP Code.Reach_HealthFactors'

/*step 1 pull reach vet health factors */
DROP TABLE IF EXISTS #HealthFactorsTIU;
SELECT c.Category
		,m.List
		,m.ItemID
		,m.Domain
		,m.Attribute
		,c.Printname
		,c.Description AS QuestionNumber
		,AttributeValue
INTO #HealthFactorsTIU
FROM [Lookup].[ListMember] m WITH(NOLOCK)
INNER JOIN [Lookup].[List] c WITH(NOLOCK) ON m.List = c.List
WHERE c.Category = 'REACH VET'

DROP TABLE IF EXISTS #DTAComments
SELECT c.List
		,c.ItemID
		,p.DerivedDtaEventResult AS Comments
		,p.DocFormActivitySID
INTO #DTAComments
FROM #HealthFactorsTIU c 
INNER JOIN [Cerner].[FactPowerForm] p WITH(NOLOCK) on c.ItemID=p.DerivedDtaEventCodeValueSID
WHERE Attribute = 'Comment'

DROP TABLE IF EXISTS #REACHHealthFactors; 
SELECT   
	d.MVIPersonSID
	,h.PatientSID
	,h.Sta3n
    ,ISNULL(ld.ChecklistID,CAST(h.Sta3n AS VARCHAR)) AS ChecklistID
    ,h.HealthFactorSID
    ,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime --removing the seconds from the HF date since the note date doesnt have seconds
    ,h.VisitDateTime
    ,h.EncounterStaffSID
	,List
	,HF.AttributeValue
    ,h.Comments
    ,h.VisitSID
    ,h.HealthFactorTypeSID
	,NULL AS DTAEventCodeValueSID
    ,CASE WHEN HF.List = 'REACH_Coordinator' OR HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 2 END AS HFType --1 for Coordinator Note, 2 for Provider Note
	,CASE WHEN HF.List LIKE 'REACH_CareEval%' THEN 1 ELSE 0 END AS CareEval
	,CASE WHEN HF.List = 'REACH_Coordinator' THEN 1 ELSE 0 END AS Coordinator
	,CASE WHEN HF.List LIKE 'REACH_PatientStatus%' THEN 1 ELSE 0 END AS PatientStatus
	,CASE WHEN HF.List LIKE 'REACH_Provider%' THEN 1 ELSE 0 END AS Provider
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreach%' THEN 1 ELSE 0 END AS OutreachAttempted
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreachSucc%' THEN 1 ELSE 0 END AS OutreachSuccess
	,CASE WHEN HF.List = 'REACH_ProviderOutreachUnsuccs' THEN 1 ELSE 0 END AS OutreachUnsuccess
	,CASE WHEN HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 0 END AS Transfer
	,s.StaffName
    ,1 AS Source
	,NULL AS TIU
INTO  #REACHHealthFactors
FROM [REACH].[History] d WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON d.MVIPersonSID = mvi.MVIPersonSID 
INNER JOIN [HF].[HealthFactor] h WITH (NOLOCK)
	ON mvi.PatientPersonSID = h.PatientSID
INNER JOIN #HealthFactorsTIU HF 
	ON HF.ItemID = h.HealthFactorTypeSID
INNER JOIN [SStaff].[SStaff] s WITH (NOLOCK) 
	ON h.EncounterStaffSID = StaffSID
LEFT JOIN [Outpat].[Visit] v WITH (NOLOCK)
	ON h.VisitSID = v.VisitSID
LEFT JOIN [LookUp].[DivisionFacility] ld WITH (NOLOCK) 
	ON ld.DivisionSID = v.DivisionSID
WHERE  h.HealthFactorDateTime >= '2017-03-01' 
	AND HF.Domain = 'HealthFactorType'
	AND h.Sta3n <> 200
UNION ALL
SELECT pf.MVIPersonSID
	,pf.PersonSID AS PatientSID
	,Sta3n=200
    ,COALESCE(ch.ChecklistID,st.ChecklistID,d.ChecklistID) AS ChecklistID
    ,HealthFactorSID=NULL
	--RV coordinator and provider documentation is done within the same form; we need to be able to distinguish when each portion was documented so we need to use TZResultClinicalSignificantModifiedDateTime rather than TZFormDateTime
    ,CONVERT(VARCHAR(16),pf.TZClinicalSignificantModifiedDateTime) AS HealthFactorDateTime 
    ,pf.TZFormUTCDateTime AS VisitDateTime
    ,pf.ResultPerformedPersonStaffSID AS EncounterStaffSID
    ,HF.List
	,HF.AttributeValue
	,c.Comments
    ,pf.EncounterSID AS VisitSID
    ,HealthFactorTypeSID=NULL
	,DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
	,CASE WHEN HF.List = 'REACH_Coordinator' OR HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 2 END AS HFType --1 for Coordinator Note, 2 for Provider Note
	,CASE WHEN HF.List LIKE 'REACH_CareEval%' THEN 1 ELSE 0 END AS CareEval
	,CASE WHEN HF.List = 'REACH_Coordinator' THEN 1 ELSE 0 END AS Coordinator
	,CASE WHEN HF.List LIKE 'REACH_PatientStatus%' THEN 1 ELSE 0 END AS PatientStatus
	,CASE WHEN HF.List LIKE 'REACH_Provider%' THEN 1 ELSE 0 END AS Provider
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreach%' THEN 1 ELSE 0 END AS OutreachAttempted
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreachSucc%' THEN 1 ELSE 0 END AS OutreachSuccess
	,CASE WHEN HF.List = 'REACH_ProviderOutreachUnsuccs' THEN 1 ELSE 0 END AS OutreachUnsuccess
	,CASE WHEN HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 0 END AS Transfer
    ,s.NameFullFormatted AS StaffName
    ,1 AS Source
	,pf.DocFormDescription AS TIU
FROM [REACH].[History] as d WITH(NOLOCK)
INNER JOIN [Cerner].[FactPowerForm] as pf WITH(NOLOCK) 
	ON d.MVIPersonSID=pf.MVIPersonSID
INNER JOIN #HealthFactorsTIU AS HF 
	ON HF.ItemID = pf.DerivedDtaEventCodeValueSID AND HF.AttributeValue = pf.DerivedDtaEventResult
LEFT JOIN #DTAComments AS c 
	ON HF.List=c.List AND pf.DocFormActivitySID=c.DocFormActivitySID
LEFT JOIN [Cerner].[FactStaffDemographic] as s WITH(NOLOCK) 
	ON pf.ResultPerformedPersonStaffSID=s.PersonStaffSID
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON pf.StaPa = ch.StaPa
LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) st
		ON st.EncounterSID = pf.EncounterSID AND CAST(st.TZServiceDateTime as date)=CAST(pf.TZClinicalSignificantModifiedDateTime as date)
WHERE HF.Domain='PowerForm'
	AND HF.Attribute ='DTA' 
UNION ALL
SELECT pf.MVIPersonSID
	,pf.PersonSID AS PatientSID
	,Sta3n=200
    ,COALESCE(ch.ChecklistID,st.ChecklistID,d.ChecklistID) AS ChecklistID
    ,HealthFactorSID=NULL
	--RV coordinator and provider documentation is done within the same form; we need to be able to distinguish when each portion was documented so we need to use TZResultClinicalSignificantModifiedDateTime rather than TZFormDateTime
    ,CONVERT(VARCHAR(16),pf.TZClinicalSignificantModifiedDateTime) AS HealthFactorDateTime 
    ,pf.TZFormUTCDateTime AS VisitDateTime
    ,pf.ResultPerformedPersonStaffSID AS EncounterStaffSID
    ,HF.List
	,HF.AttributeValue
	,c.Comments
    ,pf.EncounterSID AS VisitSID
    ,HealthFactorTypeSID=NULL
	,DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
	,CASE WHEN HF.List = 'REACH_Coordinator' OR HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 2 END AS HFType --1 for Coordinator Note, 2 for Provider Note
	,CASE WHEN HF.List LIKE 'REACH_CareEval%' THEN 1 ELSE 0 END AS CareEval
	,CASE WHEN HF.List = 'REACH_Coordinator' THEN 1 ELSE 0 END AS Coordinator
	,CASE WHEN HF.List LIKE 'REACH_PatientStatus%' THEN 1 ELSE 0 END AS PatientStatus
	,CASE WHEN HF.List LIKE 'REACH_Provider%' THEN 1 ELSE 0 END AS Provider
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreach%' THEN 1 ELSE 0 END AS OutreachAttempted
	,CASE WHEN HF.List LIKE 'REACH_ProviderOutreachSucc%' THEN 1 ELSE 0 END AS OutreachSuccess
	,CASE WHEN HF.List = 'REACH_ProviderOutreachUnsuccs' THEN 1 ELSE 0 END AS OutreachUnsuccess
	,CASE WHEN HF.List LIKE 'REACH_Transfer%' THEN 1 ELSE 0 END AS Transfer
    ,s.NameFullFormatted AS StaffName
    ,1 AS Source
	,pf.DocFormDescription AS TIU
FROM [REACH].[History] as d WITH(NOLOCK)
INNER JOIN [Cerner].[FactPowerForm] as pf WITH(NOLOCK) 
	ON d.MVIPersonSID=pf.MVIPersonSID
INNER JOIN #HealthFactorsTIU AS HF
	ON HF.ItemID = pf.DerivedDtaEventCodeValueSID
LEFT JOIN #DTAComments AS c 
	ON HF.List=c.List AND pf.DocFormActivitySID=c.DocFormActivitySID
LEFT JOIN [Cerner].[FactStaffDemographic] as s WITH(NOLOCK) 
	ON pf.ResultPerformedPersonStaffSID=s.PersonStaffSID
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON pf.StaPa = ch.StaPa
LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) st
		ON st.EncounterSID = pf.EncounterSID AND CAST(st.TZServiceDateTime as date)=CAST(pf.TZClinicalSignificantModifiedDateTime as date)
WHERE HF.Domain='PowerForm'
	AND HF.Attribute ='DTA' AND (pf.DerivedDTAEventResult LIKE 'Other:%' AND HF.List LIKE '%Other%')

/*step 2 add available reach vet tiu information*/
--Only needed for VistA data
DROP TABLE IF EXISTS #TIU;
SELECT	t.PatientSID
		,v.MVIPersonSID
		,CAST(CONVERT(CHAR(16), t.EntryDateTime, 113) AS DATETIME) AS EntryDateTime
		,t.EntryDateTime AS EntryDateTimeSec
		,t.TIUDocumentSID
		,t.VisitSID
		,t.ReferenceDateTime
		,s.StaffName AS SignedByStaff
		,CASE 
			WHEN TIU.List = 'REACH_Coordinator_TIU' THEN 1
			WHEN TIU.List = 'REACH_Provider_TIU' THEN 2 
		END AS NoteType
		,ISNULL(c.ChecklistID,CAST(t.Sta3n AS VARCHAR)) AS ChecklistID
INTO #TIU
FROM [REACH].[History] v WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON v.MVIPersonSID = mvi.MVIPersonSID
INNER JOIN [TIU].[TIUDocument] t WITH (NOLOCK)
	ON mvi.PatientPersonSID = t.PatientSID
INNER JOIN #HealthFactorsTIU TIU 
	ON TIU.ItemID = t.TIUDocumentDefinitionSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON t.TIUStatusSID = ts.TIUStatusSID
LEFT JOIN [SStaff].[SStaff] s WITH (NOLOCK) 
	ON t.SignedByStaffSID = s.StaffSID
LEFT JOIN [Dim].[Institution] i WITH (NOLOCK) 
	ON t.InstitutionSID = i.InstitutionSID
LEFT JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) 
	ON i.StaPa = c.Sta6aID
WHERE t.EntryDateTime >= '2017-03-01'
	AND TIU.Domain = 'TIUDocumentDefinition'
	AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
;

/****Join HF with an exact VisitSID match in TIU*****/
DROP TABLE IF EXISTS #Step1_SID;
SELECT a.PatientSID
	,a.HealthFactorSID
	,a.VisitSID AS HealthFactorVisitSID
	,b.VisitSID AS NoteVisitSID
	,a.HealthFactorDateTime
	,a.VisitDateTime
    ,b.EntryDateTime
	,b.ReferenceDateTime
	,b.TIUDocumentSID
	,a.HFType
INTO   #Step1_SID
FROM   #REACHHealthFactors AS a
LEFT JOIN #TIU AS b ON 
	a.VisitSID = b.VisitSID 
	AND NoteType = HFType
	; 

/*step 3 - Grab all information */
--where visitsids do not match but HF record occurs on same day as TIU record entry date
DROP TABLE IF EXISTS #Step2_Date;
SELECT a.HealthFactorSID
	  ,a.HealthFactorVisitSID
	  ,a.PatientSID
	  ,a.HealthFactorDateTime
	  ,a.VisitDateTime
	  ,a.HFType
	  ,b.EntryDateTime
	  ,b.ReferenceDateTime
	  ,b.TIUDocumentSID
INTO #Step2_Date
FROM #Step1_SID  as a
LEFT JOIN #TIU as b  
	on a.PatientSID = b.PatientSID 
	AND NoteType = HFType 
	AND ( convert(date,HealthFactorDateTime)=convert(date,b.EntryDateTime) 
		or convert(date,HealthFactorDateTime)=convert(date,b.ReferenceDateTime) 
		)
WHERE a.NoteVisitSID IS NULL 
	AND b.VisitSID IS NOT NULL	
	;
 --when neither visitsids nor entry date match…grab IDs
DROP TABLE IF EXISTS #SID_Date_Match;
	SELECT HealthFactorSID
		  ,HealthFactorVisitSID
		  ,PatientSID
		  ,HealthFactorDateTime
		  ,VisitDateTime
		  ,TIUDocumentSID
	INTO #SID_Date_Match   
	FROM #Step1_SID
	WHERE NoteVisitSID is not null --where visitsids match
UNION ALL
	SELECT HealthFactorSID
		  ,HealthFactorVisitSID
		  ,PatientSID
		  ,HealthFactorDateTime
		  ,VisitDateTime 
		  ,TIUDocumentSID
	FROM #Step2_Date --where visit sids do not match, but dates do
	;
DROP TABLE IF EXISTS #REACHHealthFactors_TIU;
SELECT DISTINCT 
	 HF.PatientSID
	,HF.MVIPersonSID
	,HF.HealthFactorSID
	,isnull(a.ReferenceDateTime ,HF.HealthFactorDateTime) as HealthFactorDateTime
	,HF.Sta3n
	,isnull(a.ChecklistID,HF.ChecklistID ) as ChecklistID
	,HF.Comments
	,1 AS Source
	,CASE WHEN a.SignedByStaff = '*Missing*' OR a.SignedByStaff IS NULL THEN HF.StaffName
		ELSE a.SignedByStaff END as StaffName
	,HF.HealthFactorTypeSID
	,HF.List
	,HF.Coordinator
	,HF.Provider
	,HF.CareEval
	,HF.OutreachAttempted
	,HF.OutreachUnsuccess
	,HF.OutreachSuccess
	,HF.PatientStatus
	,HF.Transfer
INTO #REACHHealthFactors_TIU
FROM  #REACHHealthFactors as HF 
LEFT JOIN (
	SELECT a.HealthFactorSID
			,t.* 
	FROM #SID_Date_Match as a 
	LEFT JOIN #TIU AS T ON a.TIUDocumentSID = t.TIUDocumentSID 
	) as a on a.HealthFactorSID= hf.HealthFactorSID
;

DROP TABLE IF EXISTS #PatientStatus
SELECT TOP 1 WITH TIES
	 MVIPersonSID
	,HealthFactorDateTime
	,VisitDateTime
	,VisitSID
	,CASE WHEN List='REACH_PatientStatusOutpatient' THEN 1
		WHEN List='REACH_PatientStatusInpatient' THEN 2
		WHEN List='REACH_PatientStatusIncarcerated' THEN 3
		ELSE NULL END AS PatientStatus
INTO #PatientStatus
FROM #REACHHealthFactors
WHERE PatientStatus=1
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC)

DROP TABLE IF EXISTS #REACHWriteback;
SELECT DISTINCT * 
INTO #REACHWriteback
FROM (
	SELECT m.MVIPersonSID
		  ,w.QuestionNumber
		  ,w.QuestionStatus
		  ,Max(w.EntryDate) over (partition by m.MVIPersonSID) as LastEntryDate
    FROM [REACH].[Writeback] w WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] m WITH (NOLOCK) ON w.PatientSID=m.PatientPersonSID
	) t 
PIVOT (Max([QuestionStatus]) FOR QuestionNumber 
	IN ([0],[4],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],[25],[26],[27])
	) AS pvt
;

DROP TABLE IF EXISTS #QuestionStatus;
SELECT MVIPersonSID
	  ,CASE WHEN CareEval = 1
			  OR REACH_CaringCommunications_WB = 1 
			  OR REACH_SafetyPlan_WB = 1 
			  OR REACH_CopingSkill_WB = 1 
			  OR REACH_EnhanceCareOther_WB = 1 
			  OR REACH_MonitorLifeEvents_WB = 1 
			  OR REACH_NoChangesInd_WB = 1
			  THEN 1
		  ELSE 0 END CareEvaluationChecklist
	  ,CASE WHEN (OutreachUnsuccess =1 or REACH_ProviderOutREACHUnsuccs_WB = 1  or (OutreachAttempted=1 AND Admitted=0 AND Incarcerated=0)) 
			  AND OutreachSuccess = 0 
			  AND REACH_TreatmentPlanDiscussed_WB = 0  
			  AND REACH_CareEnhancementDiscussed_WB = 0 
			  AND REACH_AccessToCareDiscussed_WB = 0 
			  AND REACH_RiskDiscussed_WB = 0
			  THEN 1
			WHEN OutreachSuccess = 1 
			  OR REACH_CareEnhancementDiscussed_WB = 1 
			  OR REACH_TreatmentPlanDiscussed_WB = 1 
			  OR REACH_AccessToCareDiscussed_WB = 1 
			  OR REACH_RiskDiscussed_WB = 1
			  THEN 2
			WHEN Admitted = 1 THEN 4
			WHEN Incarcerated = 1 THEN 5
		  ELSE 0 END FollowUpWiththeVeteran
	  ,CASE WHEN NoChangesInd = 1 OR REACH_NoChangesInd_WB = 1  THEN 1 ELSE 0 END NoCareChanges
	  ,CASE WHEN Coordinator = 1 or REACH_Coordinator_WB =1  THEN 1 ELSE 0 END InitiationChecklist
	  ,CASE WHEN Provider = 1  
			  OR REACH_ProviderAcknowledge_WB = 1 
			  THEN 1
			ELSE 0 END ProviderAcknowledgement
	  ,PatientStatus
	  ,PatientDeceased
	  ,LastCoordinatorActivity
	  ,LastProviderActivity
	  ,CoordinatorName=CAST(NULL AS varchar(50))
	  ,ProviderName=CAST(NULL AS varchar(50))
	  ,UpdateDate=getdate()
INTO #QuestionStatus
FROM (
	SELECT d.MVIPersonSID
		  ,Max(isnull(a.Coordinator, 0)) AS Coordinator
          ,Max(isnull(b.Provider, 0)) AS Provider
          ,Max(isnull(b.CareEval, 0)) AS CareEval
          ,Max(isnull(b.OutreachAttempted, 0)) AS OutreachAttempted
          ,Max(isnull(b.OutreachSuccess, 0)) AS OutreachSuccess
		  ,Max(isnull(b.OutreachUnsuccess, 0)) AS OutreachUnsuccess

		  ,MAX(CASE WHEN b.List='REACH_CareEvalNoChangesInd' THEN 1 ELSE 0 END) AS NoChangesInd
		  ,MAX(CASE WHEN b.List='REACH_ProviderOutreachIncarcerated' THEN 1 ELSE 0 END) AS Incarcerated
		  ,MAX(CASE WHEN b.List='REACH_ProviderOutreachAdmitted' THEN 1 ELSE 0 END) AS Admitted
                 
          ,Max(isnull([0], 0)) AS REACH_Coordinator_WB
          ,Max(isnull([4], 0)) AS REACH_ProviderAcknowledge_WB
          ,Max(isnull([8], 0)) AS REACH_CaringCommunications_WB
          ,Max(isnull([9], 0)) AS REACH_SafetyPlan_WB
          ,Max(isnull([10], 0)) AS REACH_MonitorLifeEvents_WB
          ,Max(isnull([11], 0)) AS REACH_CopingSkill_WB
          ,Max(isnull([21], 0)) AS REACH_EnhanceCareOther_WB
          ,Max(isnull([12], 0)) AS REACH_NoChangesInd_WB
          
          ,Max(isnull([13], 0)) AS REACH_RiskDiscussed_WB
          ,Max(isnull([14], 0)) AS REACH_CareEnhancementDiscussed_WB
          ,Max(isnull([15], 0)) AS REACH_AccessToCareDiscussed_WB
          ,Max(isnull([16], 0)) AS REACH_TreatmentPlanDiscussed_WB
          ,Max(isnull([17], 0)) AS REACH_ProviderOutREACHUnsuccs_WB

		  ,Max(isnull([18], 0)) AS PatientDeceased
		  ,Max(isnull(a.HealthFactorDateTime,w.LastEntryDate)) as LastCoordinatorActivity
		  ,Max(b.HealthFactorDateTime) as LastProviderActivity
		  ,MAX(ISNULL(p.PatientStatus,0)) AS PatientStatus
	FROM [REACH].[History] as d WITH (NOLOCK) 
    LEFT OUTER JOIN #REACHHealthFactors_TIU as a ON a.MVIPersonSID = d.MVIPersonSID AND a.Coordinator=1
	LEFT OUTER JOIN #REACHHealthFactors_TIU as b ON b.MVIPersonSID = d.MVIPersonSID AND b.Coordinator=0
    LEFT OUTER JOIN #REACHWriteback AS w ON d.MVIPersonSID = w.MVIPersonSID    
	LEFT OUTER JOIN #PatientStatus AS p ON p.MVIPersonSID = d.MVIPersonSID
	GROUP BY d.MVIPersonSID
	) AS a

; 
EXEC [Maintenance].[PublishTable] 'REACH.QuestionStatus','#QuestionStatus'

/**Health Factor Information ******/
DROP TABLE IF EXISTS #HF;
SELECT MVIPersonSID
	  ,HealthFactorDateTime
	  ,Sta3n
	  ,ChecklistID
	  ,Comments
	  ,StaffName
	  ,HealthFactorTypeSID
	  ,List
	  ,Coordinator
	,Provider
	,CareEval
	,OutreachAttempted
	,OutreachUnsuccess
	,OutreachSuccess
	,PatientStatus
	,Transfer
INTO #HF
FROM #REACHHealthFactors_TIU a
;

DROP TABLE IF EXISTS #StageReachHF;
SELECT MVIPersonSID
	  ,Sta3n
	  ,ChecklistID
	  ,QuestionNumber
	  ,Question
	  ,HealthFactorDateTime
	  ,Comments
	  ,Coordinator
	,Provider
	,CareEval
	,OutreachAttempted
	,OutreachUnsuccess
	,OutreachSuccess
	,PatientStatus
	  ,Source
	  ,MostRecent
	  ,LastActivity
	  ,StaffName
	  ,1 as QuestionStatus
	  ,CASE WHEN MostRecent=1 THEN 1 ELSE 0 END as MostRecentFlag
INTO #StageReachHF
FROM (
	SELECT MVIPersonSID,Sta3n,ChecklistID,QuestionNumber,Question,HealthFactorDateTime,Comments,Source,StaffName
		  ,Row_number() OVER(PARTITION BY QuestionNumber,MVIPersonSID ORDER BY AdjDateTime DESC,LEN(Comments) DESC) as  MostRecent
		  ,Max(a.HealthFactorDateTime) OVER(PARTITION BY MVIPersonSID) as LastActivity
		  ,Coordinator
		,Provider
		,CareEval
		,OutreachAttempted
		,OutreachUnsuccess
		,OutreachSuccess
		,PatientStatus
	FROM (--combining health factor and writeback data
			SELECT DISTINCT b.ChecklistID
					,b.Sta3n
					,TRY_Cast(lc.Description as int) as QuestionNumber
					,lc.Printname as Question 
					,MVIPersonSID
					,b.HealthFactorDateTime
					,AdjDateTime = DATEADD(hh,t.HoursAdd,b.HealthFactorDateTime) 
					,b.Comments
					,1 as Source
					,b.StaffName
					,Coordinator
					,Provider
					,CareEval
					,OutreachAttempted
					,OutreachUnsuccess
					,OutreachSuccess
					,PatientStatus
			FROM #HF as b 
			INNER JOIN [Lookup].[List] lc WITH (NOLOCK) on b.List = lc.List
			INNER JOIN (SELECT Sta3n
				  ,TimeZone
				  ,HoursAdd =  
					CASE WHEN TimeZone='Central Standard Time'  THEN 1
						 WHEN TimeZone='Mountain Standard Time' THEN 2 
						 WHEN TimeZone='Pacific Standard Time'  THEN 3 
						 WHEN TimeZone='Alaskan Standard Time' THEN 4
						 WHEN TimeZone='Hawaiian Standard Time' THEN 6
						 WHEN TimeZone='Taipei Standard Time' THEN -12
					ELSE 0 END
				FROM [Dim].[Sta3n] WITH (NOLOCK)
				) AS t ON t.Sta3n=LEFT(b.ChecklistID,3)
			WHERE lc.Category = 'REACH VET' AND TRY_CAST(lc.Description AS int) IS NOT NULL
		UNION ALL
			SELECT DISTINCT a.ChecklistID
					,m.Sta3n
					,a.QuestionNumber
					,a.Question
					,m.MVIPersonSID
					,a.EntryDate 
					,AdjDateTime = DATEADD(hh,t.HoursAdd,a.EntryDate)
					,null as Comments
					,2 as Source
					,a.UserName
					,CASE WHEN QuestionNumber = 0 THEN 1 ELSE 0 END AS Coordinator
					,CASE WHEN QuestionType = 'Re-evaluation Checklist' THEN 1 ELSE 0 END AS Provider
					,CASE WHEN QuestionType = 'Care Evaluation Checklist' THEN 1 ELSE 0 END AS CareEval
					,CASE WHEN QuestionNumber IN (13,14,15,16,17) THEN 1 ELSE 0 END AS OutreachAttempted
					,CASE WHEN QuestionNumber IN (17) THEN 1 ELSE 0 END AS OutreachUnsuccess
					,CASE WHEN QuestionNumber IN (13,14,15,16) THEN 1 ELSE 0 END AS OutreachSuccess
					,CASE WHEN QuestionNumber IN (18) THEN 1 ELSE 0 END AS PatientStatus
			FROM [REACH].[WritebackHistoric] as a WITH (NOLOCK)
			INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] m WITH (NOLOCK) ON a.PatientSID=m.PatientPersonSID
			INNER JOIN (SELECT Sta3n
				  ,TimeZone
				  ,HoursAdd =  
					CASE WHEN TimeZone='Central Standard Time'  THEN 1
						 WHEN TimeZone='Mountain Standard Time' THEN 2 
						 WHEN TimeZone='Pacific Standard Time'  THEN 3 
						 WHEN TimeZone='Alaskan Standard Time' THEN 4
						 WHEN TimeZone='Hawaiian Standard Time' THEN 6
						 WHEN TimeZone='Taipei Standard Time' THEN -12
					ELSE 0 END
				FROM [Dim].[Sta3n] WITH (NOLOCK)
				) AS t ON t.Sta3n=LEFT(a.ChecklistID,3)
			WHERE QuestionStatus = 1 and a.QuestionNumber not in (18,19) 
		) as a
	) as a 
;

EXEC [Maintenance].[PublishTable] 'REACH.HealthFactors','#StageReachHF';

--Add Coordinator name
UPDATE [REACH].[QuestionStatus]
SET CoordinatorName = StaffName
FROM [REACH].[HealthFactors] a
INNER JOIN [REACH].[QuestionStatus] b 
	ON a.MVIPersonSID=b.MVIPersonSID
WHERE QuestionNumber = 0 AND MostRecentFlag =1

--Add Provider name
DROP TABLE IF EXISTS #Provider
SELECT a.MVIPersonSID, LEFT(StaffName,50) AS StaffName
INTO #Provider
FROM (SELECT TOP 1 WITH TIES p.MVIPersonSID, p.StaffName, p.QuestionNumber
	FROM [REACH].[HealthFactors] p WITH (NOLOCK)
	WHERE p.MostRecentFlag=1 AND p.Coordinator=0
	ORDER BY ROW_NUMBER() OVER (PARTITION BY p.MVIPersonSID ORDER BY p.HealthFactorDateTime DESC)
	) a

UPDATE [REACH].[QuestionStatus]
SET ProviderName = StaffName
FROM #Provider a
INNER JOIN [REACH].[QuestionStatus] b 
	ON a.MVIPersonSID=b.MVIPersonSID

--Add last HF activity date
UPDATE [REACH].[QuestionStatus]
SET LastCoordinatorActivity = pr.LastActivity 
FROM (
	SELECT DISTINCT MVIPersonSID
		,Max(HealthFactorDateTime) AS LastActivity
	FROM [REACH].[HealthFactors] WHERE Coordinator=1 
    GROUP BY MVIPersonSID
	) as PR 
INNER JOIN [REACH].[QuestionStatus] as r on pr.MVIPersonSID = r.MVIPersonSID 

UPDATE [REACH].[QuestionStatus]
SET LastProviderActivity = pr.LastActivity 
FROM (
	SELECT DISTINCT MVIPersonSID
		,Max(HealthFactorDateTime) AS LastActivity
	FROM [REACH].[HealthFactors] WHERE Coordinator=0 
    GROUP BY MVIPersonSID
	) as PR 
INNER JOIN [REACH].[QuestionStatus] as r on pr.MVIPersonSID = r.MVIPersonSID 
;

--TEMPORARY FIX TO UPDATE 528A5 WHICH MERGED WITH 528A6 BEGINNING FY20
UPDATE [REACH].[HealthFactors]
SET ChecklistID='528A6'
WHERE ChecklistID='528A5'

--Update current facility in patient report in case of transfer
UPDATE [REACH].[PatientReport]
SET ChecklistID = pr.ChecklistID 
FROM (
	SELECT a.MVIPersonSID
		  ,b.ChecklistID
	FROM [REACH].[PatientReport] as a 
	INNER JOIN [REACH].[HealthFactors] as b on a.MVIPersonSID = b.MVIPersonSID 
	WHERE a.ChecklistID <> b.ChecklistID 
		and b.QuestionNumber = 0 
		and b.QuestionStatus = 1 
		and b.ChecklistID is not null 
		and MostRecentFlag=1 
	) as PR 
INNER JOIN [REACH].[PatientReport] as r on pr.MVIPersonSID = r.MVIPersonSID 
;

-----------------------------------------------------------------------------
-- Update StationAssignments in case of Transfer to "new" ChecklistID
-----------------------------------------------------------------------------
-- 202010 - Replaced use of StationAssignments with MasterPatient, so this section is not needed --
-- 20201209 - Added this section back because GroupAssignments is using StationAssignments to 
---- get all the patient-stations.  Re-evaluate after 4.0 to see if this is necessary
---- or if there is a better way to structure this.
	DECLARE @RequirementID INT = (
		SELECT RequirementID FROM [Config].[Present_ActivePatientRequirement]
		WHERE RequirementName = 'REACHVET'
		)
	DROP TABLE IF EXISTS #StationAssignments
	SELECT MVIPersonSID 
		,ChecklistID
		,RequirementID = @RequirementID
		,Sta3n_Loc = LEFT(ChecklistID,3)
		,PatientSID as PatientPersonSID
	INTO #StationAssignments
	FROM [REACH].[PatientReport]

	DELETE [Present].[ActivePatient] 
	WHERE RequirementID=@RequirementID

	INSERT INTO [Present].[ActivePatient] (MVIPersonSID,ChecklistID,RequirementID,Sta3n_Loc,PatientPersonSID)
	SELECT MVIPersonSID
		,ChecklistID
		,RequirementID
		,Sta3n_Loc
		,PatientPersonSID
	FROM #StationAssignments

---------------------------------------------------------------------------------------

EXEC [Log].[ExecutionEnd]

END --END OF STORED PROCEDURE