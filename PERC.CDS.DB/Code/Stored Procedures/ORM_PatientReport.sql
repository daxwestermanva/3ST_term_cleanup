
-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/13/2017
-- Description: ORM Patient Report 
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
-- 2019/01/14 - Susana Martins	Updating code to randomize patients by assigned homestation
-- 2019/01/14 - Susana Martins	focused on homestationing only patients in very high and high risk category
-- 2019/01/14 - Susana Martins	updated code to remove the 'rand' variables from final table to avoid confusion. This issue will disappear in 9m when randomization ends.
-- 2019/01/31 commented out update query for randomization implementation. Will activate on hotfix date since it has been fully validated
-- 2019/02/25 - Pooja Sohoni - Adding code to pull in recently discontinued patients
-- 2019/03/28 - Pooja Sohoni - Removing OUD from recently discontinued patients to reduce double-counting
-- 2019/08/12 Opening randomization to all groups based on Taeko's requirements
-- 2020/1/7 - Cora Bernard - Reformulating for readability/efficiency; changed recent opioid discontinuation calculation to capture more
-- 2020/1/22 - Cora Bernard - Removing HomeStation randomization calculations and column
-- 2020/03/30 - RAS - Formatting and added logging.
-- 2020/04/30 - RAS - Updated Very High threshold to .08 instead of .0609 per JT decision to limit group expansion caused by updated to MEDD and definitions.
-- 2020-05-01 - RAS - Changed discontinued criteria to OpioidOnHand=0 instead of Active=2 (updated initial 2 queries)
-- 2020-05-28 - RAS - Reverted to old Very High Risk cutoff .0609
-- 2020-10-13 - PS  - Adding MVIPersonSID, changing to current definition of active med
-- 2020-10-14 - LM - Pointing to _VM tables
-- 2021-12-14 - TG - Adding Past Year Overdose cohort
-- 2021-12-15 - TG - Added overdose date to apply to new measure
-- 2022-02-02 - TG - Fix for duplicate risk categories
-- 2022-02-02 - TG - Removing overdose patients from recently discontinued.
-- 2022-03-25 - TG - added cases statements to isolate preparatory behaviors from actual overdose events
-- 2022-05-13 - TG - switching to the new RIOSORD from Academic Detailing.
-- 2022-06-17 - TG - Removing a column which isn't necessary.
-- 2022-07-08 - JEB - Updated Synonym references to point to Synonyms from Core
-- 2023-11-30 - CW - Removing duplicates in #PatientReportStage given upstream changes to SUD.Cohort
-- 2024-03-26 - TG - Removing NULL values from staging table because it keeps failing in production
-- 2024-06-05 - CW - Adding community care past year overdose cohort; re-architecting parts of code to help with readibility re: need for mutually exclusive riskcategories
-- 2025-02-21 - TG - Fixing a bug affecting overdose/preparatory behavior display because of some documentation issues on the same date.
-- 07-23-2025   TG  Making "Elevated Risk Due To" language changes per PMOPT request
-- 08-06-2025 - TG  Fixing a bug that overrode "Elevated Risk" language for OUD Dx category.
-- 08-14-2025 - TG  Adjusting the "Elevated Risk" category logic
-- =============================================
CREATE PROCEDURE [Code].[ORM_PatientReport]
	-- Add the parameters for the stored procedure here
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.ORM_PatientReport','Execution of SP Code.ORM_PatientReport'

----------------------------------------------------------------------------
-- STEP 1:  Identify patients who have recently discontinued opioids
----------------------------------------------------------------------------
-- Get all patients without and active RxStatus nor pills on hand
DROP TABLE IF EXISTS #Discontinued
SELECT oh.MVIPersonSID
	  ,MAX(cast(OpioidOnHand as int)) as OpioidOnHand
INTO #Discontinued
FROM [ORM].[OpioidHistory] oh
GROUP BY MVIPersonSID
HAVING MAX(cast(Active as int)) = 0;


