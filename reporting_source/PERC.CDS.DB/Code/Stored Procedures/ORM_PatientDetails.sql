-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/13/2017
-- Description: ORM Patient measures 
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
-- 01/09/18 - SM - added randomization categories for risk score for Evaluation Study
-- 01/09/18 - SM -rolling back randomization changes since architecture was updated. Randomization requirements are
				 -- now inherited from ORM.PatientReport (riskscirecategory and riskscorecategorylabel).. added publish table
-- 2020-03-30 - RAS - Formatting - added logging.
-- 2020-040-01	RAS	Changed ColumnName Psych_poss to Other_MH_STORM in #dx
-- 2020-07-14   CLB - Aligned with ORM_PatientReport so discontinued patients (with no PoH) will not
					--diplay an active Rx. Reformatted and annotated code; added sample test patients
					--for risk categories 6-9.
-- 2020-08-22	RAS	Made changes to staging joins to use LEFT instead of FULL OUTER JOINs to speed up query. 
					--Added LEFT JOIN to #VAMeds_OnlyActiveOpioids to replace "AND PatientICN NOT IN (SELECT PatientICN FROM #NoPills)" (faster)
-- 2020-09-14	LM	Pulling last and next appointment info from Present.AppointmentsPast and Present.AppointmentsFuture
-- 2020-09-18   CLB - Pulling opioid meds directly from ORM.OpioidHistory so as not to miss expired rx with pills on hand
-- 2020-10-09	LM	Pointing to _VM tables for Cerner overlay
-- 2020-10-13	PS	Changing to new definition of active medication
-- 2021-07-20	JEB Enclave Refactoring - Counts confirmed
-- 2021-09-15   TG changed the MPR table reference to the one coming from Rockies.
-- 2021-09-24   TG put CDS MPR table reference back since the one coming from Rockies is missing information
-- 2021-12-14   TG added ODPastYear cohort for the new STORM updates
-- 2021-12-16   TG removing a case statement that broke report logic.
-- 2022-01-20   TG putting STORM = 1 restriction back because of station assignment issues
-- 2022-05-09	  LM Group MH and Homeless visits and get most recent/next, due to change in Present.Appointments
-- 2022-05-19   AR updating to Rockies MPR
-- 2022-07-08	JEB Updated Synonym references to point to Synonyms from Core
-- 2022-11-15   AR Fixing gap between time it's written and time it makes it into MPR where it's pulling from previous trial
-- 2023-04-20   TG Adding new provider type (community care prescriber)
-- 2024-01-10   TG Fixing the PrintName for UDS where it's not required.
-- 2024-01-25   CW Updating 'BHIP' to 'MH/BHIP' re: [Present].[GroupAssignments_STORM]
-- 2024-03-12   TG adding DoD patients not included in PatientReport
-- 2024-10-01   CW Fixing bug related to MonthsInTreatment from [ORM].[DoDOUDPatientReport] 
-- 2024-11-29   TG Adding Chronic Opioid flag
-- 2025-01-10   TG Implementing PMOP changes to risk mitigation
-- 2025-01-15   SM updating to use new structure of integrated Present.NonVAMeds
-- 2025-02-03   TG adding MetricInclusion column for downstream use.
-- 02-06-2024	SM	added 12m lookback/active non va meds since integrated Present.NonVAMeds is more expansive for RV 2.0 implementation
-- 02-18-2024	SM	updated where clause to meet tall and skinny NonVAMed format 
-- 02-20-2024	SM	correcting opioid agonist exclusion- adding timeframe
-- 04-24-2025   TG  Adding unexpected drug screen results to patient details and facility patient reports
-- 04-25-2025   TG  Restricting the unexpected drug screen to Fentanyl
-- 05-21-2025   TG  Adding NonVA cannabis, Xylazine exposure
-- 05-28-2025   TG  Remedying an issue discovered during validation
-- 06-23-2025   TG  Adding NLP Concept column to enable link to snippets report
-- 07-23-2025   TG  Making "Elevated Risk Due To" language changes per PMOPT request
-- =============================================

CREATE PROCEDURE [Code].[ORM_PatientDetails]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails','Execution of Code.ORM_PatientDetails'

/*
Code.ORM_PatientDetails attaches report details to the cohort from 
ORM.PatientReport. Specifically, the following supporting information
is pulled from a number of PERC sources:
		-Next patient appointment
		-Last patient visit
		-Patient's group assignment
		-Relevant patient diagnoses
		-Risk mitigation strategies
		-Relevant patient meds
		-Locations associated with the patient
*/

----------------------------------------------------------------------------
-- STEP 1:  Create supporting tables used in one or more future joins
----------------------------------------------------------------------------

--Pull in cohort from ORM.PatientReport
DROP TABLE IF EXISTS #Cohort
SELECT DISTINCT
	oc.MVIPersonSID
INTO #Cohort
FROM [ORM].[PatientReport] AS oc WITH (NOLOCK)

	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails ApptsVisits','Execution of Code.ORM_PatientDetails Appointments and Visits section' -- ~1:45
	
----------------------------------------------------------------------------
-- STEP 2:  Identify the next appointment 
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #FutureAppts
SELECT p.MVIPersonSID
	,CASE WHEN f.ApptCategory='PCFuture' THEN 'Primary Care Appointment'
		WHEN f.ApptCategory='MHFuture' THEN 'MH Appointment'
		WHEN f.ApptCategory='PainFuture' THEN 'Specialty Pain'
		ELSE 'OtherRecent'
		END AS PrintName
	,f.PrimaryStopCodeName AS StopCodeName
	,f.ChecklistID
	,f.AppointmentDatetime
	,ROW_NUMBER() OVER (PARTITION BY f.MVIPersonSID, f.ApptCategory ORDER BY f.AppointmentDateTime) rn 
INTO #FutureAppts
FROM #Cohort as p 
INNER JOIN (
	SELECT MVIPersonSID 
		,CASE WHEN ApptCategory='HomelessFuture' THEN 'MHFuture' 
			ELSE ApptCategory 
			END AS ApptCategory
		,PrimaryStopCodeName
		,ChecklistID
		,AppointmentDateTime
	FROM [Present].[AppointmentsFuture]  WITH (NOLOCK)
	WHERE NextAppt_ICN=1
		AND ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PainFuture','OtherFuture')
	) f ON p.MVIPersonSID=f.MVIPersonSID
WHERE AppointmentDateTime BETWEEN 
	CAST(GETDATE() as DATETIME2(0)) 
		AND DATEADD(d,370,CAST(GETDATE() as DATETIME2(0)))

