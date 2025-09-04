-- =============================================
-- Author:			Liam Mina
-- Create date:		2023-01-26
-- Description:		Get dates for COMPACT Act episodes of care and eligible encounters
-- Modifications:
	-- 2023-02-22	LM	Moved health factor/DTA query from OMHSP_Standard.HealthFactorSuicPrev
	-- 2023-02-28	LM	Added criteria for episode begin where inpatient DxCode=R45.851 and no procedure code exists
	-- 2023-03-08	LM	Added health factor that indicates a COMPACT episode should be ended
	-- 2023-03-14	LM	Added TIU data to use ReferenceDateTime of note for Community Care episodes
	-- 2023-04-14	LM	Added ChecklistID where episode was initiated
	-- 2023-06-16	LM	Corrections to logic capturing new episodes after an episode has ended
	-- 2023-07-24	LM	Count COMPACT extension health factor as COMPACT-related
	-- 2023-09-08	LM	Join to administrative eligibility from COMPACT.Eligibility to get periods where patient was eligible before becoming ineligible
	-- 2023-09-18	LM	Added indicator of whether the episode was started using the COMPACT template health factors
	-- 2023-10-10	LM	Incorporated IVC claims/notification/referral data from COMPACT.IVC
	-- 2024-01-04	LM	Combined Code.COMPACT_ContactHistory to run within this procedure
	-- 2024-05-13	LM	Revamp of code to prevent unconfirmed episodes from truncating/overriding confirmed episodes and create new table for health factor details
	-- 2024-09-12	LM	Bug fix to account for multiple templates documented into same encounter on different dates in PowerChart - take the first date
	-- 2025-04-21	LM	Add copay data to contact history
-- =============================================
CREATE PROCEDURE [Code].[COMPACT]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.COMPACT', @Description = 'Execution of Code.COMPACT SP'
	
/*Initial Event - To ensure appropriate identification and tracking of COMPACT Act Section 201-related care, one of the following diagnostic codes are to be utilized in the initial crisis care note:  
T14.91XA – Suicide Attempt, Initial 
90839 (Psychotherapy for Crisis) + R45.851 (Suicidal Ideation)  
T2034 – crisis intervention 

Follow-up Care – To ensure appropriate identification and tracking of COMPACT Act Section 201-related care, where a suicide attempt was the trigger event, one of the following diagnostic codes are to be utilized: 
T14.91XD - Suicide Attempt, Follow up 
T14.91XS - Suicide Attempt, Sequela 
Note: Where the suicidal crisis event did not involve an actualized attempt, the following healthcare common procedure coding system (HCPCS) code is to be added to the appropriate CPT code for the follow up care: 
T2034 – crisis intervention 
*/

/*COMPACT Episode Date Rules:
First COMPACT episode start date = the first date after January 17, 2023 that one of the following elements were documented (i.e. first date on the qualifying start date table).   
	--Health factor: VA-COMPACT ACT SUICIDE TX ENCOUNTER INITIAL, OR 
	--DTA: COMPACT ACT - Init-VA, Yes, this visit is the Veteran's initial presentation of this Acute Suicide Episode, OR 
	--DTA: COMPACT ACT - Init-VA, No, Veteran initially presented outside of this VA for this current Acute Suicide Episode, OR 
	--Community Care health factors: CCET COMPACT ACT or CCPN COMPACT ACT, OR 
	--Dx code T14.91XA, OR 
	--Procedure code 90839 and Dx code R45.851, OR 
	--Inpatient Dx code R45.851 and no CPT code exists
	--Procedure code T2034 
	--If the following follow-up documentation is done outside of an existing episode, these can also be used to start a new episode (assume documentation error): 
		--Health factor: VA-COMPACT ACT SUICIDE TX ENCOUNTER FOLLOW UP 
		--DTA: COMPACT ACT - Init-VA, No, Veteran has been seen before at this VA for the Acute Suicide Episode 

First COMPACT episode end date: 
End date =  
	--Active episode end dates will be subject to change over the course of the episode, pending inpatient discharge dates, episode extensions, and episode restarts
	--If Inpatient and not discharged = episode end date is admission date plus 120 days (30 days inpatient + 90 days outpatient)
	--If inpatient and discharged = episode end date is discharge plus 90 days 
	--If outpatient = episode end date is start date plus 90 
	--If community care and no Cerner DTA for start date = community care date plus 90 
	--If community care with Cerner DTA for start date = DTA start date plus 90  
	--If health factor VA-COMPACT ACT SUICIDE RISK NONACUTE, set end date to health factor date
Episode Extension (Health factor VA-COMPACT ACT SUICIDE TX ENCOUNTER EXTENSION OF CARE) = 
	--If documented while patient is inpatient, and within +/- 7 days of the end of the inpatient episode, extend estimated inpatient end date by 30 days
	--If documented while patient is outpatient, and within +/- 7 days of the end of the outpatient episode, extend estimated outpatient end date by 30 days
Episode Restart
	--If one of the following is documented mid-episode, accompanied by one of the eligible HF/dx/proc codes, set the end date of the current episode to the end of day prior to the restart, and start new episode
		--New inpatient qualifying start date, OR new suicide or overdose event reported in SBOR/CSRE, accompanied by one or more of the following
			--Health factor: VA-COMPACT ACT SUICIDE TX ENCOUNTER INITIAL, OR 
			--DTA: COMPACT ACT - Init-VA, Yes, this visit is the Veteran's initial presentation of this Acute Suicide Episode, OR 
			--DTA: COMPACT ACT - Init-VA, No, Veteran initially presented outside of this VA for this current Acute Suicide Episode, OR 
			--Community Care health factors: CCET COMPACT ACT or CCPN COMPACT ACT, OR 
			--Dx code T14.91XA, OR 
			--Procedure code 90839 and Dx code R45.851
*/ 


-- Part 1: Get all COMPACT-related health factors and DTAs
-- Identify relevant Health Factors and DTAs
DROP TABLE IF EXISTS #HealthFactorsTIU;
SELECT 
	c.Category
	,m.List
	,m.ItemID
	,m.AttributeValue
	,m.Attribute
	,c.Printname
INTO #HealthFactorsTIU
FROM [Lookup].[ListMember] m WITH (NOLOCK)
INNER JOIN [Lookup].[List] c WITH (NOLOCK) 
	ON m.List = c.List
WHERE c.Category ='COMPACT Act'	
;

-- First get VistA Health Factor SIDs
DROP TABLE IF EXISTS #PatientHealthFactorCOMPACTVistA; 
SELECT 
	mvi.MVIPersonSID
	,h.VisitSID 
	,h.Sta3n
	,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime 
	,h.Comments
	,HF.List
	,HF.AttributeValue AS TemplateSelection
INTO  #PatientHealthFactorCOMPACTVistA
FROM [HF].[HealthFactor] h WITH (NOLOCK) 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON h.PatientSID = mvi.PatientPersonSID 
INNER JOIN #HealthFactorsTIU HF WITH (NOLOCK) 
	ON HF.ItemID = h.HealthFactorTypeSID
WHERE h.HealthFactorDateTime BETWEEN '2023-01-17' AND getdate()
	AND HF.Attribute = 'HealthFactorType'

DROP TABLE IF EXISTS #AddLocationsVistA; 
SELECT 
	h.MVIPersonSID
	,ISNULL(dd.StaPa,h.Sta3n) AS StaPa
	,h.VisitSID 
	,h.Sta3n
	,h.HealthFactorDateTime  
	,h.Comments
	,h.List
	,h.TemplateSelection
INTO  #AddLocationsVistA
FROM #PatientHealthFactorCOMPACTVistA h WITH (NOLOCK) 
INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
	ON h.VisitSID = v.VisitSID
LEFT JOIN [Lookup].[DivisionFacility] dd WITH (NOLOCK) 
	ON dd.DivisionSID = v.DivisionSID

DROP TABLE IF EXISTS #GetProvider
SELECT DISTINCT p.VisitSID
	,s.StaffName
INTO #GetProvider
FROM [Outpat].[VProvider] p WITH (NOLOCK) 
INNER JOIN [SStaff].[SStaff] s WITH (NOLOCK) 
	ON p.ProviderSID = s.StaffSID
INNER JOIN #AddLocationsVistA v
	ON p.VisitSID = v.VisitSID

DROP TABLE IF EXISTS #AddProvider
SELECT VisitSID
	,LEFT(STRING_AGG(StaffName,', ') WITHIN GROUP (ORDER BY StaffName),50) AS StaffName
INTO #AddProvider
FROM #GetProvider
GROUP BY VisitSID
;

--Get Cerner DTAs
DROP TABLE IF EXISTS #PatientHealthFactorCOMPACTCerner; 
SELECT  
	h.MVIPersonSID
	,h.StaPa
	,h.EncounterSID 
	,200 AS Sta3n
	,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
	,Comments = NULL
	,HF.List
	,CONCAT(h.DerivedDTAEvent, ': ',h.DerivedDTAEventResult) AS TemplateSelection
	,LEFT(s.NameFullFormatted,50) AS StaffName
INTO #PatientHealthFactorCOMPACTCerner
FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
INNER JOIN #HealthFactorsTIU HF WITH (NOLOCK) 
	ON HF.ItemID = h.DerivedDtaEventCodeValueSID 
	AND HF.AttributeValue = h.DerivedDtaEventResult
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH (NOLOCK)
	ON h.ResultPerformedPersonStaffSID = s.PersonStaffSID
WHERE HF.Attribute ='DTA'
AND h.TZFormUTCDateTime BETWEEN '2023-01-17' AND getdate()
UNION ALL
SELECT  
	h.MVIPersonSID
	,h.StaPa
	,h.EncounterSID 
	,200 AS Sta3n
	,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
	,CAST(h.DerivedDTAEventResult as varchar) AS Comments
	,HF.List
	,CONCAT(h.DerivedDTAEvent, ': ',h.DerivedDTAEventResult) AS TemplateSelection
	,LEFT(s.NameFullFormatted,50) AS StaffName
FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
INNER JOIN #HealthFactorsTIU HF WITH (NOLOCK) 
	ON HF.ItemID = h.DerivedDtaEventCodeValueSID
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH (NOLOCK)
	ON h.ResultPerformedPersonStaffSID = s.PersonStaffSID
WHERE HF.Attribute ='FreeText'
AND h.TZFormUTCDateTime BETWEEN '2023-01-17' AND getdate()
AND (TRY_CAST(h.DerivedDTAEventResult as date) BETWEEN '2023-01-17' AND getdate() OR TRY_CAST(h.DerivedDTAEventResult as date) IS NULL)
;

DROP TABLE IF EXISTS #PatientHealthFactorCOMPACT
SELECT a.*, b.StaffName
INTO #PatientHealthFactorCOMPACT
FROM #AddLocationsVistA a
LEFT JOIN #AddProvider b
	ON a.VisitSID = b.VisitSID
UNION ALL
SELECT * 
FROM #PatientHealthFactorCOMPACTCerner

DROP TABLE IF EXISTS #HF_DTA
SELECT DISTINCT a.MVIPersonSID
	,a.Sta3n
	,ch.ChecklistID
	,VisitSID
	,MIN(CASE WHEN a.Comments IS NOT NULL AND a.Sta3n=200 THEN TRY_CAST(a.Comments AS datetime) --Powerforms indicating that patient initially presented outside of VA for care, with start date of episode in the comments
		ELSE a.HealthFactorDateTime END) OVER (PARTITION BY VisitSID, HealthFactorDateTIme) AS TemplateDateTime
	,a.List
	,a.TemplateSelection
	,a.StaffName
INTO #HF_DTA
FROM #PatientHealthFactorCOMPACT a
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) 
	ON a.StaPa = ch.StaPa

DELETE FROM #HF_DTA WHERE TemplateSelection LIKE 'COMPACT ACT - Init-Date-Outside: %'

;

EXEC [Maintenance].[PublishTable] 'COMPACT.Template','#HF_DTA'

--Get dx codes used in COMPACT
DROP TABLE IF EXISTS #ICDCodes
SELECT ICD10SID
	,Sta3n
	,ICD10Code
INTO #ICDCodes
FROM Lookup.ICD10 WITH (NOLOCK)
WHERE ICD10Code IN ('T14.91XA','R45.851','T14.91XD','T14.91XS')

--Get patient-level diagnoses from Cerner and VistA that may indicate COMPACT eligibility
DROP TABLE IF EXISTS #Diagnosis;
--Outpatient VistA
SELECT 
	c.MVIPersonSID
	,a.VisitSID
	,a.VisitDateTime
	,ic.ICD10Code
	,CASE WHEN sc.EmergencyRoom_Stop=1 OR sc2.EmergencyRoom_Stop=1 THEN 1 ELSE 0 END AS EDVisit
	,ISNULL(ld.ChecklistID,a.Sta3n) AS ChecklistID
INTO #Diagnosis
FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
INNER JOIN [Outpat].[Visit] v WITH (NOLOCK)
	ON a.VisitSID = v.VisitSID
INNER JOIN [Lookup].[DivisionFacility] ld WITH (NOLOCK)
	ON v.DivisionSID = ld.DivisionSID
INNER JOIN #ICDCodes ic ON ic.ICD10SID = a.ICD10SID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID c WITH (NOLOCK)
	ON a.PatientSID = c.PatientPersonSID
LEFT JOIN Lookup.Stopcode sc WITH (NOLOCK) 
	ON v.PrimaryStopCodeSID=sc.StopCodeSID
LEFT JOIN Lookup.Stopcode sc2 WITH (NOLOCK) 
	ON v.SecondaryStopCodeSID=sc2.StopCodeSID
WHERE a.VisitDateTime BETWEEN '2023-01-17' AND getdate()
UNION ALL
--Inpatient VistA
SELECT
	c.MVIPersonSID
	,a.InpatientSID
	,d.AdmitDateTime
	,ic.ICD10Code
	,EDVisit=0
	,ISNULL(ld.ChecklistID,a.Sta3n) AS ChecklistID
FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK) ON a.InpatientSID = d.InpatientSID 
INNER JOIN [Dim].[WardLocation] di WITH (NOLOCK)
	ON d.AdmitWardLocationSID = di.WardLocationSID
INNER JOIN [Lookup].[DivisionFacility] ld WITH (NOLOCK)
	ON di.DivisionSID = ld.DivisionSID
INNER JOIN #ICDCodes ic ON ic.ICD10SID = a.ICD10SID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID c WITH (NOLOCK)
	ON a.PatientSID = c.PatientPersonSID