/* Moving this up because there are overdose time period goes beyond the six months in discontinuation.*/
--Get Overdose in Past Year patients, with most recent OD date
DROP TABLE IF EXISTS #ODDate
SELECT DISTINCT
	sud.MVIPersonSID
	,sud.ODPastYear
	,od.PreparatoryBehavior
	,ISNULL(od.EventDateFormatted,od.EntryDateTime) AS ODdate
	,ROW_NUMBER() OVER (PARTITION BY od.MVIPersonSID ORDER BY EventDateFormatted DESC,EntryDateTime DESC) AS RN
INTO #ODDate
FROM [SUD].[Cohort] sud
INNER JOIN [OMHSP_Standard].[SuicideOverdoseEvent] od
	ON sud.MVIPersonSID = od.MVIPersonSID
WHERE sud.ODPastYear = 1 AND od.Overdose = 1
;

DROP TABLE IF EXISTS #ODPastYear
SELECT DISTINCT sud.MVIPersonSID
	,sud.ODPastYear
	,ODdate
	,PreparatoryBehavior
INTO #ODPastYear
FROM #ODDate sud
WHERE RN = 1


DROP TABLE IF EXISTS #CC_ODPastYear
SELECT c.MVIPersonSID
	,c.CommunityCare_ODPastYear
	,ChecklistID=ISNULL(od.ChecklistID,'0')
	,MAX(CAST(EpisodeStartDate as date)) as CC_ODdate
INTO #CC_ODPastYear
FROM SUD.Cohort c
INNER JOIN [CommunityCare].[ODUniqueEpisode] od WITH(NOLOCK) 
	ON c.MVIPersonSID = od.MVIPersonSID
	AND ExpectedSBOR=1 --SBOR was expected
	AND SBOR_CSRE_Any=0 --no SBOR was recorded after community care episode
WHERE c.CommunityCare_ODPastYear = 1
AND CAST(EpisodeStartDate as DATE) > DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))
GROUP BY c.MVIPersonSID, c.CommunityCare_ODPastYear, od.ChecklistID


--Find only "recently" discontinued
-- from the patients identified above, get those where pills have run out in the last 180 days
DROP TABLE IF EXISTS #RecentlyDiscontinued
SELECT DISTINCT
	oh.MVIPersonSID
INTO #RecentlyDiscontinued
FROM [ORM].[OpioidHistory] oh
INNER JOIN #Discontinued as np on np.MVIPersonSID=oh.MVIPersonSID
LEFT JOIN [SUD].[Cohort] c on c.MVIPersonSID=oh.MVIPersonSID
WHERE (c.OUD IS NULL OR c.OUD = 0) --only non-OUD because OUD is included in RiskScore, not hypothetical
	AND c.OpioidForPain_Rx = 0
	--AND c.ODPastYear = 0 --only those without recent overdose, as those go into separate category
	AND CAST(dateadd(DAY,DaysSupply,ReleaseDateTime) AS DATE) >= CAST(GETDATE() - 180 AS DATE)
	AND NOT EXISTS (SELECT MVIPersonSID FROM #ODPastYear a
	                WHERE a.MVIPersonSID = np.MVIPersonSID);

----------------------------------------------------------------------------
-- STEP 2:  Assemble the cohort with risk categories
-- The cohort should be the original STORM cohort (active opioid for pain 
-- and/or OUD diagnosis) + the recently discontinued opioid cohort + VHA reported
-- overdose in past year (ODPastYear) + possing community care overdose past 
-- year (CommunityCare_ODPastYear)
--
-- Category labels need to be mutually exclusive. (per JT May-2024)
----------------------------------------------------------------------------

