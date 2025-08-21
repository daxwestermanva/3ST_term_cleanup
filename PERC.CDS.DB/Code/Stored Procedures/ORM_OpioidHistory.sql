

/************************** Cerner Overlay Comments **************************/
--dispense quantity and days supply look suspicious. will need to test with real data.

--does rxo orderstatus update? Aligning with Present.Meds when determining
-- 'Active' status but will need to validate with real data.
/*****************************************************************************/

-- =============================================
-- Author:		Susana Martins
-- Create date: 2018-03-06
-- Description: Pull in Opioid History in past year for all patients
-- Modifications:
	-- 2018/06/07 - Jason Bacani - Removed hard coded database references
	-- 2018/09 - Pooja Sohoni - added active column and logic
	-- 20191226 - RAS - Changed Qty to QtyNumeric in case statement for MEDailyDose_CDC to correct datatype error
	-- 20200501 - RAS - Split up queries to make testing faster and easier. Added logging.
						--Replaced join to LookUp.ChecklistID with join to LookUp.Sta6a.  
						--Added OpioidOnHand flag. Updated morphine equivalence join to use new table and changed to left instead of inner join.
	-- 20200810 - RAS - Added MVIPersonSID to final table (needed in ORM_Cohort)
	-- 20200904 - RAS - Added MostRecentFill logic to create flag for downstream use
						-- Added join for cases where RxOutpat NationalDrugSID = -1 (these were being pulled in via fill data in ORM_Cohort)
	-- 20200918 - CLB - Added Sta6a for downstream use in ORM.PatientDetails
	-- 20200930 - PS  - New definition for active med, pulling new fields in for downstream purposes
	-- 20201022 - CLB - Branched for _VM code
	-- 20201103 - RAS - Replaced SourceEHR logic with Sta3n (Sta3n=200=Millenium data)
	-- 20201110 - CLB - Added NationalDrugSID back in as per Lookup.NationalDrug updates
	-- 20201210 - PS  - Refinement of Cerner data pulls, including fills w/o order
	-- 20200209 - SM -	Replaced [PrescriptionPersonOrderSID] with DerivedPersonOrderSID and replaced [DispenseDateTime] with CompletedDateTime
	-- 20210518 - JEB - Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
	-- 20210716	- JEB - Enclave Refactoring - Counts confirmed
	-- 20210811 - AMN - Refined Cerner data pull
	-- 20210819	- AMN - added to cerner pull to ensure only one row is queried when there is both a child and parent row. updated orderstatus logic for cerner
	-- 20210831 - RAS - For #DaysSupply - removed OpioidOnHand=1 because we need the sum of days supply for any fill, not just those with pills on hand or active, 
						-- to determine if the patient had > 90 days supply in the past year (i.e., ChronicOpioid).  When used downstream, may need to filter by
						-- the active opioid cohort in order to get correct patients with ACTIVE CHRONIC use.
	-- 20210924	- AMN - updated cerner orders section to use field names from newest millcds code	
	-- 20211115 - AMN - updated order id field name for millennium dispensed section to match most recent fact code
	-- 20220504 - RAS - Switched one Cerner join to use LookUp.VUID (for #MillFill), but #MillOrd does not have VUID in source. Need to review.
	-- 20220526 - RAS - Removed #MillOrd section per conversation with AMN and SM. More comments below re: plans for incorporating more pharmacy
					--	as it can be validated in MillCDS code.
	-- 20220622 - AMN - updated cerner field CompletedDateTime to use TZCompletedDateTime and OrderDateTime to OrderUTCDateTime to match latest code
 --  20221122 - AER - Updated day supply calcuation to include only medication released to the patient 
 -- 20250204  - TG - Changing the definition of LTOT (ChronicOpioid) to 90 days supply in the past 180 days.
-- =============================================

CREATE PROCEDURE [Code].[ORM_OpioidHistory]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_OpioidHistory','Execution of Code.ORM_OpioidHistory SP'

/******************************* Vista data *******************************/
--identify opioids 'for pain' fills in past year and computing MEDD
DROP TABLE IF EXISTS #Vista
SELECT DISTINCT 
	rxo.PatientSID
	,mvi.MVIPersonSID
	,ISNULL(ch.ChecklistID,rxo.Sta3n) AS ChecklistID
	,rxo.IssueDate
	,rxo.ProviderSID
	,stf.StaffName
	,rxfill.ReleaseDateTime
	,rxfill.DaysSupply
	,rxfill.Qty
	,rxo.RxOutpatSID
	,rxo.RxStatus
	,CASE 
		WHEN rxo.RxStatus IN ('HOLD','SUSPENDED','ACTIVE','PROVIDER HOLD') THEN 1 
		ELSE 0 
		END AS ActiveRxStatusVM --Active status only for VM overlay
	,nd.NationalDrugSID
	,nd.VUID
	,nd.DrugNameWithDose
	,nd.DrugNameWithoutDose
	,CASE 
		WHEN rxfill.ReleaseDateTime IS NULL THEN 0  --CLB: was getting an adding to datetime2 overflow issue that this seemed to resolve
		WHEN DATEADD(DAY, rxfill.Dayssupply,rxfill.ReleaseDateTime) >= CAST(GETDATE() AS DATE) THEN 1 
		ELSE 0 
		END AS OpioidOnHand
	,CASE WHEN me.Opioid NOT LIKE '%Tramadol%' THEN 1 ELSE 0 END AS NonTramadol
	,me.LongActing
	,rxo.Sta3n
INTO #Vista
FROM [RxOut].[RxOutpat] rxo WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON rxo.PatientSID = mvi.PatientPersonSID 
LEFT JOIN [RxOut].[RxOutpatFill] rxfill WITH (NOLOCK) ON
	rxo.RxOutpatSID = rxfill.RxOutpatSID --There are active prescriptions without any fill data. Still include them in final table.
INNER JOIN [LookUp].[NationalDrug] nd WITH (NOLOCK) ON rxo.NationalDrugSID = nd.NationalDrugSID
LEFT JOIN [LookUp].[Sta6a] ch WITH (NOLOCK)	ON ch.Sta6a=rxo.Sta6a
LEFT JOIN [SStaff].[SStaff] stf WITH (NOLOCK) ON stf.StaffSID=rxo.ProviderSID
LEFT JOIN [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] me WITH (NOLOCK) ON nd.NationalDrugSID = me.NationalDrugSID
WHERE nd.OpioidForPain_Rx = 1 
	AND rxo.Sta3n <> 200 --filter out Cerner 
	AND rxo.RxStatus NOT IN ('DELETED','NON-VERIFIED')
	AND (
		rxo.IssueDate >= DATEADD(DAY, -366, CAST(GETDATE() AS DATE))
		OR rxfill.ReleaseDateTime >= DATEADD(DAY, -366, CAST(GETDATE() AS DATE))
		)

/******************************* Millennium data *******************************/
-- Opioid for pain fills
DROP TABLE IF EXISTS #MillFill;
SELECT DISTINCT 
	rxfill.PersonSID as PatientSID
	,rxfill.MVIPersonSID
	,rxfill.StaPA as ChecklistID
	,rxfill.DerivedOrderUTCDateTime as IssueDate			
	,rxfill.DerivedOrderProviderPersonStaffSID as ProviderSID
	,pd.NameFullFormatted as StaffName
	,rxfill.TZDerivedCompletedUTCDateTime as ReleaseDateTime
	,rxfill.DaysSupply
	,CAST(rxfill.DerivedDispenseQuantity as int) as Qty
	,rxfill.MedMgrPersonOrderSID
	,rxfill.PrescriptionPersonOrderSID
	,rxfill.DerivedPersonOrderSID as RxOutpatSID
	,rxfill.PrescriptionOrderStatus as RxStatus
	,CASE 
		WHEN rxfill.RxActiveFlag=1 THEN 1 
		ELSE 0 
		END AS ActiveRxStatusVM --Active status only for VM overlay
	,rxfill.RxActiveFlag
	,rxfill.DerivedParentItemSID as NationalDrugSID
	,rxfill.VUID
	,lv.DrugNameWithDose --upper(rxfill.LabelDescription) as DrugNameWithDose -- Drug name with dose is used in MEDD calc, so changed this source to ND to be consistent with VistA names
	,lv.DrugNameWithoutDose --upper(rxfill.PrimaryMnemonic) as DrugNameWithoutDose	-- Drug name with dose is used in MEDD calc, so changed this source to ND to be consistent with VistA names
	,CASE WHEN DATEADD(DAY, rxfill.Dayssupply, rxfill.TZDerivedCompletedUTCDateTime) >= CAST(GetDate() AS DATE) THEN 1 ELSE 0 END as OpioidOnHand
	,CASE WHEN rxfill.PrimaryMnemonic NOT LIKE '%tramadol%' THEN 1 ELSE 0 END AS NonTramadol
	,me.LongActing
	,Sta3n = 200
INTO #MillFill
FROM [Cerner].[FactPharmacyOutpatientDispensed] rxfill WITH(NOLOCK)
INNER JOIN [LookUp].[Drug_VUID] lv WITH(NOLOCK) 
	ON lv.VUID = rxfill.VUID
	AND lv.OpioidForPain_Rx = 1
LEFT JOIN [Cerner].[FactStaffDemographic] pd WITH(NOLOCK) ON rxfill.DerivedOrderProviderPersonStaffSID = pd.PersonStaffSID
LEFT JOIN (
	SELECT VUID
		,MAX(LongActing) AS LongActing -- table is at NationalDrugSID level, so need group by for unique VUID
	FROM [LookUp].[MorphineEquiv_Outpatient_OpioidforPain]	WITH(NOLOCK)
	GROUP BY VUID
	) me ON lv.VUID = me.VUID
WHERE rxfill.DerivedOrderUTCDateTime >= DATEADD(DAY, -366, CAST(GETDATE() as DATE))
	OR rxfill.TZDerivedCompletedUTCDateTime >= DATEADD(DAY, -366, CAST(GETDATE() as DATE))
ORDER BY RxOutpatSID
;

---- Opioid for pain orders without an associated fill
-- COMMENTED OUT 2022-05-26 PER CONVERSATION WITH MILLCDS TEAM -- GROUPINGS OF NON-FILLED RX IS NOT RELIABLE
	-- FOR JULY 2022 RELEASE WE WILL LOOK AT ADDING RECORDS FROM [FactPharmacyOutpatientOrder] THAT
	-- CAN HAVE A VUID DUE TO BEING PARTIALLY THROUGH PHARMACY WORKFLOW (BUT NOT IN DISPENSED TABLE)
--DROP TABLE IF EXISTS #MillOrd;
--SELECT DISTINCT 
--	rxo.PersonSID as PatientSID
--	,rxo.MVIPersonSID
--	,rxo.StaPA as ChecklistID
--	,rxo.OrderDateTime as IssueDate			
--	,rxo.OrderProviderPersonStaffSID as ProviderSID
--	,pd.NameFullFormatted as StaffName
--	,CAST(NULL AS DateTime2) as ReleaseDateTime
--	,NULL AS DaysSupply
--	,NULL AS Qty
--	,COALESCE(rxo.MedMgrPersonOrderSID,rxo.PrescriptionPersonOrderSID) as RxOutpatSID
--	,rxo.PrescriptionOrderStatus
--	,rxo.RxActiveFlag 
--	,rxo.ParentItemSID as NationalDrugSID
--	,nd.VUID
--	,nd.DrugNameWithDose	--upper(rxo.DerivedDrugNameWithDose) as DrugNameWithDose -- Drug name with dose is used in MEDD calc, so changed this source to ND to be consistent with VistA names
--	,nd.DrugNameWithoutDose	--upper(rxo.PrimaryMnemonic) as DrugNameWithoutDose		 -- Drug name with dose is used in MEDD calc, so changed this source to ND to be consistent with VistA names
--	,0 as OpioidOnHand
--	,CASE WHEN rxo.PrimaryMnemonic NOT LIKE '%tramadol%' THEN 1 ELSE 0 END AS NonTramadol
--	,me.LongActing
--	,Sta3n = 200
--INTO #MillOrd
--FROM [Cerner].[FactPharmacyOutpatientOrder] rxo WITH(NOLOCK)
--INNER JOIN [LookUp].[NationalDrug] nd WITH(NOLOCK) ON 
--	rxo.ParentItemSID = nd.NationalDrugSID
--	AND nd.OpioidForPain_Rx = 1		
--	AND nd.Sta3n = 200
--LEFT JOIN [Cerner].[FactStaffDemographic] pd WITH(NOLOCK) ON rxo.OrderProviderPersonStaffSID = pd.PersonStaffSID
--LEFT JOIN (
--	SELECT VUID
--		,MAX(LongActing) AS LongActing -- table is at NationalDrugSID level, so need group by for unique VUID
--	FROM [LookUp].[MorphineEquiv_Outpatient_OpioidforPain]	WITH(NOLOCK)
--	GROUP BY VUID
--	) me ON nd.VUID = me.VUID
--WHERE rxo.MedMgrPersonOrderSID NOT IN (SELECT MedMgrPersonOrderSID FROM #MillFill)
--	AND rxo.PrescriptionPersonOrderSID NOT IN (SELECT PrescriptionPersonOrderSID FROM #MillFill)
--	AND rxo.OrderDateTime >= DATEADD(DAY, -366, CAST(GETDATE() as DATE))
--ORDER BY RxOutpatSID
--;

/******************************* Combine all sources *******************************/
DROP TABLE IF EXISTS #AllSources
SELECT PatientSID
	,MVIPersonSID
	,ChecklistID
	,IssueDate
	,ProviderSID
	,StaffName
	,ReleaseDateTime
	,DaysSupply
	,Qty
	,RxOutpatSID
	,RxStatus 
	,ActiveRxStatusVM
	,NationalDrugSID
	,Sta3n
	,VUID
	,DrugNameWithDose
	,DrugNameWithoutDose
	,OpioidOnHand
	,NonTramadol
	,LongActing
	,Active = CASE WHEN (OpioidOnHand = 1 OR RxStatus IN ('HOLD','SUSPENDED','ACTIVE','PROVIDER HOLD')) THEN 1 ELSE 0 END --OpioidOnHand OR Active Status
INTO #AllSources
FROM #Vista
UNION ALL
SELECT PatientSID
	,MVIPersonSID
	,ChecklistID
	,IssueDate
	,ProviderSID
	,StaffName
	,ReleaseDateTime
	,DaysSupply
	,CAST(Qty as varchar) as Qty
	,RxOutpatSID
	,RxStatus
	,ActiveRxStatusVM
	,NationalDrugSID
	,Sta3n
	,VUID
	,DrugNameWithDose
	,DrugNameWithoutDose
	,OpioidOnHand
	,NonTramadol
	,LongActing
	,Active = CASE WHEN OpioidOnHand = 1 OR RxActiveFlag = 1 THEN 1 ELSE 0 END --OpioidOnHand OR Active Status
FROM #MillFill
--UNION ALL
--SELECT PatientSID
--	,MVIPersonSID
--	,ChecklistID
--	,IssueDate
--	,ProviderSID
--	,StaffName
--	,ReleaseDateTime
--	,DaysSupply
--	,CAST(Qty as varchar) as Qty
--	,RxOutpatSID
--	,RxStatus
--	,NationalDrugSID
--	,Sta3n
--	,VUID
--	,DrugNameWithDose
--	,DrugNameWithoutDose
--	,OpioidOnHand
--	,NonTramadol
--	,LongActing
--FROM #MillOrd



DROP TABLE IF EXISTS #DaysSupply
SELECT MVIPersonSID
	,DrugNameWithoutDose
	,SUM(DaysSupply) as DSMedSum
INTO #DaysSupply
FROM #AllSources
where ReleaseDateTime >= CAST(DATEADD(DAY, -180, GETDATE()) AS DATETIME2(0))
GROUP BY MVIPersonSID
	,DrugNameWithoutDose


DROP TABLE IF EXISTS #Final
SELECT a.PatientSID AS PatientPersonSID
	,a.MVIPersonSID
	,a.ChecklistID
	,a.IssueDate
	,a.ProviderSID
	,a.StaffName
	,a.ReleaseDateTime
	,a.DaysSupply
	,a.Qty
	,a.RxOutpatSID
	,a.RxStatus
	,a.ActiveRxStatusVM
	,a.NationalDrugSID
	,a.Sta3n
	,a.VUID
	,a.DrugNameWithDose
	,a.DrugNameWithoutDose
	,CASE WHEN a.NonTramadol = 1 THEN 1 ELSE 0 END AS NonTramadol
	,CASE WHEN a.LongActing = 1 THEN 1 ELSE 0 END AS LongActing
	,CASE WHEN isnull(ds.DSMedSum,0) >= 90 THEN 1 ELSE 0 END AS ChronicOpioid
	,CASE WHEN ISNULL(a.LongActing,0) = 0 AND isnull(ds.DSMedSum,0) >= 90 THEN 1 ELSE 0 END ChronicShortActing
    ,CASE WHEN ISNULL(a.LongActing,0) = 0 AND isnull(ds.DSMedSum,0) < 90 THEN 1 ELSE 0 END NonChronicShortActing
	,CASE WHEN ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID,VUID ORDER BY ReleaseDateTime DESC) = 1 THEN 1 ELSE 0 END MostRecentFill
	,a.OpioidOnHand
	,a.Active
INTO #Final
FROM #AllSources a
LEFT JOIN #DaysSupply AS ds ON 
	ds.MVIPersonSID=a.MVIPersonSID
	AND ds.DrugNameWithoutDose = a.DrugNameWithoutDose


-- Publish table
EXEC [Maintenance].[PublishTable] 'ORM.OpioidHistory', '#Final'

EXEC [Log].[ExecutionEnd]

END