WHERE d.AdmitDateTime BETWEEN '2023-01-17' AND getdate()
UNION ALL
--Cerner
SELECT 
	a.MVIPersonSID
	,a.EncounterSID
	,a.TZDerivedDiagnosisDateTime
	,ic.ICD10Code
	,CASE WHEN a.EncounterTypeClass='Emergency' THEN 1 ELSE 0 END AS EDVisit
	,ch.ChecklistID
FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
INNER JOIN #ICDCodes ic ON ic.ICD10SID = a.NomenclatureSID
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON a.StaPa = ch.StaPa
WHERE a.TZDerivedDiagnosisDateTime BETWEEN '2023-01-17' AND getdate()

--Get procedure codes used in COMPACT
DROP TABLE IF EXISTS #CPTCodes
SELECT CPTSID
	,Sta3n
	,CPTCode
INTO #CPTCodes
FROM [Lookup].[CPT] WITH (NOLOCK)
WHERE CPTCode IN ('T2034','90839')

--Get patient-level data on procedure codes that may indicate COMPACT eligibility
DROP TABLE IF EXISTS #Procedures;
--Outpatient VistA
SELECT 
	c.MVIPersonSID
	,a.VisitSID
	,a.VisitDateTime
	,cc.CPTCode
	,CASE WHEN sc.EmergencyRoom_Stop=1 OR sc2.EmergencyRoom_Stop=1 THEN 1 ELSE 0 END AS EDVisit
	,ISNULL(ld.ChecklistID,a.Sta3n) AS ChecklistID
INTO #Procedures
FROM [Outpat].[VProcedure] a WITH (NOLOCK)
INNER JOIN [Outpat].[Visit] v WITH (NOLOCK)
	ON a.VisitSID = v.VisitSID
INNER JOIN [Lookup].[DivisionFacility] ld WITH (NOLOCK)
	ON v.DivisionSID = ld.DivisionSID
INNER JOIN #CPTCodes cc ON cc.CPTSID = a.CPTSID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
	ON a.PatientSID = c.PatientPersonSID
LEFT JOIN Lookup.Stopcode sc WITH (NOLOCK) 
	ON v.PrimaryStopCodeSID=sc.StopCodeSID
LEFT JOIN Lookup.Stopcode sc2 WITH (NOLOCK) 
	ON v.SecondaryStopCodeSID=sc2.StopCodeSID
WHERE a.VisitDateTime BETWEEN '2023-01-17' AND getdate()
UNION ALL
--Cerner
SELECT  
	a.MVIPersonSID
	,a.EncounterSID
	,a.TZDerivedProcedureDateTime as TZProcedureDateTime
	,cc.CPTCode
	,CASE WHEN a.EncounterTypeClass='Emergency' THEN 1 ELSE 0 END AS EDVisit
	,ch.ChecklistID
FROM [Cerner].[FactProcedure] a WITH (NOLOCK)
INNER JOIN #CPTCodes cc ON cc.CPTSID = a.NomenclatureSID
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON a.StaPa = ch.StaPa
WHERE a.TZDerivedProcedureDateTime BETWEEN '2023-01-17' AND getdate()
;


--Execute IVC code and pull relevant data
EXEC [Code].[COMPACT_IVC]
;

--Get IVC data
DROP TABLE IF EXISTS #IVC_Stage
SELECT a.MVIPersonSID	
	,ch.ChecklistID
	,a.TxDate
	,a.BeginDate AS IVCBeginDate
	,MIN(a.DischargeDate) OVER (PARTITION BY MVIPersonSID, BeginDate, TxSetting) AS DischargeDate
	,a.TxSetting
	,CASE WHEN TxSetting='CC Emergency' THEN 1 ELSE 0 END AS EDVisit
	,a.Paid
	,a.ReferralID
	,a.ConsultID
	,a.NotificationID
	,a.HealthFactorType AS TemplateSelection
	,List='COMPACT_InitialCareCommunity'
	,a.VisitSID
	,UniqueIVC_ID=CONCAT(a.NotificationID,a.ReferralID,a.ConsultID,a.VisitSID)
	,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY BeginDate,DischargeDate) AS IVCRankAsc
INTO #IVC_Stage
FROM [COMPACT].[IVC] a WITH (NOLOCK) 
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON a.StaPa = ch.StaPa
WHERE a.TxSetting <> 'CC Transport'

--Remove completely overlapping inpatient records
DROP TABLE IF EXISTS #IVC
SELECT DISTINCT a.*
	,CASE WHEN b.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS Ignore
	--,b.ivcbegindate as begin2, b.dischargedate as discharge2
INTO #IVC
FROM #IVC_Stage a
LEFT JOIN #IVC_Stage b 
	ON a.MVIPersonSID=b.MVIPersonSID
	AND a.UniqueIVC_ID <> b.UniqueIVC_ID
	AND b.IVCRankAsc<a.IVCRankAsc
	AND a.TxSetting='CC Inpatient' and b.TxSetting='CC Inpatient'
	AND a.IVCBeginDate > b.IVCBeginDate AND (ISNULL(a.DischargeDate,a.IVCBeginDate) < ISNULL(b.DischargeDate,DateAdd(day,30,b.IVCBeginDate)))

DELETE FROM #IVC WHERE Ignore=1

--Get starting cohort
--Bring together Diagnoses, Procedures, HF, and DTA at the encounter level
DROP TABLE IF EXISTS #Diagnosis_Procedure_HF_DTA_IVC_Encounter
SELECT MVIPersonSID
	,ChecklistID
	,VisitDateTime 
	,CAST(VisitSID AS varchar) AS VisitSID
	,UniqueIVC_ID=NULL
	,STRING_AGG(ICD10Code,', ') WITHIN GROUP (ORDER BY ICD10Code DESC) AS COMPACTIndicator
	,Type='ICD'
	,List=NULL
	,MAX(EDVisit) AS EDVisit
INTO #Diagnosis_Procedure_HF_DTA_IVC_Encounter
FROM #Diagnosis 
GROUP BY MVIPersonSID,ChecklistID,VisitDateTime,VisitSID
UNION ALL
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,VisitDateTime 
	,CAST(VisitSID AS varchar) AS VisitSID
	,UniqueIVC_ID=NULL
	,STRING_AGG(CPTCode,', ') WITHIN GROUP (ORDER BY CPTCode DESC) AS COMPACTIndicator
	,Type='CPT'
	,List=NULL
	,MAX(EDVisit) AS EDVisit
FROM #Procedures  
GROUP BY MVIPersonSID,ChecklistID,VisitDateTime,VisitSID
UNION ALL
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,TemplateDateTime 
	,CAST(VisitSID AS varchar) AS VisitSID
	,UniqueIVC_ID=NULL
	,STRING_AGG(TemplateSelection,', ') WITHIN GROUP (ORDER BY TemplateSelection DESC) AS COMPACTIndicator
	,Type='Template'
	,STRING_AGG(List,', ') WITHIN GROUP (ORDER BY TemplateSelection DESC) AS List
	,EDVisit=NULL
FROM COMPACT.Template WITH (NOLOCK)
WHERE List NOT LIKE '%Community%'
GROUP BY MVIPersonSID,ChecklistID,TemplateDateTime,VisitSID
UNION ALL
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,IVCBeginDate 
	,VisitSID
	,UniqueIVC_ID
	,STRING_AGG(TemplateSelection,', ') WITHIN GROUP (ORDER BY TemplateSelection DESC) AS COMPACTIndicator
	,Type='Template'
	,MAX(List) AS List --both CC health factors have the same list name so even if both are present the list will be the same
	,MAX(EDVisit) AS EDVisit
FROM #IVC
WHERE TemplateSelection IS NOT NULL
GROUP BY MVIPersonSID,ChecklistID,IVCBeginDate,VisitSID, UniqueIVC_ID
UNION ALL 
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,IVCBeginDate 
	,VisitSID
	,UniqueIVC_ID
	,CONCAT('Referral ID: ',ReferralID)
	,Type='Referral'
	,List
	,EDVisit
FROM #IVC
WHERE ReferralID IS NOT NULL
UNION ALL
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,IVCBeginDate 
	,VisitSID
	,UniqueIVC_ID
	,CONCAT('Consult ID: ',ConsultID)
	,Type='Consult'
	,List
	,EDVisit
FROM #IVC
WHERE ConsultID IS NOT NULL
UNION ALL
SELECT DISTINCT MVIPersonSID
	,ChecklistID
	,IVCBeginDate 
	,VisitSID
	,UniqueIVC_ID
	,CONCAT('Notification ID: ',NotificationID)
	,Type='Notification'
	,List
	,EDVisit
FROM #IVC
WHERE NotificationID IS NOT NULL

--String COMPACT indicators at encounter and date level
--Encounter level
DROP TABLE IF EXISTS #String_Encounter
SELECT MVIPersonSID
	,ChecklistID
	,VisitDateTime 
	,CAST(VisitSID AS varchar) AS VisitSID
	,UniqueIVC_ID
	,STRING_AGG(COMPACTIndicator,', ') WITHIN GROUP (ORDER BY Type DESC) AS COMPACTIndicator
	,STRING_AGG(List,', ') WITHIN GROUP (ORDER BY Type DESC) AS List
	,MAX(EDVisit) AS EDVisit
INTO #String_Encounter
FROM (
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,VisitDateTime 
		,CAST(VisitSID AS varchar) AS VisitSID
		,UniqueIVC_ID=NULL
		,ICD10Code AS COMPACTIndicator
		,Type='7-ICD'
		,List=NULL
		,EDVisit
	FROM #Diagnosis 
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,VisitDateTime 
		,CAST(VisitSID AS varchar) AS VisitSID
		,UniqueIVC_ID=NULL
		,CPTCode AS COMPACTIndicator
		,Type='6-CPT'
		,List=NULL
		,EDVisit
	FROM #Procedures  
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,TemplateDateTime 
		,CAST(VisitSID AS varchar) AS VisitSID
		,UniqueIVC_ID=NULL
		,TemplateSelection AS COMPACTIndicator
		,Type='1-Template'
		,List
		,EDVisit=NULL
	FROM COMPACT.Template WITH (NOLOCK)
	WHERE List NOT LIKE '%Community%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,IVCBeginDate 
		,VisitSID
		,UniqueIVC_ID
		,TemplateSelection AS COMPACTIndicator
		,Type='2-Template'
		,List --both CC health factors have the same list name so even if both are present the list will be the same
		,EDVisit
	FROM #IVC
	WHERE TemplateSelection IS NOT NULL
	UNION ALL 
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,IVCBeginDate 
		,VisitSID
		,UniqueIVC_ID
		,CONCAT('5-Referral ID: ',ReferralID)
		,Type='Referral'
		,List
		,EDVisit
	FROM #IVC
	WHERE ReferralID IS NOT NULL
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,IVCBeginDate 
		,VisitSID
		,UniqueIVC_ID
		,CONCAT('4-Consult ID: ',ConsultID)
		,Type='Consult'
		,List
		,EDVisit
	FROM #IVC
	WHERE ConsultID IS NOT NULL
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,IVCBeginDate 
		,VisitSID
		,UniqueIVC_ID
		,CONCAT('3-Notification ID: ',NotificationID)
		,Type='Notification'
		,List
		,EDVisit
	FROM #IVC
	WHERE NotificationID IS NOT NULL
) z
GROUP BY MVIPersonSID,ChecklistID,VisitDateTime,VisitSID,UniqueIVC_ID

--String ICD codes, procedure codes, health factors at date level
DROP TABLE IF EXISTS #StringCOMPACTIndicators_Encounter
SELECT MVIPersonSID
		,ChecklistID
		,VisitDate 
		,STRING_AGG(COMPACTIndicator,', ') WITHIN GROUP (ORDER BY COMPACTIndicator DESC) AS COMPACTIndicator
		,VisitSID
		,UniqueIVC_ID
		,STRING_AGG(List,', ') WITHIN GROUP (ORDER BY COMPACTIndicator DESC) AS List
INTO #StringCOMPACTIndicators_Encounter
FROM (
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(VisitDateTime AS date) AS VisitDate
		,COMPACTIndicator
		,VisitSID
		,UniqueIVC_ID
		,List
	FROM #String_Encounter 
)x
GROUP BY MVIPersonSID,ChecklistID,VisitDate,VisitSID,UniqueIVC_ID

--Date level
DROP TABLE IF EXISTS #Diagnosis_Procedure_HF_DTA_IVC_Date
SELECT MVIPersonSID
	,ChecklistID
	,VisitDateTime
	,String_AGG(COMPACTIndicator,', ') WITHIN GROUP (ORDER BY Type) AS COMPACTIndicator
	,MAX(EDVisit) AS EDVisit
INTO #Diagnosis_Procedure_HF_DTA_IVC_Date
FROM (
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(VisitDateTime AS date) AS VisitDateTime
		,ICD10Code AS COMPACTIndicator
		,Type='7-ICD'
		,EDVisit
	FROM #Diagnosis
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(VisitDateTime AS date) AS VisitDateTime
		,CPTCode AS COMPACTIndicator
		,Type='6-CPT'
		,EDVisit
	FROM #Procedures
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(TemplateDateTime AS date) AS TemplateDateTime 
		,TemplateSelection AS COMPACTIndicator
		,Type='1-Template'
		,EDVisit=NULL
	FROM COMPACT.Template WITH (NOLOCK)
	WHERE List NOT LIKE '%Community%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(IVCBeginDate AS date) 
		,TemplateSelection  AS COMPACTIndicator
		,Type='2-Template'
		,EDVisit
	FROM #IVC 
	WHERE TemplateSelection IS NOT NULL
	UNION ALL 
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(IVCBeginDate AS date) 
		,CONCAT('Referral ID: ',ReferralID)
		,Type='5-Referral'
		,EDVisit
	FROM #IVC 
	WHERE ReferralID IS NOT NULL
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(IVCBeginDate AS date) 
		,CONCAT('Consult ID: ',ConsultID)
		,Type='4-Consult'
		,EDVisit
	FROM #IVC 
	WHERE ConsultID IS NOT NULL
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(IVCBeginDate AS date) 
		,CONCAT('Notification ID: ',NotificationID)
		,Type='3-Notification'
		,EDVisit
	FROM #IVC 
	WHERE NotificationID IS NOT NULL
) z
GROUP BY MVIPersonSID,ChecklistID,VisitDateTime

--String ICD codes, procedure codes, health factors at date level
DROP TABLE IF EXISTS #StringCOMPACTIndicators_Date
SELECT MVIPersonSID
		,ChecklistID
		,VisitDate 
		,STRING_AGG(COMPACTIndicator,', ') WITHIN GROUP (ORDER BY COMPACTIndicator DESC) AS COMPACTIndicator
		,MAX(EDVisit) AS EDVisit
