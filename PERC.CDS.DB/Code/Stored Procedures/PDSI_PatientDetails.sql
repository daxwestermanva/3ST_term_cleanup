
/*=============================================
	Author:		<Paik, Meenah>
	Create date: <07/27/2021>
	Description:	<Creates staging table for PDSI Phase 3-5 patients>
	Phase 3: ALC_top, ALC, SUD16
	Phase 4: Benzo_65_OP, Benzo_SUD_OP, Benzo_Opioid_OP, Benzo_PTSD_OP, PDMP_Benzo
	Phase 5: Stimulant Use Disorder, StimulantADHD_rx
	Phase 6: Back to the Future: Monitoring_RxStim/StimRx1, ALC_top/ALC_top1, SUD16, AP_UnmetA_OP/APGluc1, CLO/CLO1, Benzo_65_OP/Gbenzo1, AP_Dem_OP/APDem1
	Updates:	
		2021-10-12	LM:  Specifying outpat, inpat, and DoD diagnoses (excluding dx only from community care or problem list)
		2022-03-21	MP:	 Adding fields for if AUD and OUD most recent dx is active (not in remission)
		2022-05-16	RAS: Replaced left joins to Present.Providers with SStaff.SStaff -- Present.Providers is a patient-level
						 table, but the purpose of the joins was only to pull in StaffName (so multiple rows were being 
						 retrieved with a DISTINCT applied). This change decreased execution time.
		2022-07-08	JEB: Updated Synonym references to point to Synonyms from Core
		2022-08-04	MP: Replacing stimulant_Rx with StimulantADHD_Rx
		2022-09-12	MP: Adding Phase 5, Step 2 Measures 
						5161	EBP_StimUD
						5162	Off_Label_RxStim
						5163	Monitoring_RxStim
						5164	CoRx-RxStim
		2023-09-25	MP:	Adding Cerner vitals (BP and pulse) for inclusion in Monitoring_RxStim
		2024-02-22	MP: Changing AUD to AUD_ORM to match metric ALC_top 
		2024-03-21	MP: Adding in Cerner meds details 
		2024-04-18	MP: Adding in MOUD details from non-active MOUD 
		2024-05-16	MP: Removing phase 1 and 2 relevant drugs
		2024-05-21	MP: Adding in stimulant rx details from present.medications for active stimrx that aren't in MPR (bc no release date) or are pills on hand
		2024-10-24	MP: Adding Phase 6 Measures
						5128	AP_Dem_OP/APDem1
						5132	AP_UnmetA_OP/APGluc1
						5116	CLO/CLO1
		2025-05-10	MP: Adding UDS health factors for STIMRX1
		2025-06-18	MP: Adding A1c and Serum Glucose outside HF for APGLUC1

	Testing execution:
		EXEC [Code].[PDSI_PatientDetails]

	Helpful Auditing Scripts

		SELECT TOP 20 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name LIKE '%Code.PDSI_PatientDetails%'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'PatientDetails' AND SchemaName = 'PDSI' ORDER BY 1 DESC
		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName LIKE 'PatientDetails%' AND SchemaName = 'PDSI' ORDER BY 1 DESC


  =============================================*/