-- OUD AND OPIOIDFORPAIN_RX 
DROP TABLE IF EXISTS #OUD_OpioidForPain_Category
SELECT a.MVIPersonSID
	,r.RiskScore
	,r.RiskScoreAny
	,(r.RiskScore-r.RiskScoreNoSed)/r.RiskScore as RiskScoreOpioidSedImpact
	,(r.RiskScoreAny-r.RiskScoreAnyNoSed)/r.RiskScoreAny as RiskScoreAnyOpioidSedImpact
	,CASE WHEN r.RiskCategory=4 AND p.MVIPersonSID IS NOT NULL THEN 10
		 ELSE r.RiskCategory 
		 END AS RiskCategory
	,r.RiskAnyCategory
	,CASE WHEN r.RiskCategory=4 AND p.MVIPersonSID IS NOT NULL THEN 'Very High - Active Status, No Pills on Hand'
		 ELSE r.RiskCategoryLabel
		 END AS RiskCategoryLabel
	,r.RiskAnyCategoryLabel
	,a.OpioidForPain_Rx
    ,a.OUD 
    ,a.SUDdx_poss 
    ,a.Hospice
    ,a.Anxiolytics_Rx  
	,1 as ORMCohort
	,0 as ODPastYear
	,ODdate=CAST(NULL as date)
	,CC_ODdate=CAST(NULL as date)
	,0 as CommunityCare_ODPastYear
	,0 as PreparatoryBehavior
	,0 as ODPastYear_Category
	,1 as OUD_OpioidForPain_Category
	,0 as RecentlyDiscontinued_HypotheticalCategory
	,0 as CC_ODPastYear_Category
INTO #OUD_OpioidForPain_Category
FROM (	SELECT s.MVIPersonSID 
			,OpioidForPain_Rx
			,OUD 
			,SUDdx_poss 
			,Hospice
			,Anxiolytics_Rx
			,ODPastYear
		FROM [SUD].[Cohort] s
		WHERE STORM = 1 
		AND ODPastYear = 0 --Added separately to assign their own category 
		--AND CommunityCare_ODPastYear = 0 --Added separately to assign their own category 
		--AND rd.MVIPersonSID IS NULL --Added separately to assign their own category 
	 ) a 
LEFT JOIN (
	SELECT MVIPersonSID,RiskScore,RiskCategory,RiskAnyCategory,
		   RiskScoreNoSed,RiskScoreAny,RiskScoreAnyNoSed,RiskCategoryLabel,RiskAnyCategoryLabel
	FROM [ORM].[RiskScore] 
	WHERE RiskScoreAny>0 
		AND RiskScore>0
	) as r on a.MVIPersonSID = r.MVIPersonSID
LEFT JOIN (
	SELECT MVIPersonSID
	FROM [ORM].[OpioidHistory]
	GROUP BY MVIPersonSID
	HAVING MAX(Active) = 1 AND MAX(OpioidOnHand) = 0
	) as p on a.MVIPersonSID = p.MVIPersonSID


-- HYPOTHETICAL90 SCORES FOR RECENTLY DISCONTINUED
DROP TABLE IF EXISTS #RecentlyDiscontinued_HypotheticalCategory
SELECT a.MVIPersonSID
	,r.RiskScoreHypothetical90 as RiskScore
	,r.RiskScoreAnyHypothetical90
	,NULL as RiskScoreOpioidSedImpact		-- There is no RiskScoreNoSed with which to compute
	,NULL as RiskScoreAnyOpioidSedImpact	-- There is no RiskScoreAnyNoSed with which to compute
	,CASE 
		WHEN (r.RiskScoreHypothetical90 >=.0609) THEN 9
		WHEN (r.RiskScoreHypothetical90 >=.0420 AND r.RiskScoreHypothetical90 < .0609) THEN 8
		WHEN (r.RiskScoreHypothetical90 >=.01615 AND r.RiskScoreHypothetical90 <.0420) THEN 7
		ELSE 6 END as RiskCategory  
    ,RiskAnyCategory_Hypothetical90 as RiskAnyCategory
	,CASE		
		WHEN (r.RiskScoreHypothetical90 >=.0609) THEN 'Very High - Recently Discontinued'
		WHEN (r.RiskScoreHypothetical90 >=.0420 AND r.RiskScoreHypothetical90 < .0609) THEN 'High - Recently Discontinued'
		WHEN (r.RiskScoreHypothetical90 >=.01615 AND r.RiskScoreHypothetical90 <.0420) THEN 'Medium - Recently Discontinued'
		ELSE 'Low - Recently Discontinued' END as RiskCategoryLabel
	,RiskAnyCategoryLabel_Hypothetical90 AS RiskAnyCategoryLabel
	,0 as OpioidForPain_Rx
    ,r.OUD 
    ,r.SUDdx_poss 
    ,r.Hospice
    ,r.Anxiolytics_Rx  
	,0 as ORMCohort
	,0 as ODPastYear
	,ODdate=CAST(NULL as date)
	,CC_ODdate=CAST(NULL as date)
	,0 as CommunityCare_ODPastYear
	,0 as PreparatoryBehavior
	,0 as ODPastYear_Category
	,0 as OUD_OpioidForPain_Category
	,1 as RecentlyDiscontinued_HypotheticalCategory
	,0 as CC_ODPastYear_Category