INTO #StringCOMPACTIndicators_Date
FROM (
	SELECT DISTINCT MVIPersonSID
		,ChecklistID
		,CAST(VisitDateTime AS date) AS VisitDate
		,COMPACTIndicator
		,EDVisit
	FROM #Diagnosis_Procedure_HF_DTA_IVC_Date 
)x
GROUP BY MVIPersonSID,ChecklistID,VisitDate


DROP TABLE IF EXISTS #EncounterCodesPivot
SELECT DISTINCT b.MVIPersonSID
	,b.ChecklistID
	,b.VisitDateTime
	,b.VisitSID
	,b.UniqueIVC_ID
	,d.List
	,b.Consult
	,b.Referral
	,b.Notification
	,b.Template
	,b.CPT
	,b.ICD
	,b.EDVisit
INTO #EncounterCodesPivot
FROM (
	SELECT MVIPersonSID
	,ChecklistID
	,MIN(VisitDateTime) OVER (PARTITION BY ISNULL(CAST(VisitSID AS varchar(15)), UniqueIVC_ID)) AS VisitDateTime
	,VisitSID
	,UniqueIVC_ID
	,Type
	,COMPACTIndicator
	,EDVisit
	FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter
) AS a
PIVOT
	(MAX(COMPACTIndicator)
	FOR TYPE IN (
		[Consult]
		,[Referral]
		,[Notification]
		,[Template]
		,[CPT]
		,[ICD]))
AS b
LEFT JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List IS NOT NULL) d
	ON ISNULL(CAST(d.VisitSID AS varchar(15)), d.UniqueIVC_ID) = ISNULL(CAST(b.VisitSID AS varchar(15)), b.UniqueIVC_ID) 		
;

/*******************************************************************************************
Combine continguous inpatient periods. 
Sometimes the patient is discharged and readmitted the same day (sometimes seconds apart); 
combining these cases will prevent inpatient episodes from ending prematurely
*******************************************************************************************/
DROP TABLE IF EXISTS #InpatientSegments
SELECT MVIPersonSID
	,AdmitDateTime
	,DischargeDateTime 
INTO #InpatientSegments
FROM (
SELECT DISTINCT s.MVIPersonSID, i.AdmitDateTime, i.DischargeDateTime
FROM #StringCOMPACTIndicators_Date s 
INNER JOIN [Inpatient].[BedSection] i WITH (NOLOCK)
	ON i.MVIPersonSID=s.MVIPersonSID
WHERE i.AdmitDateTime >='2023-01-17'
UNION ALL
SELECT DISTINCT s.MVIPersonSID, i.BeginDate, i.DischargeDate
FROM #StringCOMPACTIndicators_Date s 
INNER JOIN [COMPACT].[IVC] i WITH (NOLOCK)
	ON i.MVIPersonSID=s.MVIPersonSID
WHERE i.TxSetting='CC Inpatient'
) a

--remove segments that are entirely covered within another segment (admission and discharge fall between another segment's admission/discharge dates)
DROP TABLE IF EXISTS #Overlap
SELECT DISTINCT a.MVIPersonSID
	,a.AdmitDateTime
	,MAX(a.DischargeDateTime) OVER (PARTITION BY a.MVIPersonSID, a.AdmitDateTime) AS DischargeDateTime
	,CASE WHEN b.MVIPersonSID IS NOT NULL OR c.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS Overlap
INTO #Overlap
FROM #InpatientSegments a
LEFT JOIN #InpatientSegments b ON a.MVIPersonSID = b.MVIPersonSID 
		AND a.AdmitDateTime > b.AdmitDateTime AND a.AdmitDateTime < b.DischargeDateTime
		AND a.DischargeDateTime >= b.AdmitDateTime AND a.DischargeDateTime <= b.DischargeDateTime
LEFT JOIN #InpatientSegments c ON a.MVIPersonSID = c.MVIPersonSID 
		AND a.AdmitDateTime BETWEEN c.AdmitDateTime AND c.DischargeDateTime AND (a.DischargeDateTime IS NULL OR a.DischargeDateTime BETWEEN c.AdmitDateTime AND c.DischargeDateTime)
		AND NOT (a.AdmitDateTime=c.AdmitDateTime AND a.DischargeDateTime=c.DischargeDateTime)
LEFT JOIN #InpatientSegments d ON a.MVIPersonSID = d.MVIPersonSID 
		AND a.AdmitDateTime BETWEEN c.AdmitDateTime AND c.DischargeDateTime AND (a.DischargeDateTime IS NULL OR a.DischargeDateTime BETWEEN c.AdmitDateTime AND c.DischargeDateTime)
		AND NOT (a.AdmitDateTime=c.AdmitDateTime AND a.DischargeDateTime=c.DischargeDateTime)

DELETE FROM #Overlap 
WHERE Overlap=1
	

DROP TABLE IF EXISTS #Rank
SELECT *
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY AdmitDateTime) AS RN
INTO #Rank
FROM #Overlap

DROP TABLE IF EXISTS #IdentifyContinguousSegments
SELECT a.MVIPersonSID
	,a.AdmitDateTime
	,ISNULL(b.DischargeDateTime,a.DischargeDateTime) AS DischargeDateTime
	,a.RN
	,b.RN AS RN2
	,CASE WHEN b.MVIPersonSID IS NOT NULL AND c.MVIPersonSID IS NOT NULL THEN 1 --contiguous with previous and next
		WHEN b.MVIPersonSID IS NOT NULL THEN 2 --contiguous with next
		WHEN c.MVIPersonSID IS NOT NULL THEN 3 --contiguous with previous
		ELSE 0 END AS Contiguous
INTO #IdentifyContinguousSegments
FROM #Rank a
LEFT JOIN #Rank b
	ON a.MVIPersonSID = b.MVIPersonSID
	AND CAST(a.DischargeDateTime AS date) = CAST(b.AdmitDateTime AS date)
	AND a.RN+1 = b.RN
LEFT JOIN #Rank c
	ON a.MVIPersonSID = c.MVIPersonSID
	AND CAST(a.AdmitDateTime AS date) = CAST(c.DischargeDateTime AS date)
	AND a.RN = c.RN+1
	
DROP TABLE IF EXISTS #StatusChange
SELECT MVIPersonSID,AdmitDateTime,DischargeDateTime,RN, Contiguous,PrevStatus,NextStatus
	  ,RecordType=CASE	WHEN Contiguous=0 THEN 'BEGIN_END'
						WHEN Contiguous=2 THEN 'BEGIN'
						WHEN Contiguous=3 THEN 'END'
						WHEN Contiguous=1 THEN 'IGNORE'
						
						END
INTO #StatusChange
FROM (
	SELECT MVIPersonSID, AdmitDateTime, DischargeDateTime, RN, RN2, Contiguous
		  ,PrevStatus=ISNULL(LAG(Contiguous,1) OVER(PARTITION BY MVIPersonSID ORDER BY RN),0)
		  ,NextStatus=ISNULL(LEAD(Contiguous,1) OVER(PARTITION BY MVIPersonSID ORDER BY RN),0)
	FROM #IdentifyContinguousSegments
	) a

DELETE #StatusChange WHERE RecordType IN ('IGNORE')

DROP TABLE IF EXISTS #CombinedInpatientEpisodes
SELECT DISTINCT MVIPersonSID
	  ,AdmitDateTime
	  ,DischargeDateTime=CASE WHEN RecordType='BEGIN' THEN LEAD(DischargeDateTime,1) OVER(PARTITION BY MVIPersonSID ORDER BY AdmitDateTime) 
							  WHEN RecordType IN ('END','BEGIN_END') THEN DischargeDateTime END
	  ,RecordType
INTO #CombinedInpatientEpisodes
FROM #StatusChange
WHERE RecordType IS NOT NULL

DELETE #CombinedInpatientEpisodes WHERE RecordType IN ('END')

--Workaround for some community care admission data where old discharge dates haven't come through yet
--If a discharge date for a claim hasn't come in and there is a later admission, set discharge date to next admit date
DROP TABLE IF EXISTS #AddRowInpatient
SELECT a.*, 
	RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY AdmitDateTime)
INTO #AddRowInpatient
FROM #CombinedInpatientEpisodes a


UPDATE a
	SET DischargeDateTime = b.DischargeDateTime
FROM #AddRowInpatient a
LEFT JOIN #AddRowInpatient b
	ON a.MVIPersonSID=b.MVIPersonSID
	AND a.DischargeDateTime IS NULL
	AND b.AdmitDateTime>a.AdmitDateTime
	WHERE b.DischargeDateTime IS NOT NULL
	AND b.RN=a.RN+1

DROP TABLE IF EXISTS #DropExtraInpatRecords
SELECT a.*, CASE WHEN b.DischargeDateTime IS NULL AND b.AdmitDateTime IS NOT NULL THEN 1 ELSE 0 END AS DropRecord 
INTO #DropExtraInpatRecords
FROM #AddRowInpatient a
LEFT JOIN #AddRowInpatient b  ON a.MVIPersonSID=b.MVIPersonSID AND CAST(a.AdmitDateTime AS date)=CAST(b.AdmitDateTime AS date)
	AND a.RN<>b.RN
	
/**********************************************************
Handle Confirmed Episodes
**********************************************************/
DROP TABLE IF EXISTS #RawConfirmedEpisodes
SELECT DISTINCT e.MVIPersonSID
	,e.ChecklistID
	--,CAST(e.VisitDateTime AS date) AS VisitDate
	,MIN(e.VisitDateTime) OVER (PARTITION BY ISNULL(a.UniqueIVC_ID,a.VisitSID)) AS VisitDateTime
	,MIN(CASE WHEN ipt.AdmitDateTime < a.VisitDateTime THEN ipt.AdmitDateTime
		ELSE a.VisitDateTime END) OVER (PARTITION BY ISNULL(a.UniqueIVC_ID,a.VisitSID)) AS EpisodeBeginDate
	,e.VisitSID
	,e.List
	,CASE WHEN e.List LIKE '%Community%' OR e.UniqueIVC_ID IS NOT NULL THEN 1 ELSE 0 END AS CommunityCare
	,ConfirmedStart = 1
	,CASE WHEN ipt.MVIPersonSID IS NOT NULL THEN 'New Admission'
		WHEN s.MVIPersonSID IS NOT NULL THEN 'New SBOR'
		ELSE NULL END AS Restart
	,COMPACT = 1
	,c.COMPACTIndicator AS EncounterCodes
	,CASE WHEN i.TxSetting IS NOT NULL THEN i.TxSetting
		WHEN ipt.MVIPersonSID IS NOT NULL THEN 'Inpatient'
		ELSE 'Outpatient' END AS TxSetting
	,i.Paid --IVC data only
	,e.UniqueIVC_ID --IVC data only
	,ipt.AdmitDateTime
	,ipt.DischargeDateTime
	,s.EventDateFormatted
	,s.EntryDateTime
	,e.EDVisit
	,CASE WHEN e.VisitDateTime BETWEEN DATEADD(hour,-12,ipt.AdmitDateTime) AND ipt.AdmitDateTime AND e.EDVisit=1 
		AND (CAST(e.VisitDateTime AS date)<>CAST(ipt.AdmitDateTime AS date))
		THEN 1 ELSE 0 END AS NextDayAdmit 
INTO #RawConfirmedEpisodes
FROM #EncounterCodesPivot e
LEFT JOIN #Diagnosis_Procedure_HF_DTA_IVC_Encounter a
	ON ISNULL(a.UniqueIVC_ID,a.VisitSID) = ISNULL(e.UniqueIVC_ID,e.VisitSID)
LEFT JOIN #StringCOMPACTIndicators_Date c 
	ON e.MVIPersonSID = c.MVIPersonSID AND CAST(e.VisitDateTime AS date) = c.VisitDate
LEFT JOIN #IVC i 
	ON ISNULL(e.UniqueIVC_ID,e.VisitSID) = ISNULL(i.UniqueIVC_ID, i.VisitSID)
LEFT JOIN #DropExtraInpatRecords ipt WITH (NOLOCK) 
	ON e.MVIPersonSID=ipt.MVIPersonSID --restart episode if new inpatient admission mid-episode, if also coded with initial episode codes
	AND (e.VisitDateTime BETWEEN CAST(ipt.AdmitDateTime AS date) AND CAST(ipt.DischargeDateTime AS date) 
		OR (e.VisitDateTime >= CAST(ipt.AdmitdateTime AS date) AND CAST(ipt.DischargeDateTime AS date) IS NULL)
		OR (e.VisitDateTime BETWEEN DATEADD(hour,-12,ipt.AdmitDateTime) AND ipt.AdmitDateTime AND e.EDVisit=1))
LEFT JOIN [OMHSP_Standard].[SuicideOverdoseEvent] s WITH (NOLOCK) ON e.MVIPersonSID = s.MVIPersonSID --restart episode if new SBOR mid-episode, if also coded with initial episode codes
	AND e.VisitSID = s.VisitSID
WHERE e.List LIKE '%COMPACT_InitialCare%' OR e.UniqueIVC_ID IS NOT NULL

--Get rid of duplicate records that don't meet criteria (retains matching records that do meet criteria)
DELETE
FROM #RawConfirmedEpisodes
WHERE EncounterCodes NOT LIKE '%COMPACT%' AND EncounterCodes NOT LIKE '%ID:%'

--Set preliminary episode begin and end dates
DROP TABLE IF EXISTS #PrelimStartEnd_Inpat
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.VisitDateTime
	,a.VisitSID
	,a.List
	,a.CommunityCare
	,a.ConfirmedStart
	,a.Restart
	,a.COMPACT
	,a.EncounterCodes
	,a.TxSetting AS EpisodeBeginSetting
	,a.Paid --IVC data only
	,a.UniqueIVC_ID --IVC data only
	,a.AdmitDateTime
	,a.DischargeDateTime
	,a.EventDateFormatted
	,a.EntryDateTime
	,a.EpisodeBeginDate
	,InpatientEpisodeEndDate = CASE WHEN a.AdmitDateTime IS NOT NULL AND a.DischargeDateTime IS NULL THEN CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date)
		WHEN a.DischargeDateTime IS NOT NULL AND DateDiff(day,CAST(a.EpisodeBeginDate AS date),CAST(a.DischargeDateTime AS date))>=30 THEN  CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date)
		WHEN a.DischargeDateTime IS NOT NULL THEN CAST(a.DischargeDateTime AS date) 
		ELSE NULL END
	,Inpatient = CASE WHEN AdmitDateTime IS NOT NULL THEN 1 ELSE 0 END
