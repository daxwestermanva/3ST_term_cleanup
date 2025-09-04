/********************************************************************************************************************
DESCRIPTION: Finds all active medications from rxoutpat.
AUTHOR:   Rebecca Stephens
CREATED:  2017-09-11
UPDATE:
 YYYY-MM-DD [INIT] [CHANGE DESCRIPTION]
 10/02/2018 SG  Removed DROP/Create for permanent tables and cleanup the temp tables at the end
 12/05/2018 DH  Optimized query and refactored to use new Maintenance.PublishTable sproc.
 04/20/2020 RAS  Changed ND.* in staging table to list explicit columns from LookUp.NationalDrug.  Added logging.
 09/28/2020 PS  Adding in pills on hand as part of the definition of an active medication. Adding checklistID
 10/27/2020 RAS  Added section for Cerner Millenium data
 02/09/2021 SM  Replaced DispenseFateTime with CompletedDateTime and [PrescriptionPersonOrderSID] with [DerivedPersonOrderSID]
 2021/05/18 JEB     Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
 2021/07/21 AI  Enclave Refactoring - Counts confirmed
 2021/08/16 AMN  Refined cerner millennium data pull
 2021/08/23 AMN  added to cerner pull to ensure only one row is queried when there is both a child and parent row. updated orderstatus logic for cerner
 2021/09/24 AMN  updated field names in mill order section to align with newest version of millcds code
 2021/10/15 AMN  added comments to mill section, fixed OrderStatus source field used in #MillFill, eliminated date restriction from #millorder section because its already included in the Fact table creation logic
 2021/11/15 AMN  updated order id field name for millennium dispensed section to match most recent fact code
 2022/03/17 SM  updating code to use VUID as primary key for Millennium data
 2022/03/22 SM  updates in Mill section per validation comments from AN
 2022/04/28 RAS  Updates to VistA section for efficiency (removed unnecessary distincts, moved MVIPersonSID join
      to 1 query) and moved Sta6a/StaPa logic to final staging table (with corrections).
      Changes reduced run time from > 4 min to < 2.5 min.
 2022/05/03 RAS  Added suggestion for #MillFill section, but kept original code as well. Added VUIDFlag criteria
      for join to NationalDrug in creating #MedicationsStagingMill.  To discuss with Susana and Alyssa on 5/4.
 2022/05/04 RAS  In #MillFill section, o.STA6A instead of d.STA6A (more consistent across MedMgrPersonOrderSID).
      Also tried COALESCE(o.STA6A,d.STA6A), but not much difference (still a lot of nulls, but just more
      duplicated MedMgrPersonOrderSID).
      Switched VUID join to new table LookUp.Drug_VUID
 2022/05/18 RAS  Updated #MillFill section with suggestions from AMN - using most recent fill for VUID and STA6A
 2022/06/22  AMN  updated cerner field CompletedDateTime to use TZCompletedDateTime and OrderDateTime to OrderUTCDateTime to match latest code
 2023/09/11  AER  Adding last release for each rxoutpatsid
  2024/9/19   AER   OTP logic for opioid agonists
  2025/8/05   SM Correcting OH data extraction to mean active prescription status or pills oh hand
********************************************************************************************************************/
CREATE PROCEDURE [Code].[Present_Medications]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Present_Medications','Execution of SP Code.Present_Medications'

-----------------------------------------------------------------------------------------
-- VistA
-- Active RX
-- Pills on Hand
-----------------------------------------------------------------------------------------
/**
 Active RX - past 366 days
 **/
DROP TABLE IF EXISTS #ActiveMeds
SELECT
 rxo.PatientSID,
 rxo.NationalDrugSID,
 rxo.RxOutpatSID,
 rxo.ProviderSID,
 rxo.Sta3n,
 rxo.Sta6a,
 rxo.IssueDate,
 rxo.RxStatus,
 DrugStatus = 'ActiveRx'
INTO #ActiveMeds
FROM[RxOut].[RxOutpat] AS rxo WITH(NOLOCK)
WHERE 1=1
AND rxo.RxStatus IN ('HOLD','SUSPENDED','ACTIVE','PROVIDER HOLD') 
AND rxo.IssueDate >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE));