INTO #RecentlyDiscontinued_HypotheticalCategory
FROM #RecentlyDiscontinued a
LEFT JOIN (
	SELECT MVIPersonSID
		  ,RiskScoreHypothetical90,RiskCategory_Hypothetical90,RiskCategoryLabel_Hypothetical90
		  ,RiskScoreAnyHypothetical90,RiskAnyCategory_Hypothetical90,RiskAnyCategoryLabel_Hypothetical90
		  ,OUD,SUDdx_poss,Hospice,Anxiolytics_Rx
	FROM [ORM].[RiskScore] 
	WHERE RiskScoreHypothetical90 > 0
	) as r on a.MVIPersonSID = r.MVIPersonSID;


-- REAL OR HYPOTHETICAL SCORES FOR ODPastYear
DROP TABLE IF EXISTS #ODPastYear_Category
SELECT od.MVIPersonSID
	,r.RiskScore
	,r.RiskScoreAny
	,CASE WHEN r.Hypothetical = 1 THEN NULL 
		ELSE (r.RiskScore-r.RiskScoreNoSed)/r.RiskScore 
		END as RiskScoreOpioidSedImpact
	,CASE WHEN r.Hypothetical = 1 THEN NULL 
		ELSE (r.RiskScoreAny-r.RiskScoreAnyNoSed)/r.RiskScoreAny 
		END as RiskScoreAnyOpioidSedImpact
	,RiskCategory = 11
    ,r.RiskAnyCategory
	,RiskCategoryLabel = 'Elevated Risk Due To Overdose In The Past Year'
	,r.RiskAnyCategoryLabel
	,0 as OpioidForPain_Rx
    ,r.OUD 
    ,r.SUDdx_poss 
    ,r.Hospice
    ,r.Anxiolytics_Rx  
	,0 as ORMCohort
	,od.ODPastYear
	,od.ODdate
	,CC_ODdate=CAST(NULL as date)
	,0 as CommunityCare_ODPastYear
	,od.PreparatoryBehavior
	,1 as ODPastYear_Category
	,0 as OUD_OpioidForPain_Category
	,0 as RecentlyDiscontinued_HypotheticalCategory
	,0 as CC_ODPastYear_Category
INTO #ODPastYear_Category
FROM #ODPastyear od 
LEFT JOIN (	SELECT MVIPersonSID
				,ISNULL(RiskScore,RiskScoreHypothetical90) as RiskScore
				,RiskScoreNoSed
				,ISNULL(RiskScoreAny,RiskScoreAnyHypothetical90) as RiskScoreAny
				,ISNULL(RiskAnyCategory,RiskAnyCategory_Hypothetical90) as RiskAnyCategory
				,ISNULL(RiskAnyCategoryLabel,RiskAnyCategoryLabel_Hypothetical90) as RiskAnyCategoryLabel
				,RiskScoreAnyNoSed
				,OUD
				,SUDdx_poss
				,Hospice
				,Anxiolytics_Rx
				,CASE WHEN RiskScore IS NULL THEN 1 ELSE 0 END as Hypothetical
			FROM [ORM].[RiskScore]) as r 
	ON od.MVIPersonSID = r.MVIPersonSID;
	

