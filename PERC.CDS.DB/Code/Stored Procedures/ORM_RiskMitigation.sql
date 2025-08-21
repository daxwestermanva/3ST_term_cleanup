-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/13/2017
-- Description: ORM Patient measures 
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
-- 2018/12/20 - Pooja Sohoni - Formatting improvements, expanded cohort to look at ALL patients,
	-- and implemented rules for individual mitigations (see in-line)
-- 20200106 - RAS - Added code to exclude safety plan declines from #SafetyPlan
-- 20200429 - RAS - Changed TotalMEDD_CDC to MEDD_Report (new computation in ORM.Cohort)
-- 20200512 - RAS - Changed timely followup to use Present.AppointmentsPast instead of Present.Appointments 
-- 20200720 - PS  - Rewrote the code to make it cleaner, added annotations, updated to match latest business rules
-- 20200908 - LM- Switched health factors to use LookupList architecture
-- 20201027 - MCP - Cerner Overlay up through Note titles
-- 20201028 - PS  - continuation of Cerner overlay
-- 20201231 - CB  - Expanded date selection for time-bound mitigations and rewrote Checked and Red columns accordingly
-- 20210307 - PS  - Baseline risk mitigation set and new field 
-- 20210312 - PS  - Added declined and not needed naloxone kits
-- 20210622 - SM  - corrected SUD treatment definition to include diagnosis when using SUDTx_DxReq_Stop
-- 20210720 - JEB - Enclave Refactoring - Counts confirmed
-- 20210825 - TG - Added 'Naloxone_RxNotIndicated_HF' for Naloxone Not Needed category.
-- 20210831 - RAS - Changed initial left join with ORM.OpioidHistory to subquery because ChronicOpioid is 
				--	needed at patient level to left join to RiskScore and SUD.Cohort
				--	Added STORM=1 limitation to SUD.Cohort join (will reconsider next sprint)
-- 20210913 - LM - Removed deleted TIU documents
-- 20210917 - AI - Enclave Refactoring - Counts confirmed
-- 20211007 - TG - Limiting the PDMP metric inclusion to OpioidForPain_Rx
-- 20211026 - TG - Fixing an error discovered during validtion, RE: OpioidForPain_Rx vs ChronicOpioid
-- 20211103 - TG - Made changes to match the requirements in [ORM].[MeasureDetails].
-- 20211214 - TG - Added overdose in the past year cohort.
-- 20211216 - TG - Adding a new risk mitigation category
-- 20211217 - TG - pulled MitigationID 17 into risk mitigation table; rolled back some inadvertent changes
-- 20220104 - TG - fixing uninted rollback
-- 20220105	- LM - Removed 'Naloxone_AdminByDeclined' - this means the patient declined to state who administered naloxone, not that an rx was declined
				 --Fixed list name from 'Naloxone_PatientDeclinedNaloxone_HF' to 'Naloxone_RxPatientDeclinedNaloxone_HF'
-- 20220113 - TG - fixing a bug that resulted Consent for LTOT requirement for Tramadol only
-- 20220114 - TG - Adding new Naloxone health factor contexts: SP_NaloxoneNoteOn_HF and SP_NaloxoneCurrentRx_HF
-- 20220202 - LM - Fixing error to get most recent date of overdoses only, not any suicide/overdose event
-- 20220202 - TG - Fixing the inequality typo and bugs for overdose cohort; changes to UDS for the pandemic era
                  -- put back STORM = 1 restriction
-- 20220309 - TG - Adjusting the UDS requirement again.
-- 20220413 - TG - Removing Recently Discontinued from Active SUD Treatment
-- 20220510 - TG - Pulling consent dates for all patients whether required or not
-- 20220512 - TG - Limiting risk mitigation data to STORM cohort because the table became too large.
-- 20220520 - TG - Fixing a bug where recently discontinued with SUD diagnoses were not marked for Active SUD requirement
-- 20220608 - TG - Fixing a bug showing informed consent requirement for patient not on opioids.
-- 20220613 - TG - Inconsistencies reported in Red-Checked rules for risk mitigations
-- 20220616 - TG - Removing "BaselineMitigationsMet" column because it's pulling Consent where it's not required.
-- 20220617 - LM - Removing hard-coded activity types and pointing to Lookup.ListMember
-- 20220719 - TG - Removing UDS requirement for short-term opioids.
-- 20220815 - TG - Adding some patients who were not included in the STORM Cohort
-- 20220816 - TG - Adding UDS requirement to SUD diagnoses.
-- 20221017 - TG - PDMP label is erroneously displaying 365 days for opioid analgysics, this has been updated in the RedRules earlier
-- 20221207 - TG - fixing informed consent requirement for Tramadol Only patients.
-- 20230112	- CW - Adjusting criteria for MitigationID=16 to include RecentlyDiscontinued=1 and ODPastYear=1 per conversation with Jodie
-- 20230123 - TG - Switching to ADS UDS dataset for UDS credit in STORM
-- 20230306 - CW - Switching to Present.Present.UDSLabResults for UDS Credit in STORM - ADS 1YR table isn't updating reguarly 
-- 20230510 - CW - Adding stop code 545 (SUD telephone) to MitigationID 14 for possible credit. Updating all telephone clinics 
				-- to follow HRF telephone logic (only credited if > 11 min or paired with non-exlcuded CPT code).
				-- Also, per JT, updated to credit workload only.
-- 20230809 - TG - Switching to MEDD from ADS for dashboard purposes--the risk score are not calculated using the MEDD displayed.
-- 20240108 - TG - Displaying Urine Drug Screening dates on reports regardless of whether it's required or not
-- 20240110 - TG - Added 'NA' to UDS PrintName when not required by the last date of UDS in the past two years is displayed.
-- 20240110 - TG - Bug fix - some patients OD in the past year missing the UDS requirement.
-- 20240124 - TG - Bug fix - Overriding the UDS Checked rule for patients with both Chronic Opioid and SUD diagnosis; SUD trumps chronic opioid.
-- 20240201 - CW - Bug fix in #AllTogether - changing to MAX(PreparatoryBehavior) to ensure we're getting correct DetailText for rdl.
--				   Re-ordered MitigationIDs.
-- 20240208 - TG - Adding the DoD OUD cohort to the risk mitigation computation, instead of replicating the code
-- 20240402 - CW - Adding Safety Plan DetailsText
-- 20240402 - TG - Fixing LTOT Consent requirement bug
-- 20240415 - CW - Fixing bug to ensure completed safety plans are prioritized followed by ReferenceDate
-- 20240417 - CW - Adjusting Checked and Red rules for Data-based risk review
-- 20240510 - CW - Made change to #AllTogether so we're not prioritizing non-preparatory events when there are multiple reports on one day.
-- 20240520 - TG - Replacing "(365 Days)" with "(Reset)" in cases where DBRR reset after OD
-- 20240605 - CW - Incorporating Integrated Veterans Care (IVC) cohort (community care overdose) into risk mitigation strategies. 
--				   Adding new risk mitigation strategy associated with new cohort as well (Review Need for SBOR)
-- 2024-07-16 -TG - Fixed a typo
-- 20240718 - CW - Changing source data for hospice
-- 20240815 - TG - Fixing a bug that resulted in informed consent requirement for patients on Tramadol only.
-- 20240814 - LM - Point to Lookup.ListMember for note titles; optimization for faster run time
-- 20240826 - TG - Fixing a bug discovered during validation
-- 20241107 - TG - Crediting Naloxone fill when provider indicates 'Current Rx' in health factor
-- 20250108 - TG - Making logic changes to requested by PMOP for certain risk mitigation strategies
-- 20250115 - LM - Exclude telephone visits with CPT code 98016 due to 2025 CPT code rule changes from CMS
-- 20250203 - TG - Adding (NA) to risk mitigations not required but displayed anyway.
-- 20250317 - TG - Crediting review notes from STORM copy-paste feature.
-- 20250711 - TG - Filtering TIU notes to 'COMPLETED','AMENDED','UNCOSIGNED','UNDICTATED'
-- 20250820 - TG - Changing DBRR rules, especially for LTOT
-- =============================================
CREATE PROCEDURE [Code].[ORM_RiskMitigation]

AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_RiskMitigation','Execution of SP Code.ORM_RIskMitigation'
----------------------------------------------------------------------------
-- GET THE COHORT OF PATIENTS OF INTEREST, RELATED FIELDS, AND RISK MITIGATION STRATEGIES
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #CrudeCohort   
	SELECT r.MVIPersonSID
		,CAST(ad.MEDD30d as DECIMAL(18,0)) as MEDD_Report
		,r.Bowel_Rx
		,ISNULL(t.NonTramadol,0) NonTramadol
		,r.Hospice
		,ISNULL(o.ChronicOpioid,0) ChronicOpioid
		,ISNULL(c.CancerDx,0) CancerDx
		,ISNULL(c.Anxiolytics_Rx,0) Anxiolytics_Rx
		,ISNULL(c.OpioidForPain_Rx,0) OpioidForPain_Rx
		,ISNULL(c.OUD,0) OUD
		,ISNULL(c.SUDdx_poss,0) SUDdx_poss
		,ISNULL(c.CommunityCare_ODPastYear,0) CommunityCare_ODPastYear
		,ISNULL(c.ODPastYear,0) ODPastYear
		,ISNULL(oh.RecentlyDiscontinued,0) RecentlyDiscontinued
		,ISNULL(c.OUD_DoD,0) OUD_DoD
		,rm.MeasureID as MitigationID
		-- Specific printnames for UDS (MeasureID 5) and Timely Follow-up (MeasureID 4)
		,CASE WHEN (c.SUDdx_poss = 0 OR c.SUDdx_poss IS NULL) AND rm.MeasureID = 5 THEN rm.PrintName + ' (365 Days)'
			  WHEN c.ODPastYear = 1 AND rm.MeasureID = 12 THEN rm.PrintName + ' (Reset)'
			  WHEN c.OpioidForPain_Rx = 1 AND rm.MeasureID = 10 THEN rm.PrintName + ' (90 Days)'
			  WHEN rm.DetailsRedRules IS NOT NULL AND rm.MeasureID <> 1 and rm.MeasureID <> 15 THEN rm.PrintName + ' (' + cast(DetailsRedRules - 1 as varchar) + ' Days)'
		 ELSE rm.PrintName
		 END AS PrintName
		,CAST(rm.DetailsRedRules AS DECIMAL) as DetailsRedRules
	INTO #CrudeCohort
	FROM [ORM].[RiskScore] r WITH(NOLOCK)
	INNER JOIN [Common].[MasterPatient] as mp WITH(NOLOCK) 
		ON r.MVIPersonSID=mp.MVIPersonSID
	LEFT JOIN [PDW].[PBM_AD_DOEx_Staging_RIOSORD] as ad WITH(NOLOCK) 
		ON mp.PatientICN = ad.PatientICN
	LEFT JOIN [SUD].[Cohort] c WITH(NOLOCK)
		ON r.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN ( SELECT MVIPersonSID
					,MAX(ChronicOpioid) as ChronicOpioid
				FROM [ORM].[OpioidHistory] WITH(NOLOCK)
				WHERE ActiveRxStatusVM=1
				GROUP BY MVIPersonSID
		) o ON r.MVIPersonSID = o.MVIPersonSID
	LEFT JOIN ( SELECT MVIPersonSID
					,SUM(NonTramadol) AS NonTramadol
				FROM [ORM].[OpioidHistory] WITH(NOLOCK)
				GROUP BY MVIPersonSID
		) t ON r.MVIPersonSID = t.MVIPersonSID
	LEFT JOIN ( SELECT DISTINCT -- "recently" discontinued taken from Code.ORM_PatientReport
					oh.MVIPersonSID
					,RecentlyDiscontinued = 1
				FROM [ORM].[OpioidHistory] oh WITH (NOLOCK) 
				INNER JOIN [SUD].[Cohort] c WITH (NOLOCK)  on c.MVIPersonSID=oh.MVIPersonSID AND oh.Active = 0
				WHERE (c.OUD IS NULL OR c.OUD = 0 OR ODPastYear = 0) --only non-OUD because OUD is included in RiskScore, not hypothetical
				AND CAST(dateadd(DAY,DaysSupply,ReleaseDateTime) AS DATE) >= CAST(GETDATE() - 180 AS DATE)
				
		) oh ON r.MVIPersonSID = oh.MVIPersonSID
	LEFT JOIN ORM.HospicePalliativeCare hp
		ON r.MVIPersonSID = hp.MVIPersonSID AND hp.Hospice=1
	INNER JOIN ( SELECT MeasureID
					,PrintName
					,DetailsRedRules 
				 FROM [ORM].[MeasureDetails] WITH (NOLOCK) 
				 WHERE MeasureID <> 9
		) rm ON 1=1;


	CREATE NONCLUSTERED INDEX Cohort ON #CrudeCohort (MVIPersonSID);
/**********************************************************************************************
Even though we have been computing risk mitigation strategies for patients in Risk Score table
the dataset blew up to hundreds of millions of records. We are filtering down to STORM and discontinued cohort
************************************************************************************/
	DROP TABLE IF EXISTS #DiscontinuedAndSTORM
	SELECT
	oh.MVIPersonSID
	INTO #DiscontinuedAndSTORM
	FROM [ORM].[OpioidHistory] oh WITH (NOLOCK)  --Recently Discontinued cohort
	WHERE CAST(dateadd(DAY,DaysSupply,ReleaseDateTime) AS DATE) >= CAST(GETDATE() - 180 AS DATE)
		AND oh.Active = 0
	UNION
	SELECT MVIPersonSID
	FROM [SUD].[Cohort] WITH (NOLOCK)  WHERE STORM = 1 OR SUDdx_poss = 1 OR CommunityCare_ODPastYear=1; --STORM, SUD Dx, or CC Overdose


	--Pulling a refined cohort
	DROP TABLE IF EXISTS #NewCohort 
	SELECT *
	INTO #NewCohort
	FROM #CrudeCohort
	WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #DiscontinuedAndSTORM);

	
/************************************************************************************
Ensuring all of DoD OUD and CC Overdose cohort remain in dataset when STORM=0
************************************************************************************/
	DROP TABLE IF EXISTS #Cohort
	SELECT MVIPersonSID
		  ,MEDD_Report
		  ,Bowel_Rx
		  ,NonTramadol
		  ,Hospice
		  ,ChronicOpioid
		  ,CancerDx
		  ,Anxiolytics_Rx
		  ,OpioidForPain_Rx
		  ,OUD
		  ,SUDdx_poss
		  ,ODPastYear
		  ,CommunityCare_ODPastYear
		  ,RecentlyDiscontinued
		  ,OUD_DoD
		  ,MitigationID
		  ,CASE WHEN MitigationID IN (1,3, 5, 8, 10) THEN MitigationID ELSE NULL END AS MitigationIDRx
		  ,PrintName
		  ,CASE WHEN MitigationID IN (1,3,8) THEN PrintName --+ ' (365 Days)'
		       WHEN MitigationID =5 THEN 'Drug Screen' + ' (365 Days)'
			WHEN OpioidForPain_Rx = 1 AND MitigationID = 10 THEN 'PDMP' + ' (90 Days)'
			WHEN OpioidForPain_Rx = 0 AND MitigationID = 10 THEN 'PDMP' + ' (365 Days)'
		   ELSE NULL END AS PrintNameRx
		  ,DetailsRedRules
	INTO #Cohort
	FROM #NewCohort
	UNION
	SELECT c.MVIPersonSID
		  ,NULL AS MEDD_Report
		  ,NULL AS Bowel_Rx
		  ,NULL AS NonTramadol
		  ,NULL AS Hospice
		  ,NULL AS ChronicOpioid
		  ,NULL AS CancerDx
		  ,NULL AS Anxiolytics_Rx
		  ,NULL AS OpioidForPain_Rx
		  ,NULL AS OUD
		  ,NULL AS SUDdx_poss
		  ,NULL AS ODPastYear
		  ,NULL AS CommunityCare_ODPastYear
		  ,NULL AS RecentlyDiscontinued
		  ,ISNULL(c.OUD_DoD,0) OUD_DoD
		  ,rm.MeasureID as MitigationID
		  ,CASE WHEN rm.MeasureID IN (1,3, 5, 8, 10) THEN rm.MeasureID ELSE NULL END AS MitigationIDRx
		  ,CASE WHEN (c.SUDdx_poss = 0 OR c.SUDdx_poss IS NULL) AND rm.MeasureID = 5 THEN rm.PrintName + ' (365 Days)'
		  WHEN c.OpioidForPain_Rx = 1 AND rm.MeasureID = 10 THEN rm.PrintName + ' (90 Days)'
			WHEN rm.DetailsRedRules IS NOT NULL AND rm.MeasureID <> 1 and rm.MeasureID <> 15 THEN rm.PrintName + ' (' + cast(rm.DetailsRedRules - 1 as varchar) + ' Days)'
		   ELSE rm.PrintName
		   END AS PrintName
		   ,CASE WHEN rm.MeasureID IN (1,3, 5, 8) THEN rm.PrintName + ' (365 Days)'
			WHEN c.OpioidForPain_Rx = 1 AND rm.MeasureID = 10 THEN rm.PrintName + ' (90 Days)'
			WHEN c.OpioidForPain_Rx = 0 AND rm.MeasureID = 10 THEN rm.PrintName + ' (365 Days)'
		   ELSE NULL END AS PrintNameRx
		  ,CAST(rm.DetailsRedRules AS DECIMAL) as DetailsRedRules
	FROM [SUD].[Cohort] c WITH (NOLOCK) 
	INNER JOIN (
		SELECT MeasureID
			,PrintName
			,DetailsRedRules 
		FROM [ORM].[MeasureDetails] WITH (NOLOCK) 
		WHERE MeasureID <> 9
		) rm on 1=1
	WHERE c.STORM = 0 AND c.OUD_DoD = 1;
	