/**
    Identify all non-active prescriptions where the patient still has pills on hand. 
    This is determined by calculating whether the release date plus days supply is a future date from today.
    Dispensed pills on hand - past 580 days
  **/
DROP TABLE IF EXISTS #PillsOnHand
SELECT DISTINCT -- distinct required because multiple RxOutpatFillSID per RxOutpatSID
          rxo.PatientSID,
          rxo.NationalDrugSID,
          rxo.RxOutpatSID,
          rxo.ProviderSID,
          rxo.Sta3n,
          rxo.Sta6a,
          rxo.IssueDate,
          rxo.RxStatus,
          DrugStatus = 'PillsOnHand'
INTO  #PillsOnHand
FROM  [RxOut].[RxOutpat] AS rxo WITH(NOLOCK)
INNER JOIN [RxOut].[RxOutpatFill] AS fill WITH(NOLOCK)
  ON rxo.RxOutpatSID = fill.RxOutpatSID
WHERE 1=1
 AND rxo.RxStatus NOT IN ('HOLD','SUSPENDED','ACTIVE','PROVIDER HOLD') -- exclude those included in #ActiveMeds
 AND DATEADD(   DAY, fill.DaysSupply,fill.ReleaseDateTime) >= CAST(GETDATE() AS DATE) -- Assume this is to make sure we can identify prescriptions with potential pills on hand in past year (check with AR)
 AND  rxo.IssueDate >= DATEADD(DAY,-540,CAST(GETDATE() AS DATE));

-- Union the active medications and the pills on hand to a single table.
DROP TABLE IF EXISTS #VistaMeds

SELECT
 PatientSID,
 NationalDrugSID,
 RxOutpatSID,
 ProviderSID,
 Sta3n,
 Sta6a,
 IssueDate,
 RxStatus,
 DrugStatus
INTO
 #VistaMeds
FROM
#ActiveMeds
UNION ALL
SELECT
 PatientSID,
 NationalDrugSID,
 RxOutpatSID,
 ProviderSID,
 Sta3n,
 Sta6a,
 IssueDate,
 RxStatus,
 DrugStatus
FROM
#PillsOnHand;

DROP TABLE IF EXISTS #VistaMedsRelease
SELECT
 a.*,
 max(ReleaseDateTime) OVER (PARTITION BY a.rxoutpatsid) AS LastReleaseDateTime
INTO #VistaMedsRelease
FROM #VistaMeds AS a
LEFT OUTER JOIN rxout.rxoutpatfill AS b ON a.RxOutpatSID = b.RxOutpatSID

CREATE CLUSTERED INDEX CIX_ActiveMed
  ON #VistaMeds(RxOutpatSID)

DROP TABLE #ActiveMeds
DROP TABLE #PillsOnHand

