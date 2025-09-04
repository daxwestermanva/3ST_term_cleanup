


/***********************************************************************************************************
Author:	<Claire Hannemann>
Creation date: <6/5/2025>

Code modified from Code.STRM2
Purpose: Create cohort of STORM patients with new opioid prescription in the past 200 days (and no opioid
	     in prior year) who have not had a database risk review at any time

- Cohort should be all patients who started (has a opioid Rx with no opioid Rx in the 365 days prior) an opioid in the past 200 days with more than 5 days supply released.
	a. Consider removing patients with less than 90 days supply and no pills on hand for 45 days or more
	(i.e. IF total days supply across opioid Rx since first release is <90 AND (last release + days supply for most recent release + 45 days) is < today then remove from cohort)

	b. Remove everyone with a DBRR ever

We want 
	(1) the list of everyone beyond a short acute Rx (6-61 days supply within past 200 days), 
	(2) a flag for approaching LTOT (62-89 days supply within past 200 days), and 
	(3) a flag for overdue (90+ days supply within past 200 days)

Get an email if have at least one patient in the cohort; patient is assigned to the provider of their most recent Rx
 
 --Modifications: 

***********************************************************************************************************/
CREATE PROCEDURE [Code].[ORM_NewOpioidNoRiskReview]       

AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_NewOpioidNoRiskReview', @Description = 'Execution of Code.ORM_NewOpioidNoRiskReview SP'

/***********************************************************************
Find all opioid prescriptions in prior 565 days (past 200 + year prior for exclusion)
************************************************************************/
--VistA
DROP TABLE IF EXISTS #OpioidVistA;
SELECT DISTINCT 
	  ao.MVIPersonSID
	, ao.PatientICN
	, rxf.PatientSID
	, rxf.PrescribingSta6a
	, c.ChecklistID
	, rxf.NationalDrugSID
	, rxf.IssueDate
	, rxf.ReleaseDateTime
	, rxf.DaysSupply
	, rxf.FillRemarks
	, rxf.RxOutpatSID
	, rxf.RxStatus
	, rxf.ProviderSID
	, st.StaffName as Prescriber
	, st.PositionTitle
	, st.EmailAddress
	, rxf.DrugNameWithDose
	, rxf.DrugNameWithoutDose
INTO #OpioidVistA 
FROM 
	(
		SELECT 
			ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
			,rxf1.PatientSID
			,rxf1.PrescribingSta6a
			,rxf1.NationalDrugSID
			,rxf1.IssueDate
			,rxf1.ReleaseDateTime
			,rxf1.DaysSupply
			,rxf1.FillRemarks
			,rxf1.RxOutpatSID
			,rxf1.RxStatus
			,rxf1.ProviderSID
			,b.DrugNameWithDose
			,b.DrugNameWithoutDose
		FROM [RxOut].[RxOutpatFill] rxf1 WITH (NOLOCK)
		INNER JOIN [LookUp].[NationalDrug] b WITH (NOLOCK)
			ON rxf1.NationalDrugSID = b.NationalDrugSID 
				AND b.OpioidForPain_Rx =1 
		INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON rxf1.PatientSID = mvi.PatientPersonSID 
		WHERE	
			(CONVERT(DATE,rxf1.ReleaseDateTime) BETWEEN DATEADD(day,-565,cast(getdate() as date)) AND cast(getdate() as date)) 
	) 
	rxf
INNER JOIN [Common].[MasterPatient] ao WITH (NOLOCK)
	 ON rxf.MVIPersonSID = ao.MVIPersonSID
INNER JOIN [ORM].[RiskMitigation] rm WITH (NOLOCK)
     ON rxf.MVIPersonSID = rm.MVIPersonSID
INNER JOIN [SUD].[Cohort] sud WITH (NOLOCK)
     ON rxf.MVIPersonSID = sud.MVIPersonSID
LEFT JOIN [Lookup].[Sta6a] c WITH (NOLOCK) 
	 ON rxf.PrescribingSta6a=c.Sta6a
LEFT JOIN [SStaff].[SStaff] st WITH (NOLOCK) 
	ON rxf.ProviderSID=st.StaffSID
WHERE ao.PossibleTestPatient = 0
	  AND sud.ODPastYear = 0

--Remove the prescriptions with "CCNRx" Fill Remarks.
DELETE FROM #OpioidVistA 
WHERE FillRemarks LIKE '%ccnrx%'