----------------------------------------------------------------------------
-- METRIC INCLUSION RULES PER PATIENT AND RISK MITIGATION STRATEGY
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #RMPrep
	SELECT MVIPersonSID
		  ,MEDD_Report
		  ,Bowel_Rx
		  ,NonTramadol
		  ,Hospice
		  ,ChronicOpioid
		  ,CancerDx
		  ,Anxiolytics_Rx
		  ,OpioidForPain_Rx
		  ,OUD
		  ,SUDdx_poss
		  ,ODPastYear
		  ,CommunityCare_ODPastYear
		  ,RecentlyDiscontinued
		  ,OUD_DoD
		  ,MitigationID
		  ,MitigationIDRx
		  ,PrintName
		  ,PrintNameRx
		  ,DetailsRedRules
		  ,CASE WHEN MitigationID = 1 and OpioidForPain_Rx = 1 THEN 1
				WHEN MitigationID = 2 THEN 1
				WHEN MitigationID = 3 AND ChronicOpioid = 1 AND NonTramadol > 0 AND Hospice = 0 AND CancerDx = 0 THEN 1
				WHEN MitigationID = 4 AND (OpioidForPain_Rx = 1 OR RecentlyDiscontinued = 1 OR ODPastYear = 1) THEN 1
				--Removing UDS requirement for SUD (pandemic); requiring for LTOT
				-- nvm, we are displying UDS for all now.
				WHEN MitigationID = 5 AND (ChronicOpioid = 1 OR SUDdx_poss = 1) THEN 1
				WHEN MitigationID = 6 THEN 1
				WHEN MitigationID = 7 THEN 1
				WHEN MitigationID = 8 AND OpioidForPain_Rx = 1 THEN 1
				WHEN MitigationID = 10 THEN 1
				WHEN MitigationID = 12 THEN 1
				WHEN MitigationID = 13 THEN 1
				WHEN MitigationID = 14 AND (SUDdx_Poss = 1 OR OUD = 1 OR OUD_DoD = 1) THEN 1
				WHEN MitigationID = 14 AND RecentlyDiscontinued = 1 AND SUDdx_Poss = 1 THEN 1
				WHEN MitigationID = 15 AND (OUD = 1 OR OUD_DoD = 1) THEN 1
				WHEN MitigationID = 16 AND (OpioidForPain_Rx = 1 OR OUD = 1 OR RecentlyDiscontinued=1 OR ODPastYear=1 OR OUD_DoD = 1) AND Anxiolytics_Rx= 1 THEN 1
				WHEN MitigationID = 18 AND CommunityCare_ODPastYear=1 THEN 1
		   ELSE 0
		   END AS MetricInclusion
	INTO #RMPrep
	FROM #Cohort;



/********* Get metric inclusion for MitigationID 17*******/
	DROP TABLE IF EXISTS #MetricInclusion17
	SELECT MVIPersonSID
		  ,SUM(MetricInclusion) AS MetricInclusion17
	INTO #MetricInclusion17
	FROM #RMPrep 
	WHERE MitigationID IN (3,4,5,10,12,14)
	AND MetricInclusion = 1 
	GROUP BY MVIPersonSID;


/***********Get overdose date for the overdose cohort(s) *****/
	--ODPastYear
	DROP TABLE IF EXISTS #OD_17
	SELECT c.MVIPersonSID
		,MAX(ISNULL(od.EventDateFormatted,od.EntryDateTime)) as ODdate
	INTO #OD_17
	FROM #RMPrep c
	INNER JOIN [OMHSP_Standard].[SuicideOverdoseEvent] od WITH(NOLOCK)
		ON c.MVIPersonSID = od.MVIPersonSID
	WHERE c.ODPastYear = 1
	   AND (
			EventDateFormatted >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))
			OR (EventDateFormatted IS NULL
				AND EntryDateTime > DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)))
			)
		AND od.Overdose = 1
	GROUP BY c.MVIPersonSID;


	--CommunityCare_ODPastYear
	DROP TABLE IF EXISTS #OD_18
	SELECT c.MVIPersonSID
		,MAX(CAST(EpisodeStartDate as date)) as CC_ODdate
	INTO #OD_18
	FROM #RMPrep c
    INNER JOIN [CommunityCare].[ODUniqueEpisode] od WITH(NOLOCK)
		ON c.MVIPersonSID = od.MVIPersonSID
    WHERE c.CommunityCare_ODPastYear = 1
	GROUP BY c.MVIPersonSID;


/*************** Adding logic for Interdisciplinary Review metric inclusion ********/
	DROP TABLE IF EXISTS #RMPrepFinal
	SELECT a.MVIPersonSID
		,MEDD_Report
		,Bowel_Rx
		,NonTramadol
		,Hospice
		,ChronicOpioid
		,CancerDx
		,Anxiolytics_Rx
		,OpioidForPain_Rx
		,OUD
		,SUDdx_poss
		,ODPastYear
		,CommunityCare_ODPastYear
		,RecentlyDiscontinued
		,OUD_DoD
		,MitigationID
		,MitigationIDRx
		,PrintName
		,PrintNameRx
		,DetailsRedRules
		,CASE WHEN MitigationID = 17 AND (OpioidForPain_Rx = 1 OR RecentlyDiscontinued = 1 OR ODPastYear = 1) THEN 1
			WHEN MitigationID = 17  AND MetricInclusion17 > 0 THEN 1
					ELSE MetricInclusion
					END AS MetricInclusion
		,c.ODdate
		,d.CC_ODdate
	INTO #RMPrepFinal
	FROM #RMPrep a
	LEFT JOIN #MetricInclusion17 b
		 ON a.MVIPersonSID = b.MVIPersonSID
	LEFT JOIN #OD_17 c
		 ON a.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN #OD_18 d
		ON a.MVIPersonSID=d.MVIPersonSID;


----------------------------------------------------------------------------
-- DATA SOURCES FOR SOME OF THE RISK MITIGATION STRATEGIES
----------------------------------------------------------------------------