INTO #PrelimStartEnd_Inpat
FROM #RawConfirmedEpisodes a

DROP TABLE IF EXISTS #ExtendInpatientEpisodes
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN i.VisitDateTime IS NOT NULL AND a.DischargeDateTime IS NULL THEN CAST(DateAdd(day,30,a.InpatientEpisodeEndDate) AS date)--if inpatient episode has been extended, push out estimated inpatient episode end date by 30 days
		WHEN i.VisitDateTime IS NOT NULL AND CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,60,a.EpisodeBeginDate) AS date) THEN CAST(DateAdd(day,60,a.EpisodeBeginDate) AS date) --If admission is longer than 30 + 30 days extension then set end to 60 days
		WHEN i.VisitDateTime IS NOT NULL AND CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date) THEN CAST(DischargeDateTime AS date) --if extended and patient is already discharged, extend by up to 30 days
		ELSE a.InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,CASE WHEN i.VisitDateTime IS NOT NULL 
		AND (a.DischargeDateTime IS NULL OR CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date))
		THEN 1 ELSE 0 END AS InpatientEpisodeExtended
	,CAST(a.DischargeDateTime AS date) AS DischargeDate
	,CAST(a.AdmitDateTime AS date) AS AdmitDate
	,a.EncounterCodes
	,a.Restart
	,a.UniqueIVC_ID
INTO #ExtendInpatientEpisodes
FROM #PrelimStartEnd_Inpat a
LEFT JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_30DayExtensionOfCare%') i 
	ON a.MVIPersonSID = i.MVIPersonSID 
	AND a.AdmitDateTime IS NOT NULL 
	AND (CAST(i.VisitDateTime AS date) BETWEEN DateAdd(day,-7,a.DischargeDateTime) AND DateAdd(day,7,a.DischargeDateTime) --extend episode if HF is entered within 7 days of end of inpatient episode or discharge
			OR CAST(i.VisitDateTime AS date) BETWEEN DateAdd(day,-7,a.InpatientEpisodeEndDate) AND DateAdd(day,7,a.InpatientEpisodeEndDate))

--Set outpatient episodes to 90 days
DROP TABLE IF EXISTS #OutpatientEpisodes
SELECT MVIPersonSID
	,ChecklistID
	,CAST(EpisodeBeginDate AS date) AS EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,Inpatient
	,InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate = CASE WHEN Inpatient=0 THEN EpisodeBeginDate
		WHEN DischargeDate > InpatientEpisodeEndDate THEN CAST(DischargeDate AS date) --if patient is admitted past the inpatient episode end date, start outpatient episode at date of discharge
		WHEN DischargeDate IS NULL AND EpisodeBeginSetting LIKE 'CC%' AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(DateAdd(day,30,AdmitDate) AS date) --community care - sometimes discharge date never populates so this prevents the episode from going on forever
		WHEN DischargeDate IS NULL AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(getdate() AS date) --direct care where patient is still admitted	
		ELSE InpatientEpisodeEndDate END
	,EpisodeEndDate = CASE WHEN Inpatient = 0 THEN CAST(DateAdd(day,90,EpisodeBeginDate) AS date)
		WHEN DischargeDate > InpatientEpisodeEndDate THEN  CAST(DateAdd(day,90,DischargeDate) AS date) 
		WHEN DischargeDate IS NULL AND EpisodeBeginSetting LIKE 'CC%' AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(DateAdd(day,90,DateAdd(day,30,AdmitDate)) AS date)
		WHEN DischargeDate IS NULL AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(DateAdd(day,90,getdate()) AS date)
		ELSE CAST(DateAdd(day,90,InpatientEpisodeEndDate) AS date) END
	,InpatientEpisodeExtended
	,EncounterCodes
	,Restart
	,UniqueIVC_ID
INTO #OutpatientEpisodes
FROM #ExtendInpatientEpisodes

--If episode extension is documented within +/-7 days of end of 90-day outpatient episode, extend outpatient episode by 30 days
DROP TABLE IF EXISTS #EpisodeDates
SELECT DISTINCT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,CAST(a.OutpatientEpisodeBeginDate AS date) AS OutpatientEpisodeBeginDate
	,CASE WHEN o.VisitDateTime IS NOT NULL THEN CAST(DateAdd(day,120,a.OutpatientEpisodeBeginDate) AS date)
		ELSE a.EpisodeEndDate END AS EpisodeEndDate
	,CASE WHEN o.VisitDateTime IS NOT NULL OR a.InpatientEpisodeExtended=1 THEN 1 ELSE 0 END AS EpisodeExtended
	,a.EncounterCodes
	,a.Restart
	,a.UniqueIVC_ID
INTO #EpisodeDates
FROM #OutpatientEpisodes a
LEFT JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_30DayExtensionOfCare%') o 
	ON a.MVIPersonSID = o.MVIPersonSID AND CAST(o.VisitDateTime AS date) BETWEEN CAST(DateAdd(day,83,a.OutpatientEpisodeBeginDate) as date) AND CAST(DateAdd(day,97,a.OutpatientEpisodeBeginDate) as date) --extend outpatient episode if HF is entered between +/- 7 days of episode end

DROP TABLE IF EXISTS #AddRowEpisodes
SELECT *
	,RowNumber = ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY EpisodeBeginDate, 
																CASE WHEN EpisodeBeginSetting LIKE '%Inpatient%' THEN 0 ELSE 1 END,
																CommunityCare DESC)
	,Ignore=0
INTO #AddRowEpisodes
FROM #EpisodeDates

--Set end dates when patient has been determined to be not clinically eligible for COMPACT
DROP TABLE IF EXISTS #NotEligible
SELECT a.MVIPersonSID, a.EpisodeBeginDate, CAST(MIN(b.VisitDateTime) AS date) AS EndDate
INTO #NotEligible
FROM #AddRowEpisodes a
INNER JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_EndEpisode%') b
	ON a.MVIPersonSID = b.MVIPersonSID AND b.VisitDateTime BETWEEN CAST(a.EpisodeBeginDate AS date) AND a.EpisodeEndDate
GROUP BY a.MVIPersonSID, a.EpisodeBeginDate

DROP TABLE IF EXISTS #ShortenIneligibleEpisodes
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN b.EndDate < a.InpatientEpisodeEndDate THEN b.EndDate
		ELSE a.InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,CASE WHEN b.EndDate <= a.InpatientEpisodeEndDate THEN NULL	
		ELSE a.OutpatientEpisodeBeginDate END AS OutpatientEpisodeBeginDate
	,ISNULL(b.EndDate, a.EpisodeEndDate) AS EpisodeEndDate
	,CASE WHEN b.EndDate IS NOT NULL THEN 0 ELSE a.EpisodeExtended END AS EpisodeExtended
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN 1 ELSE 0 END AS EpisodeTruncated
	,TruncateReason = CASE WHEN b.EndDate < a.EpisodeEndDate THEN CAST('Clinically Ineligible' AS varchar(30)) ELSE NULL END
	,a.EncounterCodes
	,a.RowNumber
	,a.Restart
	,a.UniqueIVC_ID
	,Ignore=0
INTO #ShortenIneligibleEpisodes
FROM #AddRowEpisodes a
LEFT JOIN #NotEligible b ON a.MVIPersonSID = b.MVIPersonSID AND a.EpisodeBeginDate = b.EpisodeBeginDate	

--Get potential episode begin dates that fall after another episode
DECLARE @Counter INT, @MaxID INT
SELECT @Counter=MIN(RowNumber), @MaxID=MAX(RowNumber)
FROM #ShortenIneligibleEpisodes

WHILE (@Counter IS NOT NULL AND @Counter <= @MaxID)
BEGIN
	
	UPDATE t
	SET Ignore = CASE WHEN t.RowNumber=1 THEN 0
		WHEN t.EpisodeBeginDate>s.EpisodeEndDate THEN 0 
		WHEN t.Restart IS NULL THEN 1 
		WHEN t.Restart IS NOT NULL THEN 0
		ELSE NULL END
	FROM #ShortenIneligibleEpisodes t 
	INNER JOIN #ShortenIneligibleEpisodes s on s.MVIPersonSID=t.MVIPersonSID
		AND s.RowNumber=@counter
		AND t.RowNumber>@counter

	DELETE FROM #ShortenIneligibleEpisodes WHERE Ignore=1

	;WITH RowNums AS (
		SELECT MVIPersonSID	
			,RowNumber = ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY RowNumber)
			,EpisodeBeginDate
		FROM #ShortenIneligibleEpisodes
		)
	UPDATE u
	SET u.RowNumber = r.RowNumber
	FROM #ShortenIneligibleEpisodes u
	INNER JOIN RowNums r ON u.MVIPersonSID = r.MVIPersonSID AND u.EpisodeBeginDate=r.EpisodeBeginDate

	SET @counter+=1
END

--Get potential episode begin dates that fall after another episode
DROP TABLE IF EXISTS #Update
SELECT TOP 1 WITH TIES
	a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EncounterCodes
	,a.RowNumber
	,a.Restart
	,a.UniqueIVC_ID
	--,CASE WHEN a.Restart IS NOT NULL AND b.StartRestart<2 THEN 1 ELSE 0 END AS Ignore
INTO #Update
FROM #ShortenIneligibleEpisodes a
LEFT JOIN #ShortenIneligibleEpisodes b ON b.MVIPersonSID = a.MVIPersonSID --earlier episode
	AND b.EpisodeBeginDate <> a.EpisodeBeginDate-- not the same record
	AND (a.EpisodeBeginDate>b.EpisodeEndDate --episode begins after the previous one ended
		OR (a.EpisodeBeginDate>b.EpisodeBeginDate AND a.Restart IS NOT NULL)) 
ORDER BY ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID, b.EpisodeBeginDate ORDER BY a.EpisodeBeginDate)


DROP TABLE IF EXISTS #Renumber
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeEndDate
	,a.EncounterCodes
	,RowNumber = ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate)
	,a.Inpatient
	,a.EpisodeBeginSetting
	,a.Restart
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.UniqueIVC_ID
INTO #Renumber
FROM #Update a

--Identify cases where restart isn't necessary because episode doesn't overlap with previous episode
DROP TABLE IF EXISTS #FalseRestarts
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeEndDate
	,a.EncounterCodes
	,a.RowNumber
	,a.Inpatient
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,CASE WHEN a.EpisodeBeginDate NOT BETWEEN b.EpisodeBeginDate AND b.EpisodeEndDate OR a.RowNumber=1 THEN NULL
		ELSE a.Restart END AS Restart
	,b.EpisodeBeginDate AS PrevEpisode
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.UniqueIVC_ID
INTO #FalseRestarts
FROM #Renumber a
LEFT JOIN #Renumber b ON a.MVIPersonSID = b.MVIPersonSID	
	AND a.RowNumber-1=b.RowNumber
	
DROP TABLE IF EXISTS #ConsolidateEpisodes
SELECT a.MVIPersonSID
	,MAX(a.ChecklistID) AS ChecklistID
	,MIN(a.EpisodeBeginDate) AS EpisodeBeginDate
	,MIN(a.EpisodeBeginSetting) AS EpisodeBeginSetting --prioritize inpatient, then community care, then outpatient
	,MAX(a.CommunityCare) AS CommunityCare
	,MAX(a.Inpatient) AS Inpatient
	,MAX(a.InpatientEpisodeEndDate) AS InpatientEpisodeEndDate
	,MAX(a.OutpatientEpisodeBeginDate) AS OutpatientEpisodeBeginDate
	,MAX(a.EpisodeEndDate) AS EpisodeEndDate
	,MAX(a.Restart) AS Restart
	,MAX(a.EpisodeExtended) AS EpisodeExtended
	,MAX(a.EpisodeTruncated) AS EpisodeTruncated
	,MAX(a.TruncateReason) AS TruncateReason
	,ISNULL(MAX(b.EncounterCodes), MAX(a.EncounterCodes)) AS EncounterCodes
	,MAX(a.UniqueIVC_ID) AS UniqueIVC_ID
INTO #ConsolidateEpisodes
FROM #FalseRestarts a
LEFT JOIN (SELECT * FROM #FalseRestarts WHERE Restart IS NOT NULL) b --prioritize encounter codes from template 
	ON a.MVIPersonSID = b.MVIPersonSID AND a.EpisodeBeginDate = b.EpisodeBeginDate
GROUP BY a.MVIPersonSID, CAST(a.EpisodeBeginDate AS date)
	
--Identify currently active episodes
DROP TABLE IF EXISTS #Episodes
SELECT DISTINCT *
	,CASE WHEN CAST(GETDATE() AS date) BETWEEN EpisodeBeginDate AND EpisodeEndDate THEN 1 ELSE 0 END AS ActiveEpisode
INTO #Episodes
FROM #ConsolidateEpisodes

--Add ascending and descending episode ranking
--For patients who had a COMPACT episode begin while eligible, and then became ineligible
DROP TABLE IF EXISTS #AdminEligibility
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN b.EndDate < a.InpatientEpisodeEndDate AND a.Inpatient = 1 THEN b.EndDate 
		ELSE a.InpatientEpisodeEndDate 
		END AS InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN b.EndDate 
		ELSE a.EpisodeEndDate 
		END AS EpisodeEndDate
	,a.Restart
	,a.EpisodeExtended
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN 1 
		ELSE a.EpisodeTruncated 
		END AS EpisodeTruncated
	,ISNULL(a.TruncateReason,'Administratively Ineligible') AS TruncateReason
	,a.EncounterCodes
	,a.ActiveEpisode
	,a.UniqueIVC_ID
INTO #AdminEligibility
FROM #Episodes a
INNER JOIN [COMPACT].[Eligibility] b WITH (NOLOCK) 
	ON a.MVIPersonSID = b.MVIPersonSID 
	AND a.EpisodeBeginDate BETWEEN b.StartDate AND b.EndDate
INNER JOIN [COMPACT].[Eligibility] c WITH (NOLOCK)
	ON a.MVIPersonSID = c.MVIPersonSID
	AND c.ActiveRecord = 1 AND c.CompactEligible = 0 --patients not currently administratively eligible for COMPACT, but may have been in the past
WHERE b.ActiveRecord = 0 AND  b.CompactEligible = 1
UNION ALL
--Patients who are currently COMPACT eligible - include everything even if the patient wasn't documented as eligible at some point in the past
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EncounterCodes
	,a.ActiveEpisode
	,a.UniqueIVC_ID
FROM #Episodes a
INNER JOIN [COMPACT].[Eligibility] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID
WHERE b.ActiveRecord = 1 AND b.CompactEligible = 1

DROP TABLE IF EXISTS #RankEpisodes
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.Restart
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EpisodeExtended
	,a.EncounterCodes
	,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate DESC,EpisodeEndDate DESC,ActiveEpisode DESC) AS EpisodeRankDesc
	,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate,EpisodeEndDate,ActiveEpisode) AS EpisodeRankAsc