DROP TABLE IF EXISTS #NextAppts
SELECT MVIPersonSID
	,PrintName
	,StopCodeName
	,ChecklistID
	,AppointmentDateTime
	,DENSE_RANK() OVER(ORDER BY PrintName) as AppointmentID 
INTO #NextAppts
FROM #FutureAppts
WHERE rn=1 --group MH and Homeless appointment and get next - 'MH Appointment'

	DROP TABLE #FutureAppts
----------------------------------------------------------------------------
-- STEP 3:  Identify the last visit
----------------------------------------------------------------------------

DROP TABLE IF EXISTS #RecentVisits
SELECT 
	p.MVIPersonSID
	,CASE WHEN f.ApptCategory='PCRecent' THEN 'Primary Care Appointment'
		WHEN f.ApptCategory='MHRecent' THEN 'MH Appointment'
		WHEN f.ApptCategory='PainRecent' THEN 'Specialty Pain'
		ELSE 'OtherRecent'
		END AS PrintName
	,f.PrimaryStopCodeName AS StopCodeName
	,f.ChecklistID
	,f.VisitDatetime
	,ROW_NUMBER() OVER (PARTITION BY f.MVIPersonSID, f.ApptCategory ORDER BY f.VisitDateTime DESC) rn 
INTO #RecentVisits
FROM #Cohort as p 
INNER JOIN 
	(SELECT MVIPersonSID
		,CASE WHEN ApptCategory='HomelessRecent' THEN 'MHRecent' 
			ELSE ApptCategory 
			END AS ApptCategory
		,PrimaryStopCodeName
		,ChecklistID
		,VisitDateTime
	FROM [Present].[AppointmentsPast]  WITH (NOLOCK)
	WHERE MostRecent_ICN=1
		AND ApptCategory in ('PCRecent','MHRecent','HomelessRecent','PainRecent','OtherRecent')
	) f ON p.MVIPersonSID=f.MVIPersonSID

DROP TABLE IF EXISTS #LastVisit
SELECT MVIPersonSID
	,PrintName
	,StopCodeName
	,ChecklistID
	,VisitDateTime
	,DENSE_RANK() OVER(ORDER BY PrintName) as AppointmentID 
INTO #LastVisit
FROM #RecentVisits
WHERE rn=1 --group MH and Homeless visit and get most recent - 'MH Appointment'
	
	DROP TABLE #RecentVisits

	EXEC [Log].[ExecutionEnd] --Appts/Visits

----------------------------------------------------------------------------
-- STEP 4:  Determine group assignments
----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails GrpAssign','Execution of Code.ORM_PatientDetails Group Assignments section' -- ~:51
--Pull group assignments of interest
DROP TABLE IF EXISTS #Assignments
SELECT g.MVIPersonSID
	,g.GroupID
	,g.GroupType
	,g.ProviderSID 
	,g.ProviderName  
	,g.ChecklistID
	,g.Sta3n
	,g.VISN
	,CASE WHEN ProviderSID > 0 THEN 1 ELSE 0 END as Assigned
	,ROW_NUMBER() OVER(PARTITION BY g.MVIPersonSID ORDER BY g.GroupType) as GroupRowID
	,CASE WHEN GroupType = 'PCP' THEN 'Primary Care Provider'
		WHEN GroupType = 'MH/BHIP' THEN 'BHIP Team' 
		WHEN GroupType = 'MHTC' THEN 'MH Tx Coordinator'
		WHEN GroupType = 'PACT' THEN 'PACT Team' 
		WHEN GroupType = 'VA Opioid Prescriber' THEN 'VA Opioid Prescriber'
		WHEN GroupType = 'Community Care Prescriber' THEN 'Community Care Prescriber'
		--
	END GroupLabel
INTO #Assignments
FROM [Present].[GroupAssignments_STORM] g  WITH (NOLOCK)
	INNER JOIN [Present].[StationAssignments] as sa  WITH (NOLOCK)
		ON g.MVIPersonSID = sa.MVIPersonSID 
			AND g.ChecklistID = sa.ChecklistID
			AND STORM = 1
WHERE g.GroupType in ('PCP','MH/BHIP','MHTC','PACT','VA Opioid Prescriber', 'Community Care Prescriber') 
	--AND ProviderSID > 0 
	   	
	EXEC [Log].[ExecutionEnd] --Group Assignments
----------------------------------------------------------------------------
-- STEP 5:  Collect diagnosis information
----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails Dx','Execution of Code.ORM_PatientDetails Diagnosis section' -- ~1:37

----NOTE: Consider replacing with Present.Diagnosis since it is already unpivoted and you could avoid that step here.
----Present.Diagnosis is the source of the information in ORM.RiskScore and ORM.Cohort, so it should match. 
----It might also be the case that it doesn't need to be in the Cohort table

--Select dx of interest
DROP TABLE IF EXISTS #DxCategories
SELECT a.MVIPersonSID
	,[EH_AIDS]
	,[EH_CHRNPULM] 
	,[EH_COMDIAB] 
	,[EH_ELECTRLYTE]
	,[EH_HYPERTENS] 
	,[EH_LIVER] 
	,[EH_NMETTUMR] 
	,[EH_OTHNEURO] 
	,[EH_PARALYSIS] 
	,[EH_PEPTICULC] 
	,[EH_PERIVALV] 
	,[EH_RENAL] 
	,[EH_HEART] 
	,[EH_ARRHYTH]  
	,[EH_VALVDIS] 
	,[EH_PULMCIRC] 
	,[EH_HYPOTHY]   
	,[EH_RHEUMART] 
	,[EH_COAG] 
	,[EH_WEIGHTLS]  
	,[EH_DefANEMIA]
	,[SAE_Falls]
	,[SAE_OtherAccident]
	,[SAE_OtherDrug]
	,[SAE_Vehicle]
	,[SAE_Acet]
	,[SAE_sed]
	--,[SedateIssue] --removed due to it being an umbrella field
	,a.[OUD]
	,[OpioidOverdose]
	,[SleepApnea]
	,[Osteoporosis]
	,[NicDx_Poss]
	,[EH_LYMPHOMA]
	,[Suicide]
	,[EH_OBESITY] 
	,[EH_BLANEMIA]
	,[PTSD]
	,[BIPOLAR]
	,[SedativeUseDisorder]
 	,[AUD_ORM]  --new
	--,[SUDdx_poss] --removed due to it being an umbrella field
	--,[Overdose_Suicide] --removed due to it being an umbrella field
	,[AnySAE] --new
	,[Other_MH_STORM] 
	,[SUD_NoOUD_NoAUD] --added back in per JT recommendation
	,[MDD] --new
	,[OtherSUD_RiskModel] --new
	,[CannabisUD_HallucUD] --new
	,[CocaineUD_AmphUD] --new
	,[EH_UNCDIAB] --new			
	,[EH_METCANCR] --new 
	--,[COCNdx] removed because has CocaineUD_AmphUD so would overlap
	/*--these are excluded as they are not present in ORM.RiskScore
	--or they are in a slightly diff column; however, may be reviewed for inclusion later
	,[Cannabis]
	,[DEPRESS]
	,[OtherMH]
	,[AUD]
	,AmphetamineUseDisorder  
	,case when a.EH_COMDIAB = 1 then 0 else EH_UNCDIAB end EH_UNCDIAB  
	,case when a.SedativeUseDisorder = 1 or a.AmphetamineUseDisorder = 1 or  a.[Cannabis] = 1  or a.[NicDx_Poss] = 1 or a.AUD = 1 or a.OUD = 1 or a.[OpioidOverdose] = 1  
	then 0 else [SUD_Active_Dx] end [SUD_Active_Dx]
	*/