-- Using the above data set, further enrich it by joining it to additional tables to prepare it for publishing.
DROP TABLE IF EXISTS #MedicationsStagingVistA 
SELECT
 rxo.RxOutpatSID,
 rxo.PatientSID,
 m.MVIPersonSID,
 DerivedPersonOrderSID = NULL, -- to support validation with V1
 MedMgrPersonOrderSID = NULL, -- placeholder Cerner prescription ID in pharmacy workflow
 rxo.Sta3n,
 Sta6a = ISNULL(st6.Sta6a,rxo.Sta3n),
 StaPa = ISNULL(st6.StaPa,st3.StaPa),
 ChecklistID = ISNULL(st6.ChecklistID,st3.ChecklistID),
 Sta6a_rxo = rxo.Sta6a, -- for validation
 rxo.IssueDate,
 LastReleaseDateTime,
 rxo.ProviderSID AS PrescriberSID,
 s.StaffName AS PrescriberName,
 rxo.RxStatus,
 rxo.DrugStatus,
 DrugSource = 'VistA',
 rxo.NationalDrugSID,
 ND.VUID,
 ND.DrugNameWithDose,
 ND.DrugNameWithoutDose,
 ND.DrugNameWithoutDoseSiD,
 ND.CSFederalSchedule,
 ND.PrimaryDrugClassCode,
 ND.StrengthNumeric,
 ND.DosageForm,
 ND.AchAntiHist_Rx,
 ND.AChAD_Rx,
 ND.AChALL_Rx,
 ND.AlcoholPharmacotherapy_Rx,
 ND.AlcoholPharmacotherapy_notop_Rx,
 ND.Alprazolam_Rx,
 ND.Antidepressant_Rx,
 ND.SSRI_SNRI_Rx,
 ND.Antipsychotic_Geri_Rx,
 ND.Antipsychotic_Rx,
 ND.AntipsychoticSecondGen_Rx,
 ND.Anxiolytics_Rx,
 ND.Benzodiazepine_Rx,
 ND.Bowel_Rx,
 ND.Clonazepam_Rx,
 ND.Lorazepam_Rx,
 ND.Mirtazapine_Rx,
 ND.MPRCalculated_Rx,
 ND.MoodStabilizer_Rx,
 ND.MoodStabilizer_GE3_Rx,
 ND.NaltrexoneINJ_Rx,
 ND.Olanzapine_Rx,
 ND.Opioid_Rx,
 ND.OpioidAgonist_Rx,
 ND.PainAdjAnticonvulsant_Rx,
 ND.PainAdjTCA_Rx,
 ND.PainAdjSNRI_Rx,
 ND.PDSIRelevant_Rx,
 ND.Prazosin_Rx,
 ND.Prochlorperazine_Rx,
 ND.Promethazine_Rx,
 ND.Psychotropic_Rx,
 ND.Reach_AntiDepressant_Rx,
 ND.Reach_AntiPsychotic_Rx,
 ND.Reach_opioid_Rx,
 ND.Reach_statin_Rx,
 ND.Reach_SedativeAnxiolytic_Rx,
 ND.SedatingPainORM_Rx,
 ND.SedativeOpioid_Rx,
 ND.Sedative_zdrug_Rx,
 ND.Stimulant_Rx,
 ND.StimulantADHD_Rx,
 ND.TobaccoPharmacotherapy_Rx,
 ND.Tramadol_Rx,
 ND.Zolpidem_Rx,
 ND.Methadone_Rx,
 ND.OpioidForPain_Rx,
 ND.NaloxoneKit_Rx,
 ND.SSRI_Rx,
 ND.ControlledSubstance,
 ND.CNS_Depress_Rx,
 ND.CNS_ActiveMed_Rx,
 CHOICE = CASE WHEN c.RxOutpatSID IS NOT NULL THEN 1 ELSE 0 END
INTO #MedicationsStagingVistA
FROM #VistaMedsRelease AS rxo
-- LookUp join will drop records with NationalDrugSID = -1, but OK to include only records with relavant drug info
INNER JOIN [LookUp].[NationalDrug] AS ND WITH(NOLOCK)
  ON rxo.NationalDrugSID = ND.NationalDrugSID -- ~25000 with -1 NationalDrugSID
