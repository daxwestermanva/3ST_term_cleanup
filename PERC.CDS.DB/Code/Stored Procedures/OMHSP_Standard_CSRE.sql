

-- =============================================
-- Author:		Liam Mina
-- Create date: 11.03.2021
-- Description:	Collects key elements of the Comprehensive Suicide Risk Evaluation template

-- Updates:
-- 2023-09-18	LM	Added VisitDateTime
-- 2024-04-04	LM	Run past year data nightly and refresh all data weekly
-- =============================================
CREATE PROCEDURE [Code].[OMHSP_Standard_CSRE] 
	
AS
BEGIN

--Step 1: Get all relevant CSRE health factors and note titles
--Note: There is no identifier that ties the health factor to a specific TIU instance, in cases where more than 1 event is reported within the same VisitSID.  Using TIUDocumentDefinition and EntryDateTime as a proxy
DROP TABLE IF EXISTS #HealthFactors
SELECT MVIPersonSID
	  ,PatientICN
	  ,Sta3n
	  ,ChecklistID
      ,VisitSID
      ,HealthFactorDateTime
	  ,DocFormActivitySID
      ,Comments
      ,Category
      ,List
      ,PrintName
	  ,ISNULL(DocFormActivitySID,VisitSID) AS DocIdentifier
INTO #HealthFactors
FROM [OMHSP_Standard].[HealthFactorSuicPrev] WITH(NOLOCK)
WHERE Category LIKE 'CSRE%' AND List NOT LIKE 'SBOR%'

--Get all possibly relevant CSRE note titles
DROP TABLE IF EXISTS #AllTIU
SELECT a.VisitSID
	,a.Sta3n
	,a.MVIPersonSID
	,a.SecondaryVisitSID
	,a.DocFormActivitySID
	,a.TIUDocumentDefinitionSID
	,a.EntryDateTime
	,a.TIUDocumentDefinition
	,a.ReferenceDateTime
	,ISNULL(DocFormActivitySID,VisitSID) AS DocIdentifier
INTO #AllTIU 
FROM [Stage].[FactTIUNoteTitles] a WITH(NOLOCK)
WHERE List='SuicidePrevention_CSRE_TIU'

DROP TABLE IF EXISTS #DropExtraNotes
SELECT MIN(EntryDateTime) OVER (PARTITION BY DocIdentifier, SecondaryVisitSID, MVIPersonSID) AS EntryDateTime
	,DocIdentifier
	,Sta3n
INTO #DropExtraNotes
FROM #AllTIU

DROP TABLE IF EXISTS #CombinedTIU
SELECT DISTINCT a.* 
INTO #CombinedTIU
FROM #AllTIU a
INNER JOIN #DropExtraNotes b 
	ON a.EntryDateTime=b.EntryDateTime AND a.DocIdentifier=b.DocIdentifier 
	
DROP TABLE IF EXISTS #AllTIU, #DropExtraNotes

--Step 2: Get the health factors that relate to CSRE notes where the event being reported is the most recent suicide attempt
	
--Get the TIU documents that relate to CSRE notes for most recent events
DROP TABLE IF EXISTS #CSRE_TIU
SELECT *
	,row_number() OVER (PARTITION BY DocIdentifier, TIUDocumentDefinitionSID ORDER BY EntryDateTime Desc) AS TIURow
INTO #CSRE_TIU
FROM (
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,b.TIUDocumentDefinitionSID
		,a.DocIdentifier
	FROM #HealthFactors a
	INNER JOIN #CombinedTIU b ON a.DocIdentifier = b.DocIdentifier

	UNION ALL

	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,b.TIUDocumentDefinitionSID
		,a.DocIdentifier
	FROM #HealthFactors a
	INNER JOIN #CombinedTIU b ON a.VisitSID = b.SecondaryVisitSID
	WHERE a.Sta3n<>200	
	) x

