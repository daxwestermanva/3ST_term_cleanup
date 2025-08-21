
-- =============================================
-- Author: Pooja Sohoni
-- Create date: 2021-07-27
-- Description: Creating a combined cohort for STORM and PDSI patients. This will include
-- patients on prescriptions of interest as well as diagnoses of interest.

-- Last Update:
	-- 2021-08-12	MCP: Adding in join to drop deceased patients
	-- 2021-08-30	RAS: Formatting, no locks.
	-- 2021-09-23	JEB: Enclave Refactoring - Removed use of Partition ID
	-- 2021-09-28	MCP: Adding PTSD and Sedative Use Disorder for PDSI cohort
	-- 2021-10-12	LM:  Specifying outpat, inpat, and DoD diagnoses (excluding dx only from community care or problem list)
	-- 2021-12-06	TG - adding overdose cohort for the "New Interdisciplinary team review"
	-- 2021-12-17	TG - corrected the overdose in the past year (date logic)
	-- 2021-12-19	RAS: Updated date logic for ODPastYear, added distinct to that query to avoid duplicate rows, 
						--	and added OSPastYear to STORM cohort (STORM = 1 in final table)
	-- 2021-12-20	RAS: Changed OpioidForPain_Rx to come from ORM.OpioidHistory so that these always match.
	-- 2022-06-17	LM:  Pointed to Lookup.StopCode
	-- 2022-08-04	MP: Replacing stimulant_rx with stimulantADHD_Rx per metric requirements
	-- 2022-12-14   TG: Changing the FULL OUTER JOIN to RIGHT JOIN because 0 for ODPastYear was assigned to some patients
	                 --while they had OD in the past year.
    -- 2023-01-06   TG: changing the FULL OUTER JOIN back because it cut the SUD cohort dramatically and
	                --instead maxing the OD variable to avoid duplicates.
	-- 2023-01-09	CW: Adding in additional step to remove duplicates in #Cohort. 
					--Now using LEFT JOINS instead of FULL OUTER JOINS.
	-- 2023-30-11	CW: Adding in recently discontinued cohort to complete full STORM cohort
	-- 2024-10-01   CW: Adding OUD_DoD into the cohort for downstream use/identification
	-- 2024-02-08   TG: Restricting the delete statement from removing DoD OUD patients
	-- 2024-02-22	MP:	Changing AUD reference to AUD_ORM to match MDS ALC_top measure
	-- 2024-06-05  CW: Adding Community Care Overdose cohort where no SBOR recorded after community care overdose/claim date
	-- 2024-07-16  TG: Switching to the new hospice care dataset for hospice variable.
	-- 2024-10-21	MP: Additions to PDSI cohort for Phase 6
	-- 2025-03-04	MP: Switching Antipsychotic_rx to Antipsychotic_Geri_Rx

-- Combined STORM and PDSI cohort table
	---- MVIPersonSID
	---- PDSI
	---- STORM
	---- SUDdx_poss
	---- Benzo Rx
	---- Stimulant_ADHD_Rx
	---- OpioidforPain_Rx
	---- OUD
	---- AUD_ORM
	---- Stimulant UD
	---- Cancer
	---- Hospice
	---- Bowel_Rx
	---- Anxiolytics_Rx
	---- SedatingPainORM_Rx
	---- TramadolOnly
	---- PTSD
	---- SedativeUseDisorder
	---- Antipsychotics
	---- Dementia w/o SMI, huntington's, tourette's, hospice
	---- Schiz


-- Remaining STORM fields
	-- Opioid metadata
		-- NonChronicShortActing - OpioidHistory
		-- ChronicShortActing - OpioidHistory
		-- LongActing - OpioidHistory
		-- ChronicOpioid - OpioidHistory
		-- MEDD_Report - RiskScore
		-- MEDD_RiskScore - RiskScore

-- Names
	-- SUD
	-- Drugs
	-- Rx

-- Plan
	-- 1) Combined cohort - PS
	-- 2) Move phase 1 and 2 out of PDSI (JT approved) - MP
	-- 3) New code for phases 3-5, with new architecture - MP 
-- ==============================================
CREATE PROCEDURE [Code].[SUD_Cohort]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.SUD_Cohort', @Description = 'Execution of Code.SUD_Cohort SP'