INTO #RankEpisodes
FROM #AdminEligibility a

--For episodes that overlap, set end date to the day the next episode begins
DROP TABLE IF EXISTS #OverlappingEpisodes
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,CASE WHEN CAST(a.OutpatientEpisodeBeginDate AS date) <= CAST(b.EpisodeBeginDate AS date) THEN a.OutpatientEpisodeBeginDate ELSE NULL END AS OutpatientEpisodeBeginDate
	,CAST(b.EpisodeBeginDate AS date) AS EpisodeEndDate
	,EpisodeTruncated=1
	,TruncateReason = ISNULL(a.TruncateReason,b.Restart)
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeRankDesc
	,a.EncounterCodes
INTO #OverlappingEpisodes
FROM (SELECT * FROM #RankEpisodes WHERE EpisodeRankDesc>1) a
INNER JOIN #RankEpisodes b ON a.MVIPersonSID = b.MVIPersonSID 
	AND CAST(b.EpisodeBeginDate AS date) BETWEEN CAST(a.EpisodeBeginDate AS date) AND CAST(a.EpisodeEndDate AS date)
	AND b.EpisodeRankAsc = (a.EpisodeRankAsc + 1) 

DROP TABLE IF EXISTS #NonOverlappingEpisodes
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,ISNULL(a.EpisodeTruncated,0) AS EpisodeTruncated
	,a.TruncateReason
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeRankDesc
	,a.EncounterCodes
INTO #NonOverlappingEpisodes
FROM #RankEpisodes a
LEFT JOIN #RankEpisodes b ON a.MVIPersonSID = b.MVIPersonSID 
	AND CAST(b.EpisodeBeginDate AS date) BETWEEN CAST(a.EpisodeBeginDate AS date) AND CAST(a.EpisodeEndDate AS date)
	AND b.EpisodeRankAsc = (a.EpisodeRankAsc + 1) 
WHERE b.MVIPersonSID IS NULL

DROP TABLE IF EXISTS #AllConfirmedEpisodes
SELECT MVIPersonSID
	,ChecklistID AS ChecklistID_EpisodeBegin
	,EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,CASE WHEN InpatientEpisodeEndDate > EpisodeEndDate THEN EpisodeEndDate 
		ELSE InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate
	,EpisodeEndDate
	,EpisodeTruncated
	,TruncateReason
	,EpisodeExtended
	,EpisodeRankDesc
	,EncounterCodes
	,Restart
INTO #AllConfirmedEpisodes
FROM #NonOverlappingEpisodes
UNION ALL
SELECT MVIPersonSID
	,ChecklistID AS ChecklistID_EpisodeBegin
	,EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,CASE WHEN InpatientEpisodeEndDate > EpisodeEndDate THEN EpisodeEndDate ELSE InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate
	,EpisodeEndDate
	,EpisodeTruncated
	,TruncateReason
	,EpisodeExtended
	,EpisodeRankDesc
	,EncounterCodes
	,Restart
FROM #OverlappingEpisodes

UPDATE #AllConfirmedEpisodes
SET OutpatientEpisodeBeginDate = NULL
WHERE OutpatientEpisodeBeginDate < InpatientEpisodeEndDate
AND EpisodeTruncated=1

DROP TABLE IF EXISTS #StageConfirmedEpisodes
SELECT *
	,CASE WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,InpatientEpisodeEndDate) THEN 'I'
		WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,EpisodeEndDate) THEN 'O'
		ELSE NULL
		END AS ActiveEpisodeSetting --if the episode is active, is the patient inpatient or outpatient
	,CASE WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,EpisodeEndDate) THEN 1 ELSE 0 END AS ActiveEpisode
INTO #StageConfirmedEpisodes
FROM #AllConfirmedEpisodes

/**********************************************************
Handle Unconfirmed Episodes
Start with same steps as above but using dx/procedure/follow-up codes, then fill in the gaps of confirmed episodes with any existing unconfirmed
**********************************************************/
DROP TABLE IF EXISTS #RawUnconfirmedEpisodes
SELECT DISTINCT e.MVIPersonSID
	,e.ChecklistID
	--,CAST(e.VisitDateTime AS date) AS VisitDate
	,e.VisitDateTime
	,EpisodeBeginDate = CASE WHEN ipt.AdmitDateTime < a.VisitDateTime THEN ipt.AdmitDateTime
		ELSE a.VisitDateTime END
	,e.VisitSID
	,e.List
	,CASE WHEN e.List LIKE '%Community%' OR e.UniqueIVC_ID IS NOT NULL THEN 1 ELSE 0 END AS CommunityCare
	,ConfirmedStart = 0
	,CASE WHEN ipt.MVIPersonSID IS NOT NULL THEN 'New Admission'
		WHEN s.MVIPersonSID IS NOT NULL THEN 'New SBOR'
		ELSE NULL END AS Restart
	,CASE WHEN e.List LIKE '%COMPACT_FollowUp%' THEN 1 --Even if follow-up health factor is entered first, we assume this is user error and still may be considered start of episode; otherwise, followup
		WHEN e.ICD LIKE '%T14.91XA%' THEN 1 --this dx code always indicates COMPACT-eligible care
		WHEN e.ICD LIKE '%R45.851%' AND e.CPT LIKE '%90839%' THEN 1 --This pair of codes must be used together to indicate COMPACT care
		WHEN e.ICD LIKE '%R45.851%' AND e.CPT IS NULL AND ipt.MVIPersonSID IS NOT NULL THEN 1 --If this dx code is documented inpatient and there are no CPT codes, count as COMPACT
		WHEN e.CPT LIKE '%T2034%' THEN 1 --this procedure code always indicates COMPACT-eligible care
		ELSE 0 END AS COMPACT
	,c.COMPACTIndicator AS EncounterCodes
	,CASE WHEN i.TxSetting IS NOT NULL THEN i.TxSetting
		WHEN ipt.MVIPersonSID IS NOT NULL THEN 'Inpatient'
		ELSE 'Outpatient' END AS TxSetting
	,i.Paid --IVC data only
	,e.UniqueIVC_ID --IVC data only
	,ipt.AdmitDateTime
	,ipt.DischargeDateTime
	,s.EventDateFormatted
	,s.EntryDateTime
INTO #RawUnconfirmedEpisodes
FROM #EncounterCodesPivot e
LEFT JOIN #Diagnosis_Procedure_HF_DTA_IVC_Encounter a
	ON ISNULL(a.UniqueIVC_ID,a.VisitSID) = ISNULL(e.UniqueIVC_ID,e.VisitSID) AND a.VisitDateTime=e.VisitDateTime --added join on visitdate to deal with cases where templates are documented on multiple days within same encounter (mostly occurs in Oracle Health)
LEFT JOIN #StringCOMPACTIndicators_Date c 
	ON e.MVIPersonSID = c.MVIPersonSID AND CAST(e.VisitDateTime AS date) = c.VisitDate
LEFT JOIN #IVC i 
	ON ISNULL(e.UniqueIVC_ID,e.VisitSID) = ISNULL(i.UniqueIVC_ID, i.VisitSID)
LEFT JOIN #DropExtraInpatRecords ipt WITH (NOLOCK) 
	ON e.MVIPersonSID=ipt.MVIPersonSID --restart episode if new inpatient admission mid-episode, if also coded with initial episode codes
	AND (e.VisitDateTime BETWEEN ipt.AdmitDateTime AND ipt.DischargeDateTime
		OR (e.VisitDateTime >= ipt.AdmitdateTime AND ipt.DischargeDateTime IS NULL))
LEFT JOIN [OMHSP_Standard].[SuicideOverdoseEvent] s WITH (NOLOCK) ON e.MVIPersonSID = s.MVIPersonSID --restart episode if new SBOR mid-episode, if also coded with initial episode codes
	AND e.VisitSID = s.VisitSID
WHERE ((e.List NOT LIKE '%Initial%' AND e.List NOT LIKE '%Community%' and e.List NOT LIKE '%Extension%' AND e.List NOT LIKE '%EndEpisode%')  OR e.List IS NULL) 
	AND e.UniqueIVC_ID IS NULL --only unconfirmed indicators
	AND (c.COMPACTIndicator NOT LIKE '% ID: %' 
		AND c.COMPACTIndicator NOT LIKE '%INITIAL%' 
		AND c.COMPACTIndicator NOT LIKE '%NONACUTE%'
		AND c.COMPACTIndicator NOT LIKE '%EXTENSION%'
		AND c.COMPACTIndicator NOT LIKE '%CCPN%'
		AND c.COMPACTIndicator NOT LIKE '%CCET%') --grouped in with confirmed episodes above
	
DELETE FROM #RawUnconfirmedEpisodes WHERE COMPACT=0

--Remove possible unconfirmed starts that happen within a confirmed episode
DROP TABLE IF EXISTS #ConfirmedUnconfirmedOverlap
SELECT r.*
	,CASE WHEN s.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS Ignore
INTO #ConfirmedUnconfirmedOverlap
FROM #RawUnconfirmedEpisodes r
LEFT JOIN #StageConfirmedEpisodes s
	ON r.MVIPersonSID = s.MVIPersonSID
	AND CAST(r.EpisodeBeginDate AS date) BETWEEN CAST(s.EpisodeBeginDate AS date) AND CAST(s.EpisodeEndDate AS date) 

DELETE FROM #ConfirmedUnconfirmedOverlap WHERE Ignore = 1

--Set preliminary episode begin and end dates
DROP TABLE IF EXISTS #PrelimStartEnd_Inpat_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.VisitDateTime
	,a.VisitSID
	,a.List
	,a.CommunityCare
	,a.ConfirmedStart
	,a.Restart
	,a.COMPACT
	,a.EncounterCodes
	,a.TxSetting AS EpisodeBeginSetting
	,a.Paid --IVC data only
	,a.UniqueIVC_ID --IVC data only
	,a.AdmitDateTime
	,a.DischargeDateTime
	,a.EventDateFormatted
	,a.EntryDateTime
	,a.EpisodeBeginDate
	,InpatientEpisodeEndDate = CASE WHEN a.AdmitDateTime IS NOT NULL AND a.DischargeDateTime IS NULL THEN CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date)
		WHEN a.DischargeDateTime IS NOT NULL AND DateDiff(day,CAST(a.EpisodeBeginDate AS date),CAST(a.DischargeDateTime AS date))>=30 THEN  CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date)
		WHEN a.DischargeDateTime IS NOT NULL THEN CAST(a.DischargeDateTime AS date) 
		ELSE NULL END
	,Inpatient = CASE WHEN AdmitDateTime IS NOT NULL THEN 1 ELSE 0 END
INTO #PrelimStartEnd_Inpat_Unconfirmed
FROM #ConfirmedUnconfirmedOverlap a


DROP TABLE IF EXISTS #ExtendInpatientEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN i.VisitDateTime IS NOT NULL AND a.DischargeDateTime IS NULL THEN CAST(DateAdd(day,30,a.InpatientEpisodeEndDate) AS date)--if inpatient episode has been extended, push out estimated inpatient episode end date by 30 days
		WHEN i.VisitDateTime IS NOT NULL AND CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,60,a.EpisodeBeginDate) AS date) THEN CAST(DateAdd(day,60,a.EpisodeBeginDate) AS date) --If admission is longer than 30 + 30 days extension then set end to 60 days
		WHEN i.VisitDateTime IS NOT NULL AND CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date) THEN CAST(DischargeDateTime AS date) --if extended and patient is already discharged, extend by up to 30 days
		ELSE a.InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,CASE WHEN i.VisitDateTime IS NOT NULL 
		AND (a.DischargeDateTime IS NULL OR CAST(a.DischargeDateTime AS date) > CAST(DateAdd(day,30,a.EpisodeBeginDate) AS date))
		THEN 1 ELSE 0 END AS InpatientEpisodeExtended
	,CAST(a.DischargeDateTime AS date) AS DischargeDate
	,CAST(a.AdmitDateTime AS date) AS AdmitDate
	,a.EncounterCodes
	,a.Restart
	,a.UniqueIVC_ID
INTO #ExtendInpatientEpisodes_Unconfirmed
FROM #PrelimStartEnd_Inpat_Unconfirmed a
LEFT JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_30DayExtensionOfCare%') i 
	ON a.MVIPersonSID = i.MVIPersonSID AND a.AdmitDateTime IS NOT NULL 
	AND (CAST(i.VisitDateTime AS date) BETWEEN DateAdd(day,-7,a.DischargeDateTime) AND DateAdd(day,7,a.DischargeDateTime) --extend episode if HF is entered within 7 days of end of inpatient episode or discharge
			OR CAST(i.VisitDateTime AS date) BETWEEN DateAdd(day,-7,a.InpatientEpisodeEndDate) AND DateAdd(day,7,a.InpatientEpisodeEndDate))

--Set outpatient episodes to 90 days
DROP TABLE IF EXISTS #OutpatientEpisodes_Unconfirmed
SELECT MVIPersonSID
	,ChecklistID
	,CAST(EpisodeBeginDate AS date) AS EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,Inpatient
	,InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate = CASE WHEN Inpatient=0 THEN EpisodeBeginDate
		WHEN DischargeDate > InpatientEpisodeEndDate THEN CAST(DischargeDate AS date) --if patient is admitted past the inpatient episode end date, start outpatient episode at date of discharge
		WHEN DischargeDate IS NULL AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(getdate() AS date)
		ELSE InpatientEpisodeEndDate END
	,EpisodeEndDate = CASE WHEN Inpatient = 0 THEN CAST(DateAdd(day,90,EpisodeBeginDate) AS date)
		WHEN DischargeDate > InpatientEpisodeEndDate THEN  CAST(DateAdd(day,90,DischargeDate) AS date) 
		WHEN DischargeDate IS NULL AND DateAdd(day,30,AdmitDate) <= getdate() THEN CAST(DateAdd(day,90,getdate()) AS date)
		ELSE CAST(DateAdd(day,90,InpatientEpisodeEndDate) AS date) END
	,InpatientEpisodeExtended
	,EncounterCodes
	,Restart
	,UniqueIVC_ID
INTO #OutpatientEpisodes_Unconfirmed
FROM #ExtendInpatientEpisodes_Unconfirmed