/************* Naloxone Kit (MeasureID 2) *************/ 
-- Code to pull declined and not needed from health factors/power forms
-- ORM.NaloxoneKit is a union of VistA and Cerner data
	DROP TABLE IF EXISTS #NaloxoneHF
	SELECT l.List
		,l.ItemID
		,l.AttributeValue
		,CASE WHEN List IN ('Naloxone_RxDeclined_HF','Naloxone_RxPatientDeclinedNaloxone_HF') THEN 'Declined'
			WHEN List IN ('Naloxone_RxNotNeeded_HF', 'Naloxone_RxNotIndicated_HF') THEN 'Not Needed'
			WHEN List='Naloxone_RxHasCurrent_HF' THEN 'Current Rx'
			WHEN List='Naloxone_RxNeedUnknown_HF' THEN 'Note On'
			END AS Context
	INTO #NaloxoneHF
	FROM Lookup.ListMember l
	WHERE list IN ('Naloxone_RxDeclined_HF','Naloxone_RxPatientDeclinedNaloxone_HF','Naloxone_RxNotNeeded_HF', 'Naloxone_RxNotIndicated_HF','Naloxone_RxHasCurrent_HF','Naloxone_RxNeedUnknown_HF')

	-- Pull declined
	DROP TABLE IF EXISTS #NaloxoneAll
	SELECT 
		MVIPersonSID
		,MAX(HealthFactorDateTime) AS LastRelease
		,Context
	INTO #NaloxoneAll
	FROM (SELECT ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
			,HealthFactorDateTime
			,Context
		FROM  [HF].[HealthFactor] hf1 WITH (NOLOCK)
			INNER JOIN #NaloxoneHF lm WITH (NOLOCK) 
				ON hf1.HealthFactorTypeSID = lm.ItemID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON hf1.PatientSID = mvi.PatientPersonSID 
			AND hf1.HealthFactorDateTime > DATEADD(YEAR, -2, GETDATE())
		UNION ALL
		SELECT pf.MVIPersonSID
			,TZFormUTCDateTime
			,Context
		FROM [Cerner].[FactPowerForm] pf WITH (NOLOCK) 
		INNER JOIN  #NaloxoneHF lm WITH (NOLOCK) on pf.DerivedDtaEventCodeValueSID = lm.ItemID
			AND pf.DerivedDTAEventResult = lm.AttributeValue
		AND pf.TZFormUTCDateTime > '2020-10-01'
		) h
	GROUP BY h.MVIPersonSID, h.Context


	-- Get the max dates for no naloxone
	DROP TABLE IF EXISTS #MostRecentNoNaloxone
	SELECT TOP 1 WITH TIES a.MVIPersonSID
		  ,LastRelease
		  ,Context
	INTO #MostRecentNoNaloxone
	FROM #NaloxoneAll a
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastRelease DESC)

	
	-- Pull the most recent naloxone fills from the source table
	DROP TABLE IF EXISTS #MostRecentNaloxone;
	SELECT MVIPersonSID
		  ,Max(ReleaseDateTime) AS LastRelease
		  ,'Filled' AS Context
	INTO #MostRecentNaloxone
	FROM [ORM].[NaloxoneKit] WITH(NOLOCK)
	GROUP BY MVIPersonSID
	HAVING MAX(ReleaseDateTime) >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2));


	-- Then, union these tables (no naloxone and yes naloxone) together
	DROP TABLE IF EXISTS #MergeNaloxone
	SELECT MVIPersonSID
		  ,LastRelease
		  ,Context
		  ,MitigationID = 2
	INTO #MergeNaloxone
	FROM #MostRecentNaloxone
	UNION ALL
	SELECT MVIPersonSID
		  ,LastRelease
		  ,Context
		  ,MitigationID = 2
	FROM #MostRecentNoNaloxone;


	-- Finally, logic to implement the following hierarchy:
	-- 1) If there is a fill in the past year, pick that
	-- 2) If there is no fill in the past year, and there is a not-fill (i.e. decline/not needed) in the past year, pick that
	-- 3) If there is no fill in the past year and no not-fill in the past year, pick the most recent fill (will be >1 year ago)
	-- 4) Else null
	DROP TABLE IF EXISTS #NaloxonePrep
	SELECT a.MVIPersonSID
		  ,CASE WHEN b.LastRelease >=  DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN b.LastRelease --Past year fill
		   WHEN (b.LastRelease < DATEADD(YEAR,-1,CAST(GETDATE() as date)) or b.LastRelease IS NULL) and c.LastRelease >=  DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN c.LastRelease --No past year fill, past year decline/not needed
		   ELSE b.LastRelease --No past year fill, no past year decline/not needed
		   END AS LastRelease
		  ,CASE WHEN b.LastRelease >=  DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN 'Filled' --Past year fill
		   WHEN (b.LastRelease < DATEADD(YEAR,-1,CAST(GETDATE() as date)) or b.LastRelease IS NULL) and c.LastRelease >=  DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN c.Context --No past year fill, past year decline/not needed
		   ELSE b.Context --No past year fill, no past year decline/not needed
		   END AS Context
	INTO #NaloxonePrep
	FROM #MergeNaloxone a
	LEFT JOIN #MostRecentNaloxone b on a.MVIPersonSID = b.MVIPersonSID 
	LEFT JOIN #MostRecentNoNaloxone c on a.MVIPersonSID = c.MVIPersonSID;


	-- Final table that will be joined into the master 
	DROP TABLE IF EXISTS #NaloxoneKitRM_2
	SELECT DISTINCT MVIPersonSID
				   ,LastRelease
				   ,Context
	INTO #NaloxoneKitRM_2
	FROM #NaloxonePrep;


/************* UDS (MeasureID 5) *************/ 
	DROP TABLE IF EXISTS #UDS
	SELECT MVIPersonSID
		  ,MAX(LabDate) AS UDS_Any_DateTime
		  ,MitigationID = 5
	INTO #UDS
	FROM Present.UDSLabResults WITH (NOLOCK) 
	GROUP BY MVIPersonSID;


/************* PDMP (MeasureID 10) *************/ 
	-- Present.PDMP is a union of VistA and Cerner data
	DROP TABLE IF EXISTS #PDMP
	SELECT MVIPersonSID
		  ,PerformedDateTime
		  ,MitigationID = 10
	INTO #PDMP
	FROM Present.PDMP WITH (NOLOCK) ;


/************* Health Factors for data-based opioid risk review (MeasureID 12) Vista/Cerner *************/
	-- Pull the actual instances from the CDW HF table, and join on 
	-- HealthFactorTypeSID to limit it to the qualifying HFs from the above table.
	DROP TABLE IF EXISTS #HFVM;
	-- VistA
	SELECT 
		c.MVIPersonSID
		,hf.HealthFactorDateTime AS ReferenceDate
	INTO #HFVM
	FROM #Cohort c
	INNER JOIN
		(
			SELECT 
				ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				, hf1.HealthFactorDateTime
			FROM [HF].[HealthFactor] hf1 WITH (NOLOCK) 
			INNER JOIN [Lookup].[ListMember] ht WITH (NOLOCK) 
				ON hf1.HealthFactorTypeSID = ht.ItemID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON hf1.PatientSID = mvi.PatientPersonSID 
			WHERE ht.List = 'ORM_DatabasedReview_HF' 
				--AND hf1.HealthFactorDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() AS DATETIME2)) --Removing time restriction for DBRR
		) hf
		ON hf.MVIPersonSID = c.MVIPersonSID
	UNION ALL
	-- Cerner
	SELECT c.MVIPersonSID
		,pf.TZFormUTCDateTime AS ReferenceDate
	FROM #Cohort AS c
	INNER JOIN [Cerner].[FactPowerform] AS pf WITH(NOLOCK) ON pf.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Lookup].[ListMember] AS ht WITH(NOLOCK) ON ht.ItemID = pf.DerivedDtaEventCodeValueSID
	WHERE ht.List in ('ORM_DatabasedReview_HF'
					  ,'ORM_DatabasedReviewHigh_HF'
					  ,'ORM_DatabasedReviewLow_HF'
					  ,'ORM_DatabasedReviewMedium_HF'
					  ,'ORM_DatabasedReviewVeryHigh_HF')
	--AND	pf.TZFormUTCDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as datetime2)) --Removing time restriction for DBRR
	;


	--Get most recent per patient
	DROP TABLE IF EXISTS #HF;
	SELECT MVIPersonSID
		  ,MAX(ReferenceDate) AS ReferenceDate
		  ,MitigationID = 12
	INTO #HF
	FROM #HFVM 
	GROUP BY MVIPersonSID;