----------------------------------------------------------------
-- Diagnoses
----------------------------------------------------------------
DROP TABLE IF EXISTS #Diagnoses
SELECT MVIPersonSID
	 ,MAX(OUD) as OUD
	 ,MAX(SUDdx_poss) as SUDdx_poss
	 ,MAX(AUD_ORM) as AUD_ORM
	 ,MAX(CocaineUD_AmphUD) as CocaineUD_AmphUD
	 ,MAX(PTSD) as PTSD
	 ,MAX(SedativeUseDisorder) as SedativeUseDisorder
	 ,MAX(Schiz) as Schiz
	 ,MAX(Dementia) as Dementia
	 ,MAX(SMI) as SMI
	 ,MAX(Huntington) as Huntington
	 ,MAX(Tourette) as Tourette
INTO #Diagnoses
FROM (
	SELECT MVIPersonSID
		  ,DxCategory
		  ,Flag=1
	FROM [Present].[Diagnosis] WITH(NOLOCK) 
	WHERE DxCategory IN (
		'OUD'
		,'SUDDx_poss'
		,'AUD_ORM'
		,'CocaineUD_AmphUD'
		,'PTSD'
		,'SedativeUseDisorder'
		,'Schiz'
		,'Dementia'
		,'SMI'
		,'Huntington'
		,'Tourette')
	AND (Outpat=1 OR Inpat=1 OR DoD=1)
	) pv
PIVOT (MAX(Flag) FOR DxCategory IN (OUD,SUDDx_poss,AUD_ORM,CocaineUD_AmphUD,PTSD,SedativeUseDisorder,Schiz,Dementia,SMI,Huntington,Tourette)
	) upvt
GROUP BY MVIPersonSID

----------------------------------------------------------------
-- Dementia w/o concurrent SMI, Huntington's, Tourette's
----------------------------------------------------------------
DROP TABLE IF EXISTS #DementiaExcl
SELECT MVIPersonSID
	  ,DementiaExcl = CASE WHEN Dementia = 1 AND SMI IS NULL AND Huntington IS NULL AND Tourette IS NULL THEN 1 ELSE 0 END
INTO #DementiaExcl
FROM #Diagnoses
WHERE Dementia = 1

----------------------------------------------------------------
-- Pivot Medications
----------------------------------------------------------------
-- Added OpioidForPain separately to keep aligned with data in OpioidHistory
-- most of the time this will match Present Medications, 
-- but sometimes if CDW data changes between the 2 SPs running, 
-- then they will get out of sync on RxStatus
DROP TABLE IF EXISTS #OpioidForPain
SELECT MVIPersonSID
	,OpioidForPain_Rx = 1
	,TramadolOnly = CASE WHEN SUM(NonTramadol) = 0 THEN 1 ELSE 0 END
INTO #OpioidForPain
FROM [ORM].[OpioidHistory] WITH(NOLOCK)
WHERE Active = 1
GROUP BY MVIPersonSID

DROP TABLE IF EXISTS #RecentlyDiscontinued
SELECT DISTINCT -- "recently" discontinued taken from Code.ORM_PatientReport
	oh.MVIPersonSID
	,RecentlyDiscontinuedOpioid_Rx = 1
INTO #RecentlyDiscontinued
FROM [ORM].[OpioidHistory] oh
LEFT JOIN [SUD].[Cohort] c on c.MVIPersonSID=oh.MVIPersonSID AND oh.Active = 0
WHERE (c.OUD IS NULL OR c.OUD = 0 OR ODPastYear = 0) --only non-OUD because OUD is included in RiskScore, not hypothetical
	AND CAST(dateadd(DAY,DaysSupply,ReleaseDateTime) AS DATE) >= CAST(GETDATE() - 180 AS DATE) ;

DROP TABLE IF EXISTS #Medications
SELECT m.MVIPersonSID
	  ,MAX(CAST(Anxiolytics_Rx		AS INT)) AS Anxiolytics_Rx	
	  ,MAX(CAST(Benzodiazepine_Rx	AS INT)) AS Benzodiazepine_Rx
	  ,MAX(CAST(Bowel_Rx			AS INT)) AS Bowel_Rx			
	  ,MAX(CAST(SedatingPainORM_Rx	AS INT)) AS SedatingPainORM_Rx
	  ,MAX(CAST(StimulantADHD_Rx	AS INT)) AS StimulantADHD_Rx
	  ,MAX(CAST(Antipsychotic_Geri_Rx	AS INT)) AS Antipsychotic_Geri_Rx