-- Join with SStaff to get name of prescriber (should this be 'Unknown" is not in SStaff?)
INNER JOIN [SStaff].[SStaff] AS s WITH(NOLOCK) ON rxo.ProviderSID = s.StaffSID --
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS m WITH(NOLOCK)
  ON m.PatientPersonSID = rxo.PatientSID
LEFT JOIN [CHOICE].[Prescriptions] AS c WITH(NOLOCK)
  ON c.RxOutpatSID = rxo.RxOutpatSID
LEFT JOIN [LookUp].[Sta6a] st6 WITH(NOLOCK) ON st6.Sta6a = rxo.Sta6a
INNER JOIN [LookUp].[ChecklistID] st3 WITH(NOLOCK)
  ON st3.STA3N = rxo.Sta3n AND
     st3.Sta3nFlag = 1 -- this limits rows to keep Sta3n unique

/* VALIDATION
 SELECT DISTINCT Sta6a_rxo
 FROM #MedicationsStagingVistA WHERE Sta6a <> Sta6a_rxo
 AND Sta6a_rxo NOT IN ('*Missing*','*Unknown at this time*')
 --561O

 select * from #MedicationsStagingVistA WHERE Sta6a_rxo like '561O'
 --16 rows insulin

*/

-----------------------------------------------------------------------------------------
-- Cerner Millenium
-- Active RX (RxActiveFlag=1 )
-- Pills on Hand
-----------------------------------------------------------------------------------------

--Step 1 getting max FillNumber because Dispense table has multiple rows per dispense
DROP TABLE IF EXISTS  #MaxFill
SELECT *
INTO #MaxFill
FROM
	(
	SELECT d.MedMgrPersonOrderSID,
	d.FillNumber,
	d.VUID,
	d.STA6A,
	FillRowID=ROW_NUMBER() OVER(PARTITION BY d.MedMgrPersonOrderSID ORDER BY d.FillNumber DESC)
	FROM [Cerner].[FactPharmacyOutpatientDispensed] d WITH(NOLOCK)
	)a
WHERE FillRowID=1

-- Step 2: Dispensed prescriptions: For Max FillNumber assess if ActiveRx or Pills on Hand
DROP TABLE IF EXISTS #MillFill_dispensed;
SELECT *
INTO #MillFill_dispensed
FROM -- dispensed meds per rx status or pills on hand
	(
	  SELECT  DISTINCT
	  d.MVIPersonSID,
	  d.PersonSID,
	  d.DerivedPersonOrderSID, -- want to remove in future after validation -- equivalent to Rxoutpatsid in prod (coaleasce(PrescriptionPersonOrderSID,MedMgrPersonOrderSID))
	  d.MedMgrPersonOrderSID, -- pharmacy ID for a dispensed medication (entered pharmacy workflow)
	  OrderProviderPersonStaffSID=d.DerivedOrderProviderPersonStaffSID,
	  d.VUID, -- VUID from most recent fill as these can vary depending on brand, etc, dispensed at different times
	  d.STA6A, -- STA6A from order, if available, otherwise most recent fill (since people move, and a few people use both VA and DoD pharmacies)
	  d.MedMgrOrderStatus, --original pharmacy workflow status -- this is confusing to be here as RxActiveFlag is based on combination of MedMgrOrderStatus and PrescriptionOrderStatus
	  IssueDate = CAST(d.TZDerivedOrderUTCDateTime AS DATE),
	  ReleaseDateTime=TZDerivedCompletedUTCDateTime,
	  DrugStatus = CASE WHEN d.TZDerivedOrderUTCDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) AND d.RxActiveFlag = 1 THEN 'ActiveRx'
						WHEN DATEADD(DAY,CAST(d.Dayssupply AS INT),d.TZDerivedCompletedUTCDateTime) >= CAST(GETDATE() AS DATE)      THEN  'PillsOnHand'
						ELSE NULL END
	 FROM [Cerner].[FactPharmacyOutpatientDispensed] d WITH(NOLOCK)
	 INNER JOIN #MaxFill mf
		 ON d.MedMgrPersonOrderSID = mf.MedMgrPersonOrderSID and d.FillNumber=mf.FillNumber and d.VUID=mf.VUID
	 WHERE 1=1
	 AND  d.TZDerivedCompletedUTCDateTime >= DATEADD(DAY,-540,CAST(GETDATE() AS DATE)) 
	 ) m
WHERE 1=1
AND m.DrugStatus IS NOT NULL