/************* Note Titles for data-based opioid risk review (MeasureID 12) and informed consent (MeasureID 3) *************/

	-- First, grab the list of qualifying note titles for the 3 RMs
	DROP TABLE IF EXISTS #TIU_Type;
	SELECT ItemID AS TIUDocumentDefinitionSID
		  ,List AS TIU_Type
		  ,CASE WHEN List = 'ORM_InformedConsent_TIU' THEN 3
				WHEN List = 'ORM_DatabasedReview_TIU' THEN 12
				END AS MitigationID
	INTO #TIU_Type
	FROM LookUp.ListMember WITH(NOLOCK)
		WHERE List IN ('ORM_InformedConsent_TIU','ORM_DatabasedReview_TIU') 
	;
	DROP TABLE IF EXISTS #CohortUniques
	SELECT DISTINCT MVIPersonSID
	INTO #CohortUniques
	FROM #Cohort

	--Then, pull the actual notes from the CDW TIU table and Cerner PowerForm Table, 
	--joining to the above table on TIUDocumentDefinitionSID. This is also where we limit 
	--to the qualifying timeframe per the recommendations. 
	DROP TABLE IF EXISTS #NotesVM;
	-- VistA
	SELECT c.MVIPersonSID
		  ,ReferenceDateTime AS ReferenceDate
		  ,y.MitigationID
	INTO #NotesVM
	FROM #CohortUniques AS C
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON c.MVIPersonSID=mvi.MVIPersonSID
	INNER JOIN [TIU].[TIUDocument] t1 WITH (NOLOCK) 
		ON t1.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #TIU_Type y 
		ON t1.TIUDocumentDefinitionSID = y.TIUDocumentDefinitionSID	
	INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
		ON t1.TIUStatusSID = ts.TIUStatusSID
	WHERE --(t1.ReferenceDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as datetime2))
		--OR --Removing time restriction from DBRR
		--(y.TIU_Type = 'ORM_InformedConsent_TIU'  AND t1.ReferenceDateTime > CAST('2014-05-06' AS datetime2))
		--AND 
		t1.DeletionDateTime IS NULL
		AND ts.TIUStatus IN ('COMPLETED','AMENDED','UNCOSIGNED','UNDICTATED') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
	UNION ALL
	-- Cerner
	SELECT c.MVIPersonSID
		  ,n.TZEventEndUTCDateTime as ReferenceDate
		  ,y.MitigationID
	FROM #CohortUniques AS c
	INNER JOIN [Cerner].[FactNoteTitle] AS n WITH(NOLOCK) ON n.MVIPersonSID = c.MVIPersonSID
	INNER JOIN #TIU_Type AS y ON y.TIUDocumentDefinitionSID = n.EventCodeSID
	--WHERE n.TZEventEndUTCDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as datetime2))
	--	--OR --Removing time restriction from DBRR
	--	(y.TIU_Type = 'ORM_InformedConsent_TIU'
	--		AND n.TZEventEndUTCDateTime> CAST('2014-05-06' AS datetime2))
		UNION ALL
      -- Note entries from copy-paste feature on STORM report
	SELECT c.MVIPersonSID
		  ,ReferenceDateTime AS ReferenceDate
		  ,MitigationID = 12
	FROM #CohortUniques AS C
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON c.MVIPersonSID=mvi.MVIPersonSID
	INNER JOIN [PDW].[HDAP_NLP_OMHSP] t1 WITH (NOLOCK) 
		ON t1.PatientSID = mvi.PatientPersonSID 
	WHERE --t1.ReferenceDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as datetime2))
		--AND --Removing unnecessary time restriction for DBRR since it's already restricted to Feb, 2025
		t1.Snippet like '%STORM risk estimate%'  AND t1.ReferenceDateTime > CAST('2025-02-01' AS datetime2) -- the copy/paste feature was deplyed in early March 2025	
			;

	--Most recent per person	
	DROP TABLE IF EXISTS #Notes;
	SELECT DISTINCT MVIPersonSID
		  ,Max(ReferenceDate) AS ReferenceDate
		  ,MitigationID
	INTO #Notes
	FROM #NotesVM
	GROUP BY MVIPersonSID
			,MitigationID;
		
/************* Combine health factors and TIU note titles into a single temp table *************/
	DROP TABLE IF EXISTS #TIU_HF_Merge;
	SELECT MVIPersonSID
		  ,ReferenceDate
		  ,MitigationID
	INTO #TIU_HF_Merge
	FROM #Notes
	UNION ALL
	SELECT MVIPersonSID
		  ,ReferenceDate
		  ,MitigationID
	FROM #HF;


	DROP TABLE IF EXISTS #TIU_HF_3_12
	SELECT MVIPersonSID
		  ,MAX(ReferenceDate) as ReferenceDate
		  ,MitigationID
	INTO #TIU_HF_3_12
	FROM #TIU_HF_Merge
	GROUP BY MVIPersonSID
		    ,MitigationID;