--If episode extension is documented within +/-7 days of end of 90-day outpatient episode, extend outpatient episode by 30 days
DROP TABLE IF EXISTS #EpisodeDates_Unconfirmed
SELECT DISTINCT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,CASE WHEN o.VisitDateTime IS NOT NULL THEN CAST(DateAdd(day,120,a.OutpatientEpisodeBeginDate) AS date)
		ELSE a.EpisodeEndDate END AS EpisodeEndDate
	,CASE WHEN o.VisitDateTime IS NOT NULL OR a.InpatientEpisodeExtended=1 THEN 1 ELSE 0 END AS EpisodeExtended
	,a.EncounterCodes
	,a.Restart
	,a.UniqueIVC_ID
INTO #EpisodeDates_Unconfirmed
FROM #OutpatientEpisodes_Unconfirmed a
LEFT JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_30DayExtensionOfCare%') o 
	ON a.MVIPersonSID = o.MVIPersonSID AND CAST(o.VisitDateTime AS date) BETWEEN CAST(DateAdd(day,83,a.OutpatientEpisodeBeginDate) as date) AND CAST(DateAdd(day,97,a.OutpatientEpisodeBeginDate) as date) --extend outpatient episode if HF is entered between +/- 7 days of episode end
	
DROP TABLE IF EXISTS #AddRowEpisodes_Unconfirmed
SELECT *
	,RowNumber = ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY EpisodeBeginDate, Inpatient DESC)
	,Ignore=0
INTO #AddRowEpisodes_Unconfirmed
FROM #EpisodeDates_Unconfirmed

--Set end dates when patient has been determined to be not clinically eligible for COMPACT
DROP TABLE IF EXISTS #NotEligible_Unconfirmed
SELECT a.MVIPersonSID, a.EpisodeBeginDate, CAST(MIN(b.VisitDateTime) AS date) AS EndDate
INTO #NotEligible_Unconfirmed
FROM #AddRowEpisodes_Unconfirmed a
INNER JOIN (SELECT * FROM #Diagnosis_Procedure_HF_DTA_IVC_Encounter WHERE List LIKE '%COMPACT_EndEpisode%') b
	ON a.MVIPersonSID = b.MVIPersonSID AND b.VisitDateTime BETWEEN CAST(a.EpisodeBeginDate AS date) AND a.EpisodeEndDate
GROUP BY a.MVIPersonSID, a.EpisodeBeginDate

DROP TABLE IF EXISTS #ShortenIneligibleEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN b.EndDate < a.InpatientEpisodeEndDate THEN b.EndDate
		ELSE a.InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,CASE WHEN b.EndDate <= a.InpatientEpisodeEndDate THEN NULL	
		ELSE a.OutpatientEpisodeBeginDate END AS OutpatientEpisodeBeginDate
	,ISNULL(b.EndDate, a.EpisodeEndDate) AS EpisodeEndDate
	,CASE WHEN b.EndDate IS NOT NULL THEN 0 ELSE a.EpisodeExtended END AS EpisodeExtended
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN 1 ELSE 0 END AS EpisodeTruncated
	,TruncateReason = CASE WHEN b.EndDate < a.EpisodeEndDate THEN CAST('Clinically Ineligible' AS varchar(30)) ELSE NULL END
	,a.EncounterCodes
	,a.RowNumber
	,a.Restart
	,a.UniqueIVC_ID
	,Ignore=0
INTO #ShortenIneligibleEpisodes_Unconfirmed
FROM #AddRowEpisodes_Unconfirmed a
LEFT JOIN #NotEligible_Unconfirmed b ON a.MVIPersonSID = b.MVIPersonSID AND a.EpisodeBeginDate = b.EpisodeBeginDate	

--Get potential episode begin dates that fall after another episode
DECLARE @Counter2 INT, @MaxID2 INT
SELECT @Counter2=MIN(RowNumber), @MaxID2=MAX(RowNumber)
FROM #ShortenIneligibleEpisodes_Unconfirmed

WHILE (@Counter2 IS NOT NULL AND @Counter2 <= @MaxID2)
BEGIN
	
	UPDATE t
	SET Ignore = CASE WHEN t.RowNumber=1 THEN 0
		WHEN t.EpisodeBeginDate>s.EpisodeEndDate THEN 0 
		WHEN t.Restart IS NULL THEN 1 
		WHEN t.Restart IS NOT NULL THEN 0
		ELSE NULL END
	FROM #ShortenIneligibleEpisodes_Unconfirmed t 
	INNER JOIN #ShortenIneligibleEpisodes_Unconfirmed s on s.MVIPersonSID=t.MVIPersonSID
		AND s.RowNumber=@counter2
		AND t.RowNumber>@counter2

	DELETE FROM #ShortenIneligibleEpisodes_Unconfirmed WHERE Ignore=1

	;WITH RowNums AS (
		SELECT MVIPersonSID	
			,RowNumber = ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY RowNumber)
			,EpisodeBeginDate
		FROM #ShortenIneligibleEpisodes_Unconfirmed
		)
	UPDATE u
	SET u.RowNumber = r.RowNumber
	FROM #ShortenIneligibleEpisodes_Unconfirmed u
	INNER JOIN RowNums r ON u.MVIPersonSID = r.MVIPersonSID AND u.EpisodeBeginDate=r.EpisodeBeginDate

	SET @counter2+=1
END

--Get potential episode begin dates that fall after another episode
DROP TABLE IF EXISTS #Update2_Unconfirmed
SELECT TOP 1 WITH TIES
	a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EncounterCodes
	,a.RowNumber
	,a.Restart
	,a.UniqueIVC_ID
	--,CASE WHEN a.Restart IS NOT NULL AND b.StartRestart<2 THEN 1 ELSE 0 END AS Ignore
INTO #Update2_Unconfirmed
FROM #ShortenIneligibleEpisodes_Unconfirmed a
LEFT JOIN #ShortenIneligibleEpisodes_Unconfirmed b ON b.MVIPersonSID = a.MVIPersonSID --earlier episode
	AND b.EpisodeBeginDate <> a.EpisodeBeginDate-- not the same record
	AND (a.EpisodeBeginDate>b.EpisodeEndDate --episode begins after the previous one ended
		OR (a.EpisodeBeginDate>b.EpisodeBeginDate AND a.Restart IS NOT NULL)) 
ORDER BY ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID, b.EpisodeBeginDate ORDER BY a.EpisodeBeginDate)

--Truncate unconfirmed episodes where an overlapping confirmed episode is started
DROP TABLE IF EXISTS #MergeConfimedStartDates
SELECT TOP 1 WITH TIES a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN b.EpisodeBeginDate < a.InpatientEpisodeEndDate THEN b.EpisodeBeginDate
		ELSE a.InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,CASE WHEN b.EpisodeBeginDate < a.InpatientEpisodeEndDate THEN NULL
		ELSE a.OutpatientEpisodeBeginDate END AS OutpatientEpisodeBeginDate
	,CASE WHEN b.MVIPersonSID IS NOT NULL THEN b.EpisodeBeginDate --if confirmed episode overlaps, truncate unconfirmed episode and set end date as confirmed begin date
		ELSE a.EpisodeEndDate END AS EpisodeEndDate
	,a.EpisodeExtended
	,CASE WHEN b.MVIPersonSID IS NOT NULL THEN 1
		ELSE a.EpisodeTruncated END AS EpisodeTruncated
	,CASE WHEN b.MVIPersonSID IS NOT NULL THEN 'Confirmed Start'
		ELSE a.TruncateReason END AS TruncateReason
	,a.EncounterCodes
	,a.RowNumber
	,a.Restart
	,a.UniqueIVC_ID
INTO #MergeConfimedStartDates
FROM #Update2_Unconfirmed a
LEFT JOIN #StageConfirmedEpisodes b
	ON a.MVIPersonSID = b.MVIPersonSID
	AND CAST(b.EpisodeBeginDate AS date) BETWEEN CAST(a.EpisodeBeginDate AS date) AND CAST(a.EpisodeEndDate AS date)
ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, a.EpisodeBeginDate, a.EpisodeBeginSetting ORDER BY b.EpisodeEndDate)

DROP TABLE IF EXISTS #Renumber_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeEndDate
	,a.EncounterCodes
	,RowNumber = ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate)
	,a.Inpatient
	,a.EpisodeBeginSetting
	,a.Restart
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.UniqueIVC_ID
INTO #Renumber_Unconfirmed
FROM #MergeConfimedStartDates a


--Identify cases where restart isn't necessary because episode doesn't overlap with previous episode
DROP TABLE IF EXISTS #FalseRestarts_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeEndDate
	,a.EncounterCodes
	,a.RowNumber
	,a.Inpatient
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,CASE WHEN a.EpisodeBeginDate NOT BETWEEN b.EpisodeBeginDate AND b.EpisodeEndDate OR a.RowNumber=1 THEN NULL
		ELSE a.Restart END AS Restart
	,b.EpisodeBeginDate AS PrevEpisode
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.UniqueIVC_ID
INTO #FalseRestarts_Unconfirmed
FROM #Renumber_Unconfirmed a
LEFT JOIN #Renumber_Unconfirmed b ON a.MVIPersonSID = b.MVIPersonSID	
	AND a.RowNumber-1=b.RowNumber

DROP TABLE IF EXISTS #ConsolidateEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,MAX(a.ChecklistID) AS ChecklistID
	,MIN(a.EpisodeBeginDate) AS EpisodeBeginDate
	,MIN(a.EpisodeBeginSetting) AS EpisodeBeginSetting --prioritize inpatient, then community care, then outpatient
	,MAX(a.CommunityCare) AS CommunityCare
	,MAX(a.Inpatient) AS Inpatient
	,MAX(a.InpatientEpisodeEndDate) AS InpatientEpisodeEndDate
	,MAX(a.OutpatientEpisodeBeginDate) AS OutpatientEpisodeBeginDate
	,MAX(a.EpisodeEndDate) AS EpisodeEndDate
	,MAX(a.Restart) AS Restart
	,MAX(a.EpisodeExtended) AS EpisodeExtended
	,MAX(a.EpisodeTruncated) AS EpisodeTruncated
	,MAX(a.TruncateReason) AS TruncateReason
	,ISNULL(MAX(b.EncounterCodes), MAX(a.EncounterCodes)) AS EncounterCodes
	,MAX(a.UniqueIVC_ID) AS UniqueIVC_ID
INTO #ConsolidateEpisodes_Unconfirmed
FROM #FalseRestarts_Unconfirmed a
LEFT JOIN (SELECT * FROM #FalseRestarts_Unconfirmed WHERE Restart IS NOT NULL) b --prioritize encounter codes from template 
	ON a.MVIPersonSID = b.MVIPersonSID AND a.EpisodeBeginDate = b.EpisodeBeginDate
GROUP BY a.MVIPersonSID, CAST(a.EpisodeBeginDate AS date)


--Identify currently active episodes
DROP TABLE IF EXISTS #Episodes_Unconfirmed
SELECT DISTINCT *
	,CASE WHEN CAST(GETDATE() AS date) BETWEEN EpisodeBeginDate AND EpisodeEndDate THEN 1 ELSE 0 END AS ActiveEpisode
INTO #Episodes_Unconfirmed
FROM #ConsolidateEpisodes_Unconfirmed

--Add ascending and descending episode ranking
--For patients who had a COMPACT episode begin while eligible, and then became ineligible
DROP TABLE IF EXISTS #AdminEligibility_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,CASE WHEN b.EndDate < a.InpatientEpisodeEndDate AND a.Inpatient = 1 THEN b.EndDate 
		ELSE a.InpatientEpisodeEndDate 
		END AS InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN b.EndDate 
		ELSE a.EpisodeEndDate 
		END AS EpisodeEndDate
	,a.Restart
	,a.EpisodeExtended
	,CASE WHEN b.EndDate < a.EpisodeEndDate THEN 1 
		ELSE a.EpisodeTruncated 
		END AS EpisodeTruncated
	,ISNULL(a.TruncateReason,'Administratively Ineligible') AS TruncateReason
	,a.EncounterCodes
	,a.ActiveEpisode
	,a.UniqueIVC_ID
INTO #AdminEligibility_Unconfirmed
FROM #Episodes_Unconfirmed a
INNER JOIN [COMPACT].[Eligibility] b WITH (NOLOCK) 
	ON a.MVIPersonSID = b.MVIPersonSID 
	AND a.EpisodeBeginDate BETWEEN b.StartDate AND b.EndDate
INNER JOIN [COMPACT].[Eligibility] c WITH (NOLOCK)
	ON a.MVIPersonSID = c.MVIPersonSID
	AND c.ActiveRecord = 1 AND c.CompactEligible = 0 --patients not currently administratively eligible for COMPACT, but may have been in the past
WHERE b.ActiveRecord = 0 AND  b.CompactEligible = 1
UNION ALL
--Patients who are currently COMPACT eligible - include everything even if the patient wasn't documented as eligible at some point in the past
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.Inpatient
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EncounterCodes
	,a.ActiveEpisode
	,a.UniqueIVC_ID
FROM #Episodes_Unconfirmed a
INNER JOIN [COMPACT].[Eligibility] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID
WHERE b.ActiveRecord = 1 AND b.CompactEligible = 1

DROP TABLE IF EXISTS #RankEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,a.Restart
	,a.EpisodeTruncated
	,a.TruncateReason
	,a.EpisodeExtended
	,a.EncounterCodes
	,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate DESC,EpisodeEndDate DESC,ActiveEpisode DESC) AS EpisodeRankDesc
	,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY EpisodeBeginDate,EpisodeEndDate,ActiveEpisode) AS EpisodeRankAsc
INTO #RankEpisodes_Unconfirmed
FROM #AdminEligibility_Unconfirmed a

--For episodes that overlap, set end date to the day the next episode begins
DROP TABLE IF EXISTS #OverlappingEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,CASE WHEN CAST(a.OutpatientEpisodeBeginDate AS date) <= CAST(b.EpisodeBeginDate AS date) THEN a.OutpatientEpisodeBeginDate ELSE NULL END AS OutpatientEpisodeBeginDate
	,CAST(b.EpisodeBeginDate AS date) AS EpisodeEndDate
	,EpisodeTruncated=1
	,TruncateReason = ISNULL(a.TruncateReason,b.Restart)
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeRankDesc
	,a.EncounterCodes