INTO #DxCategories
FROM [ORM].[RiskScore] as a  WITH (NOLOCK)

--Unpivot dx table and make columns into row values. 
--Select only those rows with an indicator of 1.
--Join with Lookup.ColumnDescriptions for PrintName, etc.
DROP TABLE IF EXISTS #Dx
SELECT DISTINCT u.MVIPersonSID
	,cd.PrintName
	,u.DxCategory
	,cd.Category
	,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY cd.Category, cd.PrintName) as DxID
INTO #Dx
FROM #DxCategories p
	UNPIVOT (Flag FOR DxCategory IN 
					([EH_AIDS]
					,[EH_CHRNPULM] 
					,[EH_COMDIAB] 
					,[EH_ELECTRLYTE]
					,[EH_HYPERTENS] 
					,[EH_LIVER] 
					,[EH_NMETTUMR] 
					,[EH_OTHNEURO] 
					,[EH_PARALYSIS] 
					,[EH_PEPTICULC] 
					,[EH_PERIVALV] 
					,[EH_RENAL] 
					,[EH_HEART] 
					,[EH_ARRHYTH]  
					,[EH_VALVDIS] 
					,[EH_PULMCIRC] 
					,[EH_HYPOTHY]   
					,[EH_RHEUMART] 
					,[EH_COAG] 
					,[EH_WEIGHTLS]  
					,[EH_DefANEMIA]
					,[SAE_Falls]
					,[SAE_OtherAccident]
					,[SAE_OtherDrug]
					,[SAE_Vehicle]
					,[SAE_Acet]
					,[SAE_sed]
					,[OUD]
					,[OpioidOverdose]
					,[SleepApnea]
					,[Osteoporosis]
					,[NicDx_Poss]
					,[EH_LYMPHOMA]
					,[Suicide]
					,[EH_OBESITY] 
					,[EH_BLANEMIA]
					,[PTSD]
					,[BIPOLAR]
					,[SedativeUseDisorder]
 					,[AUD_ORM]  
					,[AnySAE] 
					,[Other_MH_STORM]
					,[SUD_NoOUD_NoAUD] 
					,[MDD] 
					,[OtherSUD_RiskModel]
					,[CannabisUD_HallucUD]
					,[CocaineUD_AmphUD]
					,[EH_UNCDIAB]		
					,[EH_METCANCR]  
					)
	) as u
	INNER JOIN (
		SELECT ColumnName,Category,PrintName
		FROM [LookUp].[ColumnDescriptions]  WITH (NOLOCK)
		WHERE TableName = 'ICD10'
		) as cd ON u.DxCategory = cd.ColumnName
	WHERE u.Flag > 0 

	DROP TABLE #DxCategories
	EXEC [Log].[ExecutionEnd] --Dx
----------------------------------------------------------------------------
-- STEP 6:  Collect medication information
----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails Meds','Execution of Code.ORM_PatientDetails Medication section'

--Pull all qualifying VA active (pills on hand or active status) opioids and non-opioids from Present.Medications
DROP TABLE IF EXISTS #VAMeds
SELECT DISTINCT m.MVIPersonSID
	,PrescriberName
  ,DrugNameWithDose
	,DrugNameWithoutDose
	,CASE WHEN m.OpioidForPain_Rx = 1 THEN 'Opioid Analgesics'
		WHEN m.Anxiolytics_Rx = 1 THEN 'Co-Prescribed Sedating Medications'
		WHEN m.SedatingPainORM_rx = 1 THEN 'Pain Medications (Sedating)'
	END MedType 
	,CHOICE
	,sta6a
	,RxOutpatSID
INTO #VAMeds
FROM [Present].[Medications] m  WITH (NOLOCK)
INNER JOIN #Cohort c ON m.MVIPersonSID = c.MVIPersonSID
WHERE m.Anxiolytics_Rx = 1 
	OR m.SedatingPainORM_Rx = 1 
	OR m.OpioidforPain_Rx = 1

--Attach additional information for VA meds
DROP TABLE IF EXISTS #VAMeds_Detail
SELECT distinct m.MVIPersonSID
	,m.PrescriberName
  --,m.DrugNameWithDose
    ,m.DrugNameWithoutDose
	,m.MedType
    ,st.ChecklistID
	,st.ADMPARENT_FCDM 
	,isnull(o.MonthsInTreatment,d.MonthsInTreatment) as MonthsInTreatment
	,m.CHOICE
INTO #VAMeds_Detail
FROM #VAMeds as m
	LEFT JOIN [LookUp].[Sta6a] as st  WITH (NOLOCK) ON m.Sta6a=st.Sta6a
	LEFT JOIN (
			SELECT DISTINCT MVIPersonSID
				 ,PatientSID
				,c.NationalDrugSID
        ,a.DrugNameWithDose 
				,LastRxOutpatSID_Sta3n as  Sta3n
				,MonthsInTreatment
				,LastRxOutpatSID as RxOutpatSID
			FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] as a  WITH (NOLOCK)
			inner join RxOut.RxOutpat as b  WITH (NOLOCK) on a.LastRxOutpatSID = b.RxOutpatSID
      inner join lookup.nationaldrug as c  WITH (NOLOCK) on b.nationaldrugSID = c.NationalDrugSID
      where OpioidforPain_Rx = 1 and MostRecentTrialFlag = 'True' and ActiveMedicationFlag='True'
		) as o 
		ON m.mvipersonsid = o.MVIPersonSID and m.DrugNameWithDose = o.DrugNameWithDose