-- Step 3: Max VUID for OrderCatalog (impute VUID since Ordercatalog can't be formally mapped to nomenclature)
DROP TABLE IF EXISTS #MaxVUID
SELECT OrderCatalogSynonymSID,
VUIDwithDose = max(VUIDwithDose)
INTO #MaxVUID
FROM Cerner.[DimOrderCatalog]
GROUP BY OrderCatalogSynonymSID


-- Joining dispensed with ordered and not dispensed active prescriptions
DROP TABLE IF EXISTS #MillFill 
SELECT *
INTO #MillFill
FROM
( -- dispensed meds
 SELECT *, source = 'Milld' FROM #MillFill_dispensed 
 UNION
 -- prescribed but not dispensed meds
 SELECT
  DISTINCT
  o.MVIPersonSID,
  o.PersonSID,
  o.PrescriptionPersonOrderSID, -- want to remove in future after validation -- equivalent to Rxoutpatsid in prod (coaleasce(PrescriptionPersonOrderSID,MedMgrPersonOrderSID))
  o.MedMgrPersonOrderSID, -- pharmacy ID for a dispensed medication (entered pharmacy workflow)
  o.DerivedOrderProviderPersonStaffSID AS OrderProviderPersonStaffSID,
  VUID = oc.VUIDwithDose, -- VUID from most recent fill as these can vary depending on brand, etc, dispensed at different times
  o.STA6A,
  RXStatus = COALESCE(o.MedMgrOrderStatus,o.PrescriptionOrderStatus) ,--prioritizing prescription status before pharmacy workflow                    ,
  IssueDate = CAST(o.TZDerivedOrderUTCDateTime AS DATE),--      ,max(o.TZDerivedOrderUTCDateTime) over (partition by o.DerivedPersonOrderSID)
  ReleaseDateTime = d.TZDerivedCompletedUTCDateTime,
  DrugStatus = CASE WHEN o.TZDerivedOrderUTCDateTime >= DATEADD(DAY,-366,CAST(GETDATE()AS DATE)) AND o.RxActiveFlag = 1 THEN  'ActiveRx'
					ELSE NULL END,
  source = 'Millo'
FROM Cerner.FactPharmacyOutpatientOrder o WITH (NOLOCK) -- pharm order info
FULL OUTER JOIN Cerner.FactPharmacyOutpatientDispensed d WITH (NOLOCK) -- getting all rows from both tables
	ON o.MedMgrPersonOrderSID = d.MedMgrPersonOrderSID  
LEFT JOIN #MaxVUID oc  ---Max VUID because there can be many VUIDs per OrcerCatalogSynonymSID
   ON o.DerivedOrderCatalogSynonymSID = oc.OrderCatalogSynonymSID
 WHERE 1=1
 AND  d.TZDerivedCompletedUTCDateTime IS NULL -- meds prescribed but not dispensed
 AND   o.TZDerivedOrderUTCDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) 
 AND   o.MVIPERSONSID > 0 
 AND   o.RxActiveFlag = 1
 ) a
WHERE
 a.DrugStatus IS NOT NULL

------------------------------------------------------------------------------------------------------------------
-- #VistaMedsMill: Union the active medications and the pills on hand to a single table
-------------------------------------------------------------------------------------------------------------

-- Using the above data set, further enrich it by joining it to additional tables to prepare it for publishing.
DROP TABLE IF EXISTS #MedicationsStagingMill;