CREATE PROCEDURE [Code].[PDSI_PatientDetails]
AS
BEGIN

	/* 
	This code adds patient details and measure flags relevant to the PDSI cohort from [SUD].[Cohort], AS well AS additional info: 
		- Patient demo
		- Group Assignments
		- Relevant diagnoses and medications
		- Recent visit/next appointment 
		- Locations associated with the patient
	*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails', 'Execution of Code.PDSI_PatientDetails SP'

	----------------------------------------------------------------------------
	-- STEP 1:  Identify cohort + add in age 65+
	----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Age65
	SELECT DISTINCT 
		a.MVIPersonSID
		,Age65_Eligible = 1
	INTO #Age65
	FROM [Present].[ActivePatient] b WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient] a WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID 
	WHERE a.Age >= 65
	
	DROP TABLE IF EXISTS #Cohort
	SELECT isnull(a.MVIPersonSID,b.MVIPersonSID) as MVIPersonSID
		  ,isnull(AUD_ORM,0) AUD_ORM
		  ,isnull(OUD,0) OUD
		  ,isnull(CocaineUD_AmphUD,0) CocaineUD_AmphUD --Stim UD
		  ,isnull(PTSD,0) PTSD
		  ,CASE WHEN AUD_ORM = 1 OR OUD = 1 OR SedativeUseDisorder = 1 THEN 1 ELSE 0 END SUD
		  ,isnull(Benzodiazepine_Rx,0) Benzodiazepine_Rx
		  ,isnull(StimulantADHD_Rx,0) StimulantADHD_Rx
		  ,isnull(OpioidForPain_Rx,0) OpioidForPain_Rx
		  ,isnull(Hospice,0) Hospice
		  ,isnull(Cancerdx,0) Cancerdx
		  ,isnull(Age65_Eligible,0) Age65_Eligible
		  ,isnull(Schiz,0) Schiz
		  ,isnull(DementiaExcl,0) DementiaExcl
		  ,isnull(Antipsychotic_Geri_Rx,0) Antipsychotic_Geri_Rx
		  ,1 AS PDSIcohort
	INTO #Cohort
	FROM [SUD].[Cohort] a WITH (NOLOCK)
	FULL OUTER JOIN #Age65 b
		ON a.MVIPersonSID = b.MVIPersonSID
	WHERE a.PDSI = 1 OR b.Age65_Eligible = 1
	ORDER BY MVIPersonSID
	CREATE NONCLUSTERED INDEX IX_Cohort ON #Cohort (MVIPersonSID);

	----------------------------------------------------------------------------
	-- STEP 2a:  Identify relevant active drugs
	----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: Meds via Rockies MPR','Execution of Code.PDSI_PatientDetails, Medication section'
	--Get VA Meds using Rockies MPR 
	DROP TABLE IF EXISTS #VAMeds
	SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithoutDose AS DrugName
		,m.LastRxSID -- compiled RxOutpatSID and Cerner rx SID 
		,pr.StaffName AS PrescriberName
		,'VA outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.AlcoholPharmacotherapy_Rx
		,d.NaltrexoneINJ_Rx
		,d.Benzodiazepine_Rx
		,d.Sedative_zdrug_Rx
		,d.StimulantADHD_Rx
		,d.Antipsychotic_Rx
		,d.Antipsychotic_Geri_Rx
		,0 AS OpioidForPain_Rx
		,0 AS OpioidAgonist_Rx
		,d.NaloxoneKit_Rx
		,f.IssueDate AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,'Active' AS MedRxStatus
		,'ActiveRx' AS MedDrugStatus
		,m.MPRToday
	INTO #VAMeds
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [RxOut].[RxOutpatFill] f WITH (NOLOCK)
		ON f.RxOutpatFillSID = m.RxOutpatFillSID
	INNER JOIN [LookUp].[NationalDrug] d WITH (NOLOCK)
		ON d.NationalDrugSID = f.NationalDrugSID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.PrescribingSta6a = s.Sta6a
	LEFT JOIN [SStaff].[SStaff] pr WITH (NOLOCK)
		ON pr.StaffSID = f.ProviderSID
	WHERE 
		(d.AlcoholPharmacotherapy_Rx = 1
		OR d.Benzodiazepine_Rx = 1
		OR d.NaltrexoneINJ_Rx = 1
		OR d.Sedative_zdrug_Rx = 1
		OR d.StimulantADHD_Rx = 1
		OR d.Antipsychotic_Rx = 1
		OR d.Antipsychotic_Geri_Rx = 1
		OR d.NaloxoneKit_Rx = 1
		) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.ActiveMedicationFlag = 'TRUE'
		AND m.RxSIDSource = 'RxouPatSID'

	UNION ALL

	SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithoutDose AS DrugName
		,m.LastRxSID 
		,pr.NameFullFormatted AS PrescriberName
		,'Cerner outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.AlcoholPharmacotherapy_Rx
		,d.NaltrexoneINJ_Rx
		,d.Benzodiazepine_Rx
		,d.Sedative_zdrug_Rx
		,d.StimulantADHD_Rx
		,d.Antipsychotic_Rx
		,d.Antipsychotic_Geri_Rx
		,0 AS OpioidForPain_Rx
		,0 AS OpioidAgonist_Rx
		,d.NaloxoneKit_Rx
		,f.TZDerivedOrderUTCDateTime AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,'Active' AS MedRxStatus
		,'ActiveRx' AS MedDrugStatus
		,m.MPRToday
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Cerner].[FactPharmacyOutpatientDispensed] f WITH (NOLOCK)
		ON f.DispenseHistorySID = m.RxDispenseSID
	INNER JOIN [LookUp].[Drug_VUID] d WITH (NOLOCK)
		ON d.VUID = f.VUID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.STA6A = s.Sta6a
	LEFT JOIN [Cerner].[FactStaffDemographic] pr WITH (NOLOCK)
		ON pr.PersonStaffSID = f.DerivedOrderProviderPersonStaffSID
	WHERE 
		(d.AlcoholPharmacotherapy_Rx = 1
		OR d.Benzodiazepine_Rx = 1
		OR d.NaltrexoneINJ_Rx = 1
		OR d.Sedative_zdrug_Rx = 1
		OR d.StimulantADHD_Rx = 1
		OR d.Antipsychotic_Rx = 1
		OR d.Antipsychotic_Geri_Rx = 1
		OR d.NaloxoneKit_Rx = 1
		) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.ActiveMedicationFlag = 'TRUE'
		AND m.RxSIDSource = 'DerivedMedMgrPersonOrderSID'

	UNION ALL

	SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithDose AS DrugName
		,m.LastRxSID 
		,pr.StaffName AS PrescriberName
		,'VA outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.AlcoholPharmacotherapy_Rx
		,0 AS NaltrexoneINJ_Rx
		,0 AS Benzodiazepine_Rx
		,0 AS Sedative_zdrug_Rx
		,0 AS StimulantADHD_Rx
		,0 AS Antipsychotic_Rx
		,0 AS Antipsychotic_Geri_Rx
		,d.OpioidForPain_Rx
		,d.OpioidAgonist_Rx
		,0 AS NaloxoneKit_Rx
		,f.IssueDate AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,'Active' AS MedRxStatus
		,'ActiveRx' AS MedDrugStatus
		,m.MPRToday
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [RxOut].[RxOutpatFill] f WITH (NOLOCK)
		ON f.RxOutpatFillSID = m.RxOutpatFillSID
	INNER JOIN [LookUp].[NationalDrug] d WITH (NOLOCK)
		ON d.NationalDrugSID=f.NationalDrugSID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.PrescribingSta6a = s.Sta6a
	LEFT JOIN [SStaff].[SStaff] pr WITH (NOLOCK)
		ON pr.StaffSID = f.ProviderSID
	WHERE 
		(d.OpioidForPain_Rx = 1 OR d.OpioidAgonist_Rx = 1) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.ActiveMedicationFlag = 'TRUE'
		AND m.RxSIDSource = 'RxouPatSID'

	UNION ALL

	SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithDose AS DrugName
		,m.LastRxSID 
		,pr.NameFullFormatted AS PrescriberName
		,'Cerner outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.AlcoholPharmacotherapy_Rx
		,0 AS NaltrexoneINJ_Rx
		,0 AS Benzodiazepine_Rx
		,0 AS Sedative_zdrug_Rx
		,0 AS StimulantADHD_Rx
		,0 AS Antipsychotic_Rx
		,0 AS Antipsychotic_Geri_Rx
		,d.OpioidForPain_Rx
		,d.OpioidAgonist_Rx
		,0 AS NaloxoneKit_Rx
		,f.TZDerivedOrderUTCDateTime AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,'Active' AS MedRxStatus
		,'ActiveRx' AS MedDrugStatus
		,m.MPRToday
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Cerner].[FactPharmacyOutpatientDispensed] f WITH (NOLOCK)
		ON f.DispenseHistorySID = m.RxDispenseSID
	INNER JOIN [LookUp].[Drug_VUID] d WITH (NOLOCK)
		ON d.VUID = f.VUID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.STA6A = s.Sta6a
	LEFT JOIN [Cerner].[FactStaffDemographic] pr WITH (NOLOCK)
		ON pr.PersonStaffSID = f.DerivedOrderProviderPersonStaffSID
	WHERE 
		(d.OpioidForPain_Rx = 1 OR d.OpioidAgonist_Rx = 1) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.ActiveMedicationFlag = 'TRUE'
		AND m.RxSIDSource = 'DerivedMedMgrPersonOrderSID'

	--Active MOUD
	DROP TABLE IF EXISTS #AllMOUD
	SELECT 
		 m.MVIPersonSID
		,m.Prescriber AS PrescriberName
		,m.MOUD AS DrugName
		,'MOUD' AS MedType
		,ck.ChecklistID
		,ck.ADMPARENT_FCDM
		,NULL AS Monthsintreatment
		,0 AS CHOICE
		,CAST(NULL AS VARCHAR) AS CSFederalSchedule
		,m.NonVA
		,m.Inpatient
		,m.Rx
		,m.OTP
		,m.CPT
		,m.CPRS_Order
		,m.MOUDDate
		,m.ActiveMOUD
		,CAST(NULL AS datetime2) AS MedIssueDate
		,m.MOUDDate AS MedReleaseDate
		,CASE WHEN m.ActiveMOUD = 1 THEN 'Active' ELSE 'Inactive' END MedRxStatus
		,CASE WHEN m.ActiveMOUD = 1 THEN 'ActiveRx' ELSE 'Inactive' END MedDrugStatus
	INTO #AllMOUD
	FROM [Present].[MOUD] m WITH (NOLOCK)
	INNER JOIN #Cohort co ON co.MVIPersonSID = m.MVIPersonSID
	INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON ck.StaPa = m.StaPa
	--WHERE m.ActiveMOUD = 1

	--StimRx not in MPR, but active in Present.Meds
	DROP TABLE IF EXISTS #StimRx
	SELECT 
		 m.MVIPersonSID
		,m.ChecklistID
		,m.PrescriberName
		,m.DrugNameWithoutDose AS DrugName
		,'Inactive or Unreleased StimRx' AS MedType		
		,ck.ADMPARENT_FCDM
		,NULL AS Monthsintreatment
		,0 AS CHOICE
		,CAST(NULL AS VARCHAR) AS CSFederalSchedule
		,m.IssueDate AS MedIssueDate
		,m.LastReleaseDateTime AS MedReleaseDate
		,m.RxStatus AS MedRxStatus
		,m.DrugStatus AS MedDrugStatus
	INTO #StimRx
	FROM [Present].[Medications] m WITH (NOLOCK)
	LEFT JOIN #VAMeds co ON co.MVIPersonSID = m.MVIPersonSID and co.StimulantADHD_Rx = 1
	INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) on m.ChecklistID = ck.ChecklistID
	WHERE m.StimulantADHD_Rx = 1 and co.MVIPersonSID is null -- to get only rows that aren't already in MPR table
	
		--ALC_top meds not in MPR, but active in Present.Meds
	DROP TABLE IF EXISTS #AlcPharm
	SELECT 
		 m.MVIPersonSID
		,m.ChecklistID
		,m.PrescriberName
		,m.DrugNameWithoutDose AS DrugName
		,'Alcohol Pharm' AS MedType		
		,ck.ADMPARENT_FCDM
		,NULL AS Monthsintreatment
		,0 AS CHOICE
		,CAST(NULL AS VARCHAR) AS CSFederalSchedule
		,m.IssueDate AS MedIssueDate
		,m.LastReleaseDateTime AS MedReleaseDate
		,m.RxStatus AS MedRxStatus
		,m.DrugStatus AS MedDrugStatus
	INTO #AlcPharm
	FROM [Present].[Medications] m WITH (NOLOCK)
	LEFT JOIN #VAMeds co ON co.MVIPersonSID = m.MVIPersonSID and co.AlcoholPharmacotherapy_Rx = 1
	INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) on m.ChecklistID = ck.ChecklistID
	WHERE m.AlcoholPharmacotherapy_Rx = 1 and co.MVIPersonSID is null -- to get only rows that aren't already in MPR table

	--Adding Antipsychotics not in MPR, but in Present.Meds
	DROP TABLE IF EXISTS #APPharm
	SELECT 
		 m.MVIPersonSID
		,m.ChecklistID
		,m.PrescriberName
		,m.DrugNameWithoutDose AS DrugName
		,'Antipsychotics' AS MedType		
		,ck.ADMPARENT_FCDM
		,NULL AS Monthsintreatment
		,0 AS CHOICE
		,CAST(NULL AS VARCHAR) AS CSFederalSchedule
		,m.IssueDate AS MedIssueDate
		,m.LastReleaseDateTime AS MedReleaseDate
		,m.RxStatus AS MedRxStatus
		,m.DrugStatus AS MedDrugStatus
	INTO #APPharm
	FROM [Present].[Medications] m WITH (NOLOCK)
	LEFT JOIN #VAMeds co ON co.MVIPersonSID = m.MVIPersonSID and co.Antipsychotic_Rx = 1
	INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) on m.ChecklistID = ck.ChecklistID
	WHERE m.Antipsychotic_Geri_Rx = 1 and co.MVIPersonSID is null -- to get only rows that aren't already in MPR table

		--Antipsychotics (including promethazine and prochlorperazine) in the past year for CLO denominator + clozapine; Note: remove unused fields or figure out what to use in display
	DROP TABLE IF EXISTS #PastYearRx
		SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithoutDose AS DrugName
		,m.LastRxSID -- compiled RxOutpatSID and Cerner rx SID 
		,pr.StaffName AS PrescriberName
		,'VA outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.Antipsychotic_Rx
		,CASE WHEN m.DrugNameWithoutDose like '%Clozapine%' THEN 1 ELSE 0 END Clozapine_Rx
		,f.IssueDate AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,m.ActiveMedicationFlag
		,m.MPRToday
	INTO #PastYearRx
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [RxOut].[RxOutpatFill] f WITH (NOLOCK)
		ON f.RxOutpatFillSID = m.RxOutpatFillSID
	INNER JOIN [LookUp].[NationalDrug] d WITH (NOLOCK)
		ON d.NationalDrugSID = f.NationalDrugSID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.PrescribingSta6a = s.Sta6a
	LEFT JOIN [SStaff].[SStaff] pr WITH (NOLOCK)
		ON pr.StaffSID = f.ProviderSID
	WHERE 
		(d.Antipsychotic_Rx = 1
		OR m.DrugNameWithoutDose like '%Clozapine%'
		) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.RxSIDSource = 'RxouPatSID'

	UNION ALL

	SELECT DISTINCT
		 m.MVIPersonSID
		,m.PatientICN
		,m.DrugNameWithoutDose AS DrugName
		,m.LastRxSID 
		,pr.NameFullFormatted AS PrescriberName
		,'Cerner outpatient med' AS MedType
		,s.ChecklistID
		,s.ADMPARENT_FCDM
		,f.DaysSupply
		,d.CSFederalSchedule
		,m.MonthsInTreatment
		,d.Antipsychotic_Rx
		,CASE WHEN m.DrugNameWithoutDose like '%Clozapine%' THEN 1 ELSE 0 END Clozapine_Rx
		,f.TZDerivedOrderUTCDateTime AS MedIssueDate
		,m.TrialEndDateTime AS MedReleaseDate
		,m.ActiveMedicationFlag
		,m.MPRToday
	FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] m WITH (NOLOCK)
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Cerner].[FactPharmacyOutpatientDispensed] f WITH (NOLOCK)
		ON f.DispenseHistorySID = m.RxDispenseSID
	INNER JOIN [LookUp].[Drug_VUID] d WITH (NOLOCK)
		ON d.VUID = f.VUID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK)
		ON f.STA6A = s.Sta6a
	LEFT JOIN [Cerner].[FactStaffDemographic] pr WITH (NOLOCK)
		ON pr.PersonStaffSID = f.DerivedOrderProviderPersonStaffSID
	WHERE 
		(d.Antipsychotic_Rx = 1
		OR m.DrugNameWithoutDose like '%Clozapine%'
		) 
		AND m.TrialEndDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
		AND m.RxSIDSource = 'DerivedMedMgrPersonOrderSID'

	--Combine VA and MOUD information
	DROP TABLE IF EXISTS #Meds
	SELECT 
		 m.*
		,ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID ORDER BY m.DrugName) AS MedID
	INTO #Meds
	FROM (
		SELECT 
			MVIPersonSID
			,PrescriberName
			,DrugName
			,MedType
			,ChecklistID
			,ADMParent_FCDM
			,MonthsInTreatment
			,CSFederalSchedule
			,MedIssueDate
			,MedReleaseDate
			,MedRxStatus
			,MedDrugStatus
			,StimulantADHD_Rx
		FROM #VAMeds
		UNION ALL 
		SELECT 
			MVIPersonSID
			,PrescriberName
			,DrugName
			,MedType
			,ChecklistID
			,ADMParent_FCDM
			,MonthsInTreatment
			,CSFederalSchedule
			,MedIssueDate
			,MedReleaseDate
			,MedRxStatus
			,MedDrugStatus
			,0 as StimulantADHD_Rx 
		FROM #AllMOUD 
		WHERE ActiveMOUD = 1
		UNION ALL
		SELECT 
			MVIPersonSID
			,PrescriberName
			,DrugName
			,MedType
			,ChecklistID
			,ADMParent_FCDM
			,MonthsInTreatment
			,CSFederalSchedule
			,MedIssueDate
			,MedReleaseDate
			,MedRxStatus
			,MedDrugStatus
			,1 as StimulantADHD_Rx
		FROM #StimRx
		UNION ALL
		SELECT 
			MVIPersonSID
			,PrescriberName
			,DrugName
			,MedType
			,ChecklistID
			,ADMParent_FCDM
			,MonthsInTreatment
			,CSFederalSchedule
			,MedIssueDate
			,MedReleaseDate
			,MedRxStatus
			,MedDrugStatus
			,0 as StimulantADHD_Rx
		FROM #AlcPharm
		UNION ALL
		SELECT 
			MVIPersonSID
			,PrescriberName
			,DrugName
			,MedType
			,ChecklistID
			,ADMParent_FCDM
			,MonthsInTreatment
			,CSFederalSchedule
			,MedIssueDate
			,MedReleaseDate
			,MedRxStatus
			,MedDrugStatus
			,0 as StimulantADHD_Rx
		FROM #APPharm
		) m

	CREATE NONCLUSTERED INDEX IX_Meds ON #Meds (MVIPersonSID, MedID);
	
	EXEC [Log].[ExecutionEnd] --'Code.PDSI_PatientDetails: Meds'

	----------------------------------------------------------------------------
	-- STEP 2b:  Identify relevant diagnoses
	----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: Diagnosis','Execution of SP Code.PDSI_PatientDetails, Diagnosis section'

	DROP TABLE IF EXISTS #Diagnosis
	SELECT DISTINCT 
		 d.MVIPersonSID
		,cd.PrintName
		,d.DxCategory
		,cd.Category
		,ROW_NUMBER() OVER(PARTITION BY d.MVIPersonSID ORDER BY cd.Category, cd.PrintName) AS DxID
	INTO #Diagnosis
	FROM [Present].[Diagnosis] d WITH (NOLOCK) 
	INNER JOIN #Cohort c ON d.MVIPersonSID = c.MVIPersonSID
	INNER JOIN 
		(
			SELECT ColumnName, Category, PrintName
			FROM [LookUp].[ColumnDescriptions] WITH (NOLOCK)
			WHERE TableName = 'ICD10'
		) cd 
		ON d.DxCategory = cd.ColumnName
	WHERE DxCategory IN ('Psych','Bipolar','Dementia','Depress','SMI','Schiz','PTSD','MedIndAntiDepressant','MedIndBenzodiazepine',
						'Benzo_AD_MHDx','Tourette','Huntington','MHorMedInd_AD','MHorMedInd_Benzo','OpioidOverdose',
						'AUD_ORM','OUD','SedativeUseDisorder','TBI_Dx','ChronicResp_Dx','CocaineUD_AmphUD','Narcolepsy','ADD_ADHD','BingeEating')
		AND (d.Outpat=1 OR d.Inpat=1 OR d.DoD=1)
	CREATE NONCLUSTERED INDEX IX_Diagnosis ON #Diagnosis (MVIPersonSID, DXID);

	EXEC [Log].[ExecutionEnd] --Diagnosis

	----------------------------------------------------------------------------
	-- STEP 3:  Identify the next appointment 
	----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: Appts and Visits','Execution of SP Code.PDSI_PatientDetails, appt and visit section'

	DROP TABLE IF EXISTS #FutureAppts
	SELECT 
		p.MVIPersonSID
		,CASE 
			WHEN f.ApptCategory = 'PCFuture' THEN 'Primary Care Appointment'
			WHEN f.ApptCategory IN ('MHFuture','HomelessFuture') THEN 'MH Appointment'
			WHEN f.ApptCategory = 'PainFuture' THEN 'Specialty Pain'
			ELSE 'OtherRecent'
			END AS PrintName
		,f.PrimaryStopCodeName AS StopCodeName
		,f.ChecklistID
		,f.AppointmentDatetime
	INTO #FutureAppts
	FROM #Cohort p 
	INNER JOIN 
		(
			SELECT 
				 MVIPersonSID 
				,ApptCategory
				,PrimaryStopCodeName
				,ChecklistID
				,AppointmentDateTime
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN = 1
				AND ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PainFuture','OtherFuture')
		) f 
		ON p.MVIPersonSID = f.MVIPersonSID
	WHERE AppointmentDateTime BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,370,CAST(GETDATE() AS DATE))

	DROP TABLE IF EXISTS #NextAppts
	SELECT 
		 MVIPersonSID
		,PrintName
		,StopCodeName
		,ChecklistID
		,AppointmentDateTime
		,DENSE_RANK() OVER(ORDER BY PrintName) AS AppointmentID 
	INTO #NextAppts
	FROM #FutureAppts
	CREATE NONCLUSTERED INDEX IX_NextAppts ON #NextAppts (MVIPersonSID, AppointmentID);
	DROP TABLE #FutureAppts

	----------------------------------------------------------------------------
	-- STEP 4:  Identify the last visit
	----------------------------------------------------------------------------

	DROP TABLE IF EXISTS #RecentVisits
	SELECT 
		 p.MVIPersonSID
		,CASE 
			WHEN f.ApptCategory = 'PCRecent' THEN 'Primary Care Appointment'
			WHEN f.ApptCategory IN ('MHRecent','HomelessRecent') THEN 'MH Appointment'
			WHEN f.ApptCategory = 'PainRecent' THEN 'Specialty Pain'
			ELSE 'OtherRecent'
		END AS PrintName
		,f.PrimaryStopCodeName AS StopCodeName
		,f.ChecklistID
		,f.VisitDatetime
	INTO #RecentVisits
	FROM #Cohort p 
	INNER JOIN 
		(
			SELECT 
				MVIPersonSID
				,ApptCategory
				,PrimaryStopCodeName
				,ChecklistID
				,VisitDateTime
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_ICN = 1
				AND ApptCategory IN ('PCRecent','MHRecent','HomelessRecent','PainRecent','OtherRecent')
		) f 
		ON p.MVIPersonSID = f.MVIPersonSID

	DROP TABLE IF EXISTS #LastVisit
	SELECT 
		 MVIPersonSID
		,PrintName
		,StopCodeName
		,ChecklistID
		,VisitDateTime
		,DENSE_RANK() OVER(ORDER BY PrintName) AS AppointmentID 
	INTO #LastVisit
	FROM #RecentVisits
	CREATE NONCLUSTERED INDEX IX_LastVisit ON #LastVisit (MVIPersonSID, AppointmentID);
	DROP TABLE IF EXISTS #RecentVisits

	EXEC [Log].[ExecutionEnd] --'Code.PDSI_PatientDetails: Appts and Visits'

	----------------------------------------------------------------------------
	-- STEP 5:  Determine group assignments
	----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: GrpAssign','Execution of Code.PDSI_PatientDetails Group Assignments section' 
	--Note: need to add Outpatient stop code group and Inpatient group?
	DROP TABLE IF EXISTS #Assignments
	SELECT 
		 g.MVIPersonSID
		,g.GroupID
		,g.GroupType
		,g.ProviderSID
		,g.ProviderName
		,g.ChecklistID
		,g.Sta3n
		,g.VISN
		,CASE WHEN ProviderSID > 0 THEN 1 ELSE 0 END AS Assigned
		,ROW_NUMBER() OVER(PARTITION BY g.MVIPersonSID ORDER BY g.GroupType) AS GroupRowID
		,CASE 
			WHEN g.GroupType = 'PDSI Prescriber' THEN 'PDSI Prescriber'
			WHEN g.GroupType = 'PCP' THEN 'Primary Care Provider'
			WHEN g.GroupType = 'MH/BHIP' THEN 'BHIP TEAM' 
			WHEN g.GroupType = 'MHTC' THEN 'MH Tx Coordinator'
			WHEN g.GroupType = 'PACT' THEN 'PACT Team' 
			WHEN g.GroupType = 'Inpatient' THEN 'Inpatient'
			WHEN g.GroupType = 'Outpatient Stop Codes' THEN 'Outpatient Stop Codes'
		END GroupLabel
	INTO #Assignments
	FROM [Present].[GroupAssignments_PDSI] g WITH (NOLOCK)
	--LEFT JOIN #Cohort p 
	--	ON g.MVIPersonSID = p.MVIPersonSID
	INNER JOIN [Present].[StationAssignments] sa WITH (NOLOCK)
		ON g.MVIPersonSID = sa.MVIPersonSID 
		AND g.ChecklistID = sa.ChecklistID
		AND sa.PDSI = 1 
	CREATE NONCLUSTERED INDEX IX_Assignments ON #Assignments (MVIPersonSID, GroupRowID);
	EXEC [Log].[ExecutionEnd] --'Code.PDSI_PatientDetails: GrpAssign'

	----------------------------------------------------------------------------
	-- STEP 6a:  Additional information for Phase 3
	----------------------------------------------------------------------------
	/*****************************************ALC and ALC_Top*****************************************/
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientReport: AUDC','Execution of SP Code.PDSI_PatientReport, AUDC section'
	--AUDIT-C
	DROP TABLE IF EXISTS #AUDC;
	SELECT 
		 b.MVIPersonSID
		,b.AUDCScore
		,b.SurveyGivenDatetime AS AUDC_Date
	INTO #AUDC
	FROM 
		(
			SELECT DISTINCT
				 a.MVIPersonSID
				,a.RawScore AS AUDCScore
				,a.SurveyGivenDatetime
				,a.SurveyName
				,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.SurveyGivenDateTime DESC) AS MostRecent
			FROM [OMHSP_Standard].[MentalHealthAssistant_v02] a WITH (NOLOCK)
			WHERE a.SurveyGivenDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
				AND a.display_AUDC<>-1 AND a.RawScore > -1
		) b
	WHERE b.MostRecent = 1
	CREATE NONCLUSTERED INDEX II_AUDC ON #AUDC(MVIPersonSID);
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientReport: AUDC'

	---------------------------------------------------
	--AUD drug through RxOutpat, Clinic Orders, OR CPT
	---------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientReport: AUD','Execution of SP Code.PDSI_DashboardBaseTable, AUD section'
	DROP TABLE IF EXISTS #AUDDrug;
	SELECT DISTINCT 
		 u.MVIPersonSID
		,MAX(u.ALC_Top_Key) AS ALC_Top_Key
	INTO #AUDDrug
	FROM 
		(
			SELECT MVIPersonSID
				,1 AS ALC_Top_Key
			FROM #VAMeds
			WHERE AlcoholPharmacotherapy_Rx = 1 --Outpatient Rx
				OR NaltrexoneINJ_Rx = 1
			UNION ALL
			SELECT MVIPersonSID
				,1 AS ALC_Top_Key
			FROM #AllMOUD
			WHERE ActiveMOUD = 1 and (PrescriberName = 'Inpatient' OR (CPT = 1 OR CPRS_Order = 1)) --Inpatient naltrexone INJ OR CPT OR Clinic Order 
		) u
	GROUP BY u.MVIPersonSID
	CREATE NONCLUSTERED INDEX II_AUDDrug ON #AUDDrug(MVIPersonSID);
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientReport: AUD'

	/*****************************************SUD16*****************************************/
	DROP TABLE IF EXISTS #MOUD
	SELECT 
		 MVIPersonSID
		,MOUDDate 
		,DrugName
		,NonVA
		,Inpatient
		,Rx
		,OTP
		,CPT
		,CPRS_Order
		,ActiveMOUD
		--,MAX(MOUDDate) AS MOUD_Date
		,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY MOUDDate Desc) AS MOUD_Recent
		--,1 AS MOUD_Key
	INTO #MOUD
	FROM #AllMOUD

	----------------------------------------------------------------------------
	-- STEP 6b:  Additional info for Phase 4 (Benzos)
	----------------------------------------------------------------------------
	/******************Days Supply > 5 + other Benzo measure requirements******************/
	DROP TABLE IF EXISTS #BZD;
	SELECT 
		MVIPersonSID
		,MAX(CASE WHEN Benzodiazepine_Rx = 1 AND DaysSupply > 5 THEN 1 ELSE 0 END) AS Benzodiazepine5
		,MAX
			(
				CASE 
					WHEN Benzodiazepine_Rx = 1 AND DaysSupply > 5 AND CSFederalSchedule <> 'Unscheduled'
					THEN 1
					ELSE 0 
				END
			) AS Benzodiazepine5_Schedule
		,COUNT
			(
				DISTINCT CASE 
					WHEN (Benzodiazepine_Rx = 1 AND DaysSupply > 5) OR (Sedative_zdrug_Rx = 1 AND DaysSupply > 5)
					THEN LastRxSID
					END
			) AS MultiBZD_Rx
		,MAX(CASE WHEN OpioidForPain_Rx = 1 AND DaysSupply > 5 THEN 1 ELSE 0 END) AS OpioidForPain5
		,MAX(CASE WHEN Sedative_zdrug_Rx = 1 AND DaysSupply > 5 THEN 1 ELSE 0 END) AS Sedative_zdrug5

	INTO #BZD
	FROM #VAMeds 
	GROUP BY MVIPersonSID

	/******************PDMP******************/
	--ANY PDMP Note within the past year
	DROP TABLE IF EXISTS #PDMP;
	SELECT 
		 MVIPersonSID
		,MAX(PerformedDateTime) AS PDMP_Date
		,1 AS PDMP
	INTO #PDMP
	FROM [Present].[PDMP] WITH (NOLOCK)
	GROUP BY MVIPersonSID

	----------------------------------------------------------------------------
	-- STEP 6c:  Additional Info for Phase 5
	----------------------------------------------------------------------------
	/********** Naloxone Kit **********/ 
	DROP TABLE IF EXISTS #NaloxoneKit
	SELECT 
		n.MVIPersonSID
		,MAX(ReleaseDateTime) AS LastNaloxone
		,1 AS NaloxoneKit
	INTO #NaloxoneKit
	FROM [ORM].[NaloxoneKit] n WITH (NOLOCK)
	INNER JOIN #Cohort c 
		ON n.MVIPersonSID = c.MVIPersonSID
	WHERE n.ReleaseDateTime >=  DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
	GROUP BY n.MVIPersonSID

	/********** HF Templates for STIMRX1 monitoring (UDS and blood pressure) and APGLUC1 (outside A1c and SerGluc) **********/
		DROP TABLE IF EXISTS #HealthFactors;
	SELECT 
		 --c.Category
		m.List
		,m.ItemID
		,m.AttributeValue
		,m.Attribute
		--,c.Printname
		,healthfactortype
	INTO #HealthFactors
	FROM [Lookup].[ListMember] m WITH (NOLOCK)
	INNER JOIN Dim.HealthFactorType t 
		ON t.HealthFactorTypeSID = ItemID
	--INNER JOIN [Lookup].[List] c WITH (NOLOCK) 
	--	ON m.List = c.List
	WHERE m.list like '%BloodPressure_HF%' or m.list like 'UDS_%' or m.list like 'A1cOutside_HF' or m.list like 'SerGlucoseOutside_HF' --or m.list like '%EBP_CBSUD_Template%' or m.list like '%EBP_CM_Template%'
	;

		DROP TABLE IF EXISTS #HealthFact; 
	SELECT DISTINCT 
		 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,ISNULL(z.ChecklistID,h.Sta3n) AS ChecklistID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime --removing the seconds from the HF date since the note date doesnt have seconds
		,v.VisitDateTime
		,h.Comments
		--,HF.Category
		,HF.List
		--,HF.PrintName
		,AttributeValue
		,healthfactortype
	INTO #HealthFact 
	FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.HealthFactorTypeSID
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	INNER JOIN [Dim].[Division] dd WITH (NOLOCK) 
		ON dd.DivisionSID = v.DivisionSID
	LEFT JOIN [LookUp].[Sta6a] z WITH (NOLOCK) 
		ON dd.sta6a = z.sta6a
	INNER JOIN #Cohort c
		ON mvi.MVIPersonSID = c.MVIPersonSID
	WHERE h.HealthFactorDateTime >= DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) 

		-- Health Factors for Blood Pressure and UDS to use below
	DROP TABLE IF EXISTS #HF
	SELECT DISTINCT
		 MVIPersonSID
		,VisitDateTime
		,CASE WHEN List like 'BloodPressure_HF' THEN 1 ELSE 0 END BloodPressure_HF
		,CASE WHEN List like 'UDS_%' THEN 1 ELSE 0 END UDS_HF
		,CASE WHEN List like 'SerGlucoseOutside_HF' THEN 1 ELSE 0 END SerGluc_HF
		,CASE WHEN List like 'A1cOutside_HF' THEN 1 ELSE 0 END A1c_HF
	INTO #HF
	FROM #HealthFact 
	WHERE (List like 'BloodPressure_HF' AND VisitDateTime > CAST(DATEADD(MONTH, -6, GETDATE()) AS DATE))
		OR List like 'UDS_%' OR List like 'SerGlucoseOutside_HF' OR List like 'A1cOutside_HF'
	
	/********** Blood Pressure and BP vitals **********/
	--from vitalsign
	DROP TABLE IF EXISTS #Vital
	SELECT v.*, vitaltype, c.MVIPersonSID
	INTO #Vital
	FROM [Vital].[VitalSign] v WITH (NOLOCK)
	INNER JOIN [Dim].[VitalType] b WITH (NOLOCK) ON v.vitaltypesid = b.vitaltypesid 
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] m WITH (NOLOCK) ON v.PatientSID = m.PatientPersonSID
	INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
	WHERE VitalType in ('PULSE','BLOOD PRESSURE')
	AND VitalSignTakenDateTime >=  DATEADD(Month,-6,CAST(GETDATE() AS DATE)) and VitalSignTakenDateTime <  GETDATE() --is this the best date to use?
	AND (EnteredInErrorFlag <> 'Y' or EnteredInErrorFlag is null) and VitalResult <> 'Unavailable' and VitalResult <> 'refused' and VitalResult <> 'pass' 

	--Cerner
	DROP TABLE IF EXISTS #VitalCerner
	SELECT c.MVIPersonSID, f.Event, DerivedResultValueNumeric, TZPerformedUTCDateTime, Sta6a
	INTO #VitalCerner
	FROM [Cerner].[FactVitalSign] f WITH (NOLOCK)
	INNER JOIN #Cohort c ON f.MVIPersonSID = c.MVIPersonSID
	WHERE (Event like '%Blood Pressure%' or Event like '%Pulse%') AND TZPerformedUTCDateTime >= DATEADD(Month,-6,CAST(GETDATE() AS DATE))
	AND TZPerformedUTCDateTime < GETDATE() AND DerivedResultValueNumeric is not NULL

	--Video Blood Pressure Visit Note Title (Does not exist in Cerner yet)
	DROP TABLE IF EXISTS #BPNote