--where visitsids do not match but HF record occurs on same day as TIU record entry date
DROP TABLE IF EXISTS #CSRE_TIU_HF
SELECT hf.VisitSID
	 ,t.SecondaryVisitSID
	 ,hf.DocFormActivitySID
	 ,hf.MVIPersonSID
	 ,hf.Sta3n
	 ,t.EntryDateTime
	 ,t.TIUDocumentDefinitionSID
	 ,t.TIUDocumentDefinition
	 ,hf.HealthFactorDateTime
	 ,hf.DocIdentifier
	 ,TIURow = 1
INTO #CSRE_TIU_HF
FROM #HealthFactors AS hf
INNER JOIN #CombinedTIU t ON 
	t.MVIPersonSID=hf.MVIPersonSID
WHERE hf.DocIdentifier <> t.DocIdentifier --Not those that matched in previous step
	AND hf.VisitSID <> t.SecondaryVisitSID
	AND ((CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.EntryDateTime)) 
		OR CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.ReferenceDateTime))

DROP TABLE IF EXISTS #RemovePreviousMatches
SELECT hf.VisitSID
	 ,hf.SecondaryVisitSID
	 ,hf.DocFormActivitySID
	 ,hf.MVIPersonSID
	 ,hf.Sta3n
	 ,hf.EntryDateTime
	 ,hf.TIUDocumentDefinition
	 ,hf.TIURow
	 ,hf.DocIdentifier
INTO #RemovePreviousMatches
FROM #CSRE_TIU_HF hf
LEFT JOIN #CSRE_TIU AS ex WITH (NOLOCK) 
	ON CAST(hf.HealthFactorDateTime AS DATE)=CAST(ex.EntryDateTime AS DATE) AND ex.MVIPersonSID=hf.MVIPersonSID
WHERE ex.DocIdentifier IS NULL --exclude cases where there's another note on the same day that already matches on VisitSID

--Combine the health factors with their corresponding TIUDocumentDefinitions
DROP TABLE IF EXISTS #EventDetailsCombined
--VistA - match between health factors and TIUDocumentDefinition
SELECT h.MVIPersonSID
	  ,h.PatientICN
	  ,h.Sta3n
	  ,h.ChecklistID
	  ,h.Category
	  ,h.List
	  ,h.PrintName
	  ,h.Comments
	  ,h.VisitSID
	  ,h.DocFormActivitySID
	  ,t.EntryDateTime
	  ,h.HealthFactorDateTime
	  ,t.TIUDocumentDefinition
	  ,h.DocIdentifier
