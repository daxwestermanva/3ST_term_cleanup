
/*-- =============================================
-- Author:		<Liam Mina>
-- Create date: <2021-11-18>
-- Description:	Health factors that relate to social determinants of health

-- Modifications:
	2022-08-09	CW	Added Cerner DTAs/Comments/FreeText to overlay Homeless Screen and Food Insecurity Screen. Logic closely follows SP [Code].[OMHSP_Standard_HealthFactorSuicPrev].
	2023-01-05	LM	New table to get all historic screens and scores
	2023-02-37	LM	Corrected positive/negative determination (previously missing list 'HomelessScreen_HousingConcerns_HF')
	2023-03-16	LM	Added ACORN screening health factors
	2023-07-13  CW  Added MST screening health factors
	2024-02-07	LM	Added IPV screening health factors
	2024-03-18  CW  Adding additional criteria to #GetMostRecent to ensure incomplete/declined screens are not included
	2024-04-03	LM	Add additional MST information from separate MST (non-health factor) table

-- Testing execution:
--		EXEC [Code].[SDH_HealthFactorSocialDeterminants]

-- Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'Code.[SDH_HealthFactorSocialDeterminants]
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 2 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'HealthFactorSocialDeterminants' ORDER BY 1 DESC
--
-- =============================================*/
CREATE PROCEDURE [Code].[SDH_HealthFactorSocialDeterminants]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.SDH_HealthFactorSocialDeterminants', @Description = 'Execution of Code.SDH_HealthFactorSocialDeterminants'
	

	-- Creating view to identify relevant SID's
	DROP TABLE IF EXISTS #HealthFactors;
	SELECT 
		 c.Category
		,m.List
		,m.ItemID
		,m.AttributeValue
		,m.Attribute
		,CASE WHEN Category = 'ACORN' THEN c.Description
			ELSE c.Printname END AS PrintName
	INTO #HealthFactors
	FROM [Lookup].[ListMember] m WITH (NOLOCK)
	INNER JOIN [Lookup].[List] c WITH (NOLOCK) 
		ON m.List = c.List
	WHERE (c.Category IN ('Homeless Screen','Food Insecurity Screen','MST Screen')
	AND (m.List LIKE 'FoodScreen%' OR m.List LIKE 'HomelessScreen%' OR m.List LIKE 'MST%'))
	OR c.Category IN ('ACORN','IPV')

	;

	-- Pulling in data required to expose Health Factors
	DROP TABLE IF EXISTS #PatientHealthFactorVistAStage; 
	SELECT  
		 mvi.MVIPersonSID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,NULL AS DocFormActivitySID
		,h.HealthFactorDateTime 
		,h.Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	INTO  #PatientHealthFactorVistAStage
	FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.HealthFactorTypeSID
	WHERE HF.Attribute = 'HealthFactorType'
	
	DROP TABLE IF EXISTS #PatientHealthFactorVistA;
	SELECT  
		 h.MVIPersonSID
		,ISNULL(z.ChecklistID,h.Sta3n) AS ChecklistID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime 
		,h.Comments
		,h.Category
		,h.List
		,h.PrintName
	INTO  #PatientHealthFactorVistA
	FROM #PatientHealthFactorVistAStage h WITH (NOLOCK) 
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	LEFT JOIN [LookUp].[DivisionFacility] z WITH (NOLOCK) 
		ON z.DivisionSID = v.DivisionSID
	;
	DROP TABLE IF EXISTS #PatientHealthFactorVistAStage

	--Get MST screen data that is missing from health factors
	DROP TABLE IF EXISTS #MST
	SELECT b.MVIPersonSID
		,ISNULL(df.ChecklistID,a.Sta3n) AS ChecklistID
		,VisitSID=MilitarySexualTraumaSID
		,a.Sta3n
		,HealthFactorSID=MilitarySexualTraumaSID
		,DocFormActivitySID=NULL
		,MSTChangeStatusDate AS HealthFactorDateTime
		,Comments=CAST(NULL AS varchar)
		,Category='MST Screen'
		,List= CASE WHEN a.MilitarySexualTraumaIndicator='Yes, Screened reports MST' THEN 'MST_Yes'
			WHEN a.MilitarySexualTraumaIndicator='No, Screened does not report MST' THEN 'MST_No'
			WHEN a.MilitarySexualTraumaIndicator='Screened Declines to answer' THEN 'MST_Declined'
			END
		,PrintName = MilitarySexualTraumaIndicator
	INTO #MST
	FROM [PatSub].[MilitarySexualTrauma] a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] b WITH (NOLOCK) 
		ON a.PatientSID = b.PatientPersonSID
	INNER JOIN [Dim].[Division] d WITH (NOLOCK)
		ON a.InstitutionSID = d.InstitutionSID
	LEFT JOIN [Lookup].[DivisionFacility] df WITH (NOLOCK)
		ON d.DivisionSID=df.DivisionSID
	WHERE a.MilitarySexualTraumaIndicator in ('Yes, Screened reports MST','No, Screened does not report MST','Screened Declines to answer')

	-- Exposing Cerner DtaEventResult/AttributeValue for next step
	DROP TABLE IF EXISTS #Comments;
	SELECT 
		 c.Category
		,c.List
		,c.ItemID
		,p.DerivedDtaEventResult AS AttributeValue
		,c.Attribute
		,p.DocFormActivitySID
	INTO #Comments
	FROM #HealthFactors c 
	INNER JOIN [Cerner].[FactPowerForm] p WITH (NOLOCK) 
		ON c.ItemID = p.DerivedDtaEventCodeValueSID
	WHERE c.Attribute in ('Comment')
	;
	
	-- Combining all Cerner DTAs/Comments/FreeText
	DROP TABLE IF EXISTS #PatientHealthFactorCerner;  
	SELECT
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,c.AttributeValue AS Comments 
		,HF.Category
		,HF.List
		,HF.PrintName
	INTO #PatientHealthFactorCerner
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
		AND HF.AttributeValue = h.DerivedDtaEventResult
	LEFT JOIN #Comments c WITH (NOLOCK) 
		ON HF.List = c.List
		AND h.DocFormActivitySID = c.DocFormActivitySID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE HF.Attribute = 'DTA' 
	UNION ALL
	SELECT DISTINCT 
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,CASE WHEN h.DerivedDTAEventResult LIKE 'Other: %' THEN SUBSTRING(h.DerivedDTAEventResult,8,len(h.DerivedDTAEventResult)) ELSE h.DerivedDTAEventResult END AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE HF.Attribute ='DTA' AND (h.DerivedDTAEventResult LIKE 'Other:%' AND List LIKE '%Other%')
	UNION ALL
	SELECT DISTINCT 
		h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,h.DerivedDTAEventResult AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE HF.Attribute ='FreeText'
	;

	DROP TABLE IF EXISTS #HealthFactors
	DROP TABLE IF EXISTS #Comments


	--Combining Vista and Cerner
	DROP TABLE IF EXISTS #PatientHealthFactorDTA;
	SELECT *
	INTO #PatientHealthFactorDTA
	FROM #PatientHealthFactorVistA
	UNION ALL
	SELECT * 
	FROM #PatientHealthFactorCerner
	UNION ALL
	SELECT a.* FROM #MST a
	LEFT JOIN #PatientHealthFactorVistA b --avoid duplicate results
		ON a.MVIPersonSID=b.MVIPersonSID
		AND CAST(a.HealthFactorDateTime AS date) = CAST(b.HealthFactorDateTime AS date)
		AND a.List=b.List
	WHERE b.MVIPersonSID IS NULL
	;
	DROP TABLE IF EXISTS #PatientHealthFactorVistA
	DROP TABLE IF EXISTS #MST
	DROP TABLE IF EXISTS #PatientHealthFactorCerner

	--Get all historic screens with positive/negative/skipped score - Homeless, Food Insecurity, MST
	--IPV is handled in another step. ACORN is not scored and only most recent values will be saved in later step
	DROP TABLE IF EXISTS #ScreenScores;
	SELECT DISTINCT h.MVIPersonSID
		,h.ChecklistID
		,h.Category
		,h.HealthFactorDateTime AS ScreenDateTime
		,MAX(CASE WHEN h.List LIKE '%Sometimes%' OR h.List LIKE '%Often%' OR h.List = 'MST_Yes'
				OR h.List IN ('FoodScreen_Shortage3MonthsYes_HF','HomelessScreen_30dHousingConcerns_HF','HomelessScreen_30dWithoutHousing_HF','HomelessScreen_NoStableHousing_HF','HomelessScreen_HousingConcerns_HF','MST_Yes')
				THEN 1 
			WHEN h.List LIKE '%NotPerformed%' OR h.List like '%Declined' THEN -1 ELSE 0 END) AS Score
	INTO #ScreenScores
	FROM #PatientHealthFactorDTA h
	INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK) 
			ON m.MVIPersonSID = h.MVIPersonSID
	WHERE h.Category IN ('Homeless Screen','Food Insecurity Screen','MST Screen')
	GROUP BY h.MVIPersonSID, h.Category, h.HealthFactorDateTime, h.ChecklistID
	;
	
	EXEC [Maintenance].[PublishTable] 'SDH.ScreenResults', '#ScreenScores' 
	;
	DROP TABLE IF EXISTS #ScreenScores

	/***IPV Screening - record of all historic IPV screens***/

	--get health factors and DTAs for IPV screening
	DROP TABLE IF EXISTS #AllScreeningResponses
	SELECT DISTINCT a.MVIPersonSID
			,a.VisitSID
			,a.Sta3n
			,a.ChecklistID
			,a.HealthFactorDateTime
			,a.List
			,CASE WHEN a.List LIKE '%Never' THEN 1
				WHEN a.List LIKE '%Rarely' THEN 2
				WHEN a.List LIKE '%Sometimes' THEN 3
				WHEN a.List LIKE '%Often' THEN 4
				WHEN a.List LIKE '%Frequently' THEN 5
				END AS Value
			,a.PrintName
	INTO #AllScreeningResponses
	FROM #PatientHealthFactorDTA AS a WITH (NOLOCK) 
	WHERE Category='IPV'


	--In cases where multiple responses exist for the same question, use highest value response
	DROP TABLE IF EXISTS #RemoveExtraResponses
	SELECT a.*
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, VisitSID, LEFT(List,10) ORDER BY Value DESC) AS RN
	INTO #RemoveExtraResponses
	FROM #AllScreeningResponses a

	DELETE FROM #RemoveExtraResponses where RN>1

	DROP TABLE IF EXISTS #AllScreeningResponses

	--calculate the number of questions answered in a screening and/or danger assessment
	DROP TABLE IF EXISTS #NumAnswers
	SELECT MVIPersonSID
		,Sta3n
		,ChecklistID
		,HealthFactorDateTime
		,VisitSID
		,SUM(EHITSQuestionType) as NumScreenAnswers
		,SUM(DangerQuestionType) as NumDangerAnswers
	INTO #NumAnswers
	FROM
		(SELECT DISTINCT MVIPersonSID
			,ChecklistID
			,Sta3n
			,VisitSID
			,HealthFactorDateTime
			,List
			,CASE 
				WHEN List LIKE 'IPV_Force%'
					OR List LIKE 'IPV_Insult%'
					OR List LIKE 'IPV_Physical%'
					OR List LIKE 'IPV_Scream%' 
					OR List LIKE 'IPV_Threaten%' 
				THEN 1
				ELSE 0
				END AS EHITSQuestionType
			,CASE
				WHEN List LIKE 'IPV_Increased%'
					OR List LIKE 'IPV_Choked%'
					OR List LIKE 'IPV_Killed%' 
				THEN 1
				ELSE 0
				END AS DangerQuestionType
		FROM #RemoveExtraResponses) AS a
	GROUP BY MVIPersonSID, HealthFactorDateTime, VisitSID, ChecklistID, Sta3n

	--a screening is valid if there are 5 screening responses and a danger screening is valid
	--if there are 3 responses
	DROP TABLE IF EXISTS #ValidScreens
	SELECT *
	INTO #ValidScreens
	FROM #NumAnswers
	WHERE (NumScreenAnswers = 0 OR NumScreenAnswers = 5)
		AND (NumDangerAnswers = 0 OR NumDangerAnswers = 3)

	--screenings that are considered invalid at this stage will require further checks 
	--before being counted
	DROP TABLE IF EXISTS #RequireFurtherValidation
	SELECT a.*
	INTO #RequireFurtherValidation
	FROM #NumAnswers a
	LEFT JOIN #ValidScreens b 
		ON a.VisitSID = b.VisitSID
	WHERE b.MVIPersonSID IS NULL

	--calculate the EHITS/HITS+ screening score for all screenings
	DROP TABLE IF EXISTS #ScreeningScore
	SELECT MVIPersonSID
		,Sta3n
		,ChecklistID
		,VisitSID
		,HealthFactorDateTime
		,SUM(Value) ScreeningScore
	INTO #ScreeningScore
	FROM (SELECT DISTINCT List
			,MVIPersonSID
			,Sta3n
			,ChecklistID
			,VisitSID
			,HealthFactorDateTime
			,Value
			FROM #RemoveExtraResponses) a
	GROUP BY MVIPersonSID, HealthFactorDateTime, VisitSID, ChecklistID, Sta3n

	--for now, move ahead only with the valid screening scores
	DROP TABLE IF EXISTS #ValidScreenScores
	SELECT a.*
	INTO #ValidScreenScores
	FROM #ScreeningScore a
	INNER JOIN #ValidScreens b 
		ON a.VisitSID = b.VisitSID

	DROP TABLE IF EXISTS #ScreeningScore

	--a final, summary table for valid screens
	DROP TABLE IF EXISTS #Summary_Valid
	SELECT a.MVIPersonSID 
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.HealthFactorDateTime AS ScreenDateTime
		,a.ScreeningOccurred
		,a.ScreeningScore
		,SUM(Physical) AS Physical --perform sums to collapse into one row per visitsid
		,SUM(Insult) AS Insult 
		,SUM(Scream) AS Scream
		,SUM(Threaten) AS Threaten
		,SUM(Force) AS Force
		,a.DangerScreeningOccurred
		,SUM(a.ViolenceIncreased) AS ViolenceIncreased --perform sums to collapse into one row per visitsid
		,SUM(a.Choked) AS Choked
		,SUM(a.BelievesMayBeKilled) AS BelievesMayBeKilled
	INTO #Summary_Valid
	FROM (
		SELECT DISTINCT a.MVIPersonSID 
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.HealthFactorDateTime
		,CASE
			WHEN n.NumScreenAnswers = 5 THEN 1
			ELSE 0
			END as ScreeningOccurred
		,c.ScreeningScore
		,CASE WHEN List LIKE 'IPV_Physical%'	THEN a.Value ELSE 0 END AS Physical
		,CASE WHEN List LIKE 'IPV_Insult%'		THEN a.Value ELSE 0 END AS Insult
		,CASE WHEN List LIKE 'IPV_Threaten%'	THEN a.Value ELSE 0 END AS Threaten
		,CASE WHEN List LIKE 'IPV_Scream%'		THEN a.Value ELSE 0 END AS Scream
		,CASE WHEN List LIKE 'IPV_Force%'		THEN a.Value ELSE 0 END AS Force
		,CASE WHEN n.NumDangerAnswers = 3		THEN 1		 ELSE 0 END AS DangerScreeningOccurred
		,CASE WHEN a.List='IPV_Increased_Yes'	THEN 1		 ELSE 0 END AS ViolenceIncreased
		,CASE WHEN a.List='IPV_Choked_Yes'		THEN 1		 ELSE 0 END AS Choked
		,CASE WHEN a.List='IPV_Killed_Yes'		THEN 1		 ELSE 0 END AS BelievesMayBeKilled
		FROM #RemoveExtraResponses a ---1895079
		INNER JOIN #ValidScreens b 
			ON a.VisitSID = b.VisitSID --366766
 		INNER JOIN #NumAnswers n 
			ON a.VisitSID = n.VisitSID --367777
		LEFT JOIN #ValidScreenScores c 
			ON a.VisitSID = c.VisitSID
		) a --366766
	GROUP BY a.MVIPersonSID,a.VisitSID, a.HealthFactorDateTime, a.ScreeningOccurred, a.ScreeningScore, a.DangerScreeningOccurred, a.ChecklistID, a.Sta3n

	DROP TABLE IF EXISTS #RemoveExtraResponses
	DROP TABLE IF EXISTS #NumAnswers
	DROP TABLE IF EXISTS #ValidScreens
	DROP TABLE IF EXISTS #ValidScreenScores

	;
		EXEC [Maintenance].[PublishTable] 'SDH.IPV_Screen', '#Summary_Valid' ;

	DROP TABLE IF EXISTS #Summary_Valid

	/***For all screens***/
	--Get details for most recent screen.  Prioritize completed screens over not performed/declined
	DROP TABLE IF EXISTS #GetMostRecent;
	SELECT TOP 1 WITH TIES
		MVIPersonSID
		,HealthFactorDateTime
		,Category
		,VisitSID
	INTO #GetMostRecent
	FROM #PatientHealthFactorDTA
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Category 
		ORDER BY CASE WHEN List LIKE '%NotPerformed%' OR List LIKE '%Declined' THEN 1 ELSE 0 END, HealthFactorDateTime DESC)
	;

	DROP TABLE IF EXISTS #StageHealthFactor;
	SELECT DISTINCT a.PatientICN
		,a.MVIPersonSID
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.HealthFactorSID
		,a.DocFormActivitySID
		,a.HealthFactorDateTime
		,a.Comments
		,a.Category
		,a.List  
		,a.PrintName 
	INTO #StageHealthFactor
	FROM (
		SELECT 
			 m.PatientICN
			,h.MVIPersonSID
			,h.Sta3n
			,h.ChecklistID
			,h.VisitSID
			,h.HealthFactorSID
			,h.DocFormActivitySID
			,h.HealthFactorDateTime
			,h.Comments
			,h.Category
			,h.List  
			,h.PrintName
			,row_number() OVER (PARTITION BY h.MVIPersonSID, h.List ORDER BY h.VisitSID) AS rn
		FROM #PatientHealthFactorDTA AS h
		INNER JOIN #GetMostRecent AS r
			ON h.MVIPersonSID = r.MVIPersonSID
			AND h.VisitSID = r.VisitSID
			AND h.Category = r.Category
		INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK) 
			ON m.MVIPersonSID = h.MVIPersonSID
		WHERE m.DateOfDeath_Combined IS NULL
		) a
	WHERE a.rn = 1
	;
	DROP TABLE IF EXISTS #PatientHealthFactorDTA
	DROP TABLE IF EXISTS #GetMostRecent
	
	EXEC [Maintenance].[PublishTable] 'SDH.HealthFactors', '#StageHealthFactor' ;

	DROP TABLE IF EXISTS #StageHealthFactor
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed';

END