SELECT
	mvi.MVIPersonSID
	,b.AttributeValue AS [DataType]
	,a.ReferenceDateTime AS PerformedDateTime
	,a.Sta3n
	,d.StaPa AS ChecklistID
	INTO #BPNote
FROM [TIU].[TIUDocument] as a WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] b WITH (NOLOCK)
	ON a.TIUDocumentDefinitionSID = b.ItemID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	ON a.PatientSID = mvi.PatientPersonSID
INNER JOIN [Dim].[Institution] d WITH (NOLOCK)
	ON a.InstitutionSID=d.InstitutionSID
INNER JOIN [Present].[SPatient] e WITH (NOLOCK)
	ON mvi.MVIPersonSID = e.MVIPersonSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON a.TIUStatusSID = ts.TIUStatusSID
WHERE b.List='BloodPressure_TIU' 
	AND a.ReferenceDateTime > CAST(DATEADD(MONTH, -6, GETDATE()) AS DATE)
	AND a.DeletionDateTime IS NULL
	AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
	
	--Put vitals together
	DROP TABLE IF EXISTS #VitalsAll
	SELECT DISTINCT 
		 MVIPersonSID
		,VitalSignTakenDateTime as VitalsDate
		,Vitals = 'Vitals'
	INTO #VitalsAll
	FROM #Vital
	UNION ALL
	SELECT DISTINCT 
		 MVIPersonSID
		,TZPerformedUTCDateTime as VitalsDate
		,Vitals = 'Cerner'
	FROM #VitalCerner
	UNION ALL 
	SELECT DISTINCT
		 MVIPersonSID
		,PerformedDateTime as VitalsDate
		,Vitals = 'Note Title'
	FROM #BPNote
	UNION ALL 
	SELECT DISTINCT 
		 MVIPersonSID
		,VisitDateTime as VitalsDate
		,Vitals = 'Health Factor'
	FROM
	#HF
	WHERE BloodPressure_HF = 1

	--Most recent vitals date
	DROP TABLE IF EXISTS #Monitoring
	SELECT MVIPersonSID
		,VitalsDate
		,Vitals
	INTO #Monitoring 
	FROM (SELECT
		  MVIPersonSID
		 ,VitalsDate
		 ,Vitals
		 ,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY VitalsDate desc) AS VitalsDateRecent
		 FROM #VitalsAll) a
	WHERE a.VitalsDateRecent = 1

		/********** UDS **********/ 
	DROP TABLE IF EXISTS #UDS
	SELECT 
		 u.MVIPersonSID
		,MAX(UDS_Any_DateTime) AS LastUDS
		,1 AS UDS
	INTO #UDS
	FROM [ORM].[UDS] u WITH (NOLOCK)
	INNER JOIN #Cohort c 
		ON u.MVIPersonSID = c.MVIPersonSID
	GROUP BY u.MVIPersonSID