INTO #EventDetailsCombined
FROM #HealthFactors h WITH (NOLOCK)
INNER JOIN (SELECT DocIdentifier, TIUDocumentDefinition, EntryDateTime FROM #CSRE_TIU WITH (NOLOCK) WHERE TIURow = 1
		UNION ALL
		SELECT DocIdentifier, TIUDocumentDefinition, EntryDateTime FROM #RemovePreviousMatches WITH (NOLOCK) WHERE TIURow = 1) t 
	ON h.DocIdentifier = t.DocIdentifier
WHERE h.Sta3n<>200

UNION ALL
--Cerner
SELECT h.MVIPersonSID
	  ,h.PatientICN
	  ,h.Sta3n
	  ,h.ChecklistID
	  ,h.Category
	  ,h.List
	  ,h.PrintName
	  ,h.Comments
	  ,h.VisitSID
	  ,h.DocFormActivitySID
	  ,t.EntryDateTime
	  ,h.HealthFactorDateTime
	  ,t.TIUDocumentDefinition
	  ,h.DocIdentifier
FROM #HealthFactors h WITH (NOLOCK)
INNER JOIN (SELECT * FROM #CSRE_TIU WITH (NOLOCK) WHERE TIURow = 1) t 
	ON h.DocIdentifier = t.DocIdentifier 
WHERE h.Sta3n=200

UNION ALL
-- Where health factors exist but no match to a TIUDocumentDefinition (for VistA; this doesn't happen in Cerner)
SELECT h.MVIPersonSID
	  ,h.PatientICN
	  ,h.Sta3n
	  ,h.ChecklistID
	  ,h.Category
	  ,h.List
	  ,h.PrintName
	  ,h.Comments
	  ,h.VisitSID
	  ,h.DocFormActivitySID
	  ,h.HealthFactorDateTime AS EntryDateTime
	  ,h.HealthFactorDateTime
	  ,TIUDocumentDefinition=NULL
	  ,h.DocIdentifier
FROM #HealthFactors h WITH (NOLOCK)
LEFT JOIN (SELECT DocIdentifier, TIUDocumentDefinition, EntryDateTime FROM #CSRE_TIU WITH (NOLOCK) WHERE TIURow = 1
		UNION ALL
		SELECT DocIdentifier, TIUDocumentDefinition, EntryDateTime FROM #RemovePreviousMatches WITH (NOLOCK) WHERE TIURow = 1) t 
	ON h.DocIdentifier = t.DocIdentifier
WHERE h.Sta3n<>200 AND t.DocIdentifier IS NULL

DROP TABLE IF EXISTS #AddVisitDate
SELECT DISTINCT VisitSID, MIN(VisitDateTime) AS VisitDateTime
INTO #AddVisitDate
FROM (
	SELECT a.VisitSID, b.VisitDateTime 
	FROM #EventDetailsCombined a
	INNER JOIN [Outpat].[Visit] b WITH (NOLOCK) 
		ON a.VisitSID = b.VisitSID
	UNION ALL
	SELECT a.VisitSID, b.TZDerivedVisitDateTime
	FROM #EventDetailsCombined a
	LEFT JOIN [Cerner].[FactUtilizationOutpatient] b WITH (NOLOCK)
		ON a.VisitSID = b.EncounterSID
	UNION ALL
	SELECT a.VisitSID, b.TZDerivedAdmitDateTime
	FROM #EventDetailsCombined a
	LEFT JOIN [Cerner].[FactInpatient] b WITH (NOLOCK)
		ON a.VisitSID = b.EncounterSID
	) x
GROUP BY VisitSID

DROP TABLE IF EXISTS #CombinedTIU, #CSRE_TIU, #CSRE_TIU_HF, #HealthFactors, #RemovePreviousMatches

--Step 3 - Get health factors from specific sections of the CSRE
--New/Updated Evaluation
DROP TABLE IF EXISTS #Evaluation
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,PrintName AS EvaluationType
INTO #Evaluation
FROM #EventDetailsCombined WITH (NOLOCK) 
WHERE List IN ('CSRE_NewEvaluation_HF','CSRE_UpdatedEvaluation_HF','CSRE_UnableToComplete')
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY HealthFactorDateTime DESC)

--Most Recent Ideation
DROP TABLE IF EXISTS #MostRecentIdeation
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,PrintName AS Ideation
	,Comments AS IdeationComments
INTO #MostRecentIdeation
FROM #EventDetailsCombined WITH (NOLOCK) 
WHERE List LIKE 'CSRE_SuicideThoughts%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%Yes%' THEN 0 ELSE 1 END,  HealthFactorDateTime DESC)

--Intent at time of most recent ideation
DROP TABLE IF EXISTS #MostRecentIntent
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,PrintName AS Intent
	,Comments AS IntentComments
INTO #MostRecentIntent
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_CurrentSuicidalIntent%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%Yes%' THEN 0 ELSE 1 END, HealthFactorDateTime DESC)

--Plan at time of most recent ideation
DROP TABLE IF EXISTS #MostRecentPlan
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,PrintName AS SuicidePlan
	,Comments AS PlanComments
INTO #MostRecentPlan
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_CurrentSuicidePlan%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%Yes%' THEN 0 ELSE 1 END, HealthFactorDateTime DESC)

--Access to Lethal Means
DROP TABLE IF EXISTS #LethalMeansAll
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,CASE WHEN PrintName = 'Access to Firearms' THEN 'Firearms'
		WHEN PrintName = 'Access to Other Lethal Means' THEN 'Other'
		WHEN PrintName = 'Unknown Access to Lethal Means ' THEN 'Unknown' 
		WHEN PrintName = 'No Access to Lethal Means' THEN 'None' END AS LethalMeans
	,Comments AS LethalMeansComments
	,ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY HealthFactorDateTime DESC) as rn
INTO #LethalMeansAll
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_LethalMeans%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier, PrintName ORDER BY HealthFactorDateTime DESC)