/************* Stop codes for SUD Tx (MeasureID 14) *************/

	-- First, limit the original cohort to only grab patients that have a SUD diagnosis.
	-- This is not exactly necessary, since we have the metric inclusion logic already set,
	-- but it does limit the number of rows, which will speed up subsequent queries.
	DROP TABLE IF EXISTS #SUD_Cohort
	SELECT DISTINCT MVIPersonSID
	INTO #SUD_Cohort
	FROM #Cohort 
	WHERE SUDdx_poss = 1;

	-- Grab all qualifying visits in the past 2 years for this SUD cohort (we will limit to 
	-- 90 days in the checked column). Qualifying visits are based either on SUD-specific stop codes OR 
	-- an additional set of general mental health codes specified by JT along with a SUD dx attached 
	-- to that GMH encounter. For telephone specific stop codes, credit now follows the HRF logic: credit 
	-- is only given when the contact is > 11 min or paired with CPT code that is not else excluded.
	
	-- NEW IN 2025: Any telephone visits with CPT code 98016 should be excluded, 
	-- regardless of any add-on codes that allow other brief telephone CPT codes to count.
	
	--Vista encounters
	DROP TABLE IF EXISTS #VisitSSC
	SELECT DISTINCT 
		a.MVIPersonSID 
		,b1.VisitDateTime
		,b1.VisitSID
		,b1.PrimaryStopCodeSID
	INTO #VisitSSC
	FROM #SUD_Cohort a
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.MVIPersonSID=mvi.MVIPersonSID
	INNER JOIN [Outpat].[Visit_Recent] b1 WITH (NOLOCK) 
		ON b1.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [Outpat].[VDiagnosis] c WITH (NOLOCK) 
		ON c.VisitSID = b1.VisitSID
	INNER JOIN [LookUp].[ICD10] d WITH (NOLOCK) 
		ON c.ICD10SID = d.ICD10SID
	LEFT OUTER JOIN [LookUp].[StopCode] psc WITH (NOLOCK) 
		ON b1.PrimaryStopCodeSID = psc.StopCodeSID 
	LEFT OUTER JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) 
		ON b1.SecondaryStopCodeSID = ssc.StopCodeSID 
	WHERE b1.VisitDateTime >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2))
		AND b1.VisitDateTime <= getdate()
		AND (	    ssc.SUDTx_NoDxReq_Stop = 1 
				OR (ssc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
				OR  psc.SUDTx_NoDxReq_Stop = 1
				OR (psc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
				--General MH stopcodes included as well, per JT 7/2020; we are encouraging BHIP
				--teams to offer SUD, so we are giving credit for GMH when the patient has SUD dx.
				OR (ssc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
				OR (psc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
			)
		AND b1.WorkloadLogicFlag='Y'


	--Get cpt code sids for < 10 minute cpt code to exclude (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptexclude
	SELECT CPTSID,CPTCode, CPTName, CPTExclude=1
	INTO #cptexclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('98966', '99441', '99211', '99212','98016');


	--Get cpt code sids for add-on codes that can be used with excluded CPT codes (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptinclude;
	SELECT CPTSID,CPTCode, CPTInclude=1
	INTO #cptinclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('90833','90836','90838');

	--Get cpt codes for any visit from initial visit query that have phone stop code
	DROP TABLE IF EXISTS #SUD_Tx_VistA 
	SELECT
		v.*
		,CASE 
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTCode='98016' THEN NULL --New CPT code in 2025 for 5-10 minute phone check-in, should not be paired with add-on codes and should never count for metrics
			WHEN sc.Telephone_MH_Stop=1 AND ci.CPTSID IS NOT NULL --MH_Telephone_Stop includes all MH and SUD telephone
				THEN ci.CPTCode -- if one of these CPT codes is used, the visit counts even if an excluded code is also used
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTSID IS NOT NULL 
				THEN NULL --exclude visits with these CPT codes (unless they have one of the included codes accounted for above)
			ELSE 999999 
		END AS CPTCode --999999 => that there is no procedure code requirement		
	INTO #SUD_Tx_VistA
	FROM #VisitSSC v
	INNER JOIN [Lookup].[StopCode] sc WITH (NOLOCK)
		ON v.PrimaryStopCodeSID = sc.StopCodeSID
	LEFT JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
		ON v.VisitSID = p.VisitSID 
	LEFT JOIN 
		(
			SELECT p.VisitSID, e.CPTSID, e.CPTCode 
			FROM #cptexclude e
			INNER JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
				ON e.CPTSID = p.CPTSID
		) ce 
		ON p.VisitSID = ce.VisitSID
	LEFT JOIN #cptinclude ci 
		ON ci.CPTSID = p.CPTSID;
	

	DELETE #SUD_Tx_VistA WHERE CPTCode IS NULL;


	--Cerner encounters
	DROP TABLE IF EXISTS #ListMember
	SELECT List, ItemID
	INTO #ListMember
	FROM [LookUp].[ListMember] lm
	WHERE lm.domain='ActivityType' AND lm.List IN ('MHOC_SUD','MHOC_GMH')
	
	DROP TABLE IF EXISTS #SUD_Tx_Cerner_Stage;
	SELECT  
		 co.MVIPersonSID
		,v.TZDerivedVisitDateTime AS VisitDateTime
		--,v.EncounterType --for validation
		,d.SUDdx_poss
		,v.ActivityTypeCodeValueSID
		,v.EncounterType
		,v.EncounterSID
	INTO #SUD_Tx_Cerner_Stage
	FROM [Cerner].[FactUtilizationOutpatient] AS v WITH(NOLOCK)
	INNER JOIN #SUD_Cohort AS co
		ON co.MVIPersonSID=v.MVIPersonSID 
	INNER JOIN [Cerner].[FactDiagnosis] as fd WITH(NOLOCK) 
		ON v.EncounterSID = fd.EncounterSID
	INNER JOIN [LookUp].[ICD10] d WITH(NOLOCK) 
		ON fd.NomenclatureSID = d.ICD10SID
	INNER JOIN #ListMember AS lm WITH(NOLOCK)
		ON v.ActivityTypeCodeValueSID=lm.ItemID
	WHERE (v.TZDerivedVisitDateTime >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2)) 
	AND  v.TZDerivedVisitDateTime <= getdate())
	AND (lm.List='MHOC_SUD'	OR (lm.List='MHOC_GMH' AND d.SUDdx_poss=1));

	DROP TABLE IF EXISTS #Procedure_Exclude
	SELECT DISTINCT p.EncounterSID
			,CASE WHEN p.EncounterTypeClass = 'Recurring' OR p.EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
			,CASE WHEN e.CPTCode IN ('98966','99441') THEN 1 ELSE 0 END AS TeleCPT
			,e.CPTSID 
			,e.CPTCode
	INTO #Procedure_Exclude
	FROM [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
	INNER JOIN #cptexclude AS e
		ON e.CPTCode=p.SourceIdentifier
	INNER JOIN #SUD_Tx_Cerner_Stage s
		ON p.EncounterSID = s.EncounterSID
		
	DROP TABLE IF EXISTS #Procedure_Include
	SELECT DISTINCT p.EncounterSID
			,CASE WHEN p.EncounterTypeClass = 'Recurring' OR p.EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
			,e.CPTCode
			,e.CPTSID 
	INTO #Procedure_Include
	FROM [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
	INNER JOIN #cptinclude AS e
		ON e.CPTCode=p.SourceIdentifier
	INNER JOIN #SUD_Tx_Cerner_Stage s
		ON p.EncounterSID = s.EncounterSID

	DROP TABLE IF EXISTS #SUD_Tx_Cerner
	SELECT DISTINCT
		s.MVIPersonSID
		,s.VisitDateTime
		,s.EncounterType --for validation
		--,ce.CPTCode AS CPTExclude --for validation
		--,ci.CPTCode AS CPTInclude --for validation
		,ce.EncounterSID as excludeSID
		,CASE WHEN ce.CPTCode='98016' THEN NULL ELSE ci.EncounterSID END AS includeSID 
		,ce.TeleCPT
		--,CASE WHEN s.EncounterType='Telephone' AND ci.CPTSID IS NOT NULL THEN ci.CPTCode
		--	WHEN s.EncounterType='Telephone' AND ce.CPTSID IS NOT NULL THEN NULL
		--	WHEN ce.CPTCode IN ('98966','99441') AND ci.CPTCode IS NULL THEN NULL --telephone CPT codes, may have been used in non-telephone encounter types before Telephone encounter type existed
		--	ELSE 999999 
		--	END AS CPTCode --999999 => that there is no procedure code requirement
	INTO #SUD_Tx_Cerner
	FROM #SUD_Tx_Cerner_Stage s
	LEFT JOIN #Procedure_Exclude ce
		ON   s.EncounterSID=ce.EncounterSID 
		AND (ce.TZDerivedProcedureDateTime IS NULL OR ce.TZDerivedProcedureDateTime = s.VisitDateTime)
	LEFT JOIN #Procedure_Include AS ci ON s.EncounterSID=ci.EncounterSID 
		AND (ci.TZDerivedProcedureDateTime IS NULL OR ci.TZDerivedProcedureDateTime = s.VisitDateTime)

	DELETE #SUD_Tx_Cerner WHERE (EncounterType='Telephone' OR TeleCPT=1) AND ExcludeSID IS NOT NULL AND IncludeSID IS NULL

	-- Union the VistA and Cerner data together
	DROP TABLE IF EXISTS #SUD_Tx
	-- VistA
	SELECT MVIPersonSID
		  ,VisitDateTime
	INTO #SUD_Tx
	FROM #SUD_Tx_VistA
	UNION ALL
	-- Cerner
	SELECT MVIPersonSID
		  ,VisitDateTime
	FROM #SUD_Tx_Cerner;


	-- Get the max date from the above table
	DROP TABLE IF EXISTS #SUD_Treatment_14
	SELECT MVIPersonSID
		  ,MAX(VisitDateTime) AS VisitDateTime
	INTO #SUD_Treatment_14
	FROM #SUD_Tx
	GROUP BY MVIPersonSID;


/************* Appointments for timely followup (MeasureID 4) *************/

	-- Cerner prep table
	DROP TABLE IF EXISTS #Appts
	SELECT a.MVIPersonSID
		  ,TZRegistrationDateTime AS VisitDateTime
	INTO #Appts
	FROM [Cerner].[FactUtilizationOutpatient] a WITH(NOLOCK) 
	INNER JOIN #CohortUniques b on a.MVIPersonSID=b.MVIPersonSID
	WHERE TZRegistrationDateTime >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2)) 
	-- Qualifying encounter types per JT 2020-11-04
	AND EncounterType IN (
		'Outpatient',
		'Home Health',
		'Telehealth')
	UNION ALL		
	-- VistA
	SELECT a.MVIPersonSID
			,a.VisitDateTime
	FROM [Present].[AppointmentsPast] a WITH(NOLOCK)
	INNER JOIN #CohortUniques b on a.MVIPersonSID=b.MVIPersonSID
	WHERE ApptCategory='ClinRelevantRecent' 
		AND MostRecent_ICN=1
		AND a.VisitDateTime >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2));

	
	-- Get the max date from the above table
	DROP TABLE IF EXISTS #Appts_4
	SELECT MVIPersonSID
		  ,MAX(VisitDateTime) AS VisitDateTime
	INTO #Appts_4
	FROM #Appts
	GROUP BY MVIPersonSID;


/************* Safety plan (MeasureID 13) *************/
	--Completed Safety Plan
	DROP TABLE IF EXISTS #Safety_Plan_Completed;
	SELECT a.MVIPersonSID
		  ,MAX(SafetyPlanDateTime) as ReferenceDate
		  ,SPContext='Completed'
	INTO #Safety_Plan_Completed
	FROM [OMHSP_Standard].[SafetyPlan] a WITH(NOLOCK)
	INNER JOIN #CohortUniques b on a.MVIPersonSID=b.MVIPersonSID
	WHERE SP_RefusedSafetyPlanning_HF=0
	GROUP BY a.MVIPersonSID
	HAVING MAX(SafetyPlanDateTime) >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2));


	--Declined Safety Plan
	DROP TABLE IF EXISTS #Safety_Plan_Declined;
	SELECT a.MVIPersonSID
		  ,MAX(SafetyPlanDateTime) as ReferenceDate
		  ,SPContext='Declined'
	INTO #Safety_Plan_Declined
	FROM [OMHSP_Standard].[SafetyPlan] a WITH(NOLOCK)
	INNER JOIN #CohortUniques b on a.MVIPersonSID=b.MVIPersonSID
	WHERE SP_RefusedSafetyPlanning_HF=1
	GROUP BY a.MVIPersonSID
	HAVING MAX(SafetyPlanDateTime) >= DATEADD(YEAR,-2,CAST(GETDATE() as datetime2));


	DROP TABLE IF EXISTS #CombinedSafetyPlan
	SELECT * 
	INTO #CombinedSafetyPlan
	FROM #Safety_Plan_Completed
	UNION ALL
	SELECT * 
	FROM #Safety_Plan_Declined;


	--Prioritize Completed Safety Plans
	DROP TABLE IF EXISTS #Safety_Plan_13
	SELECT * 
	INTO #Safety_Plan_13
	FROM (
	SELECT *, RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SPContext ASC, ReferenceDate DESC)
	FROM #CombinedSafetyPlan) Src
	WHERE RN=1;