UNION ALL 
	SELECT DISTINCT
		 u.MVIPersonSID
		,MAX(VisitDateTime) AS LastUDS
		,1 AS UDS
	FROM #HF u
	INNER JOIN #Cohort c
		ON u.MVIPersonSID = c.MVIPersonSID
	WHERE UDS_HF = 1 
	GROUP BY u.MVIPersonSID

	DROP TABLE IF EXISTS #UDSLast
	SELECT MVIPersonSID
		,LastUDS
		,UDS
	INTO #UDSLast 
	FROM (SELECT
		  MVIPersonSID
		 ,LastUDS
		 ,UDS
		 ,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY LastUDS desc) AS UDSDateRecent
		 FROM #UDS) a
	WHERE a.UDSDateRecent = 1

	/********** CM & CBT-SUD **********/ 
	-- CM and CBSUD templates from EBP table
	DROP TABLE IF EXISTS #EBP
	SELECT 
		 e.MVIPersonSID
		,VisitDateTime
		,CASE WHEN TemplateGroup = 'EBP_CM_Template' THEN 1 ELSE 0 END CM_Template 
		,CASE WHEN TemplateGroup = 'EBP_CBSUD_Template' THEN 1 ELSE 0 END CBTSUD_Template
	INTO #EBP
	FROM [EBP].[TemplateVisits] e WITH (NOLOCK)
	INNER JOIN #Cohort c
		ON e.MVIPersonSID = c.MVIPersonSID
	WHERE VisitDateTime >=  DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) 
	AND TemplateGroup in ('EBP_CM_Template','EBP_CBSUD_Template')

	DROP TABLE IF EXISTS #CM
	SELECT 
		 MVIPersonSID
		,MAX(VisitDateTime) AS LastCM
		,CM = 1
	INTO #CM
	FROM #EBP
	WHERE CM_Template = 1
	GROUP BY MVIPersonSID

	DROP TABLE IF EXISTS #CBTSUD
	SELECT
		 MVIPersonSID
		,MAX(VisitDateTime) AS LastCBTSUD
		,CBTSUD = 1
	INTO #CBTSUD
	FROM #EBP
	WHERE CBTSUD_Template = 1 
	GROUP BY MVIPersonSID

	/********** Off-Label Dx **********/
	DROP TABLE IF EXISTS #OffLabel
	SELECT DISTINCT 
		 MVIPersonSID
		,CASE WHEN DxCategory like 'ADD_ADHD' THEN 1 ELSE 0 END ADD_ADHD
		,CASE WHEN DxCategory like 'Narcolepsy' THEN 1 ELSE 0 END Narcolepsy
		,CASE WHEN DxCategory like 'BingeEating' THEN 1 ELSE 0 END BingeEating
	INTO #OffLabel
	FROM #Diagnosis 

	DROP TABLE IF EXISTS #OffLabelMax
	SELECT DISTINCT 
		 MVIPersonSID
		,MAX(ADD_ADHD) AS ADD_ADHD
		,MAX(Narcolepsy) AS Narcolepsy
		,MAX(BingeEating) AS BingeEating
	INTO #OffLabelMax
	FROM #OffLabel
	WHERE ADD_ADHD = 1 OR Narcolepsy = 1 OR BingeEating = 1
	GROUP BY MVIPersonSID

	----------------------------------------------------------------------------
	-- STEP 6d:  Additional Info for Phase 6
	----------------------------------------------------------------------------
	--Rx component for CLO denominator 
	DROP TABLE IF EXISTS #CloDen
	SELECT
		 MVIPersonSID
		,MAX(CAST(Antipsychotic_Rx AS INT)) AS AntiPsychoticLastYear
		,MAX(CAST(Clozapine_Rx AS INT)) AS ClozapineLastYear
	INTO #CloDen
	FROM #PastYearRx
	GROUP BY MVIPersonSID

	--Glucose Monitoring for APGluc1