INTO #Medications
FROM [Present].[Medications] m
WHERE 1 IN ( -- No need to flag tramadol because it's captured by OpioidforPain_Rx
	Anxiolytics_Rx
	,Benzodiazepine_Rx
	,Bowel_Rx
	,SedatingPainORM_Rx
	,StimulantADHD_Rx
	,Antipsychotic_Geri_Rx
	) 
GROUP BY m.MVIPersonSID

--Overdose in the past year
DROP TABLE IF EXISTS #OverDosePastYear;
SELECT DISTINCT MVIPersonSID   
      ,1 AS ODPastYear 
  INTO #OverDosePastYear
  FROM [OMHSP_Standard].[SuicideOverdoseEvent]
  WHERE (
		EventDateFormatted >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))
		OR (EventDateFormatted IS NULL
			AND EntryDateTime > DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)))
		)
	AND Overdose = 1
	AND Fatal = 0
	AND MVIPersonSID IS NOT NULL

----------------------------------------------------------------
-- OUD from DoD
----------------------------------------------------------------
DROP TABLE IF EXISTS #OUD_DoD
SELECT DISTINCT MVIPersonSID, OUD_DoD=1	
INTO #OUD_DoD
FROM [ORM].[DoD_OUD]

----------------------------------------------------------------
-- Community Care Overdose with no SBOR
----------------------------------------------------------------
DROP TABLE IF EXISTS #CC_Overdose
SELECT DISTINCT MVIPersonSID, CommunityCare_ODPastYear=1
INTO #CC_Overdose
FROM [CommunityCare].[ODUniqueEpisode]
WHERE SBOR_CSRE_Any=0 --no SBOR was recorded after community care episode
AND ExpectedSBOR=1 --SBOR was expected
AND CAST(EpisodeStartDate as DATE) > DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))

----------------------------------------------------------------
-- Combine Dx and Medications into a single cohort table
----------------------------------------------------------------
--Adding step to remove duplicate rows below and ensure accurate values for ODPastYear variable
DROP TABLE IF EXISTS #CohortPrep 
SELECT MVIPersonSID INTO #CohortPrep FROM #Diagnoses
UNION
SELECT MVIPersonSID FROM #Medications
UNION
SELECT MVIPersonSID FROM #OverDosePastYear
UNION
SELECT MVIPersonSID FROM #OpioidForPain
UNION
SELECT MVIPersonSID FROM #RecentlyDiscontinued
UNION
SELECT MVIPersonSID FROM #OUD_DoD
UNION
SELECT MVIPersonSID FROM #CC_Overdose

--Combining for cohort
DROP TABLE IF EXISTS #Cohort 
SELECT P.MVIPersonSID
       ,ISNULL(d.OUD								,0) as OUD
       ,ISNULL(d.SUDdx_poss							,0) as SUDdx_poss
       ,ISNULL(d.AUD_ORM							,0) as AUD_ORM
       ,ISNULL(d.CocaineUD_AmphUD					,0) as CocaineUD_AmphUD
       ,ISNULL(orx.OpioidForPain_Rx					,0) as OpioidForPain_Rx
	   ,ISNULL(rd.RecentlyDiscontinuedOpioid_Rx     ,0) as RecentlyDiscontinuedOpioid_Rx
       ,ISNULL(m.Anxiolytics_Rx						,0) as Anxiolytics_Rx
       ,ISNULL(m.Benzodiazepine_Rx					,0) as Benzodiazepine_Rx
       ,ISNULL(m.Bowel_Rx							,0) as Bowel_Rx
       ,ISNULL(m.SedatingPainORM_Rx					,0) as SedatingPainORM_Rx
       ,ISNULL(m.StimulantADHD_Rx					,0) as StimulantADHD_Rx
       ,ISNULL(orx.TramadolOnly						,0) as TramadolOnly
       ,ISNULL(d.PTSD								,0) as PTSD
       ,ISNULL(d.SedativeUseDisorder				,0) as SedativeUseDisorder
       ,ISNULL(od.ODPastYear						,0) as ODPastYear
       ,ISNULL(dod.OUD_DoD							,0) as OUD_DoD
	   ,ISNULL(CommunityCare_ODPastYear				,0) as CommunityCare_ODPastYear
	   ,ISNULL(m.Antipsychotic_Geri_Rx				,0) as Antipsychotic_Geri_Rx
	   ,ISNULL(d.Schiz								,0) as Schiz
	   ,ISNULL(de.DementiaExcl						,0) as DementiaExcl