DROP TABLE IF EXISTS #LethalMeans
SELECT MVIPersonSID
	,DocIdentifier
	,STRING_AGG(LethalMeans, ', ') WITHIN GROUP (ORDER BY LethalMeans) AS LethalMeans
	,STRING_AGG(LethalMeansComments, '. ') WITHIN GROUP (ORDER BY LethalMeans) AS LethalMeansComments
INTO #LethalMeans
FROM #LethalMeansAll
GROUP BY MVIPersonSID, DocIdentifier
	
--History of prior attempts
DROP TABLE IF EXISTS #PriorAttempts
SELECT TOP 1 WITH TIES 
	MVIPersonSID
	,DocIdentifier
	,PrintName AS PriorAttempts
	,Comments AS PriorAttemptComments
INTO #PriorAttempts
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_HistorySuicideAtt%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%Yes%' THEN 0 ELSE 1 END, HealthFactorDateTime DESC)

--Acute Risk
DROP TABLE IF EXISTS #AcuteRisk
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,CASE WHEN PrintName LIKE '%Low' THEN 'Low'
		WHEN PrintName LIKE '%Intermediate' THEN 'Intermediate'
		WHEN PrintName LIKE '%High' OR List='CSRE_UnableRisk_HighAcuteYes' THEN 'High'
		END AS AcuteRisk
	,Comments AS AcuteRiskComments
INTO #AcuteRisk
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_ClinImpressRiskAcute%' OR List='CSRE_UnableRisk_HighAcuteYes'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%High%' THEN 0 WHEN List LIKE '%Intermediate%' THEN 1 ELSE 2 END, HealthFactorDateTime DESC)

--Chronic Risk
DROP TABLE IF EXISTS #ChronicRisk
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,DocIdentifier
	,CASE WHEN PrintName LIKE '%Low' THEN 'Low'
		WHEN PrintName LIKE '%Intermediate' THEN 'Intermediate'
		WHEN PrintName LIKE '%High' THEN 'High'
		END AS ChronicRisk
	,Comments AS ChronicRiskComments
INTO #ChronicRisk
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_ClinImpressRiskChronic%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY CASE WHEN List LIKE '%High%' THEN 0 WHEN List LIKE '%Intermediate%' THEN 1 ELSE 2 END, HealthFactorDateTime DESC)

--Clinical Setting
DROP TABLE IF EXISTS #Setting
SELECT TOP 1 WITH TIES 
	MVIPersonSID
	,DocIdentifier
	,CASE WHEN PrintName = 'Emergency Department/Urgent Care Center' THEN 'ED/UC'
		ELSE PrintName END AS Setting
INTO #Setting
FROM #EventDetailsCombined WITH (NOLOCK)
WHERE List LIKE 'CSRE_Setting%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY HealthFactorDateTime DESC)

--Step 4: Pull together relevant health factors for each event
DROP TABLE IF EXISTS #CombineAll
SELECT a.MVIPersonSID
	  ,a.PatientICN
	  ,a.Sta3n
	  ,a.ChecklistID
	  ,a.VisitSID
	  ,a.DocFormActivitySID
	  ,a.DocIdentifier
	  ,v.VisitDateTime
	  ,a.EntryDateTime
	  ,a.TIUDocumentDefinition
	  ,j.EvaluationType
	  ,b.Ideation
	  ,b.IdeationComments
	  ,c.Intent
	  ,c.IntentComments
	  ,d.SuicidePlan
	  ,d.PlanComments
	  ,e.LethalMeans
	  ,e.LethalMeansComments
	  ,f.PriorAttempts
	  ,f.PriorAttemptComments
	  ,g.AcuteRisk
	  ,g.AcuteRiskComments
	  ,h.ChronicRisk
	  ,h.ChronicRiskComments
	  ,i.Setting
INTO #CombineAll
FROM #EventDetailsCombined a
LEFT JOIN #AddVisitDate v
	ON a.VisitSID = v.VisitSID
LEFT JOIN #MostRecentIdeation b 
	ON a.DocIdentifier=b.DocIdentifier
LEFT JOIN #MostRecentIntent c 
	ON a.DocIdentifier=c.DocIdentifier