--Glucose and A1c Labs
	DROP TABLE IF EXISTS #GlucLabVista
	SELECT 
		lc.LabChemSID
		, lc.Sta3n
		, lc.MVIPersonSID
		, lc.LabChemTestSID
		, lc.LabChemCompleteDateTime
		, lc.LabChemResultValue
		, 1 AS GlucLab
		, lc.A1c_Blood AS A1C_Blood
		, lc.Glucose_Blood AS Glucose_Blood
	INTO #GlucLabVista
	FROM #Cohort c
	INNER JOIN
		(
			SELECT
				ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				, ll.A1c_Blood 
				, ll.Glucose_Blood 
				, lc1.LabChemSID
				, lc1.Sta3n
				, lc1.LabChemTestSID
				, lc1.LabChemCompleteDateTime
				, lc1.LabChemResultValue
			FROM [Chem].[LabChem] lc1 WITH (NOLOCK)
			INNER JOIN [LookUp].[Lab] ll WITH (NOLOCK)
				ON ll.LabChemTestSID = lc1.LabChemTestSID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON lc1.PatientSID = mvi.PatientPersonSID 
			WHERE lc1.LabChemCompleteDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0)) 
				AND (
						ll.A1c_Blood = 1
						OR ll.Glucose_Blood = 1
					)
		)
		lc
		ON c.MVIPersonSID = lc.MVIPersonSID

	DROP TABLE IF EXISTS #GlucLabCerner;
	SELECT lc.EncounterSID as LabChemSID
		,200 as Sta3n
		,lc.MVIPersonSID
		,lc.SourceIdentifier as LabChemTestSID
		,lc.TZPerformedUTCDateTime as LabChemCompleteDateTime
		,lc.ResultValue as LabChemResultValue
		,1 AS GlucLab
		,ll.A1c_Blood AS A1c_Blood
		,ll.Glucose_Blood AS Glucose_Blood
	INTO #GlucLabCerner
	FROM #Cohort AS C WITH (NOLOCK)  
	INNER JOIN [Cerner].[FactLabResult] lc WITH (NOLOCK) on c.MVIPersonSID=lc.MVIPersonSID
	INNER JOIN [LookUp].[Lab] ll WITH (NOLOCK) ON ll.LOINCSID=lc.NomenclatureSID
	WHERE lc.TZPerformedUTCDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0)) 
		AND (
			ll.A1c_Blood = 1
			OR ll.Glucose_Blood = 1
			)