SELECT
 DISTINCT rxo.PersonSID,
          rxo.MVIPersonSID,
          RxOutpatSID = NULL, -- Vista prescription ID
          rxo.DerivedPersonOrderSID,
          rxo.MedMgrPersonOrderSID,
          rxo.STA6A,
          l.ChecklistID,
          rxo.IssueDate,
          ReleaseDateTime,
          PrescriberSID = rxo.OrderProviderPersonStaffSID,
          PrescriberName = ISNULL(s.NameFullFormatted,'Unknown'),
          rxo.MedMgrOrderStatus,
          rxo.DrugStatus,
          DrugSource = [source],
          NationalDrugSID = NULL,
          nd.VUID,
          Sta3n = 200,
          nd.DrugNameWithDose,
          nd.DrugNameWithoutDose,
          DrugNameWithoutDoseSID = NULL,
          nd.CSFederalSchedule,
          nd.PrimaryDrugClassCode,
          nd.StrengthNumeric,
          nd.DosageForm,
          nd.AchAntiHist_Rx,
          nd.AChAD_Rx,
          nd.AChALL_Rx,
          nd.AlcoholPharmacotherapy_Rx,
          nd.AlcoholPharmacotherapy_notop_Rx,
          nd.Alprazolam_Rx,
          nd.Antidepressant_Rx,
          nd.SSRI_SNRI_Rx,
          nd.Antipsychotic_Geri_Rx,
          nd.Antipsychotic_Rx,
          nd.AntipsychoticSecondGen_Rx,
          nd.Anxiolytics_Rx,
          nd.Benzodiazepine_Rx,
          nd.Bowel_Rx,
          nd.Clonazepam_Rx,
          nd.Lorazepam_Rx,
          nd.Mirtazapine_Rx,
          nd.MPRCalculated_Rx,
          nd.MoodStabilizer_Rx,
          nd.MoodStabilizer_GE3_Rx,
          nd.NaltrexoneINJ_Rx,
          nd.Olanzapine_Rx,
          nd.Opioid_Rx,
          nd.OpioidAgonist_Rx,
          nd.PainAdjAnticonvulsant_Rx,
          nd.PainAdjTCA_Rx,
          nd.PainAdjSNRI_Rx,
          nd.PDSIRelevant_Rx,
          nd.Prazosin_Rx,
          nd.Prochlorperazine_Rx,
          nd.Promethazine_Rx,
          nd.Psychotropic_Rx,
          nd.Reach_AntiDepressant_Rx,
          nd.Reach_AntiPsychotic_Rx,
          nd.Reach_opioid_Rx,
          nd.Reach_statin_Rx,
          nd.Reach_SedativeAnxiolytic_Rx,
          nd.SedatingPainORM_Rx,
          nd.SedativeOpioid_Rx,
          nd.Sedative_zdrug_Rx,
          nd.Stimulant_Rx,
          nd.StimulantADHD_Rx,
          nd.TobaccoPharmacotherapy_Rx,
          nd.Tramadol_Rx,
          nd.Zolpidem_Rx,
          nd.Methadone_Rx,
          nd.OpioidForPain_Rx,
          nd.NaloxoneKit_Rx,
          nd.SSRI_Rx,
          nd.ControlledSubstance,
          nd.CNS_Depress_Rx,
          nd.CNS_ActiveMed_Rx,
          CHOICE = NULL
INTO
 #MedicationsStagingMill
FROM
#MillFill rxo
INNER JOIN [LookUp].[Drug_VUID] nd WITH(NOLOCK) ON rxo.VUID = nd.VUID
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH(NOLOCK) -- has duplicate PersonStaffSIDs
  ON rxo.OrderProviderPersonStaffSID = s.PersonStaffSID
LEFT JOIN [LookUp].[Sta6a] l WITH(NOLOCK) ON rxo.Sta6a = l.Sta6a;

-----------------------------------------------------------------------------------------
-- Stage and Publish Final Table
-----------------------------------------------------------------------------------------

-- Union 2 sets here and add choice prescriptions
DROP TABLE IF EXISTS #MedicationsStaging;