-- REAL OR HYPOTHETICAL SCORES FOR CommunityCare_ODPastYear
DROP TABLE IF EXISTS #CC_ODPastYear_Category
SELECT od.MVIPersonSID
	,r.RiskScore
	,r.RiskScoreAny
	,CASE WHEN r.Hypothetical = 1 THEN NULL 
		ELSE (r.RiskScore-r.RiskScoreNoSed)/r.RiskScore 
		END as RiskScoreOpioidSedImpact
	,CASE WHEN r.Hypothetical = 1 THEN NULL 
		ELSE (r.RiskScoreAny-r.RiskScoreAnyNoSed)/r.RiskScoreAny 
		END as RiskScoreAnyOpioidSedImpact
	,RiskCategory = 12
    ,r.RiskAnyCategory
	,RiskCategoryLabel = 'Additional Possible Community Care Overdose In The Past Year'
	,r.RiskAnyCategoryLabel
	,0 as OpioidForPain_Rx
    ,r.OUD 
    ,r.SUDdx_poss 
    ,r.Hospice
    ,r.Anxiolytics_Rx  
	,0 as ORMCohort
	,o.ODPastYear
	,ODdate=CAST(NULL as date)
	,od.CC_ODdate
	,od.CommunityCare_ODPastYear
	,0 as PreparatoryBehavior
	,0 as ODPastYear_Category
	,0 as OUD_OpioidForPain_Category
	,0 as RecentlyDiscontinued_HypotheticalCategory
	,1 as CC_ODPastYear_Category
INTO #CC_ODPastYear_Category
FROM #CC_ODPastYear od 
LEFT JOIN (	SELECT MVIPersonSID
				,ISNULL(RiskScore,RiskScoreHypothetical90) as RiskScore
				,RiskScoreNoSed
				,ISNULL(RiskScoreAny,RiskScoreAnyHypothetical90) as RiskScoreAny
				,ISNULL(RiskAnyCategory,RiskAnyCategory_Hypothetical90) as RiskAnyCategory
				,ISNULL(RiskAnyCategoryLabel,RiskAnyCategoryLabel_Hypothetical90) as RiskAnyCategoryLabel
				,RiskScoreAnyNoSed
				,OUD
				,SUDdx_poss
				,Hospice
				,Anxiolytics_Rx
				,CASE WHEN RiskScore IS NULL THEN 1 ELSE 0 END as Hypothetical
			FROM [ORM].[RiskScore]) as r 
	ON od.MVIPersonSID = r.MVIPersonSID
LEFT JOIN #ODPastyear o
	ON o.MVIPersonSID=od.MVIPersonSID;


--Prioritizing risk category to ensure mutually exclusive categories
DROP TABLE IF EXISTS #CohortWithRisk 
SELECT TOP (1) WITH TIES *
INTO #CohortWithRisk
FROM (	SELECT *
			,CategoryPriority=CASE WHEN ODPastYear_Category=1 AND RiskScore IS NOT NULL THEN 4 --Overdose Past Year
								   WHEN OUD_OpioidForPain_Category=1 AND RiskScore IS NOT NULL THEN 3 --OUD or Opioid for Pain
								   WHEN RecentlyDiscontinued_HypotheticalCategory=1 AND RiskScore IS NOT NULL THEN 2 --Recently Discontinued
								   WHEN CC_ODPastYear_Category=1 AND RiskScore IS NOT NULL THEN 1 --CC Overdose
							  ELSE 0 END
		FROM (	SELECT * 
				FROM #OUD_OpioidForPain_Category
				UNION ALL
				SELECT * 
				FROM #RecentlyDiscontinued_HypotheticalCategory
				UNION ALL
				SELECT * 
				FROM #ODPastYear_Category
				UNION ALL
				SELECT *
				FROM #CC_ODPastYear_Category
			 ) Src1 
	  ) Src2
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY CategoryPriority DESC);