INTO #OverlappingEpisodes_Unconfirmed
FROM (SELECT * FROM #RankEpisodes_Unconfirmed WHERE EpisodeRankDesc>1) a
INNER JOIN #RankEpisodes_Unconfirmed b ON a.MVIPersonSID = b.MVIPersonSID 
	AND CAST(b.EpisodeBeginDate AS date) BETWEEN CAST(a.EpisodeBeginDate AS date) AND CAST(a.EpisodeEndDate AS date)
	AND b.EpisodeRankAsc = (a.EpisodeRankAsc + 1) 

DROP TABLE IF EXISTS #NonOverlappingEpisodes_Unconfirmed
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.EpisodeBeginDate
	,a.EpisodeBeginSetting
	,a.CommunityCare
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeEndDate
	,ISNULL(a.EpisodeTruncated,0) AS EpisodeTruncated
	,a.TruncateReason
	,a.Restart
	,a.EpisodeExtended
	,a.EpisodeRankDesc
	,a.EncounterCodes
INTO #NonOverlappingEpisodes_Unconfirmed
FROM #RankEpisodes_Unconfirmed a
LEFT JOIN #RankEpisodes_Unconfirmed b ON a.MVIPersonSID = b.MVIPersonSID 
	AND CAST(b.EpisodeBeginDate AS date) BETWEEN CAST(a.EpisodeBeginDate AS date) AND CAST(a.EpisodeEndDate AS date)
	AND b.EpisodeRankAsc = (a.EpisodeRankAsc + 1) 
WHERE b.MVIPersonSID IS NULL

DROP TABLE IF EXISTS #AllUnconfirmedEpisodes
SELECT MVIPersonSID
	,ChecklistID AS ChecklistID_EpisodeBegin
	,EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,CASE WHEN InpatientEpisodeEndDate > EpisodeEndDate THEN EpisodeEndDate 
		ELSE InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate
	,EpisodeEndDate
	,EpisodeTruncated
	,TruncateReason
	,EpisodeExtended
	,EpisodeRankDesc
	,EncounterCodes
	,Restart
INTO #AllUnconfirmedEpisodes
FROM #NonOverlappingEpisodes_Unconfirmed
UNION ALL
SELECT MVIPersonSID
	,ChecklistID AS ChecklistID_EpisodeBegin
	,EpisodeBeginDate
	,EpisodeBeginSetting
	,CommunityCare
	,CASE WHEN InpatientEpisodeEndDate > EpisodeEndDate THEN EpisodeEndDate ELSE InpatientEpisodeEndDate END AS InpatientEpisodeEndDate
	,OutpatientEpisodeBeginDate
	,EpisodeEndDate
	,EpisodeTruncated
	,TruncateReason
	,EpisodeExtended
	,EpisodeRankDesc
	,EncounterCodes
	,Restart
FROM #OverlappingEpisodes_Unconfirmed

UPDATE #AllUnconfirmedEpisodes
SET OutpatientEpisodeBeginDate = NULL
WHERE OutpatientEpisodeBeginDate < InpatientEpisodeEndDate
AND EpisodeTruncated=1

DROP TABLE IF EXISTS #StageUnconfirmedEpisodes
SELECT *
	,CASE WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,InpatientEpisodeEndDate) THEN 'I'
		WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,EpisodeEndDate) THEN 'O'
		ELSE NULL
		END AS ActiveEpisodeSetting --if the episode is active, is the patient inpatient or outpatient
	,CASE WHEN GETDATE() BETWEEN EpisodeBeginDate AND DateAdd(day,1,EpisodeEndDate) THEN 1 ELSE 0 END AS ActiveEpisode
INTO #StageUnconfirmedEpisodes
FROM #AllUnconfirmedEpisodes

/*************************************************************************
Merge confirmed and unconfirmed episodes.
Start with confirmed episodes; if there are gaps in confirmed episodes that are filled by unconfirmed episodes, fill in those gaps.
*************************************************************************/
DROP TABLE IF EXISTS #ConfirmedUnconfirmedTogether
SELECT *
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY EpisodeBeginDate, Confirmed DESC) RN
INTO #ConfirmedUnconfirmedTogether
FROM (	SELECT DISTINCT *, Confirmed=1 FROM #StageConfirmedEpisodes 
		UNION 
		SELECT DISTINCT *, Confirmed=0 FROM #StageUnconfirmedEpisodes 
	 ) a

UPDATE #ConfirmedUnconfirmedTogether
SET EpisodeExtended=0
WHERE EpisodeTruncated=1 AND EpisodeExtended=1

UPDATE #ConfirmedUnconfirmedTogether
SET EpisodeEndDate=DATEADD(Day,DateDiff(day,OutpatientEpisodeBeginDate, EpisodeEndDate),InpatientEpisodeEndDate)
	,OutpatientEpisodeBeginDate=InpatientEpisodeEndDate
	,EpisodeExtended=1
WHERE InpatientEpisodeEndDate>OutpatientEpisodeBeginDate

UPDATE #ConfirmedUnconfirmedTogether
SET OutpatientEpisodeBeginDate=NULL
	,InpatientEpisodeEndDate=EpisodeEndDate
WHERE EpisodeEndDate <InpatientEpisodeEndDate

UPDATE #ConfirmedUnconfirmedTogether
SET OutpatientEpisodeBeginDate=NULL
WHERE EpisodeEndDate<OutpatientEpisodeBeginDate

DROP TABLE IF EXISTS #StageAllEpisodes
SELECT DISTINCT a.MVIPersonSID
	,a.ChecklistID_EpisodeBegin
	,a.EpisodeBeginDate
	,EpisodeEndDate=CAST(a.EpisodeEndDate AS date)
	,a.CommunityCare
	,a.EpisodeBeginSetting
	,InpatientEpisodeEndDate=CAST(a.InpatientEpisodeEndDate AS date)
	,OutpatientEpisodeBeginDate=CAST(a.OutpatientEpisodeBeginDate AS date)
	,a.ActiveEpisode
	,a.ActiveEpisodeSetting
	,a.EpisodeTruncated
	,CASE WHEN a.EpisodeTruncated=1 AND b.Confirmed=0 THEN b.Restart
		ELSE a.TruncateReason END AS TruncateReason
	,a.EpisodeExtended
	,EpisodeRankDesc=ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.EpisodeBeginDate DESC,a.EpisodeEndDate DESC,a.ActiveEpisode DESC)
	,a.EncounterCodes
	,TemplateStart = CASE WHEN a.Confirmed=1 AND a.EncounterCodes LIKE '%COMPACT%' THEN 1 ELSE 0 END
	,ConfirmedStart = a.Confirmed
INTO #StageAllEpisodes
FROM #ConfirmedUnconfirmedTogether a
LEFT JOIN #ConfirmedUnconfirmedTogether b
	ON a.MVIPersonSID=b.MVIPersonSID AND b.RN=a.RN+1


EXEC [Maintenance].[PublishTable] 'COMPACT.Episodes', '#StageAllEpisodes' 
	
EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;


/* =============================================
Code below is modified from Code.COMPACT_ContactHistory.
Pulls all inpatient stays, outpatient encounters, community care encounters, and medication releases 
occuring during the COMPACT act episode of care
============================================= */

--Get encounter-level/medication fill detail
DROP TABLE IF EXISTS #Patients
SELECT a.MVIPersonSID
	,b.PatientPersonSID
	,a.EpisodeBeginDate
	 --for consecutive episodes that share an end/begin date, count encounters that occur on that date in the second episode to avoid double-counting in both
	,CASE WHEN c.MVIPersonSID IS NOT NULL THEN DateAdd(day,-1,a.EpisodeEndDate)
		ELSE a.EpisodeEndDate END AS EpisodeEndDate
	,a.ActiveEpisode
	,a.EpisodeExtended
	,a.EpisodeRankDesc 
INTO #Patients
FROM [COMPACT].[Episodes] as a WITH (NOLOCK)
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] as b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID
LEFT JOIN [COMPACT].[Episodes] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID AND a.EpisodeEndDate=c.EpisodeBeginDate
	AND c.EpisodeRankDesc=a.EpisodeRankDesc+1

/**************************************************************************************************/
/*** Pull all Cerner and VISIT inpatient stays where either the admission or discharge was during the COMPACT episode**/
/**************************************************************************************************/

--inpatient stays 
DROP TABLE IF EXISTS #InpatientStays
SELECT DISTINCT 'Inpatient Stay' AS ContactType
	,a.MVIPersonSID
	,Sta3n_EHR
	,b.Sta6a
	,InpatientEncounterSID AS ContactSID
	,CASE WHEN b.Sta3n_EHR = 200 THEN 'EncounterSID'
		ELSE 'InpatientSID' END ContactSIDType
	,DerivedBedSectionRecordSID
	,CASE WHEN b.Sta3n_EHR = 200 THEN 'BedSectionRecordSID'
		ELSE 'SpecialtyTransferSID' END RecordSIDType
	,AdmitDateTime
	,DischargeDateTime
	,a.EpisodeRankDesc
	,b.BedSectionName
	,ib.ARBillNumber
	,ib.TotalCharge
	,ib.BriefDescription
	,r.ChargeRemoveReason
INTO #InpatientStays
FROM #Patients AS a 
INNER JOIN [Inpatient].[BedSection] as b WITH (NOLOCK) 
	ON a.MVIPersonSID = b.MVIPersonSID 
	AND (CAST(b.AdmitDateTime AS DATE) BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
		OR CAST(b.DischargeDateTime AS DATE) BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate)
LEFT JOIN [IB].[IBAction] ib WITH (NOLOCK)
	ON b.InpatientEncounterSID=ib.InpatientSID
LEFT JOIN [Dim].[IBChargeRemoveReason] r WITH (NOLOCK)
	ON ib.IBChargeRemoveReasonSID=r.IBChargeRemoveReasonSID
AND AdmitDateTime BETWEEN '2023-01-17' AND getdate()

/**************************************************************************************************/
/*** Pull outpatient encounters during the episode  *************/
/**************************************************************************************************/
--VISTA
DROP TABLE IF EXISTS #Outpatient
SELECT TOP 1 WITH TIES
	'Outpatient Encounter' as ContactType
	,a.MVIPersonSID
	,b.Sta3n
	,c.Sta6a
	,b.VisitSID
	,'VisitSID' EncounterSIDType
	,b.VisitDateTime
	,a.EpisodeRankDesc
	,l.LocationName
	,ib.ARBillNumber
	,ib.TotalCharge
	,ib.BriefDescription
	,r.ChargeRemoveReason
INTO #Outpatient
FROM #Patients AS a 
INNER JOIN [Outpat].[Visit] AS b WITH (NOLOCK) 
	ON a.PatientPersonSID = b.PatientSID 
      AND CAST(b.VisitDateTime as date) BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
INNER JOIN [Dim].[Division] AS c WITH (NOLOCK) 
	ON b.InstitutionSID = c.InstitutionSID
LEFT JOIN [Dim].[Location] l WITH (NOLOCK)
	ON b.LocationSID = l.LocationSID
LEFT JOIN [IB].[IBAction] ib WITH (NOLOCK)
	ON b.VisitSID=ib.VisitSID
LEFT JOIN [Dim].[IBChargeRemoveReason] r WITH (NOLOCK)
	ON ib.IBChargeRemoveReasonSID=r.IBChargeRemoveReasonSID
WHERE b.WorkLoadLogicFlag = 'Y'
AND b.VisitDateTime BETWEEN '2023-01-17' AND getdate()
ORDER BY ROW_NUMBER() OVER (PARTITION BY b.VisitSID ORDER BY l.LocationName)

DROP TABLE IF EXISTS #ProcedureCodes
SELECT o.VisitSID
	,LEFT(STRING_AGG(cpt.CPTCode,','),50) AS CPTCodes
INTO #ProcedureCodes
FROM #Outpatient o
INNER JOIN Outpat.VProcedure p WITH (NOLOCK)
	ON o.VisitSID = p.VisitSID
INNER JOIN Lookup.CPT cpt WITH (NOLOCK)
	ON cpt.CPTSID = p.CPTSID 
GROUP BY o.VisitSID

DROP TABLE IF EXISTS #GetProvider_Visit_VistA
SELECT DISTINCT p.VisitSID
	,s.StaffName
INTO #GetProvider_Visit_VistA
FROM [Outpat].[VProvider] p WITH (NOLOCK) 
INNER JOIN [SStaff].[SStaff] s WITH (NOLOCK) 
	ON p.ProviderSID = s.StaffSID
INNER JOIN #Outpatient v
	ON p.VisitSID = v.VisitSID
WHERE p.PrimarySecondary='P'

DROP TABLE IF EXISTS #AddProvider_Visit_VistA
SELECT VisitSID
	,LEFT(STRING_AGG(StaffName,'; ') WITHIN GROUP (ORDER BY StaffName),50) AS StaffName
INTO #AddProvider_Visit_VistA
FROM #GetProvider_Visit_VistA
GROUP BY VisitSID


--CERNER
DROP TABLE IF EXISTS #OutpatientCerner
SELECT DISTINCT
	'Outpatient Encounter' as ContactType
	,c.MVIPersonSID
	,200 as Sta3n
	,ISNULL(s2.Sta6a,s3.DerivedSTA6A) as STA6A
	,s2.EncounterSID
	,'EncounterSID' EncounterSIDType
	,s2.TZDerivedVisitDateTime as VisitDateTime
	,c.EpisodeRankDesc
	,s2.LocationNurseUnit
	,s2.DerivedPersonStaffSID