-- Glucose and A1c CPT 

	DROP TABLE IF EXISTS #VistaCPT
	SELECT DISTINCT c.MVIPersonSID
				   ,CASE WHEN CPTcode like '82947' THEN 1 ELSE 0 END GlucCPT
				   ,CASE WHEN CPTcode like '83036' THEN 1 ELSE 0 END A1cCPT
	INTO #VistaCPT
	FROM #Cohort c
	INNER JOIN Common.vwMVIPersonSIDPatientPersonSID m WITH (NOLOCK)
		ON c.MVIPersonSID=m.MVIPersonSID
	INNER JOIN Outpat.VProcedure p WITH (NOLOCK)
		ON m.PatientPersonSID=p.PatientSID
		AND p.WorkloadLogicFlag='Y'
	INNER JOIN LookUp.CPT cpt WITH (NOLOCK)
		ON p.CPTSID=cpt.CPTSID
	WHERE cpt.CPTCode IN ('82947','83036') AND
		  p.VisitDateTime >= GETDATE() - 365;

	DROP TABLE IF EXISTS #CernerCPT
	SELECT DISTINCT c.MVIPersonSID
				   ,CASE WHEN CPTcode like '82947' THEN 1 ELSE 0 END GlucCPT
				   ,CASE WHEN CPTcode like '83036' THEN 1 ELSE 0 END A1cCPT
	INTO #CernerCPT
	FROM #Cohort c
	INNER JOIN Cerner.FactProcedure p WITH (NOLOCK)
		ON c.MVIPersonSID=p.MVIPersonSID
	INNER JOIN LookUp.CPT cpt WITH (NOLOCK)
		ON p.NomenclatureSID=cpt.CPTSID
	WHERE cpt.CPTCode IN ('82947','83036') AND
		  p.TZDerivedProcedureDateTime >= GETDATE() - 365;

--All glucose monitoring
	DROP TABLE IF EXISTS #GlucMonitoringAll
	SELECT DISTINCT 
			MVIPersonSID
		   ,GlucMonitoring = 1
	INTO #GlucMonitoringAll
	FROM #GlucLabVista
UNION ALL 
	SELECT DISTINCT	
			MVIPersonSID
		   ,GlucMonitoring = 1
	FROM #GlucLabCerner
UNION ALL 
	SELECT DISTINCT	
			MVIPersonSID
		   ,GlucMonitoring = 1
	FROM #VistaCPT
UNION ALL
	SELECT DISTINCT	
			MVIPersonSID
		   ,GlucMonitoring = 1
	FROM #CernerCPT
UNION ALL
	SELECT DISTINCT
			MVIPersonSID
		   ,GlucMonitoring = 1
	FROM #HF
	WHERE SerGluc_HF = 1 OR A1c_HF = 1

	DROP TABLE IF EXISTS #GlucMonitoring
	SELECT DISTINCT MVIPersonSID
		,GlucMonitoring
	INTO #GlucMonitoring
	FROM #GlucMonitoringAll

	----------------------------------------------------------------------------
	-- STEP 6e: Put Measures together
	----------------------------------------------------------------------------
	--Metric Inclusion: one row per patient per measure that will indicate inclusion in each metric
	DROP TABLE IF EXISTS #MetricInclusion
	SELECT 
		 c.MVIPersonSID
		,d.MeasureID
		,d.VariableName
		,c.Hospice
		,c.OUD
		,c.AUD_ORM
		,c.PTSD
		,c.SUD
		,c.CocaineUD_AmphUD
		,c.OpioidForPain_Rx
		,ISNULL(b.Benzodiazepine5,0) AS Benzodiazepine5
		,ISNULL(b.Benzodiazepine5_Schedule,0) AS Benzodiazepine5_Schedule
		,StimulantADHD_Rx
		,c.Age65_Eligible
		,c.Antipsychotic_Geri_Rx
		,ISNULL(cl.ClozapineLastYear,0) AS ClozapineLastYear
		,CASE 
			WHEN d.MeasureID = 1116 AND c.OUD = 1 THEN 1 --sud16
			WHEN d.MeasureID = 5119 AND c.AUD_ORM = 1 THEN 1 --alc_top
			WHEN d.MeasureID = 5125 AND c.Hospice = 0 AND c.PTSD = 1 THEN 1 --benzo_PTSD_OP
			WHEN d.MeasureID = 5154 AND c.Hospice = 0 AND c.Age65_Eligible = 1 THEN 1 --benzo_65_OP
			WHEN d.MeasureID = 5155 AND c.Hospice = 0 AND c.SUD = 1 THEN 1 --benzo_SUD_OP
			WHEN d.MeasureID = 5156 AND c.Hospice = 0 AND b.Benzodiazepine5 = 1 THEN 1 --benzo_opioid_OP
			WHEN d.MeasureID = 5157 AND c.Hospice = 0 AND b.Benzodiazepine5_Schedule = 1 THEN 1 --pdmp_benzo
			WHEN d.MeasureID = 5158 AND c.CocaineUD_AmphUD = 1 THEN 1 --StimUD and Naloxone
			WHEN d.MeasureID = 5161 AND c.CocaineUD_AmphUD = 1 THEN 1 -- EBP and StimUD
			WHEN d.MeasureID = 5162 AND c.StimulantADHD_Rx = 1 THEN 1 -- Off label stimulant use
			WHEN d.MeasureID = 5163 AND c.StimulantADHD_Rx = 1 THEN 1 -- Monitoring and stimulant use
			WHEN d.MeasureID = 5164 AND c.StimulantADHD_Rx = 1 THEN 1 -- Co rx with stimulant use
			WHEN d.MeasureID = 5128 AND c.Hospice = 0 AND c.DementiaExcl = 1 THEN 1 -- Dementia and Antipsychotics
			WHEN d.MeasureID = 5132 AND c.Antipsychotic_Geri_Rx = 1 THEN 1 --Antipsychotics and Gluc not monitored
			WHEN d.MeasureID = 5116 AND c.Schiz = 1 AND cl.AntiPsychoticLastYear = 1 THEN 1 -- Schiz and Clozapine 
			ELSE 0 
		END AS MetricInclusion
	INTO #MetricInclusion 
	FROM #Cohort c
	LEFT JOIN #BZD b 
		ON c.MVIPersonSID = b.MVIPersonSID
	LEFT JOIN #CloDen cl
		ON c.MVIPersonSID = cl.MVIPersonSID
	INNER JOIN 
		(
			SELECT MeasureID, VariableName 
			FROM [PDSI].[Definitions] WITH (NOLOCK)
			WHERE DimensionID >=4 AND MeasureID <> '5117' 
		) d 
		ON 1=1	--Remove ALC from PDSI.Definitions table