----------------------------------------------------------------------------
-- STEP 3:  Join information to the cohort and publish table
----------------------------------------------------------------------------
--Get ChecklistID for all STORM patients and any CC OD patients 
DROP TABLE IF EXISTS #Locations
SELECT MVIPersonSID, ChecklistID, STORM
INTO #Locations
FROM [Present].[StationAssignments] 
WHERE STORM = 1 
UNION
SELECT MVIPersonSID, ChecklistID, NULL
FROM #CC_ODPastYear --If patient isn't in StationAssignment, use ChecklistID from CC Overdose data
WHERE ChecklistID > '0'


DROP TABLE IF EXISTS #PatientReportStage
SELECT DISTINCT 
	c.MVIPersonSID
	,b.Sta3n
	,p.ChecklistID
	,b.VISN
	,b.Facility
	,c.OpioidForPain_Rx
	,c.OUD
	,c.SUDdx_poss
	,c.Hospice
	,c.Anxiolytics_Rx
	,c.RiskScore
	,c.RiskScoreAny
	,c.RiskScoreOpioidSedImpact
	,c.RiskScoreAnyOpioidSedImpact
	,CASE WHEN c.ODPastYear = 1 THEN 11
	    ELSE c.RiskCategory
		END AS RiskCategory
    ,CASE WHEN c.ODPastYear = 1 THEN 11
	    ELSE c.RiskAnyCategory
		END AS RiskAnyCategory
	,rehab.RM_ActiveTherapies_Key
	,rehab.RM_ActiveTherapies_Date
	,rehab.RM_ChiropracticCare_Key
	,rehab.RM_ChiropracticCare_Date
	,rehab.RM_OccupationalTherapy_Key
	,rehab.RM_OccupationalTherapy_Date
	,rehab.RM_OtherTherapy_Key
	,rehab.RM_OtherTherapy_Date
	,rehab.RM_PhysicalTherapy_Key
	,rehab.RM_PhysicalTherapy_Date
	,rehab.RM_SpecialtyTherapy_Key
	,rehab.RM_SpecialtyTherapy_Date
	,rehab.RM_PainClinic_Key
	,rehab.RM_PainClinic_Date
	,rehab.CAM_Key
	,rehab.CAM_Date 
	,rio.RIOSORDScore as riosordscore
	,rio.RiskClass as riosordriskclass
	,Case when prf.MVIPersonSID IS NOT NULL then 1 else 0 end as PatientRecordFlag_Suicide
	,CASE WHEN r.Top01Percent = 1 THEN 1 ELSE 0 END AS REACH_01
	,CASE WHEN r.MonthsIdentified24 IS NOT NULL THEN 1 ELSE 0 END AS REACH_Past
	,CASE WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 0 THEN 'Elevated Risk Due To Overdose In The Past Year'
	      WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 1 THEN 'Elevated Risk Due To Preparatory Behavior'
		  WHEN c.OUD = 1 THEN 'Elevated Risk Due To OUD Dx, No Opioid Rx'
	    ELSE c.RiskCategoryLabel
		END AS RiskCategoryLabel
	,CASE WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 0 THEN 'Elevated Risk Due To Overdose In The Past Year'
	     WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 1 THEN 'Elevated Risk Due To Preparatory Behavior'
		 WHEN c.OUD = 1 THEN 'Elevated Risk Due To OUD Dx, No Opioid Rx'
	    ELSE c.RiskAnyCategoryLabel
		END AS RiskAnyCategoryLabel
	,ODPastYear
	,ODdate
	,p.STORM
INTO #PatientReportStage
FROM #CohortWithRisk AS c
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] AS m ON c.MVIPersonSID=m.MVIPersonSID -- Get PatientICN for riosord join
INNER JOIN #Locations p ON c.MVIPersonSID=p.MVIPersonSID -- Get facilities where patient will display on reports
INNER JOIN [LookUp].[ChecklistID] AS b ON p.ChecklistID = b.ChecklistID
LEFT JOIN [ORM].[Rehab] as rehab on c.MVIPersonSID=rehab.MVIPersonSID
LEFT JOIN [PDW].[PBM_AD_DOEx_Staging_RIOSORD] as rio on m.PatientICN=rio.PatientICN
LEFT JOIN [PRF_HRS].[ActivePRF] as prf on c.MVIPersonSID=prf.MVIPersonSID
LEFT JOIN [REACH].[History] as r on c.MVIPersonSID = r.MVIPersonSID
LEFT JOIN [ORM].[RiskMitigation] as rm on c.MVIPersonSID = rm.MVIPersonSID;