SELECT
 DISTINCT PatientPersonSID = PatientSID,
          MVIPersonSID,
          RxOutpatSID,
          DerivedPersonOrderSID,
          MedMgrPersonOrderSID,
          Sta6a,
          ChecklistID,
          IssueDate,
          LastReleaseDateTime,
          PrescriberSID,
          PrescriberName,
          RxStatus,
          DrugStatus,
          DrugSource,
          NationalDrugSID,
          VUID,
          Sta3n,
          DrugNameWithDose,
          DrugNameWithoutDose,
          DrugNameWithoutDoseSiD,
          CSFederalSchedule,
          PrimaryDrugClassCode,
          StrengthNumeric,
          DosageForm,
          AchAntiHist_Rx,
          AChAD_Rx,
          AChALL_Rx,
          AlcoholPharmacotherapy_Rx,
          AlcoholPharmacotherapy_notop_Rx,
          Alprazolam_Rx,
          Antidepressant_Rx,
          SSRI_SNRI_Rx,
          Antipsychotic_Geri_Rx,
          Antipsychotic_Rx,
          AntipsychoticSecondGen_Rx,
          Anxiolytics_Rx,
          Benzodiazepine_Rx,
          Bowel_Rx,
          Clonazepam_Rx,
          Lorazepam_Rx,
          Mirtazapine_Rx,
          MPRCalculated_Rx,
          MoodStabilizer_Rx,
          MoodStabilizer_GE3_Rx,
          NaltrexoneINJ_Rx,
          Olanzapine_Rx,
          Opioid_Rx,
          OpioidAgonist_Rx,
          PainAdjAnticonvulsant_Rx,
          PainAdjTCA_Rx,
          PainAdjSNRI_Rx,
          PDSIRelevant_Rx,
          Prazosin_Rx,
          Prochlorperazine_Rx,
          Promethazine_Rx,
          Psychotropic_Rx,
          Reach_AntiDepressant_Rx,
          Reach_AntiPsychotic_Rx,
          Reach_opioid_Rx,
          Reach_statin_Rx,
          Reach_SedativeAnxiolytic_Rx,
          SedatingPainORM_Rx,
          SedativeOpioid_Rx,
          Sedative_zdrug_Rx,
          Stimulant_Rx,
          StimulantADHD_Rx,
          TobaccoPharmacotherapy_Rx,
          Tramadol_Rx,
          Zolpidem_Rx,
          Methadone_Rx,
          OpioidForPain_Rx,
          NaloxoneKit_Rx,
          SSRI_Rx,
          ControlledSubstance,
          CNS_Depress_Rx,
          CNS_ActiveMed_Rx,
          CHOICE
INTO
 #MedicationsStaging
FROM
#MedicationsStagingVistA
UNION ALL
SELECT
 DISTINCT PersonSID,
          MVIPersonSID,
          RxoutpatSID,
          DerivedPersonOrderSID,
          MedMgrPersonOrderSID,
          STA6A,
          ChecklistID,
          IssueDate,
          ReleaseDateTime,
          PrescriberSID,
          PrescriberName,
          MedMgrOrderStatus,
          DrugStatus,
          DrugSource,
          NationalDrugSID,
          VUID,
          Sta3n,
          DrugNameWithDose,
          DrugNameWithoutDose,
          DrugNameWithoutDoseSID,
          CSFederalSchedule,
          PrimaryDrugClassCode,
          StrengthNumeric,
          DosageForm,
          AchAntiHist_Rx,
          AChAD_Rx,
          AChALL_Rx,
          AlcoholPharmacotherapy_Rx,
          AlcoholPharmacotherapy_notop_Rx,
          Alprazolam_Rx,
          Antidepressant_Rx,
          SSRI_SNRI_Rx,
          Antipsychotic_Geri_Rx,
          Antipsychotic_Rx,
          AntipsychoticSecondGen_Rx,
          Anxiolytics_Rx,
          Benzodiazepine_Rx,
          Bowel_Rx,
          Clonazepam_Rx,
          Lorazepam_Rx,
          Mirtazapine_Rx,
          MPRCalculated_Rx,
          MoodStabilizer_Rx,
          MoodStabilizer_GE3_Rx,
          NaltrexoneINJ_Rx,
          Olanzapine_Rx,
          Opioid_Rx,
          OpioidAgonist_Rx,
          PainAdjAnticonvulsant_Rx,
          PainAdjTCA_Rx,
          PainAdjSNRI_Rx,
          PDSIRelevant_Rx,
          Prazosin_Rx,
          Prochlorperazine_Rx,
          Promethazine_Rx,
          Psychotropic_Rx,
          Reach_AntiDepressant_Rx,
          Reach_AntiPsychotic_Rx,
          Reach_opioid_Rx,
          Reach_statin_Rx,
          Reach_SedativeAnxiolytic_Rx,
          SedatingPainORM_Rx,
          SedativeOpioid_Rx,
          Sedative_zdrug_Rx,
          Stimulant_Rx,
          StimulantADHD_Rx,
          TobaccoPharmacotherapy_Rx,
          Tramadol_Rx,
          Zolpidem_Rx,
          Methadone_Rx,
          OpioidForPain_Rx,
          NaloxoneKit_Rx,
          SSRI_Rx,
          ControlledSubstance,
          CNS_Depress_Rx,
          CNS_ActiveMed_Rx,
          CHOICE = 0