/************* MOUD (MeasureID 15) *************/
-- Present.MOUD is a union of VistA and Cerner data

	DROP TABLE IF EXISTS #MOUD_15
	SELECT a.MVIPersonSID
		  ,MAX(MOUDDate) as MOUDDate
	INTO #MOUD_15
	FROM Present.MOUD a WITH(NOLOCK) 
	INNER JOIN #CohortUniques b on a.MVIPersonSID=b.MVIPersonSID
	WHERE Inpatient = 0 
	GROUP BY a.MVIPersonSID
	HAVING MAX(CAST(ActiveMOUD_Patient AS INT)) = 1;	


----------------------------------------------------------------------------
-- PULL ALL THE RISK MITIGATIONS TOGETHER AND APPLY RULES FOR CHECKBOXES ETC.
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #AllTogether
	SELECT rm.MVIPersonSID
		  ,rm.MitigationID
		  ,rm.MitigationIDRx
		  ,rm.PrintName
		  ,rm.PrintNameRx
		  ,CASE WHEN rm.MitigationID = 1 THEN CAST(MEDD_Report AS VARCHAR)
				WHEN rm.MitigationID = 2 THEN Context 
				WHEN rm.MitigationID = 13 THEN SPContext
		   END AS DetailsText
		  ,CASE WHEN rm.MitigationID = 2 THEN na.LastRelease
			   WHEN rm.MitigationID = 3 THEN ic.ReferenceDate
			   WHEN rm.MitigationID = 4 THEN ap.VisitDateTime
			   WHEN rm.MitigationID = 5 THEN u.UDS_Any_DateTime
			   WHEN rm.MitigationID = 6 AND v.Psych_Assessment_Key = 1 THEN v.Psych_Assessment_Date
			   WHEN rm.MitigationID = 7 AND v.Psych_Therapy_Key = 1 THEN v.Psych_Therapy_Date
			   WHEN rm.MitigationID = 10 THEN pd.PerformedDateTime
			   WHEN rm.MitigationID = 12 THEN db.ReferenceDate
			   WHEN rm.MitigationID = 13 THEN sp.ReferenceDate
			   WHEN rm.MitigationID = 14 THEN sud.VisitDateTime
			   WHEN rm.MitigationID = 15 THEN moud.MOUDDate
			   WHEN rm.MitigationID = 17 THEN rm.ODdate
			   WHEN rm.MitigationID = 18 THEN rm.CC_ODdate
		   END AS DetailsDate
		   ,CASE WHEN rm.ODPastYear = 1 AND rm.MitigationID = 5 THEN 1
				 ELSE MetricInclusion
				 END AS MetricInclusion
		   ,rm.SUDdx_poss
		   ,rm.OpioidForPain_Rx
		   ,rm.ChronicOpioid
		   ,rm.Bowel_Rx
		   ,rm.DetailsRedRules
		   ,rm.ODPastYear
		   ,rm.OUD_DoD
		   ,db.ReferenceDate --want to keep ReferenceDate and ODdate for the Checked logic.
		   ,rm.ODdate
		   ,rm.CC_ODdate
		   ,ISNULL(sbor.PreparatoryBehavior,0) PreparatoryBehavior
	INTO #AllTogether
	-- #RMPrep already has MEDD (RM 1) and Bowel Rx (RM 8)
	FROM #RMPrepFinal rm
	-- MitigationID=2 (Naloxone Kit)
	LEFT JOIN #NaloxoneKitRM_2 na
		on rm.MVIPersonSID = na.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	-- MitigationID=3 (Informed Consent)
	LEFT JOIN ( SELECT MVIPersonSID,MAX(ReferenceDate) as ReferenceDate --attempting to get latest consent date in case of multiples
				FROM #TIU_HF_3_12 ic
				WHERE MitigationID = 3
				GROUP BY MVIPersonSID
			  ) ic on rm.MVIPersonSID = ic.MVIPersonSID
	-- MitigationID=4 (Timely Follow-Up)
	LEFT JOIN #Appts_4 ap
		on rm.MVIPersonSID = ap.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	-- MitigationID=5 (UDS)
	LEFT JOIN #UDS u
		on rm.MVIPersonSID = u.MVIPersonSID
	-- MitigationID=6 (Psychosocial Assessment) and MitigationID=7 (Psychosocial Tx)
	LEFT JOIN [ORM].[Visit] v WITH(NOLOCK)
		on rm.MVIPersonSID = v.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	-- MitigationID=10 (PDMP)
	LEFT JOIN #PDMP pd
		on rm.MVIPersonSID = pd.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
		and pd.MitigationID = 10
	-- MitigationID=12 (Data-based opioid risk review)
	LEFT JOIN #TIU_HF_3_12 db
		on rm.MVIPersonSID = db.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
		and db.MitigationID = 12
	-- MitigationID=13 (Suicide Safety Plan)
	LEFT JOIN #Safety_Plan_13 sp
		on rm.MVIPersonSID = sp.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	-- MitigationID=14 (Active SUD Tx)
	LEFT JOIN #SUD_Treatment_14 sud
		on rm.MVIPersonSID = sud.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	-- MitigationID=15 (MOUD)
	LEFT JOIN #MOUD_15 moud
		on rm.MVIPersonSID = moud.MVIPersonSID AND (MetricInclusion = 1 OR rm.ODPastYear = 1)
	LEFT JOIN ( SELECT TOP (1) WITH TIES MVIPersonSID, SDVClassification, EventDateFormatted, PreparatoryBehavior
				FROM [OMHSP_Standard].[SuicideOverdoseEvent] WITH(NOLOCK)
				WHERE Overdose=1
				ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, EventDateFormatted ORDER BY EventDateFormatted DESC, PreparatoryBehavior ASC) --non-prep prioritized if duplicate SBORs on same-day
			   ) sbor 
		ON rm.MVIPersonSID = sbor.MVIPersonSID
		AND rm.ODdate=sbor.EventDateFormatted;


	DROP TABLE IF EXISTS #Checked
	SELECT DISTINCT MVIPersonSID
			,MitigationID
			,MitigationIDRx
			,PrintName
			,PrintNameRx
			,DetailsText
			,DetailsDate
			,MetricInclusion
			,SUDdx_poss
			,OpioidForPain_Rx
			,Bowel_Rx
			,DetailsRedRules
			,ODPastYear
			,OUD_DoD
			,ReferenceDate 
			,ODdate
			,PreparatoryBehavior
			,Checked=
				CASE WHEN MitigationID IN (4,6,7,14,15) AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules THEN 1
					 WHEN MitigationID = 1  AND DetailsText <= DetailsRedRules THEN 1
					 WHEN MitigationID = 1  AND DetailsText IS NULL THEN 1
					 WHEN MitigationID = 2  AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules AND DetailsText = 'Filled' THEN 1
					 WHEN MitigationID = 2  AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules AND DetailsText = 'Current Rx' THEN 1
					 WHEN MitigationID = 3  AND DetailsDate IS NOT NULL THEN 1
					 WHEN MitigationID = 5  AND DATEDIFF(D, DetailsDate, GETDATE()) < 366 and ChronicOpioid = 1 AND (MetricInclusion = 1) AND SUDdx_poss = 0	THEN 1
					 WHEN MitigationID = 5  AND DATEDIFF(D, DetailsDate, GETDATE()) < 366 and ChronicOpioid = 0 AND (MetricInclusion = 1) AND SUDdx_poss = 0	THEN 1
					 WHEN MitigationID = 5  AND DATEDIFF(D, DetailsDate, GETDATE()) < 91 and SUDdx_poss = 1 AND (MetricInclusion = 1) THEN 1 
					 WHEN MitigationID = 5  AND MetricInclusion = 0  THEN 1 
					 WHEN MitigationID = 8  AND Bowel_Rx = 1 THEN 1
					 --WHEN MitigationID = 10 AND DATEDIFF(D, DetailsDate, GETDATE()) < 366 and OpioidForPain_Rx = 0 THEN 1
					 WHEN MitigationID = 10 AND DATEDIFF(D, DetailsDate, GETDATE()) < 366 and (OpioidForPain_Rx = 0 OR OpioidForPain_Rx IS NULL) THEN 1
					 WHEN MitigationID = 10 AND DATEDIFF(D, DetailsDate, GETDATE()) < 91 and OpioidForPain_Rx = 1 THEN 1
					 WHEN MitigationID = 12 AND (ODPastYear = 1 
											AND ReferenceDate IS NOT NULL 
											AND CAST(ReferenceDate AS DATE) >= CAST(ODdate AS DATE))
											AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules THEN 1 
					 WHEN MitigationID = 12 AND MetricInclusion = 1 AND (ODPastYear = 0 OR ODPastYear IS NULL)
											AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules THEN 1 
                     --Adding new rule for LTOT
                      WHEN MitigationID = 12 AND MetricInclusion = 1 AND ChronicOpioid = 1 AND (ODPastYear = 0 OR ODPastYear IS NULL)
											AND DetailsDate IS NOT NULL THEN 1
					 WHEN MitigationID = 13 AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules and DetailsText = 'Completed' THEN 1
					 WHEN MitigationID = 17 AND ODPastYear = 1 
											AND ReferenceDate IS NOT NULL 
											AND CAST(ReferenceDate AS DATE) >= CAST(ODdate AS DATE) THEN 1 --Not sure if the datetime issue will affect this
					 WHEN MitigationID = 18 AND CAST(ODdate as DATE) > CAST(CC_ODdate AS DATE) THEN 1
					 ELSE 0 END 
			,Red=
				CASE WHEN MitigationID = 1 AND MetricInclusion = 1 AND DetailsText > DetailsRedRules THEN 1

					 WHEN MitigationID = 2  AND ((DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) >= DetailsRedRules) OR DetailsText NOT IN ('Filled','Current Rx')) THEN 1
					 WHEN MitigationID IN (3,4,6,7) AND MetricInclusion =1 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) >= DetailsRedRules) THEN 1
					 WHEN MitigationID = 5  AND SUDdx_poss = 0 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 365) AND (MetricInclusion = 1) THEN 1
					 WHEN MitigationID = 5  AND SUDdx_poss = 1 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 90) AND (MetricInclusion = 1) THEN 1
					 WHEN MitigationID = 5  AND DetailsDate IS NULL AND MetricInclusion = 1 THEN 1
					 WHEN MitigationID = 8 AND MetricInclusion = 1 AND DetailsDate IS NULL AND Bowel_Rx = 0 THEN 1
					 WHEN MitigationID = 10 AND (OpioidForPain_Rx = 0 OR OpioidForPain_Rx IS NULL) AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 365) THEN 1
					 WHEN MitigationID = 10 AND OpioidForPain_Rx = 1 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 90) THEN 1
					 WHEN MitigationID = 12 AND (ODPastYear = 1 
											AND ReferenceDate IS NOT NULL 
											AND CAST(ReferenceDate AS DATE) < CAST(ODdate AS DATE)) THEN 1
					 WHEN MitigationID = 12 AND MetricInclusion = 1 
											AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) >= DetailsRedRules) THEN 1 
                    --Adding the new LTOT rule on the next line
					WHEN MitigationID = 12 AND MetricInclusion = 1 AND ChronicOpioid = 1 AND (ODPastYear = 0 OR ODPastYear IS NULL)
											AND DetailsDate IS NULL THEN 1 
                     WHEN MitigationID = 13  AND ((DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) >= DetailsRedRules) OR DetailsText NOT IN ('Completed')) THEN 1
					 WHEN MitigationID = 14  AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 90) AND (MetricInclusion = 1) THEN 1
					 WHEN MitigationID = 15  AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 90) AND (MetricInclusion = 1) THEN 1
					 WHEN MitigationID = 17 AND ODPastYear = 1 
											AND ReferenceDate IS NOT NULL
											AND CAST(ReferenceDate AS DATE) < CAST(ODdate AS DATE) THEN 1
					 WHEN MitigationID = 17 AND ODPastYear = 1 AND ReferenceDate IS NULL THEN 1
					 ELSE 0 END
	INTO #Checked
	FROM #AllTogether;