DROP TABLE IF EXISTS #PatientReport
SELECT MVIPersonSID
	,STA3N
	,ChecklistID
	,VISN
	,Facility
	,[OpioidForPain_Rx]				=MAX([OpioidForPain_Rx])
	,[OUD]							=MAX([OUD])
	,[SUDdx_poss]					=MAX([SUDdx_poss])
    ,[Hospice]						=MAX([Hospice])
    ,[Anxiolytics_Rx]				=MAX([Anxiolytics_Rx])
    ,[RiskScore]					=MAX([RiskScore])
    ,[RiskScoreAny]					=MAX([RiskScoreAny])				
    ,[RiskScoreOpioidSedImpact]		=MAX([RiskScoreOpioidSedImpact])
    ,[RiskScoreAnyOpioidSedImpact]	=MAX([RiskScoreAnyOpioidSedImpact])
    ,[RiskCategory]					=MAX([RiskCategory])				
    ,[RiskAnyCategory]				=MAX([RiskAnyCategory])			
    ,[RM_ActiveTherapies_Key]		=MAX([RM_ActiveTherapies_Key])	
    ,[RM_ActiveTherapies_Date]		=MAX([RM_ActiveTherapies_Date])	
    ,[RM_ChiropracticCare_Key]		=MAX([RM_ChiropracticCare_Key])
    ,[RM_ChiropracticCare_Date]		=MAX([RM_ChiropracticCare_Date])	
    ,[RM_OccupationalTherapy_Key]	=MAX([RM_OccupationalTherapy_Key])
    ,[RM_OccupationalTherapy_Date]	=MAX([RM_OccupationalTherapy_Date])
    ,[RM_OtherTherapy_Key]			=MAX([RM_OtherTherapy_Key])
    ,[RM_OtherTherapy_Date]			=MAX([RM_OtherTherapy_Date])		
    ,[RM_PhysicalTherapy_Key]		=MAX([RM_PhysicalTherapy_Key])
    ,[RM_PhysicalTherapy_Date]		=MAX([RM_PhysicalTherapy_Date])	
    ,[RM_SpecialtyTherapy_Key]		=MAX([RM_SpecialtyTherapy_Key])
    ,[RM_SpecialtyTherapy_Date]		=MAX([RM_SpecialtyTherapy_Date])	
    ,[RM_PainClinic_Key]			=MAX([RM_PainClinic_Key])
    ,[RM_PainClinic_Date]			=MAX([RM_PainClinic_Date])		
    ,[CAM_Key]						=MAX([CAM_Key])	
    ,[CAM_Date]						=MAX([CAM_Date])					
    ,[RiosordScore]					=MAX([RiosordScore])
    ,[RiosordRiskClass]				=MAX([RiosordRiskClass])
    ,[PatientRecordFlag_Suicide]	=MAX([PatientRecordFlag_Suicide])
    ,[REACH_01]						=MAX([REACH_01])
    ,[REACH_Past]					=MAX([REACH_Past])
    ,[RiskCategoryLabel]			=MAX([RiskCategoryLabel])
    ,[RiskAnyCategoryLabel]			=MAX([RiskAnyCategoryLabel])
    ,[ODPastYear]					=MAX([ODPastYear])	
    ,[ODdate]						=MAX([ODdate])			
INTO #PatientReport
FROM #PatientReportStage
WHERE RiskCategoryLabel IS NOT NULL AND RiskAnyCategoryLabel IS NOT NULL
GROUP BY MVIPersonSID, STA3N, ChecklistID, VISN, Facility;


EXEC [Maintenance].[PublishTable] 'ORM.PatientReport', '#PatientReport'

EXEC [Log].[ExecutionEnd] 

END

GO