INTO #Cohort
FROM #CohortPrep p
LEFT JOIN #Diagnoses d ON p.MVIPersonSID=d.MVIPersonSID
LEFT JOIN #Medications m ON p.MVIPersonSID=m.MVIPersonSID
LEFT JOIN #OverDosePastYear od ON p.MVIPersonSID = od.MVIPersonSID 
LEFT JOIN #OpioidForPain orx ON orx.MVIPersonSID = p.MVIPersonSID
LEFT JOIN #RecentlyDiscontinued rd ON rd.MVIPersonSID=p.MVIPersonSID
LEFT JOIN #OUD_DoD dod ON dod.MVIPersonSID=p.MVIPersonSID
LEFT JOIN #CC_Overdose cc ON cc.MVIPersonSID=p.MVIPersonSID
LEFT JOIN #DementiaExcl de ON de.MVIPersonSID=p.MVIPersonSID
WHERE p.MVIPersonSID > 0;

--Remove test/deceased patients
DELETE C 
FROM #Cohort as c
LEFT JOIN [Common].[MasterPatient] mp ON mp.MVIPersonSID = c.MVIPersonSID
WHERE (mp.MVIPersonSID IS NULL AND C.OUD_DoD = 0) -- e.g. test patients
	OR mp.DateOfDeath IS NOT NULL --remove decedents
	OR (c.MVIPersonSID IS NULL OR c.MVIPersonSID=0) --also remove invalid MVIPersonSID

/***** Flag: Hospice Care*************** */ 
DROP TABLE IF EXISTS #Hospice_STOPCODE 
SELECT DISTINCT 
	co.MVIPersonSID
	, 1 AS HospiceCare
INTO #Hospice_STOPCODE
FROM #Cohort co
INNER JOIN  ORM.HospicePalliativeCare hp
	ON co.MVIPersonSID = hp.MVIPersonSID AND hp.Hospice = 1

/**************** Flag: Cancer via dx or stopcode *************************/
--NOTE: including most accurate ActivityType information as of 12/2020.
--May chance as JT gets updates.

DROP TABLE IF EXISTS #Cancer_STOPCODE_ORM 
SELECT DISTINCT 
	a.MVIPersonSID
    ,1 AS Cancer_StopCode 
INTO #Cancer_STOPCODE_ORM
FROM (
	SELECT co.MVIPersonSID
	FROM #Cohort co 
	INNER JOIN (
		SELECT 
			ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
			,ov1.PrimaryStopCodeSID
			,ov1.SecondaryStopCodeSID
			,ov1.locationSID
		FROM [Outpat].[Visit] ov1 WITH (NOLOCK) 
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) ON ov1.PatientSID = mvi.PatientPersonSID 
		WHERE ov1.VisitDateTime >= CAST(DATEADD(DAY,-366,GETDATE())AS DATETIME2(0))
		) ov ON co.MVIPersonSID = ov.MVIPersonSID
	INNER JOIN [Dim].[Location] lo WITH (NOLOCK) ON ov.locationSID = lo.locationSID
	WHERE lo.PrimaryStopCodeSID IN 
			(
				SELECT DISTINCT StopCodeSID 
				FROM [Lookup].[StopCode] WITH (NOLOCK)
				WHERE Cancer_Stop=1 
			) 
		OR lo.SecondaryStopCodeSID IN 
			(
				SELECT DISTINCT StopCodeSID 
				FROM [Lookup].[StopCode] WITH (NOLOCK)
				WHERE Cancer_Stop=1
			)

	UNION ALL

	SELECT co.MVIPersonSID
	FROM #Cohort AS co
	INNER JOIN [Cerner].[FactUtilizationOutpatient] fuo WITH(NOLOCK) ON fuo.MVIPersonSID=co.MVIPersonSID
	WHERE fuo.MedicalService IN ('Oncology','Radiation Oncology','Hematology')
		AND fuo.TZDerivedVisitDateTime >= cast(dateadd(day,-366,GETDATE())as datetime2(0))
	) a 
	--should we change this to use Cerner Stop Codes?
	--SELECT a.MVIPersonSID 
	--FROM #cohort co
	--INNER JOIN [Cerner].[FactUtilizationStopCode] a WITH (NOLOCK) ON a.MVIPersonSID=co.MVIPersonSID
	--INNER JOIN Lookup.StopCode b WITH (NOLOCK) ON a.CompanyUnitBillTransactionAliasSID = b.StopCodeSID
	--WHERE b.Cancer_Stop = 1 AND a.TZServiceDateTime >= cast(dateadd(day,-366,GETDATE())as datetime2(0))