left outer join  ( 
      	SELECT DISTINCT MVIPersonSID
				, PatientSID
				,b.NationalDrugSID
        ,c.DrugNameWithoutDose 
				,LastRxOutpatSID_Sta3n as  Sta3n
				,MonthsInTreatment
				,LastRxOutpatSID as RxOutpatSID
			FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] as a  WITH (NOLOCK)
			inner join RxOut.RxOutpat as b WITH (NOLOCK) on a.LastRxOutpatSID = b.RxOutpatSID
      inner join lookup.nationaldrug as c WITH (NOLOCK) on b.nationaldrugSID = c.NationalDrugSID
      where ( Anxiolytics_Rx = 1 	OR SedatingPainORM_Rx = 1 ) and MostRecentTrialFlag = 'True' and ActiveMedicationFlag='True'
		) as d
		ON m.mvipersonsid = d.MVIPersonSID and m.DrugNameWithoutDose = d.DrugNameWithoutDose


--Pull available information for qualifying Non-VA meds.
--Note: Patients in categories 6-9 (recently discontinued)
--may still have active Non-VA meds, which will display.
--Per PS, this inconsistency is okay, since messaging to the 
--field has emphasized the focus on VA meds and the poor
--data quality for Non-VA. 
DROP TABLE IF EXISTS #NonVAMeds
SELECT a.MVIPersonSID
	,'Non-VA Prescriber' as PrescriberName
	,DrugNameWithoutDose=a.DrugNameWithoutDose_Max  -- renaming to updated Present.NonVaMed table structure
	,'Non-VA' as MedType 
	,'' as ChecklistID
	,'' as ADMPARENT_FCDM
	,NULL as Monthsintreatment 
	,0 as CHOICE
INTO #NonVAMeds
FROM [Present].[NonVAMed] a WITH (NOLOCK)
LEFT join (
			select MVIPersonSID
			from [Present].[NonVAMed] 
			where 1=1
			AND SetTerm in ('OpioidAgonist_RX')
			AND [InstancetoDate] IS NULL	
			AND [InstanceFromDate] >=  DATEADD(month, -12, CAST(GETDATE() AS DATE))
			) b on a.MVIPersonSID=b.MVIPersonSID
WHERE a.SetTerm in ('OpioidforPain','Anxiolytic','SedatingPainORM_Rx','ControlledSubstance') --expanding to include all controlled substances
AND a.[InstancetoDate] IS NULL	
AND a.[InstanceFromDate] >=  DATEADD(month, -12, CAST(GETDATE() AS DATE))
and b.MVIpersonSID is NULL -- exclude OpioidAgonist_RX


--Pull active MOUD on record
DROP TABLE IF EXISTS #MOUD
SELECT MVIPersonSID
	  ,Prescriber as PrescriberName
	  ,MOUD as DrugNameWithoutDose
	  ,'MOUD' as MedType
	  ,ck.ChecklistID
	  ,ck.ADMPARENT_FCDM
	  ,NULL as Monthsintreatment
	  ,0 as CHOICE
INTO #MOUD
FROM [Present].[MOUD] m WITH (NOLOCK)
INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON ck.StaPa = m.StaPa
WHERE ActiveMOUD = 1

--Combine VA and Non-VA med information
DROP TABLE IF EXISTS #Meds
SELECT m.*
	,ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID ORDER BY m.DrugNameWithoutDose) as MedID