----------------------------------------------------------------------------
-- ADD A FLAG FOR WHETHER A BASELINE SET OF RISK MITIGATIONS HAVE BEEN MET
-- BASELINE MITIGATION SET INCLUDES:
------ INFORMED CONSENT (RM 3)
------ TIMELY FOLLOW-UP (RM 4)
------ UDS (RM 5)
------ PDMP (RM 10)
------ DBORR (RM 12)
------ SUD TX (RM 14)
----------------------------------------------------------------------------
/********Getting the baseline mitigation met logic. Similar to #MetricInclusion17***********/
	DROP TABLE IF EXISTS #Baseline
	SELECT MVIPersonSID
		  ,SUM(MetricInclusion) AS BaselineD
		  ,SUM(Checked) AS BaselineN 
	INTO #Baseline
	FROM #Checked 
	WHERE MitigationID IN (3,4,5,10,12,14)
	AND MetricInclusion = 1 
	GROUP BY MVIPersonSID

----------------------------------------------------------------------------
-- PUBLISH THE FINAL TABLE
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Staging;
	SELECT DISTINCT cd.MVIPersonSID
		   ,cd.MitigationID
		  ,CASE WHEN cd.MitigationID = 5 AND MetricInclusion = 0 THEN 'Drug Screen (NA)'
				ELSE cd.PrintName
				END AS PrintName
		  ,CASE WHEN cd.MitigationID = 17 AND cd.DetailsDate IS NOT NULL AND PreparatoryBehavior = 0 THEN 'Overdose Event On'
				WHEN cd.MitigationID = 17 AND cd.DetailsDate IS NOT NULL AND PreparatoryBehavior = 1 THEN 'Preparatory Behavior On'
				WHEN cd.MitigationID = 18 AND cd.DetailsDate IS NOT NULL THEN 'Community Care Report On'
				ELSE cd.DetailsText
				END AS DetailsText
		  ,CAST(cd.DetailsDate as DATE) as DetailsDate
		  --added ODPastYear = 0 because review on or after overdose event satisfies requirement for ODPastYear = 1
		  ,CASE	WHEN MitigationID = 17 AND bl.BaselineN = bl.BaselineD 
				AND ODPastYear = 0 AND  MetricInclusion = 1 THEN 1            
				ELSE Checked END AS Checked
		  ,CASE WHEN MitigationID = 17 AND bl.BaselineN < bl.BaselineD 
				AND ODPastYear = 0 AND MetricInclusion = 1 THEN 1
				ELSE Red END AS Red
		  ,MetricInclusion
		  ,cd.MitigationIDRx
		  ,CASE WHEN cd.PrintNameRx IS NOT NULL AND MetricInclusion = 0 THEN cd.PrintNameRx + ' (NA)'
		      ELSE cd.PrintNameRx
			  END AS PrintNameRx
		  ,CASE WHEN  cd.MitigationIDRx = 5  
		         AND DATEDIFF(D, DetailsDate, GETDATE()) < 366 THEN 1
				 WHEN cd.MitigationIDRx IS NOT NULL AND MetricInclusion = 0 THEN 1
				 ELSE cd.Checked END AS CheckedRx
		 ,CASE WHEN cd.MitigationIDRx = 5 AND MetricInclusion = 1 AND DATEDIFF(D, DetailsDate, GETDATE()) >= 366 THEN 1
		       WHEN cd.MitigationIDRx = 5  AND DATEDIFF(D, DetailsDate, GETDATE()) >= 90 AND 
			   DATEDIFF(D, DetailsDate, GETDATE()) <366 THEN 0
			   --WHEN cd.MitigationIDRx = 5 AND MetricInclusion = 0 THEN 0
				ELSE cd.Red
				END AS RedRx
	INTO #Staging 
	FROM #Checked cd
	LEFT JOIN #Baseline bl 
		ON cd.MVIPersonSID = bl.MVIPersonSID;


	-- Delete records where Active SUD Tx is pulling in red rules for non required.
	DELETE FROM #Staging
		   WHERE MetricInclusion = 0 
		   and MitigationID IN (4, 14);


	-- Delete records in dataset that are no longer relevant to recommended mitigation strategies
	DELETE FROM #Staging
		   WHERE MitigationID IN (2, 4, 6, 7, 12, 13, 14, 15, 16, 17, 18)
		   AND Red=0 AND Checked=0 AND MetricInclusion=0;

EXEC Maintenance.PublishTable 'ORM.RiskMitigation', '#Staging'

EXEC [Log].[ExecutionEnd]

END

GO