--eRx supposedly contains prescriptions originating outside of the VA
DROP TABLE IF EXISTS #ePrescriptions
SELECT ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
			, rxf1.VistaPatientSID
			,rxf1.[RxOutpatSID]
INTO #ePrescriptions
FROM [RxOut].[eRxHoldingQueue] rxf1 WITH (NOLOCK)
LEFT OUTER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON rxf1.VistaPatientSID = mvi.PatientPersonSID 
WHERE (CONVERT(DATE,rxf1.WrittenDateTime) BETWEEN DATEADD(day,-565,cast(getdate() as date)) AND cast(getdate() as date)) 

--Remove the ePrescriptions
DELETE FROM #OpioidVistA 
WHERE RxOutpatSID IN (SELECT RxOutpatSID FROM #ePrescriptions)

--Cerner
DROP TABLE IF EXISTS #OpioidMillennium;
SELECT DISTINCT
	 ao.MVIPersonSID
	,ao.PatientICN
	,rxf.PersonSID AS PatientSID
	,e.EncounterSTA6A AS PrescribingSta6a
	,c.ChecklistID
	,rxf.DerivedParentItemSID AS NationalDrugSID
	,rxf.TZDerivedOrderUTCDateTime AS IssueDate
	,rxf.TZDerivedCompletedUTCDateTime AS ReleaseDateTime
	,rxf.DaysSupply
	,rxf.MedMgrOrderStatus as RxStatus
	,rxf.DerivedOrderProviderPersonStaffSID as ProviderSID
	,st1.NameFullFormatted as Prescriber
	,st2.ProviderType as PositionTitle
	,st1.Email
	,rxf.DerivedLabelDescription as DrugNameWithDose
	,rxf.PrimaryMnemonic as DrugNameWithoutDose
INTO #OpioidMillennium 
FROM [Cerner].[FactPharmacyOutpatientDispensed]	rxf WITH (NOLOCK) 
INNER JOIN [OrderMill].[PersonOrder] o
	ON rxf.DerivedPersonOrderSID = o.PersonOrderSID
LEFT JOIN [Cerner].[EncMillEncounter] e WITH (NOLOCK) 
	ON o.EncounterSID = e.EncounterSID
INNER JOIN [LookUp].[Drug_VUID] b WITH (NOLOCK) 
	ON rxf.VUID = b.VUID 
	AND b.OpioidForPain_Rx = 1 
INNER JOIN [Common].[MasterPatient] ao WITH (NOLOCK) 
	ON rxf.MVIPersonSID = ao.MVIPersonSID
INNER JOIN [ORM].[RiskMitigation] rm WITH (NOLOCK) 
     ON rxf.MVIPersonSID = rm.MVIPersonSID
INNER JOIN [SUD].[Cohort] sud WITH (NOLOCK) 
     ON rxf.MVIPersonSID = sud.MVIPersonSID
LEFT JOIN [Lookup].[Sta6a] c WITH (NOLOCK) 
	 ON e.EncounterSTA6A=c.Sta6a
LEFT JOIN [Cerner].[FactStaffDemographic] st1 WITH (NOLOCK) 
	 ON rxf.DerivedOrderProviderPersonStaffSID=st1.PersonStaffSID
LEFT JOIN [Cerner].[FactStaffProviderType] st2 WITH (NOLOCK) 
	 ON rxf.DerivedOrderProviderPersonStaffSID=st2.PersonStaffSID
WHERE 1 = 1
	AND (CONVERT(DATE,rxf.TZDerivedCompletedUTCDateTime)  BETWEEN DATEADD(day,-565,cast(getdate() as date)) AND cast(getdate() as date))
	AND sud.ODPastYear = 0

-- Union VistA and Cerner
DROP TABLE IF EXISTS #OpioidAnalgesics;
SELECT 
	MVIPersonSID
	,PatientICN
    ,PatientSID
	,PrescribingSta6a
	,ChecklistID
	,NationalDrugSID
	,IssueDate
	,ReleaseDateTime
	,DaysSupply
	,RxStatus
	,ProviderSID
	,Prescriber
	,PositionTitle
	,EmailAddress
	,DrugNameWithDose
	,DrugNameWithoutDose
INTO #OpioidAnalgesics 
FROM #OpioidVistA
UNION
SELECT 
	MVIPersonSID
	,PatientICN
    ,PatientSID
	,PrescribingSta6a
	,ChecklistID
	,NationalDrugSID
	,IssueDate
	,ReleaseDateTime
	,DaysSupply
	,RxStatus
	,ProviderSID
	,Prescriber
	,PositionTitle
	,Email
	,DrugNameWithDose
	,DrugNameWithoutDose
FROM #OpioidMillennium

/********************************************************************************************************************************
Find all new opioid prescriptions in prior 200 days among patients with no fill in the year prior (with at least 5 days supply)
*********************************************************************************************************************************/
DROP TABLE IF EXISTS #OpioidAnalgesics_Past200days
SELECT MVIPersonSID
	,PatientICN
    ,PatientSID
	,PrescribingSta6a
	,ChecklistID
	,NationalDrugSID
	,IssueDate
	,ReleaseDateTime
	,DaysSupply
	,RxStatus
	,ProviderSID
	,Prescriber
	,PositionTitle
	,EmailAddress
	,DrugNameWithDose
	,DrugNameWithoutDose
	,YearPrior
INTO #OpioidAnalgesics_Past200days
FROM (
		SELECT *
			,DATEADD(year,-1,ReleaseDateTime) as YearPrior
			,ROW_NUMBER() over (PARTITION BY MVIPersonSID ORDER BY ReleaseDateTime) AS RN --grab earliest release date in last 200 days
		FROM #OpioidAnalgesics
		WHERE ReleaseDateTime >= DATEADD(day,-200,cast(getdate() as date)) and ReleaseDateTime <= cast(getdate() as date)-- they are using issue date in VISN 23 - check in about this
			and DaysSupply > 5
	 ) a
WHERE RN=1

DROP TABLE IF EXISTS #OpioidAnalgesics_PriorUse
SELECT MVIPersonSID, max(PriorUse) as PriorUse
INTO #OpioidAnalgesics_PriorUse
FROM (
		SELECT a.*
			,b.ReleaseDateTime as PreviousReleaseDateTime
			,case when b.ReleaseDateTime < a.ReleaseDateTime and b.ReleaseDateTime >= DATEADD(year,-1,a.ReleaseDateTime) then 1 else 0 end as PriorUse
		FROM #OpioidAnalgesics_Past200days a
		LEFT JOIN #OpioidAnalgesics b on a.MVIPersonSID=b.MVIPersonSID and b.DaysSupply > 5
	) a
GROUP BY MVIPersonSID

DROP TABLE IF EXISTS #OpioidAnalgesics_New
SELECT a.*
INTO #OpioidAnalgesics_New
FROM #OpioidAnalgesics_Past200days a
INNER JOIN #OpioidAnalgesics_PriorUse b on a.MVIPersonSID=b.MVIPersonSID
WHERE PriorUse=0

/***********************************************************************
Exclude hospice and humaitarian care
************************************************************************/
DELETE FROM #OpioidAnalgesics_New
WHERE MVIPersonSID in (SELECT DISTINCT MVIPersonSID FROM ORM.HospicePalliativeCare WHERE Hospice = 1)

DELETE FROM #OpioidAnalgesics_New
WHERE MVIPersonSID in (SELECT DISTINCT MVIPersonSID FROM Common.MasterPatient WHERE PriorityGroup NOT IN (1,2,3,4,5,6,7,8) OR PrioritySubGroup IN ('e', 'g'))


/***********************************************************************
Find TIU notes for risk reviews - only want to retain patients who have never had risk review 
************************************************************************/
/*****************TIU Note Titles******************/
DROP TABLE IF EXISTS #TIU_Type1;
SELECT ItemID AS TIUDocumentDefinitionSID
INTO  #TIU_Type1
FROM [LookUp].[ListMember] AS a WITH (NOLOCK) 
WHERE List='ORM_DatabasedReview_TIU'

--VistA
DROP TABLE IF EXISTS #Notes1VistA;
SELECT  
	mvi.MVIPersonSID
	,a1.Referencedatetime
INTO #Notes1VistA
FROM #OpioidAnalgesics_New a
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON a.MVIPersonSID = mvi.MVIPersonSID
INNER JOIN [TIU].[TIUDocument] a1 WITH (NOLOCK)
			ON a1.PatientSID = mvi.PatientPersonSID
INNER JOIN #TIU_Type1 c 
			ON a1.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID

--Cerner
DROP TABLE IF EXISTS #Notes1Cerner;
SELECT a.MVIPersonSID
	,f.TZFormUTCDateTime
INTO #Notes1Cerner
FROM #OpioidAnalgesics_New a
INNER JOIN [Cerner].[FactPowerForm] AS f WITH (NOLOCK)
			ON a.MVIPersonSID=f.MVIPersonSID
INNER JOIN #TIU_Type1 AS c 
			ON f.DCPFormsReferenceSID = c.TIUDocumentDefinitionSID

-- Note entries from copy-paste feature on STORM report
DROP TABLE IF EXISTS #RiskEstimate
SELECT a.MVIPersonSID
		,t1.ReferenceDateTime
INTO #RiskEstimate
FROM #OpioidAnalgesics_New a
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.MVIPersonSID=mvi.MVIPersonSID
INNER JOIN [PDW].[HDAP_NLP_OMHSP] t1 WITH (NOLOCK) 
		ON t1.PatientSID = mvi.PatientPersonSID 
WHERE  t1.Snippet like '%STORM risk estimate%'  
	AND t1.ReferenceDateTime > CAST('2025-02-01' AS datetime2) -- the copy/paste feature was deplyed in early March 2025	
	

/*****************Health Factors******************/
DROP TABLE IF EXISTS #HF_Type1
SELECT ItemID as HealthFactorTypeSID
	,AttributeValue as HealthFactorType
	,MeasureID=12
	,ItemID
INTO #HF_Type1
FROM [LookUp].[ListMember] With(NoLock) 
WHERE Domain IN ('HealthFactorType','PowerForm')
       AND List IN ('ORM_DatabasedReview_HF','ORM_DatabasedReviewHigh_HF','ORM_DatabasedReviewLow_HF',
	   'ORM_DatabasedReviewMedium_HF','ORM_DatabasedReviewVeryHigh_HF')

-- VistA
DROP TABLE IF EXISTS #HF1Vista;  
SELECT 
	ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
	, c.HealthFactorType
	, a1.HealthFactorDateTime
	, c.MeasureID
INTO #HF1Vista
FROM  #OpioidAnalgesics_New a
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.MVIPersonSID=mvi.MVIPersonSID
INNER JOIN [HF].[HealthFactor] a1 WITH (NOLOCK)
		ON mvi.PatientPersonSID = a1.PatientSID
INNER JOIN #HF_Type1 c 
		ON a1.HealthFactorTypeSID = c.HealthFactorTypeSID

--Cerner
DROP TABLE IF EXISTS #HF1Cerner;  
SELECT  
	a.MVIPersonSID
	,c.HealthFactorType
	,f.TZFormUTCDateTime
	,c.MeasureID
INTO #HF1Cerner
FROM #OpioidAnalgesics_New a
INNER JOIN [Cerner].[FactPowerform] AS f WITH (NOLOCK) 
		ON a.MVIPersonSID = f.MVIPersonSID
INNER JOIN #HF_Type1 AS c 
		ON f.DerivedDtaEventCodeValueSID = c.ItemID AND c.HealthFactorType=f.DerivedDtaEventResult


/*****************Union TIU and HFs******************/
DROP TABLE IF EXISTS #HF_TIU_Union
SELECT MVIPersonSID
	,MAX(ReferenceDateTime) as ReferenceDateTime
INTO #HF_TIU_Union
FROM (
		SELECT MVIPersonSID, ReferenceDateTime
		FROM #Notes1VistA
		UNION
		SELECT MVIPersonSID, TZFormUTCDateTime
		FROM #Notes1Cerner
		UNION
		SELECT MVIPersonSID, ReferenceDateTime
		FROM #RiskEstimate
		UNION
		SELECT MVIPersonSID, HealthFactorDateTime
		FROM #HF1Vista
		UNION
		SELECT MVIPersonSID, TZFormUTCDateTime
		FROM #HF1Cerner
	) a
GROUP BY MVIPersonSID

--Delete from cohort all patients who have had risk review 
DELETE FROM #OpioidAnalgesics_New
WHERE MVIPersonSID in (select distinct MVIPersonSID from #HF_TIU_Union)

/***********************************************************************
Find days supply of pills per person and days since last pill on hand
Drop from cohort if patients have less than 90 days supply AND no pills on hand for at least 45 days
************************************************************************/
DROP TABLE IF EXISTS #OpioidAnalgesics_New_AllMeds
SELECT a.*
INTO #OpioidAnalgesics_New_AllMeds
FROM #OpioidAnalgesics a
INNER JOIN #OpioidAnalgesics_New b on a.MVIPersonSID=b.MVIPersonSID
WHERE a.ReleaseDateTime >= DATEADD(day,-200,cast(getdate() as date)) and a.ReleaseDateTime <= cast(getdate() as date)

--Calculate days supply of meds in past 200 days (may be somewhat of overestimate since not accounting for overlap in prescriptions)
DROP TABLE IF EXISTS #OpioidAnalgesics_New_TotalDaysSupply
SELECT MVIPersonSID	
	,SUM(DaysSupply) as TotalDaysSupply
INTO #OpioidAnalgesics_New_TotalDaysSupply
FROM #OpioidAnalgesics_New_AllMeds
GROUP BY MVIPersonSID

--Calculate days since most recent release
DROP TABLE IF EXISTS #OpioidAnalgesics_New_MostRecentRelease
SELECT *
	,DATEDIFF(day,ReleaseDateTime,cast(getdate() as date)) as DaysSinceLastRelease
INTO #OpioidAnalgesics_New_MostRecentRelease
FROM (
		SELECT *
			,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ReleaseDateTime DESC) AS RN
		FROM #OpioidAnalgesics_New_AllMeds
	 ) a
WHERE RN=1

--Combine 
DROP TABLE IF EXISTS #OpioidAnalgesics_New2
SELECT a.MVIPersonSID
	,a.ReleaseDateTime as EarliestReleaseDate
	,c.ReleaseDateTime as MostRecentReleaseDate
	,c.ChecklistID
	,c.ProviderSID 
	,c.Prescriber as MostRecentPrescriber
	,c.PositionTitle as MostRecentPrescriber_PositionTitle
	,c.EmailAddress as MostRecentPrescriber_EmailAddress
	,c.DrugNameWithoutDose as MostRecentDrugNameWithoutDose
	,c.DaysSupply as MostRecentDaysSupply
	,c.IssueDate as MostRecentIssueDate
	,c.RxStatus as MostRecentRxStatus
	,b.TotalDaysSupply
INTO #OpioidAnalgesics_New2
FROM #OpioidAnalgesics_New a
INNER JOIN #OpioidAnalgesics_New_TotalDaysSupply b on a.MVIPersonSID=b.MVIPersonSID
INNER JOIN #OpioidAnalgesics_New_MostRecentRelease c on a.MVIPersonSID=c.MVIPersonSID
WHERE b.TotalDaysSupply >= 90 or c.DaysSinceLastRelease < 45


/***********************************************************************
Create staging table and drop non-VA prescribers 
To display:
Patient info
Prescriber of most recent med
Most recent medication details and: 
Date of first Rx/release, 
Most recent Rx – date 
Pills on hand:  “Yes until date (most recent Rx date plus most recent Rx day supply)” or “None for X days (today minus (most recent Rx date plus most recent Rx day supply)”
Total days supply across all Rx and providers since first release:  Categorize as (1) 1-61 days, (2) 62-90 days (yellow), (3) 90+ days.   
Note if UDS or PDMP or informed consent is also missing

************************************************************************/
DROP TABLE IF EXISTS #Staging
SELECT DISTINCT 
	 b.MVIPersonSID
	,b.PatientICN
	,b.PatientName
	,b.LastFour
	,c.VISN
	,c.ChecklistID
    ,c.Facility
	,a.ProviderSID
	,a.MostRecentPrescriber
	,a.MostRecentPrescriber_PositionTitle
	,a.MostRecentPrescriber_EmailAddress
	,a.MostRecentDrugNameWithoutDose
	,a.MostRecentDaysSupply
	,cast(a.MostRecentIssueDate as date) as MostRecentIssueDate
	,cast(a.MostRecentReleaseDate as date) as MostRecentReleaseDate
	,cast(a.EarliestReleaseDate as date) as EarliestReleaseDate
	,DATEDIFF(day,a.MostRecentReleaseDate,getdate()) as DaysOld
	,a.MostRecentRxStatus
	,PillsOnHand_Count = MostRecentDaysSupply - DATEDIFF(day,a.MostRecentReleaseDate,getdate())
	,PillsOnHand_Date = DATEADD(day,a.MostRecentDaysSupply,cast(a.MostRecentReleaseDate as date))
	,a.TotalDaysSupply as TotalDaysSupplyInPast200Days
INTO #Staging
FROM #OpioidAnalgesics_New2 a
INNER JOIN Common.MasterPatient b on a.mvipersonsid=b.mvipersonsid
INNER JOIN lookup.checklistid c on a.checklistid=c.checklistid

--Delete non-VA prescribers
DELETE FROM #Staging
WHERE MostRecentPrescriber_PositionTitle='NON-VA PROVIDER'

EXEC [Maintenance].[PublishTable] 'ORM.NewOpioidNoRiskReview', '#Staging'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END