INTO #Meds
FROM (SELECT DISTINCT MVIPersonSID FROM #Cohort) co
INNER JOIN (
	SELECT *
	FROM #VAMeds_Detail
	UNION ALL 
	SELECT *
	FROM #NonVAMeds
	UNION ALL
	SELECT *
	FROM #MOUD
	) m ON m.MVIPersonSID=co.MVIPersonSID


	EXEC [Log].[ExecutionEnd] --meds
----------------------------------------------------------------------------
-- STEP 7:  Collect location information
----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails Loc','Execution of Code.ORM_PatientDetails Locations section'

--Pull in facility information via ChecklistID
DROP TABLE IF EXISTS #Locations_STORM
SELECT co.MVIPersonSID
	  ,loc.ChecklistID
	  ,ROW_NUMBER() OVER(PARTITION BY loc.MVIPersonSID ORDER BY loc.Checklistid) as LocationID
INTO #Locations_STORM
FROM #Cohort co
INNER JOIN [Present].[StationAssignments] as loc ON loc.MVIPersonSID=co.MVIPersonSID
WHERE loc.STORM=1;


--Catching any CC locations of Veteran's not accounted for in [Present].[StationAssignments]
--Using ORM.PatientReport because the ChecklistID has already been mapped correctly to CommunityCare_ODPastYear
DROP TABLE IF EXISTS #Locations_CC 
SELECT co.MVIPersonSID
	  ,loc.ChecklistID
	  ,ROW_NUMBER() OVER(PARTITION BY loc.MVIPersonSID ORDER BY loc.Checklistid) as LocationID
INTO #Locations_CC
FROM #Cohort co
INNER JOIN ORM.PatientReport as loc WITH (NOLOCK) ON co.MVIPersonSID=loc.MVIPersonSID;


DROP TABLE IF EXISTS #Locations
SELECT * INTO #Locations FROM #Locations_STORM
UNION
SELECT * FROM #Locations_CC --If patient isn't in StationAssignment, use ChecklistID from CC Overdose data per Code.ORM_PatientReport #Locations logic


  EXEC [Log].[ExecutionEnd] --Loc
----------------------------------------------------------------------------
-- STEP 8:  Assemble patient details into final table
----------------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails Stage1','Execution of Code.ORM_PatientDetails #PatientDetails section'

--The original method for ORM.PatientDetails was to employ a 
--FULL OUTER JOIN (FOJ) multiple times in this code when joining details tables.
--The join occurs on both PatientICN and category IDs, the 
--latter being unique to each table. Although these IDs are 
--NOT external linking keys, joining on them in the FOJ 
--context is appropriate in order to minimize the information 
--duplicated across rows. Either, an ID will have the same
--value in both details tables, in which case the two respective
--rows will be slotted together into one longer row, or the ID
--value will be unique to one, in which case its rows are slotted
--with an empty row of the other (populated by an ID of -1 and NULL 
--values in the other columns). A FOJ that joins solely on PatientICN
--would repeat rows from both details tables, slotting them together
--in every possible combination of IDs.

--In order to improve efficiency, a series of LEFT JOINS is used
--to pull all this data together, but in order to accomplish the 
--same goal, we have to first ensure all PatientICNs and detail IDs 
--are acconted for in the first table that is left joined.
--#CohortRowID is a table with every PatientICN and RowID from
--1 to the maximum possible number of rows from any of the detail tables.
--Also, I (RAS) tried adding indexes to detail tables, but the time it took to 
--create the indexes did not seem to justify the small improvement in run time

	--CREATE TABLE WITH MAX NUMBER OF ROWS PER PATIENT
	----Creating this table to test if left joins are faster than the many full outer joins
	DROP TABLE IF EXISTS #RowID
	CREATE TABLE #RowID (RowID INT NOT NULL)
	--Get the max row number
	DECLARE @MaxID INT = (
		SELECT MAX(ID) 
		FROM (
			SELECT MitigationID ID FROM [ORM].[RiskMitigation]
			UNION ALL
			SELECT DxID FROM #Dx
			UNION ALL
			SELECT MedID FROM #Meds
			UNION ALL
			SELECT GroupRowID FROM #Assignments
			UNION ALL
			SELECT AppointmentID FROM #NextAppts
			UNION ALL
			SELECT AppointmentID FROM #LastVisit
			UNION ALL
			SELECT LocationID FROM #Locations
			) a	)
	DECLARE @Counter INT = 1
	WHILE @Counter <= @MaxID
	BEGIN
		INSERT INTO #RowID
		SELECT @Counter

		SET @Counter = @Counter+1

	END
	
	DROP TABLE IF EXISTS #CohortRowID
	SELECT DISTINCT 
		MVIPersonSID
		,RowID
	INTO #CohortRowID
	FROM #Cohort,#RowID
	ORDER BY MVIPersonSID,RowID

	--Validate:
	--SELECT (SELECT count(*) FROM #RowID)*(SELECT count(distinct PatientICN) FROM #Cohort)
	--SELECT count(*) FROM #CohortRowID

--Begin with all possible PatientICN and ID combinations then join all detail tables
DROP TABLE IF EXISTS #PatientDetails
SELECT a.MVIPersonSID
	  --Locations
	  ,loc.ChecklistID as Locations
	  
	  --Risk mitigation
	  ,ISNULL(rm.MitigationID,-1) as MitigationID
	  ,rm.PrintName as RiskMitigation
	  ,rm.DetailsText
	  ,rm.DetailsDate
	  ,rm.Checked
	  ,rm.Red
	  ,rm.[MitigationIDRx]
      ,rm.[PrintNameRx]
      ,rm.[CheckedRx]
      ,rm.[RedRx]
	  ,rm.MetricInclusion
	  --Dx
	  ,ISNULL(dx.DxID,-1) as DxID
	  ,dx.PrintName as Diagnosis
	  ,dx.DxCategory as ColumnName
	  ,dx.Category

	  --Meds
	  ,ISNULL(meds.MedID,-1) AS MedID
	  ,meds.DrugNameWithoutDose
	  ,meds.PrescriberName
	  ,meds.MedType
	  ,meds.ChecklistID as  MedLocation
	  ,meds.MonthsinTreatment
	  ,meds.CHOICE

	  --Providers
	  ,ISNULL(prov.GroupRowID,-1) as GroupRowID 
	  ,prov.GroupID
	  ,prov.GroupLabel as GroupType
	  ,prov.ProviderName
	  ,prov.ProviderSID
	  ,prov.ChecklistID as ProviderLocation

	  --Visit/Appointment Types 
	  ,ISNULL(appt.AppointmentID,ISNULL(v.AppointmentID,-1)) as AppointmentID
	  ,ISNULL(appt.PrintName,v.PrintName) as AppointmentType

	  --Appointments
	  ,appt.StopCodeName as AppointmentStop
	  ,appt.AppointmentDateTime
	  ,appt.ChecklistID as AppointmentLocation

	  --Visits 
	  ,v.StopCodeName as VisitStop
	  ,v.VisitDateTime 
	  ,v.ChecklistID as VisitLocation
INTO #PatientDetails
FROM #CohortRowID a
	LEFT JOIN [ORM].[RiskMitigation] AS rm WITH (NOLOCK) ON
		a.MVIPersonSID=rm.MVIPersonSID AND (rm.MetricInclusion = 1 OR (rm.MitigationID IN (1, 3, 5, 8, 10) AND rm.MetricInclusion = 0))
		AND a.RowID=rm.MitigationID
	LEFT JOIN #Dx AS dx ON
		a.MVIPersonSID=dx.MVIPersonSID
		AND a.RowID=dx.DxID
	LEFT JOIN #Meds AS meds ON 
		a.MVIPersonSID = meds.MVIPersonSID 
		AND a.RowID = meds.MedID
	LEFT JOIN #Assignments AS prov ON 
		a.MVIPersonSID = prov.MVIPersonSID 
		AND a.RowID = prov.GroupRowID
	LEFT JOIN #NextAppts as appt ON 
		a.MVIPersonSID = appt.MVIPersonSID 
		AND a.RowID = appt.AppointmentID
	LEFT JOIN #LastVisit as v ON 
		A.MVIPersonSID = v.MVIPersonSID 
		AND a.RowID = v.AppointmentID
	LEFT JOIN #Locations as loc ON 
		a.MVIPersonSID = loc.MVIPersonSID 
		AND a.RowID = loc.LocationID
WHERE --Only keep rows with some kind of detail data (for when there are too many patient rows in #CohortRowID)
	COALESCE(rm.MitigationID
		,dx.DxID
		,meds.MedID
		,prov.GroupRowID
		,appt.AppointmentID
		,v.AppointmentID
		,loc.LocationID
		) IS NOT NULL

		----NOTE: Validation could be added here to make sure all data from contributing tables is included

--Add station colors for all location information
--1000796364 has 8 stations
--select top 1 * from #PatientDetails_ColorsAdded
DROP TABLE IF EXISTS #PatientDetails_ColorsAdded
SELECT a.*
	  ,loc.Code as LocationsColor 
	  ,loc.Facility as LocationName
	  ,med.Code as MedLocationColor 
	  ,med.Facility as MedLocationName
	  ,prov.Code as ProviderLocationColor 
	  ,prov.Facility as ProviderLocationName
	  ,appt.Code as AppointmentLocationColor 
	  ,appt.Facility as AppointmentLocationName
	  ,vst.Code as VisitLocationColor 
	  ,vst.Facility as VisitLocationName
INTO #PatientDetails_ColorsAdded
FROM #PatientDetails as a 
	LEFT JOIN [LookUp].[StationColors] as loc WITH (NOLOCK) ON a.Locations = loc.ChecklistID
	LEFT JOIN [LookUp].[StationColors] as med WITH (NOLOCK) ON a.MedLocation = med.ChecklistID
	LEFT JOIN [LookUp].[StationColors] as prov WITH (NOLOCK) ON a.ProviderLocation = prov.ChecklistID
	LEFT JOIN [LookUp].[StationColors] as appt WITH (NOLOCK) ON a.AppointmentLocation = appt.ChecklistID
	LEFT JOIN [LookUp].[StationColors] as vst WITH (NOLOCK) ON a.VisitLocation = vst.ChecklistID

--Get positive xylazine exposure
DROP TABLE IF EXISTS #XylazineExposure
     SELECT nlp.MVIPersonSID, Concept  
        INTO #XylazineExposure
      FROM [Present].[NLP_Variables] nlp WITH (NOLOCK)
        WHERE nlp.Concept = 'XYLA'

--Combine with ORM.PatientReport and Present.MOUD
DROP TABLE IF EXISTS #ORM_PatientDetails
SELECT DISTINCT pr.MVIPersonSID

	  ,sc.Locations
      ,sc.LocationName 
      ,sc.LocationsColor

    --  ,[Facility]
   --   ,[VISN]
	  ,pr.OUD
	  ,pr.OpioidForPain_Rx
      ,pr.SUDdx_poss
      ,pr.Hospice
	 -- ,null as opioidprescribersid
	 -- ,null as opioidprescriber
    --,pr.[Sta3n]
	  ,pr.RiskCategory
	  ,pr.RiskCategorylabel
	  ,pr.RiskAnyCategory
	  ,pr.RiskAnyCategorylabel
	  ,pr.RiskScore
	  ,pr.RiskScoreAny
	  ,pr.RiskScoreAnyOpioidSedImpact
	  ,pr.RiskScoreOpioidSedImpact
      ,pr.[RM_ActiveTherapies_Key]
      ,pr.[RM_ActiveTherapies_Date]
      ,pr.[RM_ChiropracticCare_Key]
      ,pr.[RM_ChiropracticCare_Date]
      ,pr.[RM_OccupationalTherapy_Key]
      ,pr.[RM_OccupationalTherapy_Date]
      ,pr.[RM_OtherTherapy_Key]
      ,pr.[RM_OtherTherapy_Date]
      ,pr.[RM_PhysicalTherapy_Key]
      ,pr.[RM_PhysicalTherapy_Date]
      ,pr.[RM_SpecialtyTherapy_Key]
      ,pr.[RM_SpecialtyTherapy_Date]
      ,pr.[RM_PainClinic_Key]
      ,pr.[RM_PainClinic_Date]
      ,pr.[CAM_Key]
      ,pr.[CAM_Date]
      ,pr.RiosordScore
      ,pr.RiosordRiskClass
	  --,pr.BaselineMitigationsMet

	  ,d.RiskMitScore
	  ,d.MaxMitigations

	  ,pr.PatientRecordFlag_Suicide
	  ,pr.REACH_01
	  ,pr.REACH_Past

	  ,sc.MitigationID
	  ,sc.RiskMitigation
	  ,sc.DetailsText
	  ,sc.DetailsDate
	  ,sc.Checked
	  ,sc.Red
	  ,sc.[MitigationIDRx]
      ,sc.[PrintNameRx]
      ,sc.[CheckedRx]
      ,sc.[RedRx]
	  ,sc.MetricInclusion
	  ,sc.DxId
	  ,sc.Diagnosis
	  ,sc.ColumnName
	  ,sc.Category
	  ,sc.MedID
	  ,sc.DrugNameWithoutDose
	  ,sc.PrescriberName
	  ,sc.MedType
	  ,sc.CHOICE
	  ,sc.MedLocation
	  ,sc.MedLocationName
	  ,sc.MedLocationColor
	  ,sc.MonthsinTreatment  
	  ,sc.GroupID 
	  ,sc.GroupType
	  ,sc.ProviderName
	  ,sc.ProviderSID
	  ,sc.ProviderLocation 
	  ,sc.ProviderLocationName
	  ,sc.ProviderLocationColor
	  ,sc.AppointmentID
	  ,sc.AppointmentType
	  ,sc.AppointmentStop
	  ,sc.AppointmentDateTime
	  ,sc.AppointmentLocation
	  ,sc.AppointmentLocationName
	  ,sc.AppointmentLocationColor 
	  ,sc.VisitStop
	  ,sc.VisitDateTime
	  ,sc.VisitLocation 
	  ,sc.VisitLocationName
	  ,sc.VisitLocationColor

	  ,d.ReceivingCommunityCare

	  ,CASE WHEN m.ActiveMOUD_Patient = 1 THEN 1
			WHEN m.ActiveMOUD_Patient = 0 THEN 0
			ELSE 2
	   END AS ActiveMOUD_Patient
	  ,CASE WHEN n.MVIPersonSID IS NOT NULL THEN 1
			ELSE 0
	   END AS NonVA_Meds
	   ,pr.ODPastYear
	   ,pr.ODdate
	   ,oh.ChronicOpioid
	   ,idu.Details
	   ,ca.OrderName AS NonVACannabis
	   ,CASE WHEN xy.MVIPersonSID IS NOT NULL THEN 'Xylazine Exposure'
	      ELSE NULL END AS XylazineExposure
		,xy.Concept
INTO #ORM_PatientDetails
FROM #PatientDetails_ColorsAdded AS sc
	INNER JOIN [ORM].[PatientReport] AS pr WITH (NOLOCK)
		ON pr.MVIPersonSID = sc.MVIPersonSID 
	INNER JOIN (
				SELECT MVIPersonSID
					  ,COUNT(distinct RiskMitigation) as MaxMitigations
					  ,SUM(checked) RiskMitScore
					  ,case when MAX(CHOICE) > 0 then 1 end as ReceivingCommunityCare
				FROM #PatientDetails_ColorsAdded 
				GROUP BY MVIPersonSID
				) AS d 
		ON pr.MVIPersonSID = d.MVIPersonSID 
	LEFT JOIN Present.MOUD AS m WITH (NOLOCK) 
		ON pr.MVIPersonSID = m.MVIPersonSID
	LEFT JOIN #NonVAMeds AS n WITH (NOLOCK)
		ON pr.MVIPersonSID = n.MVIPersonSID
	LEFT JOIN (SELECT MVIPersonSID, MAX(ChronicOpioid) AS ChronicOpioid 
            FROM [ORM].[OpioidHistory] WITH(NOLOCK)
			WHERE ActiveRxStatusVM=1 AND ChronicOpioid = 1
            GROUP BY MVIPersonSID )oh
		ON pr.MVIPersonSID = oh.MVIPersonSID
		LEFT JOIN (SELECT MVIPersonSID, Details FROM [SUD].[IDUEvidence] WITH(NOLOCK)
	            WHERE EvidenceType = 'Drug Screen' AND Details LIKE '%Fentanyl%') AS idu
				ON sc.MVIPersonSID = idu.MVIPersonSID
       LEFT JOIN (SELECT MVIPersonSID, OrderName
				FROM [Present].[NonVAMed] WITH(NOLOCK)
                  WHERE SetTerm = 'Marijuana'
	           ) AS ca
			    ON sc.MVIPersonSID = ca.MVIPersonSID
	   LEFT JOIN #XylazineExposure AS xy
				  ON sc.MVIPersonSID = xy.MVIPersonSID

	EXEC [Log].[ExecutionEnd] --Stage1

	EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_PatientDetails DeID','Execution of Code.ORM_PatientDetails Add deidentified data section'


--Create de-identified sample data and insert into #ORM_PatientDetails
INSERT INTO #ORM_PatientDetails 
SELECT a.MVIPersonSID
	,c.Locations
	,c.LocationName
	,c.LocationsColor
	,c.OUD
	,c.OpioidForPain_Rx
	,c.SUDdx_poss
	,1 as Hospice
	,c.RiskCategory
	,c.RiskCategorylabel
	,c.RiskAnyCategory
	,c.RiskAnyCategorylabel
	,c.RiskScore
	,c.RiskScoreAny
	,c.RiskScoreAnyOpioidSedImpact
	,c.RiskScoreOpioidSedImpact
	,c.RM_ActiveTherapies_Key
	,DATEADD(year,-2,c.RM_ActiveTherapies_Date) as RM_ActiveTherapies_Date
	,c.RM_ChiropracticCare_Key
	,DATEADD(year,-5,c.RM_ChiropracticCare_Date) as RM_ChiropracticCare_Date
	,c.RM_OccupationalTherapy_Key
	,DATEADD(year,-3,c.RM_OccupationalTherapy_Date) as RM_OccupationalTherapy_Date
	,c.RM_OtherTherapy_Key
	,DATEADD(year,-6,c.RM_OtherTherapy_Date) as RM_OtherTherapy_Date
	,c.RM_PhysicalTherapy_Key
	,DATEADD(year,-1,c.RM_PhysicalTherapy_Date) as RM_PhysicalTherapy_Date
	,c.RM_SpecialtyTherapy_Key
	,DATEADD(year,-2,c.RM_SpecialtyTherapy_Date) as RM_SpecialtyTherapy_Date
	,c.RM_PainClinic_Key
	,DATEADD(year,-4,c.RM_PainClinic_Date) as RM_PainClinic_Date
	,c.CAM_Key
	,DATEADD(year,-5,c.CAM_Date) as CAM_Date
	,c.RiosordScore
	,c.RiosordRiskClass
	,c.RiskMitScore
	,c.MaxMitigations
	--,c.BaselineMitigationsMet
	,c.PatientRecordFlag_Suicide
	,c.REACH_01
	,c.REACH_Past
	,c.MitigationID
	,c.RiskMitigation
	,c.DetailsText
	,c.DetailsDate
	,c.Checked
	,c.Red
	,c.[MitigationIDRx]
    ,c.[PrintNameRx]
    ,c.[CheckedRx]
    ,c.[RedRx]
	,c.MetricInclusion
	,c.DxId
	,c.Diagnosis
	,c.ColumnName
	,c.Category
	,c.MedID
	,c.DrugNameWithoutDose
	,'Dr Zivago' as PrescriberName
	,c.MedType
	,c.CHOICE
	,c.MedLocation
	,c.MedLocationName
	,c.MedLocationColor
	,c.MonthsinTreatment
	,c.GroupID
	,c.GroupType
	,CASE WHEN GroupType ='Primary Care Provider' then 'Pcp,Ima'
		WHEN GroupType ='MH Tx Coordinator' then 'Mhtc,Ima' 
		WHEN GroupType ='VA Opioid Prescriber' then 'Prescriber,Ima'
		ELSE ProviderName
		END as ProviderName
	,-1 as ProviderSID
	,c.ProviderLocation
    ,c.ProviderLocationName
    ,c.ProviderLocationColor
    ,c.AppointmentID
    ,c.AppointmentType
    ,c.AppointmentStop
    ,DATEADD(year,-3,c.AppointmentDatetime) as AppointmentDatetime
    ,c.AppointmentLocation
    ,c.AppointmentLocationName
    ,c.AppointmentLocationColor
    ,c.VisitStop
    ,DATEADD(year,-2,c.VisitDatetime) as VisitDateTime
    ,c.VisitLocation
    ,c.VisitLocationName
    ,c.VisitLocationColor
	,c.ReceivingCommunityCare
	,c.ActiveMOUD_Patient 
	,c.NonVA_Meds
	,c.ODPastYear
	,c.ODdate
	,c.ChronicOpioid
	,idu.Details
	,ca.OrderName AS NonVACannabis
	,CASE WHEN xy.MVIPersonSID IS NOT NULL THEN 'Xylazine Exposure'
	      ELSE NULL END AS XylazineExposure
    ,xy.Concept
FROM ( 
		SELECT DISTINCT 
			mvi.MVIPersonSID	--,PatientName
			, ROW_NUMBER() OVER (ORDER BY mvi.MVIPersonSID) AS PatientID
		FROM [SPatient].[SPatient] sp WITH (NOLOCK) 
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON sp.PatientSID = mvi.PatientPersonSID 
		WHERE mvi.MVIPersonSID IN 
			( 9382966, 15258421, 9144260, 9097259,
			  13066049, 9279280, 13426804, 14920678, 9160057
			)
	) AS a 
	INNER JOIN (
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 1 
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 2
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 3
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 4
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 5
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 6
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 7
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 8
		UNION ALL
		SELECT TOP 1 MVIPersonSID,RiskCategory as PatientID FROM  #ORM_PatientDetails WHERE RiskCategory = 9
	) AS b ON a.PatientID = b.PatientID
	INNER JOIN #ORM_PatientDetails AS c ON b.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN (SELECT MVIPersonSID, Details FROM [SUD].[IDUEvidence] WITH(NOLOCK)
	            WHERE EvidenceType = 'Drug Screen'AND Details LIKE '%Fentanyl%') AS idu
				ON c.MVIPersonSID = idu.MVIPersonSID
      LEFT JOIN (SELECT MVIPersonSID, OrderName 
				FROM [Present].[NonVAMed] WITH(NOLOCK)
                  WHERE SetTerm = 'Marijuana'
	           ) AS ca
			    ON c.MVIPersonSID = ca.MVIPersonSID
LEFT JOIN #XylazineExposure AS xy
				  ON c.MVIPersonSID = xy.MVIPersonSID

	EXEC [Log].[ExecutionEnd] --DeID


--DoD OUD leftouts
INSERT INTO #ORM_PatientDetails 
SELECT a.MVIPersonSID
	,c.Locations
	,c.LocationName
	,c.LocationsColor
	,c.OUD
	,c.OpioidForPain_Rx
	,c.SUDdx_poss
	,NULL AS Hospice
	,5 AS RiskCategory
	,'Elevated Risk Due To OUD Dx, No Opioid Rx' AS RiskCategorylabel
	,5 AS RiskAnyCategory
	,'Elevated Risk Due To OUD Dx, No Opioid Rx'RiskAnyCategorylabel
	,c.RiskScore
	,c.RiskScoreAny
	,c.RiskScoreAnyOpioidSedImpact
	,c.RiskScoreOpioidSedImpact
	,c.RM_ActiveTherapies_Key
	,DATEADD(year,-2,c.RM_ActiveTherapies_Date) as RM_ActiveTherapies_Date
	,c.RM_ChiropracticCare_Key
	,DATEADD(year,-5,c.RM_ChiropracticCare_Date) as RM_ChiropracticCare_Date
	,c.RM_OccupationalTherapy_Key
	,DATEADD(year,-3,c.RM_OccupationalTherapy_Date) as RM_OccupationalTherapy_Date
	,c.RM_OtherTherapy_Key
	,DATEADD(year,-6,c.RM_OtherTherapy_Date) as RM_OtherTherapy_Date
	,c.RM_PhysicalTherapy_Key
	,DATEADD(year,-1,c.RM_PhysicalTherapy_Date) as RM_PhysicalTherapy_Date
	,c.RM_SpecialtyTherapy_Key
	,DATEADD(year,-2,c.RM_SpecialtyTherapy_Date) as RM_SpecialtyTherapy_Date
	,c.RM_PainClinic_Key
	,DATEADD(year,-4,c.RM_PainClinic_Date) as RM_PainClinic_Date
	,c.CAM_Key
	,DATEADD(year,-5,c.CAM_Date) as CAM_Date
	,c.RiosordScore
	,c.RiosordRiskClass
	,NULL AS RiskMitScore
	,NULL AS MaxMitigations
	--,c.BaselineMitigationsMet
	,c.PatientRecordFlag_Suicide
	,c.REACH_01
	,c.REACH_Past
	,ISNULL(rm.MitigationID,-1) as MitigationID
	,c.RiskMitigation
	,c.DetailsText
	,c.DetailsDate 
	,c.Checked
	,c.Red
	,c.[MitigationIDRx]
    ,c.[PrintNameRx]
    ,c.[CheckedRx]
    ,c.[RedRx]
	,c.MetricInclusion
	,ISNULL(c.DxId,-1) as DxId
	,c.Diagnosis
	,c.ColumnName
	,c.Category
	,ISNULL(c.MedID,-1) as MedID
	,c.DrugNameWithoutDose
	,'Uknown' as PrescriberName
	,c.MedType
	,c.CHOICE
	,c.MedLocation
	,c.MedLocationName
	,c.MedLocationColor
	,MonthsinTreatment=CASE WHEN c.MonthsinTreatment NOT LIKE '%<%' THEN c.MonthsinTreatment ELSE m.MonthsInTreatment END
	,c.GroupID
	,c.GroupType
	,CASE WHEN c.GroupType ='Primary Care Provider' then 'Pcp,Ima'
		WHEN c.GroupType ='MH Tx Coordinator' then 'Mhtc,Ima' 
		WHEN c.GroupType ='VA Opioid Prescriber' then 'Prescriber,Ima'
		ELSE c.ProviderName
		END as ProviderName
	,-1 as ProviderSID
	,c.ProviderLocation
    ,c.ProviderLocationName
    ,c.ProviderLocationColor
	,ISNULL(c.AppointmentID,-1) as AppointmentID
    ,c.AppointmentType
    ,c.AppointmentStop
    ,DATEADD(year,-3,c.AppointmentDatetime) as AppointmentDatetime
    ,c.AppointmentLocation
    ,c.AppointmentLocationName
    ,c.AppointmentLocationColor
    ,c.VisitStop
    ,DATEADD(year,-2,c.VisitDatetime) as VisitDateTime
    ,c.VisitLocation
    ,c.VisitLocationName
    ,c.VisitLocationColor
	,NULL AS ReceivingCommunityCare
	,ISNULL(c.ActiveMOUD_Patient,-1) as ActiveMOUD_Patient
	,ISNULL(c.NonVA_Meds,-1) as NonVA_Meds
	,c.ODPastYear
	,CAST( CAST(c.ODdate AS char(8)) AS date ) AS ODdate
	,pd.ChronicOpioid
	,idu.Details
	,ca.OrderName AS NonVACannabis
	,CASE WHEN xy.MVIPersonSID IS NOT NULL THEN 'Xylazine Exposure'
	      ELSE NULL END AS XylazineExposure
	,xy.Concept
FROM ( 
		SELECT DISTINCT 
			sp.MVIPersonSID	
		FROM [ORM].[DoDOUDPatientReport] sp WITH (NOLOCK) 
		WHERE MVIPersonSID NOT IN (select MVIPersonSID from ORM.PatientReport)
	) AS a 
	INNER JOIN [ORM].[DoDOUDPatientReport]  AS c WITH (NOLOCK) ON a.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN [ORM].[RiskMitigation] AS rm WITH (NOLOCK) ON a.MVIPersonSID=rm.MVIPersonSID
	LEFT JOIN #Meds as m ON c.MVIPersonSID = m.MVIPersonSID
	LEFT JOIN #ORM_PatientDetails AS pd ON a.MVIPersonSID = pd.MVIPersonSID
	LEFT JOIN (SELECT MVIPersonSID, Details FROM [SUD].[IDUEvidence] WITH(NOLOCK)
	            WHERE EvidenceType = 'Drug Screen'AND Details LIKE '%Fentanyl%') AS idu
				ON a.MVIPersonSID = idu.MVIPersonSID
     LEFT JOIN (SELECT MVIPersonSID, OrderName
				FROM [Present].[NonVAMed] WITH(NOLOCK)
                  WHERE SetTerm = 'Marijuana'
	           ) AS ca
			    ON c.MVIPersonSID = ca.MVIPersonSID
     LEFT JOIN #XylazineExposure AS xy
				  ON c.MVIPersonSID = xy.MVIPersonSID

-- Publish table
Exec [Maintenance].[PublishTable] 'ORM.PatientDetails', '#ORM_PatientDetails'

EXEC [Log].[ExecutionEnd]

END
GO