DROP TABLE IF EXISTS #CancerDx 
SELECT  DISTINCT co.MVIPersonSID, CancerDx=1
INTO #CancerDx
FROM #Cohort AS co 
LEFT OUTER JOIN (
	SELECT DISTINCT MVIPersonSID,CancerDx=1
	FROM [Present].[Diagnosis] WITH(NOLOCK)
	WHERE DxCategory IN ('EH_LYMPHOMA','EH_METCANCR','EH_SolidTumorNoMet')
	AND (Outpat=1 OR Inpat=1 OR DoD=1)
	) as dx ON co.MVIPersonSID = dx.MVIPersonSID
LEFT OUTER JOIN #Cancer_STOPCODE_ORM as sc ON co.MVIPersonSID=sc.MVIPersonSID
WHERE dx.CancerDx= 1
	OR sc.Cancer_StopCode =1

----------------------------------------------------------------
/****STAGE AND PUBLISH SUD.COHORT****/
----------------------------------------------------------------
DROP TABLE IF EXISTS #Stage_SUD_Cohort 
SELECT c.MVIPersonSID
	  ,CASE WHEN c.OUD = 1 OR c.OpioidforPain_Rx = 1 OR ODPastYear = 1 OR RecentlyDiscontinuedOpioid_Rx=1 THEN 1 
	   ELSE 0
	   END AS STORM
   	  ,OUD_DoD
	  ,CASE WHEN c.OUD = 1 OR c.AUD_ORM = 1 OR c.CocaineUD_AmphUD = 1 OR c.StimulantADHD_Rx = 1 OR c.Benzodiazepine_Rx = 1 OR c.PTSD = 1 OR SedativeUseDisorder = 1 OR c.OpioidforPain_Rx = 1 OR Schiz = 1 OR DementiaExcl = 1 OR Antipsychotic_Geri_Rx = 1 THEN 1
	   ELSE 0
	   END AS PDSI
	  ,c.OUD
	  ,c.AUD_ORM
	  ,c.SUDdx_poss
	  ,c.CocaineUD_AmphUD
	  ,c.OpioidforPain_Rx
	  ,c.RecentlyDiscontinuedOpioid_Rx
	  ,c.Anxiolytics_Rx
	  ,c.Benzodiazepine_Rx
	  ,c.Bowel_Rx
	  ,c.SedatingPainORM_Rx
	  ,c.StimulantADHD_Rx
	  ,c.TramadolOnly
	  ,ISNULL(ca.CancerDx,0) AS CancerDx
	  ,ISNULL(h.HospiceCare,0) AS Hospice
	  ,c.PTSD
	  ,c.SedativeUseDisorder
	  ,c.ODPastYear
	  ,c.CommunityCare_ODPastYear
	  ,c.Schiz
	  ,c.DementiaExcl
	  ,c.Antipsychotic_Geri_Rx
INTO #Stage_SUD_Cohort
FROM #Cohort c
LEFT JOIN #CancerDx ca on c.MVIPersonSID = ca.MVIPersonSID
LEFT JOIN #Hospice_STOPCODE h on c.MVIPersonSID = h.MVIPersonSID

EXEC [Maintenance].[PublishTable] 'SUD.Cohort', '#Stage_SUD_Cohort'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END