INTO #OutpatientCerner
FROM  #Patients c 
INNER JOIN [Cerner].[FactUtilizationOutpatient] s2 WITH (NOLOCK) 
	ON c.PatientPersonSID = s2.PersonSID 
     AND cast(s2.TZDerivedVisitDateTime as date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
LEFT JOIN Cerner.FactUtilizationStopCode s3 WITH (NOLOCK) 
	ON s2.EncounterSID = s3.EncounterSID
	AND (s2.EncounterType<>'Recurring' OR CAST(s2.TZDerivedVisitDateTime AS date)=CAST(s3.TZDerivedVisitDateTime AS date))
AND s2.TZDerivedVisitDateTime BETWEEN '2023-01-17' AND getdate()

DROP TABLE IF EXISTS #CernerProcedures
SELECT a.EncounterSID
	,a.VisitDateTime
	,LEFT(STRING_AGG(b.SourceIdentifier,','),50) AS CPTCodes
INTO #CernerProcedures
FROM #OutpatientCerner a
INNER JOIN Cerner.FactUtilizationStopCode b WITH (NOLOCK)
	ON a.EncounterSID = b.EncounterSID
	AND CAST(a.VisitDateTime AS date)=CAST(b.TZDerivedVisitDateTime AS date)
GROUP BY a.EncounterSID, a.VisitDateTime

DROP TABLE IF EXISTS #GetProvider_Visit_Cerner
SELECT DISTINCT p.EncounterSID
	,p.VisitDateTime
	,s.NameFullFormatted
INTO #GetProvider_Visit_Cerner
FROM #OutpatientCerner p WITH (NOLOCK) 
INNER JOIN [Cerner].[FactStaffDemographic] s WITH (NOLOCK) 
	ON p.DerivedPersonStaffSID = s.PersonStaffSID 

DROP TABLE IF EXISTS #AddProvider_Visit_Cerner
SELECT EncounterSID
	,VisitDateTime
	,LEFT(STRING_AGG(NameFullFormatted,', ') WITHIN GROUP (ORDER BY NameFullFormatted),50) AS StaffName
INTO #AddProvider_Visit_Cerner
FROM #GetProvider_Visit_Cerner
GROUP BY EncounterSID, VisitDateTime

--Combine all VA visits
DROP TABLE IF EXISTS #CombineVisits
SELECT a.ContactType
	,a.MVIPersonSID
	,a.EpisodeRankDesc
	,a.Sta3n_EHR
	,a.Sta6a
	,CAST(a.ContactSID AS varchar) AS ContactSID
	,a.ContactSIDType
	,a.EncounterStartDate
	,a.EncounterEndDate
	,a.LocationDetail AS Detail
	,a.StaffName
	,i.COMPACTIndicator AS EncounterCodes
	,CASE WHEN i.COMPACTIndicator LIKE '%COMPACT%' THEN 1 ELSE 0 END AS Template
	,a.CPTCodes_All
	,ARBillNumber
	,TotalCharge
	,BriefDescription
	,ChargeRemoveReason
INTO #CombineVisits
FROM (
	SELECT a.ContactType
		,a.MVIPersonSID
		,a.Sta3n AS Sta3n_EHR
		,a.Sta6a
		,a.VisitSID AS ContactSID
		,a.EncounterSIDType AS ContactSIDType
		,a.VisitDateTime AS EncounterStartDate
		,a.VisitDateTime AS EncounterEndDate
		,a.LocationName AS LocationDetail
		,b.StaffName
		,a.EpisodeRankDesc
		,c.CPTCodes AS CPTCodes_All
		,a.ARBillNumber
		,TotalCharge
		,BriefDescription
		,ChargeRemoveReason
	FROM #Outpatient a
	LEFT JOIN #AddProvider_Visit_VistA b
		ON a.VisitSID = b.VisitSID
	LEFT JOIN #ProcedureCodes c
		ON a.VisitSID = c.VisitSID
	UNION ALL 
	SELECT a.ContactType
		,a.MVIPersonSID
		,a.Sta3n
		,a.Sta6a
		,a.EncounterSID
		,a.EncounterSIDType
		,a.VisitDateTime AS EncounterStartDate
		,a.VisitDateTime AS EncounterEndDate
		,a.LocationNurseUnit
		,b.StaffName
		,a.EpisodeRankDesc
		,c.CPTCodes AS CPTCodes_All
		,ARBillNumber=NULL
		,TotalCharge=NULL
		,BriefDescription=NULL
		,ChargeRemoveReason=NULL
	FROM #OutpatientCerner a
	LEFT JOIN #AddProvider_Visit_Cerner b
		ON a.EncounterSID = b.EncounterSID
		AND a.VisitDateTime = b.VisitDateTime
	LEFT JOIN #CernerProcedures c
		ON a.EncounterSID = c.EncounterSID
		AND a.VisitDateTime = c.VisitDateTime
	UNION ALL
	SELECT ContactType
		,MVIPersonSID
		,Sta3n_EHR
		,Sta6a
		,ContactSID
		,ContactSIDType
		,AdmitDateTime AS EncounterStartDate
		,DischargeDateTime AS EncounterEndDate
		,BedSectionName AS LocationDetail
		,StaffName=NULL
		,EpisodeRankDesc
		,CPTCodes_All=NULL
		,ARBillNumber
		,TotalCharge
		,BriefDescription
		,ChargeRemoveReason
	FROM #InpatientStays
	) a
LEFT JOIN #StringCOMPACTIndicators_Encounter i
	ON a.ContactSID = i.VisitSID

--Community Care encounters associated with COMPACT; bring in others later
DROP TABLE IF EXISTS #CommunityEncounters
--Records with a VisitSID
SELECT DISTINCT ContactType = CONCAT(i.TxSetting, ' Encounter')
	,c.MVIPersonSID
	,StaPa
	,CAST(VisitSID AS varchar) AS VisitSID
	,EncounterSIDType = 'VisitSID'
	,BeginDate
	,DischargeDate=CASE WHEN DischargeDate IS NOT NULL THEN DischargeDate
		WHEN TxSetting='CC Inpatient' THEN NULL
		ELSE BeginDate END
	,HealthFactorType
	,c.EpisodeRankDesc
	,i.TxSetting
	,i.Paid
INTO #CommunityEncounters
FROM #Patients c 
INNER JOIN [COMPACT].[IVC] i WITH (NOLOCK)
	ON c.MVIPersonSID = i.MVIPersonSID
	AND (cast(i.BeginDate as date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
		OR CAST(i.DischargeDate AS date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate)
WHERE VisitSID IS NOT NULL
UNION ALL
--Records with a Notification ID
SELECT DISTINCT ContactType = CONCAT (i.TxSetting, ' Encounter')
	,c.MVIPersonSID
	,StaPa
	,NotificationID
	,EncounterSIDType = 'NotificationID'
	,BeginDate
	,DischargeDate=CASE WHEN DischargeDate IS NOT NULL THEN DischargeDate
		WHEN TxSetting='CC Inpatient' THEN NULL
		ELSE BeginDate END
	,HealthFactorType
	,c.EpisodeRankDesc
	,i.TxSetting
	,i.Paid
FROM #Patients c 
INNER JOIN COMPACT.IVC i WITH (NOLOCK)
	ON c.MVIPersonSID = i.MVIPersonSID
	AND (CAST(i.BeginDate as date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
		OR CAST(i.DischargeDate AS date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate)
WHERE VisitSID IS NULL AND NotificationID IS NOT NULL
UNION ALL
--Records with a Referral ID
SELECT DISTINCT ContactType = CONCAT (i.TxSetting, ' Encounter')
	,c.MVIPersonSID
	,StaPa
	,ReferralID
	,EncounterSIDType = 'ReferralID'
	,BeginDate
	,DischargeDate=CASE WHEN DischargeDate IS NOT NULL THEN DischargeDate
		WHEN TxSetting='CC Inpatient' THEN NULL
		ELSE BeginDate END
	,HealthFactorType
	,c.EpisodeRankDesc
	,i.TxSetting
	,i.Paid
FROM #Patients c 
INNER JOIN COMPACT.IVC i WITH (NOLOCK)
	ON c.MVIPersonSID = i.MVIPersonSID
	AND (cast(i.BeginDate as date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
		OR CAST(i.DischargeDate AS date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate)
WHERE VisitSID IS NULL AND NotificationID IS NULL AND ReferralID IS NOT NULL
UNION ALL
--Records with a Consult ID
SELECT DISTINCT ContactType = CONCAT (i.TxSetting, ' Encounter')
	,c.MVIPersonSID
	,StaPa
	,ConsultID
	,EncounterSIDType = 'ConsultID'
	,BeginDate
	,DischargeDate=CASE WHEN DischargeDate IS NOT NULL THEN DischargeDate
		WHEN TxSetting='CC Inpatient' THEN NULL
		ELSE BeginDate END
	,HealthFactorType
	,c.EpisodeRankDesc
	,i.TxSetting
	,i.Paid
FROM #Patients c 
INNER JOIN [COMPACT].[IVC] i WITH (NOLOCK)
	ON c.MVIPersonSID = i.MVIPersonSID
		AND (cast(i.BeginDate as date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
		OR CAST(i.DischargeDate AS date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate)
WHERE VisitSID IS NULL AND NotificationID IS NULL AND ReferralID IS NULL AND ConsultID IS NOT NULL

/**************************************************************************************************/
/*** pull all medications released to the patient during the episode  *************/
/**************************************************************************************************/
----VISTA
DROP TABLE IF EXISTS #Medications
SELECT 'Medication Fill' as ContactType 
	,a.MVIPersonSID
	,b.Sta3n
	,b.PrescribingSta6a
	,b.RxOutpatFillSID
	,'RxoutpatFillSID' as EncounterSIDType
	,rx.RxNumber
	,b.ReleaseDateTime
	,a.EpisodeRankDesc
	,b.LocalDrugNameWithDose
	,LEFT(s.StaffName,50) AS StaffName
	,ib.ARBillNumber
	,ib.TotalCharge
	,ib.BriefDescription
	,r.ChargeRemoveReason
INTO #Medications
FROM #Patients as a 
INNER JOIN [RxOut].[RxOutpatFill] as b WITH (NOLOCK) 
	ON a.PatientPersonSID = b.PatientSID AND CAST(b.ReleaseDateTime as date) BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
LEFT JOIN [RxOut].[RxOutpat] rx WITH (NOLOCK)
	ON rx.RxOutpatSID=b.RxOutpatSID
LEFT JOIN [SStaff].[SStaff] AS s WITH (NOLOCK)
	ON b.ProviderSID = s.StaffSID
LEFT JOIN [IB].[IBAction] ib WITH (NOLOCK)
	ON b.RxOutpatFillSID=ib.RxOutpatFillSID
LEFT JOIN [Dim].[IBChargeRemoveReason] r WITH (NOLOCK)
	ON ib.IBChargeRemoveReasonSID=r.IBChargeRemoveReasonSID
AND b.ReleaseDateTime BETWEEN '2023-01-17' AND getdate()
UNION ALL
--Cerner
SELECT DISTINCT 'Medication Fill' as ContactType
	,a.MVIPersonSID
	,200 as Sta3n
	,CASE WHEN CAST(s1.STA6A AS VARCHAR) IS NULL OR CAST(s1.STA6A AS VARCHAR) IN ('0','-1','*Missing*','*Unknown at this time*')
		THEN CAST(s1.StaPA AS VARCHAR) ELSE CAST(s1.STA6A AS VARCHAR) END AS STA6A 
	,s1.DispenseHistorySID 
	,'DispenseHistorySID' EncounterSIDType
	,s1.RxNumber
	,s1.TZDerivedCompletedUTCDateTime as InstanceToDateTime 
	,a.EpisodeRankDesc
	,s1.DerivedLabelDescription
	,LEFT(s.NameFullFormatted,50) AS StaffName
	,ARBillNumber=NULL
	,TotalCharge=NULL
	,BriefDescription=NULL
	,ChargeRemoveReason=NULL
FROM #Patients as a 
INNER JOIN [Cerner].[FactPharmacyOutpatientDispensed] s1 WITH (NOLOCK) 
	ON a.MVIPersonSID = s1.MVIPersonSID AND cast(s1.TZDerivedCompletedUTCDateTime as date) BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH (NOLOCK)
	ON s1.DerivedOrderProviderPersonStaffSID = s.PersonStaffSID
AND s1.TZDerivedCompletedUTCDateTime BETWEEN '2023-01-17' AND getdate()

/**************************************************************************************************
 Union all contact into one table 
**************************************************************************************************/

DROP TABLE IF EXISTS #Final
SELECT DISTINCT v.ContactType
	,v.MVIPersonSID
	,v.EpisodeRankDesc
	,v.Sta3n_EHR
	,v.Sta6a
	,CAST(v.ContactSID AS varchar) AS ContactSID
	,v.ContactSIDType
	,RxNumber=NULL
	,v.EncounterStartDate
	,v.EncounterEndDate
	,v.Detail
	,v.StaffName
	,v.EncounterCodes
	,v.Template
	,v.CPTCodes_All
	,COMPACTCategory = ISNULL(can.COMPACTCategory,rv.COMPACTCategory)
	,COMPACTAction = ISNULL(can.COMPACTAction,rv.COMPACTAction)
	,v.TotalCharge
	,v.BriefDescription
	,CASE WHEN v.ChargeRemoveReason='*Missing*' THEN NULL ELSE v.ChargeRemoveReason END AS ChargeRemoveReason
INTO #Final
FROM #CombineVisits v
LEFT JOIN COMPACT.ORB_Copay_Cancel can WITH (NOLOCK)
	ON v.ARBillNumber=can.ARBillNumber
LEFT JOIN COMPACT.ORB_Copay_Review rv WITH (NOLOCK)
	ON v.ARBillNumber=rv.ARBillNumber

UNION ALL

SELECT DISTINCT ContactType
	,MVIPersonSID
	,EpisodeRankDesc
	,CAST(LEFT(StaPa,3) AS int)
	,StaPa
	,VisitSID
	,EncounterSIDType
	,RxNumber=NULL
	,BeginDate
	,DischargeDate
	,TxSetting
	,StaffName=NULL
	,HealthFactorType
	,CASE WHEN HealthFactorType IS NOT NULL THEN 1 ELSE 0 END AS Template
	,CPTCodes_All=NULL
	,COMPACTCategory=NULL
	,COMPACTAction=NULL
	,TotalCharge=NULL
	,BriefDescription=NULL
	,ChargeRemoveReason=CASE WHEN Paid=1 THEN '1720J' ELSE NULL END
FROM #CommunityEncounters

UNION ALL

SELECT DISTINCT ContactType
	,m.MVIPersonSID
	,m.EpisodeRankDesc
	,Sta3n
	,m.PrescribingSta6a
	,CAST(m.RxOutpatFillSID AS varchar) AS RxOutpatFillSID
	,m.EncounterSIDType
	,m.RxNumber
	,m.ReleaseDateTime
	,m.ReleaseDateTime
	,m.LocalDrugNameWithDose
	,m.StaffName
	,EncounterCodes=NULL
	,Template=0
	,CPTCodes_All=NULL
	,COMPACTCategory = ISNULL(can.COMPACTCategory,rv.COMPACTCategory)
	,COMPACTAction = ISNULL(can.COMPACTAction,rv.COMPACTAction)
	,m.TotalCharge
	,m.BriefDescription
	,CASE WHEN m.ChargeRemoveReason='*Missing*' THEN NULL ELSE m.ChargeRemoveReason END AS ChargeRemoveReason
FROM #Medications m
LEFT JOIN COMPACT.ORB_Copay_Cancel can WITH (NOLOCK)
	ON m.ARBillNumber=can.ARBillNumber
LEFT JOIN COMPACT.ORB_Copay_Review rv WITH (NOLOCK)
	ON m.ARBillNumber=rv.ARBillNumber


EXEC [Maintenance].[PublishTable] 'COMPACT.ContactHistory','#Final'
		


EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END