FROM
#MedicationsStagingMill ----------Updating Opioid agonists and Opioid for pain based on patients with appointments with an OTP clinic or an OTP CPT code
                       ;

--resetting opioid agonists
UPDATE #MedicationsStaging
SET OpioidAgonist_Rx = 0
WHERE  DrugNameWithoutDose LIKE '%METHADONE%';

DROP TABLE IF EXISTS #DayTreat
SELECT
 A.STA3N,
 a.RxOutpatSID,
 VISITDATETIME,
 VisitSID,
 b.mvipersonsid,
 Stop523,
 Cpt
INTO
 #DayTreat
FROM
#MedicationsStaging AS a
INNER JOIN
		(		
		SELECT DISTINCT mvipersonsid,
		          A.VISITDATETIME,
		          a.VisitSID,
		          Stop523=CASE WHEN b.StopCode = '523' OR c.stopcode = '523' THEN 1 ELSE 0  END ,
		          Cpt=CASE WHEN cv.OTP_HCPCS = 1 THEN 1 ELSE 0 END 
		 FROM
		 outpat.visit AS a WITH(NOLOCK)
		 LEFT OUTER JOIN Outpat.VProcedure v1 WITH(NOLOCK) ON a.VisitSID = v1.VisitSID --since not all visits have procedures this needs to be an outer join
		 INNER JOIN Common.MVIPersonSIDPatientPersonSID AS m WITH(NOLOCK)
		   ON a.PatientSID = m.PatientPersonSID
		 LEFT OUTER JOIN LookUp.CPT cv WITH(NOLOCK) ON v1.CPTSID = cv.CPTSID
		 LEFT OUTER JOIN LookUp.stopcode AS b WITH(NOLOCK)
		   ON a.PrimaryStopCodeSID = b.StopCodeSID
		 LEFT OUTER JOIN LookUp.stopcode AS c WITH(NOLOCK)
		   ON a.SecondaryStopCodeSID = c.StopCodeSID
		 WHERE 1=1
		  AND ((b.StopCode = '523' OR c.stopcode = '523') OR cv.OTP_HCPCS = 1) 
		  AND a.visitdatetime > getdate() - 730
		  ) AS b
		  ON a.mvipersonsid = b.mvipersonsid AND
		     issuedate BETWEEN dateadd(d,-180,VISITDATETIME)AND dateadd(d,180,VISITDATETIME)
		  WHERE 1=1
		  AND VUID IN (
		  			   SELECT VUID
		  			   FROM LookUp.NationalDrug
		  			   WHERE 1=1
		  			   AND OpioidAgonist_Rx = 1 
		  			   AND DrugNameWithoutDose LIKE '%METHADONE%'
					   )

/*  setting opioid agonist to 1 if the medication is a possible opioid agonist (LookUp.nationaldrugm where OpioidAgonist_Rx = 1) and the patient
 had an encounter for OUD within 1 year of the issue date    */
UPDATE #MedicationsStaging
SET OpioidAgonist_Rx = 1
WHERE  1=1
AND RxoutpatSID IN (
					SELECT DISTINCT RxOutpatSID FROM #DayTreat
					WHERE stop523 = 1 OR cpt = 1
					)

/* setting opioid for pain = 0 where the Rx met the opioid agonist rules above */
UPDATE #MedicationsStaging
SET OpioidForPain_Rx = 0
WHERE  1=1
AND OpioidAgonist_Rx = 1

/* setting the opioid for pain to 1 for methadone perscriptions which do not meet the OTP rules above */

UPDATE #MedicationsStaging
SET OpioidForPain_Rx = 1
WHERE  1=1
AND OpioidAgonist_Rx = 0 
AND VUID IN (
				SELECT VUID
				FROM LookUp.NationalDrug
				WHERE OpioidAgonist_Rx = 1 AND  DrugNameWithoutDose LIKE '%METHADONE%'
			)


EXEC [Maintenance].[PublishTable] 'Present.Medications', '#MedicationsStaging'

EXEC [Log].[ExecutionEnd]

END