-- To prepare for identifying unmet measures, attach and process relevant information from all the preparatory tables to each of the measures' rows per patient.
	DROP TABLE IF EXISTS #MetricPrep
	SELECT DISTINCT 
		 mi.MVIPersonSID
		,mi.MeasureID
		,mi.VariableName
		,CASE 
			WHEN mi.MeasureID = 1116 and m.MOUD_Recent = 1 THEN m.MOUDDate -- date of most recent MOUD regardless of if it's active or not
			WHEN mi.MeasureID = 5119 THEN AUDC_Date
			WHEN mi.MeasureID = 5157 THEN PDMP_Date
			WHEN mi.MeasureID = 5158 THEN LastNaloxone
			WHEN mi.MeasureID = 5161 THEN LastCM --Last CM     /CBT-SUD visit
			WHEN mi.MeasureID = 5163 THEN LastUDS 
		END DetailsDate
		,CASE 
			WHEN mi.MeasureID = 1116 and m.MOUD_Recent = 1 THEN cast(m.DrugName as nvarchar(255))
			WHEN mi.MeasureID = 5119 THEN cast(AUDCScore as nvarchar(255))
			WHEN mi.MeasureID IN (5125,5154,5155,5156,5157) THEN cast(MultiBZD_Rx as nvarchar(255))
		END DetailsText 
		,mi.MetricInclusion
		,CASE
			WHEN m.activeMOUD = 1 THEN 1 ELSE 0
		END MOUD_Key
		,ISNULL(ALC_Top_Key,0) AS ALC_Top_Key
		,ISNULL(PDMP,0) AS PDMP
		,ISNULL(NaloxoneKit,0) AS NaloxoneKit
		,ISNULL(UDS,0) AS UDS
		,mi.Age65_Eligible
		,mi.OUD
		,mi.AUD_ORM
		,mi.SUD
		,mi.PTSD
		,mi.OpioidForPain_Rx
		,mi.Antipsychotic_Geri_Rx
		,mi.ClozapineLastYear
		,b.Benzodiazepine5
		,b.Benzodiazepine5_Schedule
		,b.OpioidForPain5
		,b.Sedative_zdrug5
		,ISNULL(re.AUDactiveMostRecent,0) AS AUDActiveMostRecent
		,ISNULL(re.OUDActiveMostRecent,0) AS OUDActiveMostRecent
		,ISNULL(c.CM,0) AS CM
		,ISNULL(cb.CBTSUD,0) AS CBTSUD
		,ISNULL(v.Vitals,0) AS Vitals
		,VitalsDate
		,ISNULL(o.ADD_ADHD,0) AS ADD_ADHD
		,ISNULL(o.Narcolepsy,0) AS Narcolepsy
		,ISNULL(o.BingeEating,0) AS BingeEating
		,cb.LastCBTSUD
		,ISNULL(g.GlucMonitoring,0) AS GlucMonitoring
	INTO #MetricPrep
	FROM #MetricInclusion mi
	LEFT JOIN #AUDC ac ON ac.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #AUDDrug ad ON ad.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #MOUD m ON m.MVIPersonSID = mi.MVIPersonSID and ActiveMOUD = 1
	LEFT JOIN #PDMP p ON p.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #BZD b ON b.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #NaloxoneKit n ON n.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #UDS u ON u.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #Monitoring v ON v.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #CM c ON c.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #CBTSUD cb ON cb.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN [PDSI].[AUD_OUD_Active] re WITH (NOLOCK) ON re.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #OffLabelMax o ON o.MVIPersonSID = mi.MVIPersonSID
	LEFT JOIN #GlucMonitoring g ON g.MVIPersonSID = mi.MVIPersonSID

	DROP TABLE IF EXISTS #MeasureUnmet
	SELECT 
		DISTINCT 
			* 
			,CASE 
				WHEN MeasureID = 1116 AND OUD = 1 AND MOUD_Key = 0  THEN 1
				WHEN MeasureID = 5119 AND AUD_ORM = 1 AND ALC_Top_Key = 0 THEN 1
				WHEN MeasureID = 5125 AND Benzodiazepine5 = 1 THEN 1 
				WHEN MeasureID = 5154 AND Benzodiazepine5 = 1 THEN 1
				WHEN MeasureID = 5155 AND Benzodiazepine5 = 1 THEN 1
				WHEN MeasureID = 5156 AND OpioidForPain_Rx = 1 THEN 1
				WHEN MeasureID = 5157 AND PDMP = 0 THEN 1
				WHEN MeasureID = 5158 AND NaloxoneKit = 0 THEN 1
				WHEN MeasureID = 5161 AND CM = 0 AND CBTSUD = 0 THEN 1
				WHEN MeasureID = 5162 AND ADD_ADHD = 0 AND Narcolepsy = 0 AND BingeEating = 0 THEN 1
				WHEN MeasureID = 5163 AND (Vitals = '0' OR UDS = 0) THEN 1 
				WHEN MeasureID = 5164 AND (Benzodiazepine5 = 1 OR OpioidForPain5 = 1 OR Sedative_ZDrug5 = 1) THEN 1
				WHEN MeasureID = 5128 AND Antipsychotic_Geri_Rx = 1  THEN 1
				WHEN MeasureID = 5132 AND GlucMonitoring = 0 THEN 1 
				WHEN MeasureID = 5116 AND ClozapineLastYear = 0 THEN 1
			
				ELSE 0 
			END AS MeasureUnmet 
	INTO #MeasureUnmet
	FROM #MetricPrep
	WHERE MetricInclusion = 1
	ORDER BY MVIPersonSID, MeasureID

	CREATE NONCLUSTERED INDEX IX_MeasureUnmet ON #MeasureUnmet (MVIPersonSID, MeasureID);

	-- STEP 7 Removed

	----------------------------------------------------------------------------
	-- STEP 8: Patient location information
	----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: Location','Execution of Code.PDSI_PatientDetails Locations section'
	--Pull IN facility information via ChecklistID
	DROP TABLE IF EXISTS #Locations
	SELECT 
		 co.MVIPersonSID
		,loc.ChecklistID
		,ROW_NUMBER() OVER(PARTITION BY loc.MVIPersonSID ORDER BY loc.Checklistid) AS LocationID
	INTO #Locations
	FROM #Cohort co
	INNER JOIN [Present].[StationAssignments] loc WITH (NOLOCK)
		ON loc.MVIPersonSID = co.MVIPersonSID
	WHERE loc.PDSI = 1 
	
	CREATE NONCLUSTERED INDEX IX_Locations ON #Locations (MVIPersonSID, LocationID);
	
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientDetails: Location'

	----------------------------------------------------------------------------
	-- STEP 9:  Assemble patient details into final table
	----------------------------------------------------------------------------

	DROP TABLE IF EXISTS #RowID
	CREATE TABLE #RowID (RowID INT NOT NULL)
	INSERT #RowID 
		(RowID) 
	SELECT 
		j.RowID
	FROM
		(
			SELECT MeasureID AS RowID FROM #MeasureUnmet 
			UNION 
			SELECT DxID AS RowID FROM #Diagnosis
			UNION 
			SELECT MedID AS RowID FROM #Meds
			UNION 
			SELECT GroupRowID AS RowID FROM #Assignments
			UNION 
			SELECT AppointmentID AS RowID FROM #NextAppts
			UNION 
			SELECT AppointmentID AS RowID FROM #LastVisit
			UNION 
			SELECT LocationID AS RowID FROM #Locations
		) j
	ORDER BY j.RowID

	--------------------------------------------------------------------------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: #CohortRowID','Execution of Code.PDSI_PatientDetails #CohortRowID section'
	
	--Intention is to create a RowID table with only the row numbers with relevant information (no nulls)
	DROP TABLE IF EXISTS #CohortRowID
	SELECT 
		MVIPersonSID
		,RowID
	INTO #CohortRowID
	FROM #Cohort, #RowID
	ORDER BY MVIPersonSID, RowID
	
	EXEC [Log].[ExecutionEnd]	--'EXEC Code.PDSI_PatientDetails: #CohortRowID'

	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: #CohortRowID Clustered Index','Execution of Code.PDSI_PatientDetails #CohortRowID Clustered Index section'
	CREATE CLUSTERED INDEX PK_CohortRowID ON #CohortRowID (MVIPersonSID, RowID);
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientDetails: #CohortRowID Clustered Index'

	DROP TABLE IF EXISTS #Cohort
	DROP TABLE IF EXISTS #RowID
	DROP TABLE IF EXISTS #MetricPrep
	DROP TABLE IF EXISTS #MetricInclusion

	--------------------------------------------------------------------------------------------------------------------------------------------
	--Begin with all possible PatientICN and ID combinations then join all detail tables
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: #PatientDetails','Execution of Code.PDSI_PatientDetails #PatientDetails section'
	
	DROP TABLE IF EXISTS #PatientDetails
	SELECT DISTINCT 
		a.MVIPersonSID

		--Locations
		,loc.ChecklistID AS Locations

		--Measure Info
		,ISNULL(mu.MeasureID,-1) AS MeasureID
		,mu.VariableName AS Measure
		,mu.DetailsText
		,mu.DetailsDate
		,mu.MeasureUnmet
		,mu.PTSD
		,mu.SUD
		,mu.MOUD_Key
		,mu.ALC_Top_Key
		,mu.PDMP
		,mu.NaloxoneKit
		,mu.UDS
		,mu.Age65_Eligible
		,mu.OpioidForPain_Rx
		,mu.Benzodiazepine5
		,mu.Benzodiazepine5_Schedule
		,mu.OpioidForPain5
		,mu.Sedative_zdrug5
		,mu.CM
		,mu.CBTSUD
		,mu.LastCBTSUD
		,mu.Vitals
		,mu.VitalsDate
		,mu.ADD_ADHD
		,mu.Narcolepsy
		,mu.BingeEating
		,aoud.AUDActiveMostRecent
		,aoud.OUDActiveMostRecent

		--Dx
		,ISNULL(dx.DxID,-1) AS DXID
		,dx.PrintName AS Diagnosis
		,dx.DxCategory
		,dx.Category

		--Rx
		,ISNULL(rx.MedID,-1) AS MedID
		,rx.DrugName
		,rx.PrescriberName
		,rx.MedType
		,rx.ChecklistID AS MedLocation
		,rx.MonthsInTreatment
		,rx.MedIssueDate
		,rx.MedReleaseDate
		,rx.MedRxStatus
		,rx.MedDrugStatus
		,rx.StimulantADHD_Rx

		--Providers
		,ISNULL(prov.GroupRowID,-1) AS GroupRowID 
		,prov.GroupID
		,prov.GroupLabel AS GroupType
		,prov.ProviderName
		,prov.ProviderSID
		,prov.ChecklistID AS ProviderLocation

		--Visit/Appointment Types 
		,ISNULL(appt.AppointmentID,ISNULL(v.AppointmentID,-1)) AS AppointmentID
		,ISNULL(appt.PrintName,v.PrintName) AS AppointmentType

		--Appointments
		,appt.StopCodeName AS AppointmentStop
		,appt.AppointmentDateTime
		,appt.ChecklistID AS AppointmentLocation

		--Visits 
		,v.StopCodeName AS VisitStop
		,v.VisitDateTime 
		,v.ChecklistID AS VisitLocation

	INTO #PatientDetails 
	FROM #CohortRowID a
	LEFT JOIN #MeasureUnmet mu 
		ON a.MVIPersonSID = mu.MVIPersonSID
		AND a.RowID = mu.MeasureID
	LEFT JOIN #Diagnosis dx 
		ON a.MVIPersonSID = dx.MVIPersonSID
		AND a.RowID = dx.DxID
	LEFT JOIN #Meds AS rx 
		ON a.MVIPersonSID = rx.MVIPersonSID
		AND a.RowID = rx.MedID
	LEFT JOIN #Assignments prov 
		ON a.MVIPersonSID = prov.MVIPersonSID 
		AND a.RowID = prov.GroupRowID
	LEFT JOIN #NextAppts appt 
		ON a.MVIPersonSID = appt.MVIPersonSID 
		AND a.RowID = appt.AppointmentID
	LEFT JOIN #LastVisit v 
		ON A.MVIPersonSID = v.MVIPersonSID 
		AND a.RowID = v.AppointmentID
	LEFT JOIN #Locations loc 
		ON a.MVIPersonSID = loc.MVIPersonSID 
		AND a.RowID = loc.LocationID
	LEFT JOIN [PDSI].[AUD_OUD_Active] aoud WITH (NOLOCK)
		ON a.MVIPersonSID = aoud.MVIPersonSID
	WHERE --Only keep rows with some kind of detail data (for when there are too many patient rows IN #CohortRowID)
		COALESCE
			(
				 mu.MeasureID
				,dx.DxID
				,rx.MedID
				,prov.GroupRowID
				,appt.AppointmentID
				,v.AppointmentID
				,loc.LocationID
			) IS NOT NULL

	--Housekeeping, remove non need Temp Tables to help manage TempDB
	DROP TABLE IF EXISTS #MeasureUnmet
	DROP TABLE IF EXISTS #Diagnosis
	DROP TABLE IF EXISTS #Meds
	DROP TABLE IF EXISTS #Assignments
	DROP TABLE IF EXISTS #NextAppts
	DROP TABLE IF EXISTS #LastVisit
	DROP TABLE IF EXISTS #Locations
		   
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientDetails: #PatientDetails'

	--------------------------------------------------------------------------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: #PatientDetails_ColorsAdded','Execution of Code.PDSI_PatientDetails #PatientDetails_ColorsAdded section'

	DROP TABLE IF EXISTS #PatientDetails_ColorsAdded
	SELECT 
		a.*
		,loc.Code AS LocationsColor 
		,loc.Facility AS LocationName
		,med.Code AS MedLocationColor 
		,med.Facility AS MedLocationName
		,prov.Code AS ProviderLocationColor 
		,prov.Facility AS ProviderLocationName
		,appt.Code AS AppointmentLocationColor 
		,appt.Facility AS AppointmentLocationName
		,vst.Code AS VisitLocationColor 
		,vst.Facility AS VisitLocationName
	INTO #PatientDetails_ColorsAdded
	FROM #PatientDetails a 
	LEFT JOIN [LookUp].[StationColors] loc WITH (NOLOCK) ON a.Locations = loc.ChecklistID
	LEFT JOIN [LookUp].[StationColors] med WITH (NOLOCK) ON a.MedLocation = med.ChecklistID
	LEFT JOIN [LookUp].[StationColors] prov WITH (NOLOCK) ON a.ProviderLocation = prov.ChecklistID
	LEFT JOIN [LookUp].[StationColors] appt WITH (NOLOCK) ON a.AppointmentLocation = appt.ChecklistID
	LEFT JOIN [LookUp].[StationColors] vst WITH (NOLOCK) ON a.VisitLocation = vst.ChecklistID
	
	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientDetails: #PatientDetails_ColorsAdded'

	--------------------------------------------------------------------------------------------------------------------------------------------
	--Combine everything else

	--Add IN fields from PDSI.AUD_OUD_Active?
	EXEC [Log].[ExecutionBegin] 'Code.PDSI_PatientDetails: #PDSI_PatientDetails','Execution of Code.PDSI_PatientDetails Staging #PDSI_PatientDetails section'
	
	DROP TABLE IF EXISTS #PDSI_PatientDetails
	SELECT DISTINCT 
		 pd.MVIPersonSID
		 --Patient Info
		,mp.PatientSSN
		,mp.LastFour
		,mp.PatientName
		,mp.Age
		,mp.DisplayGender as Gender
		,mp.Veteran

		,pd.Locations
		,pd.LocationName
		,pd.LocationsColor

		,pd.MeasureID
		,pd.Measure
		,pd.DetailsText
		,pd.DetailsDate
		,pd.MeasureUnmet

		-- If want naloxonekit/UDS/PDMP dates and AUDIT-C scores for all, then neeed to pull them out of the DetailsText?
		,pd.PTSD
		,pd.SUD
		,pd.MOUD_Key
		,pd.ALC_Top_Key
		,pd.PDMP
		,pd.NaloxoneKit
		,pd.UDS
		,pd.Age65_Eligible
		,pd.OpioidForPain_Rx
		,pd.Benzodiazepine5
		,pd.Benzodiazepine5_Schedule

		,pd.DxId
		,pd.Diagnosis
		,pd.DxCategory
		,pd.Category
		,pd.MedID
		,pd.DrugName
		,pd.PrescriberName
		,pd.MedType
		,pd.MedLocation
		,pd.MedLocationName
		,pd.MedLocationColor
		,pd.MonthsinTreatment
		,pd.MedIssueDate
		,pd.MedReleaseDate
		,pd.MedRxStatus
		,pd.MedDrugStatus
		,pd.GroupID 
		,pd.GroupType
		,pd.ProviderName
		,pd.ProviderSID
		,pd.ProviderLocation 
		,pd.ProviderLocationName
		,pd.ProviderLocationColor
		,pd.AppointmentID
		,pd.AppointmentType
		,pd.AppointmentStop
		,pd.AppointmentDateTime
		,pd.AppointmentLocation
		,pd.AppointmentLocationName
		,pd.AppointmentLocationColor 
		,pd.VisitStop
		,pd.VisitDateTime
		,pd.VisitLocation 
		,pd.VisitLocationName
		,pd.VisitLocationColor

		,pd.AUDActiveMostRecent
		,pd.OUDActiveMostRecent

		,pd.OpioidForPain5
		,pd.Sedative_zdrug5
		,pd.CM
		,pd.CBTSUD
		,pd.Vitals
		,pd.VitalsDate
		,pd.ADD_ADHD
		,pd.Narcolepsy
		,pd.BingeEating
		,pd.LastCBTSUD
		,pd.StimulantADHD_Rx
	INTO #PDSI_PatientDetails
	FROM #PatientDetails_ColorsAdded pd
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
		ON pd.MVIPersonSID = mp.MVIPersonSID

	EXEC [Log].[ExecutionEnd]	--'Code.PDSI_PatientDetails: #PDSI_PatientDetails'

--------------------------------------------------------------------------------------------------------------------------------------------
EXEC [Maintenance].[PublishTable] 'PDSI.PatientDetails', '#PDSI_PatientDetails'

EXEC [Log].[ExecutionEnd]

END