LEFT JOIN #MostRecentPlan d 
	ON a.DocIdentifier=d.DocIdentifier
LEFT JOIN #LethalMeans e 
	ON a.DocIdentifier=e.DocIdentifier
LEFT JOIN #PriorAttempts f 
	ON a.DocIdentifier=f.DocIdentifier
LEFT JOIN #AcuteRisk g 
	ON a.DocIdentifier=g.DocIdentifier
LEFT JOIN #ChronicRisk h 
	ON a.DocIdentifier=h.DocIdentifier
LEFT JOIN #Setting i 
	ON a.DocIdentifier=i.DocIdentifier
LEFT JOIN #Evaluation j
	ON a.DocIdentifier=j.DocIdentifier

DELETE FROM #CombineAll
WHERE TIUDocumentDefinition IS NULL AND EvaluationType IS NULL --count if note title exists or health factors for new/updated evaluation exist

DROP TABLE IF EXISTS #RemoveDuplicates
SELECT * 
INTO #RemoveDuplicates
FROM (SELECT *
	,ROW_NUMBER() OVER (PARTITION BY DocIdentifier ORDER BY EntryDateTime DESC) AS rownum
	FROM #CombineAll ) a
WHERE rownum=1

DELETE FROM #RemoveDuplicates
WHERE COALESCE(TIUDocumentDefinition,Ideation,Intent,SuicidePlan,LethalMeans,PriorAttempts,AcuteRisk,ChronicRisk,Setting) IS NULL

DROP TABLE IF EXISTS #AcuteRisk,#AddVisitDate,#ChronicRisk,#CombineAll,#Evaluation,#LethalMeans,#LethalMeansAll
					,#MostRecentIdeation,#MostRecentIntent,#MostRecentPlan,#PriorAttempts,#Setting

--Step 5 - Create final table
DROP TABLE IF EXISTS #CSRE_Stage
SELECT DISTINCT MVIPersonSID
	  ,PatientICN
	  ,Sta3n
	  ,ChecklistID
	  ,VisitSID
	  ,DocFormActivitySID
	  ,VisitDateTime
	  ,EntryDateTime
	  ,TIUDocumentDefinition
	  ,EvaluationType
	  ,Ideation
	  ,IdeationComments
	  ,Intent
	  ,IntentComments
	  ,SuicidePlan
	  ,PlanComments
	  ,LethalMeans
	  ,LethalMeansComments
	  ,PriorAttempts
	  ,PriorAttemptComments
	  ,AcuteRisk
	  ,AcuteRiskComments
	  ,ChronicRisk
	  ,ChronicRiskComments
	  ,Setting
	  ,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY EntryDateTime DESC) AS OrderDesc
INTO #CSRE_Stage
FROM #RemoveDuplicates
;

DROP TABLE IF EXISTS #RemoveDuplicates

EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.CSRE','#CSRE_Stage'


; 

--Step 6 - pull together health factors for details table - risk factors, warning signs, protective factors, strategies for managing risk
DROP TABLE IF EXISTS #Details_Stage
SELECT DISTINCT MVIPersonSID
	,PatientICN
	,Sta3n
	,ChecklistID
	,VisitSID
	,DocFormActivitySID
	,EntryDateTime
	,CASE WHEN List LIKE 'CSRE_Warning%' THEN 'Warning Sign'
		WHEN List LIKE 'CSRE_RiskFactor%' THEN 'Risk Factor'
		WHEN List LIKE 'CSRE_ProtectFactor%' THEN 'Protective Factor'
		WHEN List LIKE 'CSRE_RiskMitigation%' THEN 'Risk Mitigation Strategy'
		END AS Type
	,PrintName
	,Comments
INTO #Details_Stage
FROM #EventDetailsCombined
WHERE (List LIKE 'CSRE_Warning%' OR List LIKE 'CSRE_RiskMitigation%' OR List LIKE 'CSRE_RiskFactor%' OR List LIKE 'CSRE_ProtectFactor%')

DROP TABLE IF EXISTS #EventDetailsCombined

EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.CSRE_Details','#Details_Stage'
;


END