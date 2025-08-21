


-- =============================================
-- Author:		Liam Mina
-- Create DATE: 03.07.2019
-- Description:	Suicide and overdose events are reported in two CPRS note templates, the Suicide Behavior and Overdose Report (SBOR) and the Comprehensive Suicide Risk Evaluation (CSRE).  Elements of those
-- note templates are captured as health factors. The purpose of this code is to have one row per event (CPRS note) that displays the information about that event.

-- Updates:
-- 2019-04-16 - LM - Added formatting to event date, added uses of CSRE, added logic to remove duplicates
-- 2019-04-17 - RAS - Replaced PatientICN with MVIPersonSID. Formatted.
-- 2019-04-30 - LM - Updated logic to drop duplicates, added commenting, added CSRE health factors to SDV temp tables
-- 2019-07-05 - LM - Updated date formatting, addressed issue of multiple SBORs in the same VisitSID by referencing a table with manually-entered data for those events
-- 2019-08-13 - LM - Added preparatory behaviors from CSRE
-- 2019-11-06 - LM - Changed code to include events reported in the CSRE where the TIUDocumentDefinition is null
-- 2020-01-15 - LM - Added SecondaryVisitSID and ReferenceDateTime to get all the relevant TIU notes
-- 2020-08-19 - LM - Dropping manually-entered data; there is no mechanism to identify if these health factors get deleted or updated
-- 2020-08-26 - LM - Overlay of Vista and Millennium data
-- 2020-11-02 - LM - Correcting formatting of dates coming from Cerner
-- 2021-02-16 - LM - Correcting for cases where invalid dates (e.g., Feb 31) are entered
-- 2021-03-19 - LM - Additional fine-tuning of event dates
-- 2021-04-13 - LM - Fixed joins to SecondaryVisitSID to correctly differentiate between notes with different SecondaryVisitSIDs; added SDV classification for events missing an intent health factor
-- 2021-07-22 - LM - Fix to ensure consistency between EventType and SDV classification when health factors for both suicidal intent and undetermined intent are present. Classify event with suicidal intent in these cases.
-- 2021-08-04 - LM - Added next provider overdose review date
-- 2021-08-25 - JEB - Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
-- 2021-09-13 - LM - Removed deactivated TIU notes; adjusted provider overdose review date to account for cases where the healthfactor date occurs before the note entry date
-- 2021-12-11 - LM - Added 2022 in date section
-- 2022-11-09 - LM - Use max(EntryDateTime) instead of min(EntryDateTime) to reduce cases where event date is misclassified as a future date
-- 2022-03-16 - LM - Classified cocaine and amphetamines together as Method = Stimulants, with specific drug in MethodComments
-- 2023-08-22 - LM - Remove deduplication step - this already happens downstream in OMHSP_Standard.SuicideOverdoseEvent
-- 2023-11-15 - LM - Added initial build parameter to only look back 1 year and replace that data instead of doing full reload nightly.
-- 2024-02-05 - CW - Removing #AddYear. When event date > entry date, we're now defaulting to entry date (instead of subtracting a year); per JT request.
--
--	Testing execution:
--		EXEC [Code].[OMHSP_Standard_SBOR] @InitialBuild=1
--
--	Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'EXEC Code.OMHSP_Standard_SBOR'
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'SBOR' ORDER BY 1 DESC
--
--
-- =============================================
CREATE PROCEDURE [Code].[OMHSP_Standard_SBOR]
	@InitialBuild BIT = 0
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SBOR','Execution of Code.OMHSP_Standard_SBOR SP'

	--DECLARE @InitialBuild BIT = 0
	DECLARE @BeginDate DATE 

	IF (SELECT COUNT(*) FROM OMHSP_Standard.SBOR)=0 --if table is empty, populate with all data
	BEGIN SET @InitialBuild = 1
	END;

	IF @InitialBuild = 1 
	BEGIN
		SET @BeginDate = '2019-02-01'  --earliest entrydatetime for SBOR note is 2019-02-22
	END
	ELSE 
	BEGIN
		SET @BeginDate = DATEADD(DAY,-365,CAST(GETDATE() AS DATE))
	END

	--Step 1: Get all relevant factors (from SBOR and CSRE notes), and SBOR and CSRE note titles that have share a VisitSID with an SBOR Health Factor
	--Note: There is no identifier that ties the health factor to a specific TIU instance, in cases where more than 1 event is reported within the same VisitSID.  Using TIUDocumentDefinition and EntryDateTime as a proxy
	DROP TABLE IF EXISTS #HealthFactors
	SELECT DISTINCT 
		MVIPersonSID
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
	FROM [OMHSP_Standard].[HealthFactorSuicPrev] WITH (NOLOCK)
	WHERE Category IN ('SBOR DATE','SBOR EventType','SBOR PatientStatus','SBOR VAProperty'
		,'SBOR Injury', 'SBOR 7Days','SBOR Preparatory','SBOR Interrupted','SBOR Outcome'
		,'SBOR Method Category','SBOR Method I','SBOR Method II')

	--Get all possibly relevant SBOR and CSRE note titles
	DROP TABLE IF EXISTS #AllTIU
	SELECT 
		a.Sta3n
		,a.MVIPersonSID
		,a.VisitSID
		,a.SecondaryVisitSID
		,a.TIUDocumentDefinitionSID
		,a.DocFormActivitySID
		,a.EntryDateTime
		,a.TIUDocumentDefinition
		,a.ReferenceDateTime
		,CASE 
			WHEN List='SuicidePrevention_CSRE_TIU'THEN 'CSRE'
			WHEN List='SuicidePrevention_SBOR_TIU' THEN 'SBOR'
		END AS NoteType
		,ISNULL(a.DocFormActivitySID,a.VisitSID) AS DocIdentifier
	INTO #AllTIU 
	FROM [Stage].[FactTIUNoteTitles] a WITH (NOLOCK)
	WHERE List IN('SuicidePrevention_SBOR_TIU','SuicidePrevention_CSRE_TIU') 
		AND a.EntryDateTime >= @BeginDate
	;

	DROP TABLE IF EXISTS #DropExtraNotes
	SELECT DISTINCT 
		 MAX(EntryDateTime) OVER (PARTITION BY DocIdentifier, SecondaryVisitSID, NoteType, MVIPersonSID) AS EntryDateTime
		,DocIdentifier
		,NoteType
		,Sta3n
	INTO #DropExtraNotes
	FROM #AllTIU

	DROP TABLE IF EXISTS #CombinedTIU
	SELECT a.* 
	INTO #CombinedTIU
	FROM #AllTIU a
	INNER JOIN #DropExtraNotes b 
		ON a.EntryDateTime=b.EntryDateTime 
		AND a.DocIdentifier=b.DocIdentifier 
		AND a.NoteType=b.NoteType
	; 
	CREATE NONCLUSTERED INDEX TIUIndex ON #CombinedTIU (DocIdentifier); 
	
	--Step 1a: Get the health factors that relate to SBOR notes
	DROP TABLE IF EXISTS #SBOR_HealthFactors
	SELECT h.* INTO #SBOR_HealthFactors
	FROM #HealthFactors h
	INNER JOIN (SELECT DISTINCT VisitSID FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF') d ON h.VisitSID = d.VisitSID
	WHERE d.VisitSID IS NOT NULL AND h.List NOT LIKE '%CSRE%' AND h.Sta3n<>200
	UNION
	SELECT h.* 
	FROM #HealthFactors h
	INNER JOIN (SELECT DISTINCT DocFormActivitySID FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF') d ON h.DocFormActivitySID = d.DocFormActivitySID
	WHERE d.DocFormActivitySID IS NOT NULL AND h.List NOT LIKE '%CSRE%' AND h.Sta3n=200

	--Get the TIU documents that relate to SBOR notes
	DROP TABLE IF EXISTS #SBOR_TIU
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, b.TIUDocumentDefinitionSID ORDER BY b.EntryDateTime Desc) AS TIURow
	INTO #SBOR_TIU
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.VisitSID = b.VisitSID
	WHERE a.Sta3n<>200 AND b.NoteType = 'SBOR'
	UNION
	SELECT a.VisitSID
		,c.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,c.EntryDateTime
		,c.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, c.TIUDocumentDefinitionSID ORDER BY c.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF') a
	INNER JOIN #CombinedTIU c on a.VisitSID = c.SecondaryVisitSID
	WHERE a.Sta3n<>200 AND c.NoteType = 'SBOR'
	UNION
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.DocFormActivitySID ORDER BY b.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.DocFormActivitySID = b.DocFormActivitySID 
	WHERE a.Sta3n = 200 AND b.NoteType='SBOR'

	--where visitsids do not match but HF record occurs on same day as TIU record entry DATE
	DROP TABLE IF EXISTS #SBOR_TIU_HF
	SELECT DISTINCT  hf.VisitSID
		 ,t.SecondaryVisitSID
		 ,t.DocFormActivitySID
		 ,hf.MVIPersonSID
		 ,hf.Sta3n
		 ,t.EntryDateTime
		 ,t.TIUDocumentDefinition
		 ,TIURow=1
	INTO #SBOR_TIU_HF
	FROM #SBOR_HealthFactors AS hf
	INNER JOIN (SELECT * FROM #CombinedTIU WHERE NoteType='SBOR') t 
		ON t.MVIPersonSID=hf.MVIPersonSID
	LEFT JOIN #SBOR_TIU AS ex ON CAST(hf.HealthFactorDateTime AS DATE)=CAST(ex.EntryDateTime AS DATE) AND ex.MVIPersonSID=hf.MVIPersonSID
	WHERE hf.VisitSID <> t.VisitSID --Not those that matched in previous step
		AND ex.VisitSID IS NULL --exclude cases where there's another note on the same day that already matches on VisitSID
		AND hf.VisitSID <> t.SecondaryVisitSID
		AND ((CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.EntryDateTime)) 
			OR CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.ReferenceDateTime))
		AND hf.Sta3n<>200
	
	--Combine the health factors with their corresponding TIUDocumentDefinitions
	DROP TABLE IF EXISTS #EventDetails_SBOR
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY  h.VisitSID, h.DocFormActivitySID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'SBOR'
		  ,h.VisitSID AS DocIdentifier
	INTO #EventDetails_SBOR
	FROM #SBOR_HealthFactors h
	INNER JOIN (SELECT * FROM #SBOR_TIU WHERE TIURow = 1
		UNION ALL
		SELECT * FROM #SBOR_TIU_HF WHERE TIURow = 1) t ON h.VisitSID = t.VisitSID
	WHERE h.Sta3n<>200 
	UNION
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY  h.VisitSID, h.DocFormActivitySID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'SBOR'
		  ,h.DocFormActivitySID AS DocIdentifier
	FROM #SBOR_HealthFactors h
	INNER JOIN (SELECT * FROM #SBOR_TIU WHERE TIURow = 1) t ON h.DocFormActivitySID = t.DocFormActivitySID
	WHERE h.Sta3n=200

	--Step 1b: Get the health factors that relate to CSRE notes where the event being reported is the most recent suicide attempt
	DROP TABLE IF EXISTS #CSRE_HealthFactors
	SELECT h.* INTO #CSRE_HealthFactors
	FROM #HealthFactors h 
	INNER JOIN (SELECT * FROM #HealthFactors WHERE List = 'SBOR_SuicideAttemptCSRE_HF') d ON h.VisitSID = d.VisitSID
	WHERE h.List NOT LIKE '%LtCSRE%' AND h.List NOT LIKE '%PrepCSRE%' AND h.List <> 'SBOR_EventDate_HF' AND h.List NOT LIKE 'SBOR_OD%' AND h.sta3n<>200
	UNION
	SELECT h.* 
	FROM #HealthFactors h
	INNER JOIN (SELECT * FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF' AND Sta3n=200) d ON h.DocFormActivitySID = d.DocFormActivitySID
	WHERE h.List NOT LIKE '%LtCSRE%' AND h.List NOT LIKE '%PrepCSRE%'  AND h.Category not in ('SBOR Preparatory')
	
	--Get the TIU documents that relate to CSRE notes for most recent events
	DROP TABLE IF EXISTS #CSRE_TIU
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, b.TIUDocumentDefinitionSID ORDER BY b.EntryDateTime Desc) AS TIURow
	INTO #CSRE_TIU
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_SuicideAttemptCSRE_HF') a
	INNER JOIN #CombinedTIU b ON a.VisitSID = b.VisitSID
	WHERE b.NoteType='CSRE' and a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,c.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,c.EntryDateTime
		,c.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, c.TIUDocumentDefinitionSID ORDER BY c.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_SuicideAttemptCSRE_HF') a
	INNER JOIN #CombinedTIU c ON a.VisitSID = c.SecondaryVisitSID
	WHERE c.NoteType='CSRE' and a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.DocFormActivitySID ORDER BY b.EntryDateTime Desc) AS TIURow
	FROM (SELECT distinct VisitSID, DocFormActivitySID, mvipersonsid, Sta3n FROM #HealthFactors WHERE List = 'SBOR_EventDate_HF' AND Sta3n=200) a
	INNER JOIN #CombinedTIU b ON a.DocFormActivitySID = b.DocFormActivitySID AND b.NoteType='CSRE'

	--where visitsids do not match but HF record occurs on same day as TIU record entry DATE
	DROP TABLE IF EXISTS #CSRE_TIU_HF
	SELECT DISTINCT  hf.VisitSID, t.SecondaryVisitSID
		 ,hf.DocFormActivitySID
		 ,hf.MVIPersonSID
		 ,hf.Sta3n
		 ,t.EntryDateTime
		 ,t.TIUDocumentDefinition
		 ,TIURow = 1
	INTO #CSRE_TIU_HF
	FROM #CSRE_HealthFactors AS hf
	INNER JOIN (SELECT * FROM #CombinedTIU WHERE NoteType='CSRE') t ON 
		t.MVIPersonSID=hf.MVIPersonSID
	LEFT JOIN #CSRE_TIU AS ex ON CAST(hf.HealthFactorDateTime AS DATE)=CAST(ex.EntryDateTime AS DATE) AND ex.MVIPersonSID=hf.MVIPersonSID
	WHERE hf.VisitSID <> t.VisitSID --Not those that matched in previous step
	AND ex.VisitSID IS NULL --exclude cases where there's another note on the same day that already matches on VisitSID
	AND hf.VisitSID <> t.SecondaryVisitSID
	AND ((CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.EntryDateTime)) 
		OR CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.ReferenceDateTime))
	AND hf.Sta3n<>200

	--Combine the health factors with their corresponding TIUDocumentDefinitions
	DROP TABLE IF EXISTS #EventDetails_CSRE
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY  h.VisitSID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Most Recent'
		  ,h.VisitSID AS DocIdentifier
	INTO #EventDetails_CSRE
	FROM #CSRE_HealthFactors h
	INNER JOIN (SELECT * FROM #CSRE_TIU WHERE TIURow = 1
		UNION 
		SELECT * FROM #CSRE_TIU_HF WHERE TIURow = 1) t ON h.VisitSID = t.VisitSID
	WHERE h.Sta3n<>200
	UNION
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
		  --,row_number() OVER (PARTITION BY h.DocFormActivitySID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Most Recent'
		  ,h.DocFormActivitySID AS DocIdentifier
	FROM #CSRE_HealthFactors h
	INNER JOIN (SELECT * FROM #CSRE_TIU WHERE TIURow = 1) t ON h.DocFormActivitySID = t.DocFormActivitySID 
	WHERE h.Sta3n=200

	--Step 1c: Get the health factors that relate to CSRE notes where the event being reported is the most lethal suicide attempt
	DROP TABLE IF EXISTS #CSRE_LtHealthFactors
	SELECT h.* INTO #CSRE_LtHealthFactors
	FROM #HealthFactors h
	INNER JOIN (SELECT DISTINCT VisitSID, HealthFactorDateTime FROM #HealthFactors 
		WHERE List='SBOR_LtCSREEventDate_HF') 
		d ON h.VisitSID = d.VisitSID
	WHERE d.VisitSID IS NOT NULL AND h.List LIKE '%LtCSRE%' AND h.sta3n<>200
	UNION
	SELECT h.* 
	FROM #HealthFactors h
	INNER JOIN (SELECT * FROM #HealthFactors WHERE List = 'SBOR_LtCSREEventDate_HF') d ON h.DocFormActivitySID = d.DocFormActivitySID
	WHERE d.DocFormActivitySID IS NOT NULL AND h.List LIKE '%LtCSRE%' AND h.sta3n=200 AND h.Category NOT IN ('SBOR Preparatory','SBOR EventType')

	--Get the TIU documents that relate to CSRE notes for most lethal events
	DROP TABLE IF EXISTS #LtCSRE_TIU
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, b.TIUDocumentDefinitionSID ORDER BY b.EntryDateTime Desc) AS TIURow
	INTO #LtCSRE_TIU
	FROM (SELECT DISTINCT * FROM #HealthFactors WHERE List LIKE 'SBOR_LtCSRE%' AND LIST <> 'SBOR_LtCSRESuicideAttempt_HF' AND LIST <> 'SBOR_LtCSREEventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.VisitSID = b.VisitSID
	WHERE b.NoteType='CSRE' AND a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,c.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,c.EntryDateTime
		,c.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, c.TIUDocumentDefinitionSID ORDER BY c.EntryDateTime Desc) AS TIURow
	FROM (SELECT DISTINCT * FROM #HealthFactors WHERE List LIKE 'SBOR_LtCSRE%' AND LIST <> 'SBOR_LtCSRESuicideAttempt_HF' AND LIST <> 'SBOR_LtCSREEventDate_HF') a
	INNER JOIN #CombinedTIU c on a.VisitSID = c.SecondaryVisitSID
	WHERE c.NoteType='CSRE' AND a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.DocFormActivitySID ORDER BY b.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_LtCSREEventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.DocFormActivitySID = b.DocFormActivitySID AND a.Sta3n = 200 AND b.NoteType='CSRE'

	--where visitsids do not match but HF record occurs on same day as TIU record entry DATE
	DROP TABLE IF EXISTS #LtCSRE_TIU_HF
	SELECT DISTINCT  hf.VisitSID, t.SecondaryVisitSID
		 ,hf.DocFormActivitySID
		 ,hf.MVIPersonSID
		 ,hf.Sta3n
		 ,t.EntryDateTime
		 ,t.TIUDocumentDefinition
		 ,TIURow = 1
	INTO #LtCSRE_TIU_HF
	FROM #CSRE_LtHealthFactors AS hf
	INNER JOIN (SELECT * FROM #CombinedTIU WHERE NoteType='CSRE') t ON 
		t.MVIPersonSID=hf.MVIPersonSID
	LEFT JOIN #LtCSRE_TIU AS ex ON CAST(hf.HealthFactorDateTime AS DATE)=CAST(ex.EntryDateTime AS DATE) AND ex.MVIPersonSID=hf.MVIPersonSID
	WHERE hf.VisitSID <> t.VisitSID --Not those that matched in previous step
	AND ex.VisitSID IS NULL --exclude cases where there's another note on the same day that already matches on VisitSID
	AND hf.VisitSID <> t.SecondaryVisitSID
	AND ((CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.EntryDateTime)) 
		OR CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.ReferenceDateTime) )
	AND hf.Sta3n<>200

	--Combine the health factors with their corresponding TIUDocumentDefinitions
	DROP TABLE IF EXISTS #EventDetails_LtCSRE
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY  h.VisitSID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Most Lethal'
		  ,h.VisitSID AS DocIdentifier
	INTO #EventDetails_LtCSRE
	FROM #CSRE_LtHealthFactors h
	INNER JOIN (SELECT * FROM #LtCSRE_TIU WHERE TIURow = 1
		UNION
		SELECT * FROM #LtCSRE_TIU_HF WHERE TIURow = 1) t ON h.VisitSID = t.VisitSID 
	WHERE h.Sta3n<>200
	UNION
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
		  --,row_number() OVER (PARTITION BY h.DocFormActivitySID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Most Lethal'
		  ,h.DocFormActivitySID AS DocIdentifier
	FROM #CSRE_LtHealthFactors h
	INNER JOIN (SELECT * FROM #LtCSRE_TIU WHERE TIURow = 1) t ON h.DocFormActivitySID = t.DocFormActivitySID 
	WHERE h.Sta3n=200

	--Step 1d: Get the health factors that relate to CSRE notes where the event being reported is the most recent preparatory behavior for suicide
	DROP TABLE IF EXISTS #CSRE_PrepHealthFactors
	SELECT h.* INTO #CSRE_PrepHealthFactors
	FROM #HealthFactors h
	INNER JOIN (SELECT * FROM #HealthFactors WHERE List  = 'SBOR_PrepCSREEventDate_HF') d ON h.VisitSID = d.VisitSID
	WHERE d.VisitSID IS NOT NULL AND h.List LIKE '%PrepCSRE%' AND h.Sta3n<>200
	UNION
	SELECT h.* 
	FROM #HealthFactors h
	INNER JOIN (SELECT * FROM #HealthFactors WHERE List = 'SBOR_PrepCSREEventDate_HF') d ON h.DocFormActivitySID = d.DocFormActivitySID
	WHERE d.DocFormActivitySID IS NOT NULL AND h.List LIKE '%PrepCSRE%' AND h.Sta3n=200 AND h.Category NOT IN ('SBOR Preparatory','SBOR EventType')

	--Get the TIU documents that relate to CSRE notes for preparatory behaviors
	DROP TABLE IF EXISTS #PrepCSRE_TIU
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, b.TIUDocumentDefinitionSID ORDER BY b.EntryDateTime Desc) AS TIURow
	INTO #PrepCSRE_TIU
	FROM (SELECT * FROM #HealthFactors WHERE List  = 'SBOR_PrepCSREEventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.VisitSID = b.VisitSID
	WHERE b.NoteType='CSRE' AND a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,c.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,c.EntryDateTime
		,c.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.VisitSID, c.TIUDocumentDefinitionSID ORDER BY c.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List  = 'SBOR_PrepCSREEventDate_HF') a
	INNER JOIN #CombinedTIU c ON a.VisitSID = c.SecondaryVisitSID
	WHERE c.NoteType='CSRE' AND a.Sta3n<>200
	UNION
	SELECT a.VisitSID
		,b.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,row_number() OVER (PARTITION BY a.DocFormActivitySID ORDER BY b.EntryDateTime Desc) AS TIURow
	FROM (SELECT * FROM #HealthFactors WHERE List = 'SBOR_PrepCSREEventDate_HF') a
	INNER JOIN #CombinedTIU b ON a.DocFormActivitySID = b.DocFormActivitySID AND a.Sta3n = 200 AND b.NoteType='CSRE'

	--where visitsids do not match but HF record occurs on same day as TIU record entry DATE
	DROP TABLE IF EXISTS #PrepCSRE_TIU_HF
	SELECT DISTINCT hf.VisitSID, t.SecondaryVisitSID
		 ,hf.DocFormActivitySID
		 ,hf.MVIPersonSID
		 ,hf.Sta3n
		 ,t.EntryDateTime
		 ,t.TIUDocumentDefinition
		 ,TIURow = 1
	INTO #PrepCSRE_TIU_HF
	FROM #CSRE_PrepHealthFactors AS hf
	INNER JOIN (SELECT * FROM #CombinedTIU WHERE NoteType='CSRE') t ON 
		t.MVIPersonSID=hf.MVIPersonSID
	LEFT JOIN #PrepCSRE_TIU AS ex ON CAST(hf.HealthFactorDateTime AS DATE)=CAST(ex.EntryDateTime AS DATE) AND ex.MVIPersonSID=hf.MVIPersonSID
	WHERE hf.VisitSID <> t.VisitSID --Not those that matched in previous step
	AND ex.VisitSID IS NULL --exclude cases where there's another note on the same day that already matches on VisitSID
	AND hf.VisitSID <> t.SecondaryVisitSID
	AND ((CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.EntryDateTime)) 
		OR CONVERT(DATE,hf.HealthFactorDateTime)=CONVERT(DATE,t.ReferenceDateTime) )
	AND hf.Sta3n<>200

	--Combine the health factors with their corresponding TIUDocumentDefinitions
	DROP TABLE IF EXISTS #EventDetails_PrepCSRE
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY  h.VisitSID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Preparatory'
		  ,h.VisitSID AS DocIdentifier
	INTO #EventDetails_PrepCSRE
	FROM #CSRE_PrepHealthFactors h
	INNER JOIN (SELECT * FROM #PrepCSRE_TIU WHERE TIURow = 1
		UNION
		SELECT * FROM #PrepCSRE_TIU_HF WHERE TIURow = 1) t ON h.VisitSID = t.VisitSID 
	WHERE h.Sta3n<>200
	UNION
	SELECT DISTINCT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.Category
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.DocFormActivitySID
		  --,row_number() OVER (PARTITION BY h.DocFormActivitySID, t.TIUDocumentDefinition, h.Category ORDER BY h.Comments desc, h.PrintName desc) AS RowNum
		  ,t.EntryDateTime
		  ,h.HealthFactorDateTime
		  ,t.TIUDocumentDefinition
		  ,EventCategory = 'CSRE Preparatory'
		  ,h.DocFormActivitySID AS DocIdentifier
	FROM #CSRE_PrepHealthFactors h
	INNER JOIN (SELECT * FROM #PrepCSRE_TIU WHERE TIURow = 1) t ON h.DocFormActivitySID = t.DocFormActivitySID 
	WHERE h.Sta3n=200
	;

	--Step 1e: Union the four temp tables created above
	DROP TABLE IF EXISTS #EventDetailsCombined
	SELECT * 
	,row_number() OVER (PARTITION BY  DocIdentifier, TIUDocumentDefinition,Category ORDER BY Comments desc, PrintName desc) AS RowNum
	INTO #EventDetailsCombined
	FROM #EventDetails_SBOR
	UNION ALL 
	SELECT *
	,row_number() OVER (PARTITION BY  DocIdentifier, TIUDocumentDefinition,Category ORDER BY Comments desc, PrintName desc) AS RowNum
	FROM #EventDetails_CSRE
	UNION ALL 
	SELECT * 
	,row_number() OVER (PARTITION BY  DocIdentifier, TIUDocumentDefinition,Category ORDER BY Comments desc, PrintName desc) AS RowNum
	FROM #EventDetails_LtCSRE
	UNION ALL 
	SELECT * 
	,row_number() OVER (PARTITION BY  DocIdentifier, TIUDocumentDefinition,Category ORDER BY Comments desc, PrintName desc) AS RowNum
	FROM #EventDetails_PrepCSRE
	;

	DROP TABLE IF EXISTS #AllTIU
	DROP TABLE IF EXISTS #CombinedTIU
	DROP TABLE IF EXISTS #CSRE_HealthFactors
	DROP TABLE IF EXISTS #CSRE_LtHealthFactors
	DROP TABLE IF EXISTS #CSRE_PrepHealthFactors
	DROP TABLE IF EXISTS #CSRE_TIU
	DROP TABLE IF EXISTS #CSRE_TIU_HF
	DROP TABLE IF EXISTS #DropExtraNotes
	DROP TABLE IF EXISTS #HealthFactors
	DROP TABLE IF EXISTS #LtCSRE_TIU
	DROP TABLE IF EXISTS #LtCSRE_TIU_HF
	DROP TABLE IF EXISTS #PrepCSRE_TIU
	DROP TABLE IF EXISTS #PrepCSRE_TIU_HF
	DROP TABLE IF EXISTS #SBOR_HealthFactors
	DROP TABLE IF EXISTS #SBOR_TIU
	DROP TABLE IF EXISTS #SBOR_TIU_HF
	DROP TABLE IF EXISTS #VistaTIU



	CREATE NONCLUSTERED INDEX DetailsIndex ON #EventDetailsCombined (DocIdentifier); 

	--Step 2: Clean up event DATE data from text field to a format that can be sorted and aggregated
	--Dates can be entered in the template as a free text field, meaning that a variety of non-standard dates are entered.
	--Rules for cleaning up dates: 
	--  -If EventDate is entered as a relationship to EntryDateTime (e.g., 'yesterday', 'two months ago', 'last week'):
	--		-Apply rules to interpret teh text string (CommentsDate) as a DATE
	--		-e.g., CASE WHEN Comments LIKE '%four%weeks%ago%' OR Comments LIKE '%4 weeks ago%' THEN DateAdd(week,-4,EntryDateTime)
	--		-EventDateFormatted = CommentsDate
	--	-Otherwise, apply the following steps:
	--		-Extract the first string of numbers and / from the string and TRY_CAST the extracted string of numbers as a DATE (FormattedDate)
	--		-TRY_CAST the entire comments field as a DATE (FormattedDateC)
	--		-Use rules to identify potential months, dates, and years, and use DateFromParts to concatenate a DATE from month, day, year (FormattedDateFromParts)
	--		-If any of these dates (FormattedDate, FormattedDateC, FormattedDateFromParts) is greater than EntryDateTime by no more than 1 year, subtract a year from the DATE.
	--			-The assumption here is that the year was written incorrectly.  E.g., if the event was reported on 3/1/19 and was reported to have occurred on 11/1/19, assume the intent was to write that the event occurred on 11/1/18
	--			-If the event is reported to have occurred more than 1 year in the future, cast as NULL
	--		-If these three dates do not match, select the DATE that is closest to (but not greater than) EntryDateTime

	--Step 2a: Pull strings of numbers that might be dates out of the Comments field of the event DATE health factor
	DROP TABLE IF EXISTS #NumbersOnly;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,EntryDateTime
		  ,b.DateOfBirth
		  ,CASE WHEN a.Sta3n = 200 OR TRY_CAST(Comments AS DATE) BETWEEN b.DateOfBirth AND a.EntryDateTime THEN TRY_CAST(Comments AS date) ELSE NULL END AS CernerDate
		  ,LEFT(SubString(Comments, PatIndex('%[0-9]%', Comments), 10), PatIndex('%[^0-9/]%', SubString(Comments, PatIndex('%[0-9/]%', Comments), 10) + 'X')-1)  as NumbersOnly --filter out characters except numbers and dashes
		  ,LEFT(SubString(Comments, PatIndex('%[0-9]%', Comments), 4), PatIndex('%[^0-9]%', SubString(Comments, PatIndex('%[0-9]%', Comments), 4) + 'X')-1) AS fourdigit --pull four digit string that could be a year
		  ,LEFT(SubString(Comments, PatIndex('%[0-9]%', Comments), 2), PatIndex('%[^0-9]%', SubString(Comments, PatIndex('%[0-9]%', Comments), 2) + 'X')-1) as twodigit
	INTO #NumbersOnly
	FROM #EventDetailsCombined a
	LEFT JOIN [Common].[MasterPatient] b WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID
	WHERE Category = 'SBOR Date'
	;

	--Step 2b: Cast the Comments field as a DATE (if possible) and cast the number string pulled out of Step 2a as a DATE (if possible). 
	--Also, use any numbers and words written in the comments field that express the DATE as a relationship to EntryDateTime to infer a DATE.
	DROP TABLE IF EXISTS #CastDate;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,b.DATE AS FormattedDateC
		  ,NumbersOnly
		  ,FourDigit
		  ,TwoDigit
		  ,EntryDateTime
		  ,CernerDate
		  ,c.DATE AS FormattedDate
		  ,CASE WHEN Comments LIKE '%today%' OR Comments LIKE '%this morning%' OR Comments LIKE '%tonight%' THEN EntryDateTime
			WHEN Comments LIKE '%yesterday%' THEN DateAdd(day,-1,EntryDateTime)
			WHEN Comments LIKE '%two%days%ago%' OR Comments LIKE '%2 days ago%' OR Comments LIKE '%couple days ago%' THEN DateAdd(day,-2,EntryDateTime)
			WHEN Comments LIKE '%three%days%ago%' OR Comments LIKE '%3 days ago%' OR Comments LIKE '%few days ago%' THEN DateAdd(day,-3,EntryDateTime)
			WHEN Comments LIKE '%four%days%ago%' OR Comments LIKE '%4 days ago%' THEN DateAdd(day,-4,EntryDateTime)
			WHEN Comments LIKE '%five%days%ago%' OR Comments LIKE '%5 days ago%' THEN DateAdd(day,-5,EntryDateTime)
			WHEN Comments LIKE '%six%days%ago%' OR Comments LIKE '%6 days ago%' THEN DateAdd(day,-6,EntryDateTime)
			WHEN (Comments LIKE '%ast%days%' OR Comments LIKE '%days ago%') AND TRY_CAST(NumbersOnly AS int) BETWEEN 1 AND 90 THEN DateAdd(day,-CAST(NumbersOnly AS int),EntryDateTime)
			WHEN Comments LIKE '%ast week%' OR Comments LIKE '%week %ago%' THEN DateAdd(week,-1,EntryDateTime)
			WHEN Comments LIKE '%two%weeks%ago%' OR Comments LIKE '%2 weeks ago%' OR Comments LIKE '%couple%weeks%ago%' OR Comments LIKE '%ast two weeks%' OR Comments LIKE '%ast couple%weeks%' THEN DateAdd(week,-2,EntryDateTime)
			WHEN Comments LIKE '%three%weeks%ago%' OR Comments LIKE '%3 weeks ago%' OR Comments LIKE '%few%weeks%ago%' OR Comments LIKE '%ast few weeks%' THEN DateAdd(week,-3,EntryDateTime)
			WHEN Comments LIKE '%four%weeks%ago%' OR Comments LIKE '%4 weeks ago%' THEN DateAdd(week,-4,EntryDateTime)
			WHEN Comments LIKE '%five%weeks%ago%' OR Comments LIKE '%5 weeks ago%' THEN DateAdd(week,-5,EntryDateTime)
			WHEN Comments LIKE '%six%weeks%ago%' OR Comments LIKE '%6 weeks ago%' THEN DateAdd(week,-6,EntryDateTime)
			WHEN (Comments LIKE '%ast%weeks%' OR Comments LIKE '%weeks ago%') AND TRY_CAST(NumbersOnly AS int) BETWEEN 1 AND 12 THEN DateAdd(week,-CAST(NumbersOnly AS int),EntryDateTime)
			WHEN Comments LIKE '%ast month%' OR Comments LIKE '%month ago%' THEN DateAdd(month,-1,EntryDateTime)
			WHEN Comments LIKE '%two%months%ago%' OR Comments LIKE '%2 months ago%' OR Comments LIKE '%couple%months%ago%' THEN DateAdd(month,-2,EntryDateTime)
			WHEN Comments LIKE '%three%months%ago%' OR Comments LIKE '%3 months ago%' OR Comments LIKE '%few%months%ago%' THEN DateAdd(month,-3,EntryDateTime)
			WHEN Comments LIKE '%four%months%ago%' OR Comments LIKE '%4 months ago%' THEN DateAdd(month,-4,EntryDateTime)
			WHEN Comments LIKE '%five%months%ago%' OR Comments LIKE '%5 months ago%' THEN DateAdd(month,-5,EntryDateTime)
			WHEN Comments LIKE '%six%months%ago%' OR Comments LIKE '%6 months ago%' THEN DateAdd(month,-6,EntryDateTime)
			WHEN (Comments LIKE '%ast%months%' OR Comments LIKE '%months ago%' OR Comments LIKE '% mos ago%' OR Comments LIKE '% mo ago%') AND TRY_CAST(NumbersOnly AS int) BETWEEN 1 AND 24 THEN DateAdd(month,-CAST(NumbersOnly AS int),EntryDateTime)
			WHEN Comments LIKE '%ast year%' OR Comments LIKE '%year ago%'  OR Comments LIKE '%a yr ago%' OR Comments LIKE '%yr. ago%' THEN DateAdd(year,-1,EntryDateTime)
			WHEN Comments LIKE '%two%years%ago%' OR Comments LIKE '2 years ago%' OR Comments LIKE '% 2 years ago%' OR Comments LIKE '%couple%years%ago%' THEN DateAdd(year,-2,EntryDateTime)
			WHEN Comments LIKE '%three%years%ago%' OR Comments LIKE '3 years ago%' OR Comments LIKE '% 3 years ago%' OR Comments LIKE '%few%years%ago%' THEN DateAdd(year,-3,EntryDateTime)
			WHEN Comments LIKE '%four%years%ago%' OR Comments LIKE '4 years ago%' OR Comments LIKE '% 4 years ago%' THEN DateAdd(year,-4,EntryDateTime)
			WHEN Comments LIKE '%five%years%ago%' OR Comments LIKE '5 years ago%' OR Comments LIKE '% 5 years ago%' THEN DateAdd(year,-5,EntryDateTime)
			WHEN Comments LIKE '%six%years%ago%' OR Comments LIKE '6 years ago%'OR Comments LIKE '% 6 years ago%' THEN DateAdd(year,-6,EntryDateTime)
			WHEN (Comments LIKE '%ast%years%' OR Comments LIKE '%years ago%' OR Comments like '%yrs% ago%' OR Comments LIKE '%years prior%' OR Comments like '%yeas ago%' OR Comments like '% y ago%' OR Comments LIKE '%yr ago%' ) AND TRY_CAST(NumbersOnly AS int) BETWEEN 1 AND 100 THEN DateAdd(year,-CAST(NumbersOnly AS int),EntryDateTime)
			WHEN (Comments LIKE '%year% old%' OR Comments LIKE '%yrs old%' OR Comments LIKE 'age %' OR Comments LIKE '% age%' OR Comments like '%y/o%' OR Comments like '%yo') AND TRY_CAST(NumbersOnly AS int) BETWEEN 5 AND 100 THEN DateAdd(year,CAST(NumbersOnly AS int),DateOfBirth)
			ELSE NULL END AS CommentsDate
	INTO #CastDate
	FROM #NumbersOnly a
	LEFT JOIN [Dim].[Date] b WITH(NOLOCK) ON TRY_CAST(a.Comments AS DATE)=b.DATE
	LEFT JOIN [Dim].[Date] c WITH(NOLOCK) ON TRY_CAST(a.NumbersOnly AS DATE)=c.DATE
	;

	--Step 2c: CONVERT written months to corresponding numbers.  Identify month, day, and year of event.
	DROP TABLE IF EXISTS #FormattedDateParts;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,NumbersOnly
		  ,EntryDateTime
		  ,CernerDate
		  ,CASE WHEN CernerDate IS NOT NULL THEN Month(CernerDate)
				WHEN Comments LIKE '%Jan %' OR Comments like '%Jan.%' OR Comments LIKE '%January%' THEN 1
				WHEN Comments LIKE '%Feb %' OR Comments like '%Feb.%' OR Comments LIKE '%February%' THEN 2
				WHEN Comments LIKE '%Mar %' OR Comments like '%Mar.%' OR Comments LIKE '%March%' THEN 3
				WHEN Comments LIKE '%Apr %' OR Comments like '%Apr.%' OR Comments LIKE '%April%' THEN 4
				WHEN Comments LIKE '%Jun %' OR Comments like '%Jun.%' OR Comments LIKE '%June%' THEN 6
				WHEN Comments LIKE '%Jul %' OR Comments like '%Jul.%' OR Comments LIKE '%July%' THEN 7
				WHEN Comments LIKE '%Aug %' OR Comments like '%Aug.%' OR Comments LIKE '%August%' THEN 8
				WHEN Comments LIKE '%Sep %' OR Comments LIKE '%Sept%' OR Comments like '%Sep.%' OR Comments like '%Sept.%' OR Comments LIKE '%September%' THEN 9
				WHEN Comments LIKE '%Oct %' OR Comments like '%Oct.%' OR Comments LIKE '%October%' THEN 10
				when Comments LIKE '%Nov %' OR Comments like '%Nov.%' OR Comments LIKE '%November%' THEN 11
				WHEN Comments LIKE '%Dec %' OR Comments like '%Dec.%' OR Comments LIKE '%December%' THEN 12
				WHEN Comments LIKE '%May%' THEN 5 --last in case the comments have the word 'may' in them for another meaning
				WHEN Comments LIKE '%Winter%' THEN 2
				WHEN Comments LIKE '%Spring%' THEN 5
				WHEN Comments LIKE '%Summer%' THEN 8
				WHEN Comments LIKE '%Fall%' THEN 11
				WHEN month(FormattedDate) IS NOT NULL AND year(FormattedDate) > '1901' THEN month(FormattedDate)
				WHEN Comments LIKE '%week%ago%' OR Comments LIKE '%ast%week%' OR Comments LIKE '%day%ago%' THEN month(EntryDateTime)
				WHEN TwoDigit IN ('1','01','2','02','3','03','4','04','5','05','6','06','7','07','8','08','9','09','10','11','12') THEN twodigit
				ELSE NULL
			END AS [EventMonth]
		  ,CASE WHEN CernerDate IS NOT NULL THEN day(CernerDate)
				WHEN day(FormattedDate) IS NOT NULL AND year(FormattedDate) > '1901' THEN day (FormattedDate)
				WHEN day(FormattedDateC) IS NOT NULL AND year(FormattedDateC) > '1901' THEN day (FormattedDateC)
				WHEN TwoDigit IN ('1','01','2','02','3','03','4','04','5','05','6','06','7','07','8','08','9','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31') 
					AND LEN(NumbersOnly)>4 then TwoDigit
				END AS [EventDay]
		  ,CASE WHEN CernerDate IS NOT NULL THEN year(CernerDate)
				WHEN year(FormattedDate) > '1901' AND FormattedDate <= EntryDateTime THEN year(FormattedDate)
				WHEN TRY_CAST(RIGHT(Comments,4) as int) between 1901 and year(EntryDateTime) THEN CAST(RIGHT(Comments,4) as int)
				WHEN TRY_CAST(LEFT(Comments,4) as int) between 1901 and year(EntryDateTime) THEN CAST(LEFT(Comments,4) as int)
				WHEN (Comments LIKE '%2024%' OR Comments LIKE '%24') AND EntryDateTime > '2024-01-01' THEN 2024
				WHEN (Comments LIKE '%2023%' OR Comments LIKE '%23') AND EntryDateTime > '2023-01-01' THEN 2023
				WHEN (Comments LIKE '%2022%' OR Comments LIKE '%22') AND EntryDateTime > '2022-01-01' THEN 2022
				WHEN (Comments LIKE '%2021%' OR Comments LIKE '%21') AND EntryDateTime > '2021-01-01' THEN 2021
				WHEN (Comments LIKE '%2020%' OR Comments LIKE '%20') AND EntryDateTime > '2020-01-01' THEN 2020
				WHEN (Comments LIKE '%2019%' OR (Comments LIKE '%/19%' AND Comments NOT LIKE '%19/%' AND Comments NOT LIKE '%19__') 
					OR (Comments LIKE '%-19%' AND Comments NOT LIKE '%-19-%') OR (Comments LIKE '%.19%' AND Comments NOT LIKE '%.19.%')) AND EntryDateTime > '2019-01-01' THEN 2019
				WHEN (Comments LIKE '%2018%' OR (Comments LIKE '%/18%' AND Comments NOT LIKE '%18/%') OR (Comments LIKE '%-18%' AND Comments NOT LIKE '%-18-%') 
					OR (Comments LIKE '%.18%' AND Comments NOT LIKE '%.18.%')) AND EntryDateTime > '2018-01-01' THEN 2018
				WHEN (Comments LIKE '%2017%' OR (Comments LIKE '%/17%' AND Comments NOT LIKE '%17/%') OR (Comments LIKE '%-17%' AND Comments NOT LIKE '%-17-%') 
					OR (Comments LIKE '%.17%' AND Comments NOT LIKE '%.17.%')) AND EntryDateTime > '2017-01-01' THEN 2017
				WHEN (Comments LIKE '%2016%' OR (Comments LIKE '%/16%' AND Comments NOT LIKE '%16/%') OR (Comments LIKE '%-16%' AND Comments NOT LIKE '%-16-%') 
					OR (Comments LIKE '%.16%' AND Comments NOT LIKE '%.16.%')) AND EntryDateTime > '2016-01-01' THEN 2016
				WHEN (Comments LIKE '%2015%' OR (Comments LIKE '%/15%' AND Comments NOT LIKE '%15/%') OR (Comments LIKE '%-15%' AND Comments NOT LIKE '%-15-%') 
					OR (Comments LIKE '%.15%' AND Comments NOT LIKE '%.15.%')) AND EntryDateTime > '2015-01-01' THEN 2015
				WHEN (Comments LIKE '%week%ago%' OR Comments LIKE '%ast%week%' OR Comments LIKE '%month%ago%' OR Comments LIKE '%ast%month%') 
					AND year(EntryDateTime) = year(DateAdd(month, -1, EntryDateTime)) then year(EntryDateTime)
				WHEN (Comments LIKE '%week%ago%' OR Comments LIKE '%ast%week%' OR Comments LIKE '%month%ago%' OR Comments LIKE '%ast%month%') 
					AND year(EntryDateTime) > year(DateAdd(month, -1, EntryDateTime)) THEN year(DateAdd(year,-1,EntryDateTime))
				WHEN TRY_CAST(NumbersOnly AS int) between 1901 and year(EntryDateTime) THEN CAST(NumbersOnly AS int)
				ELSE NULL END AS [EventYear]
		  ,FormattedDateC
		  ,CommentsDate
		,CASE WHEN FormattedDate < '1901' THEN NULL ELSE FormattedDate END AS FormattedDate
	INTO #FormattedDateParts
	FROM #CastDate

	DROP TABLE IF EXISTS #AdjustDays
	SELECT DocIdentifier, EventCategory, List, Comments, NumbersOnly, EntryDateTime, CernerDate, EventDay, EventMonth, FormattedDate, FormattedDateC, CommentsDate,
	EventYear=CASE WHEN (DateFromParts(Eventyear, Eventmonth, Eventday) <= EntryDateTime) THEN EventYear
			WHEN (DateFromParts(Eventyear, Eventmonth, Eventday) > EntryDateTime) THEN year(EntryDateTime)
			WHEN EventYear IS NULL AND EventMonth IS NOT NULL AND DateFromParts(Year(EntryDateTime), EventMonth, EventDay) <= EntryDateTime THEN  year(EntryDateTime)
			WHEN EventYear IS NULL AND EventMonth IS NOT NULL AND DateFromParts(Year(EntryDateTime), EventMonth, EventDay) > EntryDateTime THEN  year(EntryDateTime)
			ELSE EventYear END 
	INTO #AdjustDays
	FROM (
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,NumbersOnly
		  ,EntryDateTime
		  ,CernerDate
		  ,CASE WHEN EventYear IS NOT NULL AND EventMonth IS NULL THEN 1 ELSE EventMonth END AS EventMonth
		  ,CASE WHEN b.DayOfMonth IS NOT NULL THEN a.EventDay
			WHEN EventMonth=2 AND EventDay > 28 THEN 28
			WHEN EventMonth in (4,6,9,11) AND EventDay > 30 THEN 30
			WHEN EventDay IS NULL THEN 1
			ELSE EventDay END AS EventDay
		  ,EventYear
		  ,c.DATE AS FormattedDate
		  ,FormattedDateC
		  ,CommentsDate
	FROM #FormattedDateParts a
	LEFT JOIN [Dim].[Date] b ON b.CalendarYear=a.EventYear AND b.MonthOfYear=a.EventMonth AND a.EventDay=b.DayOfMonth
	LEFT JOIN [Dim].[Date] c ON a.FormattedDate=c.DATE
	) Src
	;

	DROP TABLE IF EXISTS #FormattedDate;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,EntryDateTime
		  ,NumbersOnly
		  ,CASE WHEN FormattedDateC BETWEEN '1901-01-01' AND EntryDateTime THEN FormattedDateC 
			WHEN FormattedDateC BETWEEN '1901-01-01' AND DateAdd(year,1,EntryDateTime) THEN EntryDateTime
			ELSE NULL END AS FormattedDateC
		  ,CASE WHEN FormattedDate BETWEEN '1901-01-01' AND EntryDateTime THEN FormattedDate 
			WHEN FormattedDate BETWEEN '1901-01-01' AND DateAdd(year,1,EntryDateTime) THEN EntryDateTime
			ELSE NULL END AS FormattedDate
		  ,CommentsDate
		  ,CernerDate
		  ,DATEFROMPARTS ( Eventyear, Eventmonth, Eventday ) AS formatteddateParts
		  ,EventMonth
		  ,CASE WHEN EventMonth IS NOT NULL THEN EventDay
			ELSE NULL END AS EventDay
		  ,CASE WHEN EventYear > '1901' THEN EventYear ELSE NULL END AS EventYear
	INTO #FormattedDate
	FROM #AdjustDays
	;

	--Step 2e: If CernerDate is not null, use CernerDate (selected from a calendar field unlike health factors which are free text)
	--If CommentsDate (where the DATE was expressed as a relationship to entrydatetime) use that as the final DATE.  
	--Otherwise, compare the other three computed dates and take the one that is closest to EntryDateTime.
	DROP TABLE IF EXISTS #FormattedDate2;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,EntryDateTime
		  ,CernerDate
		  ,FormattedDateC
		  ,FormattedDate
		  ,CommentsDate
		  ,FormattedDateParts
		  ,EventMonth
		  ,EventDay
		  ,EventYear
		  ,CASE WHEN CernerDate IS NOT NULL THEN CernerDate
			WHEN CommentsDate IS NOT NULL THEN CommentsDate
			WHEN FormattedDateC IS NOT NULL THEN FormattedDateC
			ELSE (SELECT MAX(FinalDate)
				FROM (VALUES (FormattedDateC), (FormattedDate), (FormattedDateParts)) AS FormattedDate(FinalDate))
				END AS FinalDate
	INTO #FormattedDate2
	FROM #FormattedDate

	DROP TABLE IF EXISTS #FormattedDateFinal;
	SELECT DocIdentifier
		  ,EventCategory
		  ,List
		  ,Comments
		  ,CernerDate
		  ,EntryDateTime
		  ,EventMonth
		  ,EventDay
		  ,CASE WHEN FinalDate IS NULL THEN EventYear
			ELSE year(FinalDate) END AS EventYear
		  ,FinalDate=CASE WHEN FinalDate > EntryDateTime THEN EntryDateTime ELSE FinalDate END
	INTO #FormattedDateFinal
	FROM #FormattedDate2
	;

	DROP TABLE IF EXISTS #AdjustDays
	DROP TABLE IF EXISTS #CastDate
	DROP TABLE IF EXISTS #FormattedDate
	DROP TABLE IF EXISTS #FormattedDate2
	DROP TABLE IF EXISTS #FormattedDateParts
	DROP TABLE IF EXISTS #NumbersOnly
	

	CREATE NONCLUSTERED INDEX DateIndex
		  ON #FormattedDateFinal (DocIdentifier); 

	--Step 3a: Match PatientICN with specific SBOR health factors, to generate temp tables for SDV Classification
	--Events with suicidal intent from SBOR
	DROP TABLE IF EXISTS #SuicideIntentSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #SuicideIntentSBOR
	FROM #EventDetails_SBOR
	WHERE List = 'SBOR_SuicideAttempt_HF' AND EventCategory='SBOR'
	--Events with undetermined suicidal intent from SBOR
	DROP TABLE IF EXISTS #SuicideUndeterminedSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #SuicideUndeterminedSBOR
	FROM #EventDetails_SBOR
	WHERE List = 'SBOR_SuicideAttemptUndetermined_HF'
	--Get identifiers for events that are missing a health factor that indicates intent
	DROP TABLE IF EXISTS #MissingIntent
	SELECT a.docidentifier
	INTO #MissingIntent
	FROM #EventDetails_SBOR a
	EXCEPT
	(SELECT docidentifier from #SuicideIntentSBOR 
	UNION ALL 
	SELECT docidentifier FROM #SuicideUndeterminedSBOR
	UNION ALL SELECT DocIdentifier FROM #EventDetails_SBOR WHERE List IN ('SBOR_TypeODAccidental_HF','SBOR_TypeODAdverseEffect_HF'))
	--Events reported in SBOR that are missing intent health factor will be categorized as having undetermined intent
	INSERT INTO #SuicideUndeterminedSBOR
	SELECT a.MVIPersonSID
		  ,a.HealthFactorDateTime
		  ,a.DocIdentifier
		  ,a.EntryDateTime
		  ,a.List
		  ,a.EventCategory
	FROM #EventDetails_SBOR AS a
	INNER JOIN #MissingIntent AS b ON a.DocIdentifier=b.DocIdentifier

	--Preparatory behaviors for suicide from SBOR
	DROP TABLE IF EXISTS #PreparatoryYesSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #PreparatoryYesSBOR 
	FROM #EventDetails_SBOR
	WHERE List = 'SBOR_PrepOnlyYes_HF'
	--Events that were interrupted by self or other, from SBOR
	DROP TABLE IF EXISTS #InterruptedYesSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InterruptedYesSBOR
	FROM #EventDetails_SBOR
	WHERE List IN ('SBOR_EventInterruptedBySelf_HF' ,'SBOR_EventInterruptedByOther_HF')
	--Events that resulted in injury, from SBOR
	DROP TABLE IF EXISTS #InjuryYesSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InjuryYesSBOR
	FROM #EventDetails_SBOR
	WHERE List = 'SBOR_EventInjuryYes_HF'
	--Events that resulted in death, from the SBOR
	DROP TABLE IF EXISTS #DiedSBOR;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #DiedSBOR
	FROM #EventDetails_SBOR
	WHERE List = 'SBOR_EventOutcomeDied_HF'
	;
	--SDV classifications for most recent suicide attempt in CSRE
	DROP TABLE IF EXISTS #SuicideIntentCSRERecent;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #SuicideIntentCSRERecent
	FROM #EventDetails_CSRE
	WHERE List in ('SBOR_SuicideAttempt_HF','SBOR_SuicideAttemptCSRE_HF') AND EventCategory = 'CSRE Most Recent'
	--Events that were interrupted by self or other, from most recent suicide attempt from CSRE
	DROP TABLE IF EXISTS #InterruptedYesCSRERecent;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InterruptedYesCSRERecent
	FROM #EventDetails_CSRE
	WHERE List IN ('SBOR_CSREEventInterruptedBySelf_HF' ,'SBOR_CSREEventInterruptedByOther_HF')
	--Events that resulted in injury, from most recent suicide attempt from CSRE
	DROP TABLE IF EXISTS #InjuryYesCSRERecent;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InjuryYesCSRERecent
	FROM #EventDetails_CSRE
	WHERE List IN ('SBOR_EventInjuryYes_HF', 'SBOR_CSREEventInjuryYes_HF')

	--SDV classifications for most lethal suicide attempt in CSRE (done separately so the health factors for most recent and most lethal don't get mixed together in the SDV classification)
	--Suicide Attempts, from CSRE most lethal
	DROP TABLE IF EXISTS #SuicideAttemptMostLeth;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #SuicideAttemptMostLeth
	FROM #EventDetails_LtCSRE
	WHERE EventCategory = 'CSRE Most Lethal'
	--Events that were interrupted by self or other, from CSRE most lethal
	DROP TABLE IF EXISTS #InterruptedYesMostLeth;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InterruptedYesMostLeth
	FROM #EventDetails_LtCSRE
	WHERE List IN ('SBOR_LtCSREEventInterruptedBySelf_HF' ,'SBOR_LtCSREEventInterruptedByOther_HF')
	--Events that resulted in injury, from CSRE most lethal
	DROP TABLE IF EXISTS #InjuryYesMostLeth;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #InjuryYesMostLeth
	FROM #EventDetails_LtCSRE
	WHERE List = 'SBOR_LtCSREEventInjuryYes_HF'
	;
	--SDV classification for most recent preparatory behavior in CSRE
	DROP TABLE IF EXISTS #PreparatoryCSRE;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime
		  ,DocIdentifier
		  ,EntryDateTime
		  ,List
		  ,EventCategory
	INTO #PreparatoryCSRE
	FROM #EventDetails_PrepCSRE
	WHERE List = 'SBOR_PrepCSREEventDate_HF' AND EventCategory = 'CSRE Preparatory'

	--For faster queries in below steps: join preparatory, injury, and/or died
	DROP TABLE IF EXISTS #PrepInjuryDied
	SELECT sa.MVIPersonSID, sa.DocIdentifier 
	INTO #PrepInjuryDied
	FROM #SuicideUndeterminedSBOR sa
	LEFT OUTER JOIN #PreparatoryYesSBOR Pr ON pr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = sa.DocIdentifier
	WHERE pr.DocIdentifier IS NOT NULL OR Inj.DocIdentifier IS NOT NULL OR Died.DocIdentifier IS NOT NULL

	--Step 3b: Join temp tables from step 2 to create SDV Classifications
	-- Suicide 
	DROP TABLE IF EXISTS #SuicideSBOR
	SELECT SA.HealthFactorDateTime
		  ,SDVClass = '1'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideSBOR
	FROM #SuicideIntentSBOR SA 
	INNER JOIN #DiedSBOR Died ON Died.DocIdentifier = sa.DocIdentifier
	
	--Undetermined SDV, Fatal
	DROP TABLE IF EXISTS #UndeterminedSDVFatalSBOR
	SELECT Died.HealthFactorDateTime
		  ,SDVClass = '2'
		  ,Died.MVIPersonSID
		  ,Died.List
		  ,Died.DocIdentifier
		  ,Died.EntryDateTime
		  ,SA.EventCategory
	INTO #UndeterminedSDVFatalSBOR
	FROM #DiedSBOR Died 
	INNER JOIN #SuicideUndeterminedSBOR SA ON Died.DocIdentifier = sa.DocIdentifier
	LEFT JOIN #SuicideSBOR Sui ON Died.DocIdentifier = Sui.DocIdentifier
	WHERE Sui.DocIdentifier IS NULL
	
	-- Suicide Attempt With Injury, Interrupted 
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedSBOR
	SELECT SA.HealthFactorDateTime
		  ,SDVClass = '3'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjuryInterruptedSBOR
	FROM #SuicideIntentSBOR SA 
	INNER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = sa.DocIdentifier
	INNER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = sa.DocIdentifier
	WHERE Died.DocIdentifier IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedCSRERecent
	SELECT SA.HealthFactorDateTime
		  ,SDVClass = '3'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjuryInterruptedCSRERecent
	FROM #SuicideIntentCSRERecent SA 
	INNER JOIN #InterruptedYesCSRERecent Intr ON Intr.DocIdentifier = sa.DocIdentifier
	INNER JOIN #InjuryYesCSRERecent Inj ON Inj.DocIdentifier = sa.DocIdentifier

	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedMostLeth
	SELECT SA.HealthFactorDateTime
		  ,SDVClass = '3'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjuryInterruptedMostLeth
	FROM #SuicideAttemptMostLeth SA 
	INNER JOIN #InterruptedYesMostLeth Intr ON Intr.DocIdentifier = sa.DocIdentifier
	INNER JOIN #InjuryYesMostLeth Inj ON Inj.DocIdentifier = sa.DocIdentifier

	-- Undetermined SDV With Injury, Interrupted 
	DROP TABLE IF EXISTS #UndeterminedSDVWithInjuryInterruptedSBOR
	SELECT Intr.HealthFactorDateTime
		  ,SDVClass = '4'
		  ,Intr.MVIPersonSID
		  ,Intr.List
		  ,Intr.DocIdentifier
		  ,Intr.EntryDateTime
		  ,Intr.EventCategory
	INTO #UndeterminedSDVWithInjuryInterruptedSBOR
	FROM #InterruptedYesSBOR Intr 
	INNER JOIN #InjuryYesSBOR Inj ON  Inj.DocIdentifier = Intr.DocIdentifier
	INNER JOIN #SuicideUndeterminedSBOR SA ON Intr.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = Intr.DocIdentifier
	LEFT JOIN #SuicideAttemptWithInjuryInterruptedSBOR Sui ON Intr.DocIdentifier = Sui.DocIdentifier
	WHERE Sui.DocIdentifier IS NULL AND Died.MVIPersonSID IS NULL

	--Suicide Attempt With Injury 
	DROP TABLE IF EXISTS #SuicideAttemptWithInjurySBOR
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '5'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjurySBOR
	FROM #SuicideIntentSBOR SA 
	INNER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = SA.DocIdentifier
	WHERE Died.MVIPersonSID IS NULL 
		AND Intr.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryCSRERecent
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '5'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjuryCSRERecent
	FROM #SuicideIntentCSRERecent SA 
	INNER JOIN #InjuryYesCSRERecent Inj ON Inj.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesCSRERecent Intr ON Intr.DocIdentifier = SA.DocIdentifier
	WHERE Intr.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryMostLeth
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '5'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptWithInjuryMostLeth
	FROM #SuicideAttemptMostLeth SA 
	INNER JOIN #InjuryYesMostLeth Inj ON Inj.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesMostLeth Intr ON Intr.DocIdentifier = SA.DocIdentifier
	WHERE Intr.MVIPersonSID IS NULL

	-- Undetermined SDV With Injury 
	DROP TABLE IF EXISTS #UndeterminedSDVWithInjurySBOR
	SELECT Inj.HealthFactorDateTime
		  ,SDVClass = '6'
		  ,Inj.MVIPersonSID
		  ,Inj.List
		  ,Inj.DocIdentifier
		  ,Inj.EntryDateTime
		  ,Inj.EventCategory
	INTO #UndeterminedSDVWithInjurySBOR
	FROM #InjuryYesSBOR Inj 
	INNER JOIN  #SuicideUndeterminedSBOR SA ON Inj.DocIdentifier = SA.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = Inj.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = Inj.DocIdentifier
	LEFT JOIN #SuicideAttemptWithInjurySBOR Sui ON Inj.DocIdentifier = Sui.DocIdentifier
	WHERE Sui.DocIdentifier IS NULL AND Died.MVIPersonSID IS NULL AND Intr.MVIPersonSID IS NULL

	-- Suicide Attempt Without Injury 
	DROP TABLE IF EXISTS #SuicideAttemptNoInjurySBOR
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '7'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjurySBOR
	FROM #SuicideIntentSBOR SA 
	LEFT OUTER JOIN #PrepInjuryDied pid ON pid.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = sa.DocIdentifier
	WHERE pid.MVIPersonSID IS NULL 
		AND Intr.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryCSRERecent
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '7'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjuryCSRERecent
	FROM #SuicideIntentCSRERecent SA 
	LEFT OUTER JOIN #InjuryYesCSRERecent Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesCSRERecent Intr ON Intr.DocIdentifier = sa.DocIdentifier
	WHERE Inj.MVIPersonSID IS NULL 
		AND Intr.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryMostLeth
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '7'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjuryMostLeth
	FROM #SuicideAttemptMostLeth SA 
	LEFT OUTER JOIN #InjuryYesMostLeth Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesMostLeth Intr ON Intr.DocIdentifier = sa.DocIdentifier
	WHERE Inj.MVIPersonSID IS NULL 
		AND Intr.MVIPersonSID IS NULL

	-- Undetermined SDV Without Injury
	DROP TABLE IF EXISTS #UndeterminedSDVNoInjurySBOR;
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '8'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #UndeterminedSDVNoInjurySBOR
	FROM #SuicideUndeterminedSBOR SA 
	LEFT OUTER JOIN #PrepInjuryDied pid ON sa.DocIdentifier = pid.DocIdentifier
	LEFT OUTER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #SuicideAttemptNoInjurySBOR Sui ON Sui.DocIdentifier = sa.DocIdentifier
	WHERE Intr.MVIPersonSID IS NULL 
		AND Pid.MVIPersonSID IS NULL 
		AND Sui.DocIdentifier IS NULL

	--Suicide Attempt Without Injury, Interrupted
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedSBOR 
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '9'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjuryInterruptedSBOR
	FROM #SuicideIntentSBOR SA
	INNER JOIN #InterruptedYesSBOR Intr ON Intr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #PreparatoryYesSBOR Pr ON pr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = sa.DocIdentifier
	WHERE Died.MVIPersonSID IS NULL 
		AND Pr.MVIPersonSID IS NULL 
		AND Inj.MVIPersonSID IS NULL
	
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedCSRERecent 
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '9'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjuryInterruptedCSRERecent 
	FROM #SuicideIntentCSRERecent  SA
	INNER JOIN #InterruptedYesCSRERecent  Intr ON Intr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesCSRERecent  Inj ON Inj.DocIdentifier = sa.DocIdentifier
	WHERE Inj.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedMostLeth 
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '9'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicideAttemptNoInjuryInterruptedMostLeth
	FROM #SuicideAttemptMostLeth SA
	INNER JOIN #InterruptedYesMostLeth Intr ON Intr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesMostLeth Inj ON Inj.DocIdentifier = sa.DocIdentifier
	WHERE Inj.MVIPersonSID IS NULL

	-- Undetermined SDV Without Injury, Interrupted 
	DROP TABLE IF EXISTS #UndeterminedSDVNoInjuryInterruptedSBOR
	SELECT Intr.HealthFactorDateTime
		  ,SDVClassification = '10'
		  ,Intr.MVIPersonSID
		  ,Intr.List
		  ,Intr.DocIdentifier
		  ,Intr.EntryDateTime
		  ,Intr.EventCategory
	INTO #UndeterminedSDVNoInjuryInterruptedSBOR
	FROM #InterruptedYesSBOR Intr 
	INNER JOIN #SuicideUndeterminedSBOR SA ON Intr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #PrepInjuryDied Pid ON pid.DocIdentifier = Intr.DocIdentifier
	LEFT OUTER JOIN #SuicideAttemptNoInjuryInterruptedSBOR Sui ON Sui.DocIdentifier=Intr.DocIdentifier
	WHERE Pid.MVIPersonSID IS NULL 
		AND Sui.DocIdentifier IS NULL

	--Suicidal SDV, Preparatory 
	DROP TABLE IF EXISTS #SuicidalSDVPrepSBOR
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '11'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicidalSDVPrepSBOR
	FROM #SuicideIntentSBOR SA 
	INNER JOIN #PreparatoryYesSBOR Pr ON pr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = sa.DocIdentifier
	WHERE Died.MVIPersonSID IS NULL 
		AND Inj.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #SuicidalSDVPrepCSRE
	SELECT SA.HealthFactorDateTime
		  ,SDVClassification = '11'
		  ,SA.MVIPersonSID
		  ,SA.List
		  ,SA.DocIdentifier
		  ,SA.EntryDateTime
		  ,SA.EventCategory
	INTO #SuicidalSDVPrepCSRE
	FROM #PreparatoryCSRE SA 

	--Undetermined SDV, Preparatory 
	DROP TABLE IF EXISTS #UndeterminedSDVPrepSBOR;
	SELECT Pr.HealthFactorDateTime
		  ,SDVClassification = '12'
		  ,Pr.MVIPersonSID
		  ,Pr.List
		  ,Pr.DocIdentifier
		  ,Pr.EntryDateTime
		  ,Pr.EventCategory
	INTO #UndeterminedSDVPrepSBOR
	FROM #PreparatoryYesSBOR  Pr
	INNER JOIN #SuicideUndeterminedSBOR SA ON pr.DocIdentifier = sa.DocIdentifier
	LEFT OUTER JOIN #InjuryYesSBOR Inj ON Inj.DocIdentifier = Pr.DocIdentifier
	LEFT OUTER JOIN #DiedSBOR Died ON Died.DocIdentifier = Pr.DocIdentifier
	LEFT OUTER JOIN #SuicidalSDVPrepSBOR Sui ON Sui.DocIdentifier = Pr.DocIdentifier
	WHERE Died.MVIPersonSID IS NULL 
		AND Inj.MVIPersonSID IS NULL
		AND Sui.DocIdentifier IS NULL
	;

	--Step 4: Union all SDV temp tables (Step 3) together
	DROP TABLE IF EXISTS #SDVClass
	SELECT * INTO #SDVClass FROM #SuicideSBOR
	UNION ALL
	SELECT * FROM #UndeterminedSDVFatalSBOR
	UNION ALL
	SELECT * FROM #SuicideAttemptWithInjuryInterruptedSBOR
	UNION ALL
	SELECT * FROM #UndeterminedSDVWithInjuryInterruptedSBOR
	UNION ALL
	SELECT * FROM #SuicideAttemptWithInjurySBOR 
	UNION ALL
	SELECT * FROM #UndeterminedSDVWithInjurySBOR
	UNION ALL
	SELECT * FROM #SuicideAttemptNoInjurySBOR
	UNION ALL
	SELECT * FROM #UndeterminedSDVNoInjurySBOR
	UNION ALL
	SELECT * FROM #SuicideAttemptNoInjuryInterruptedSBOR
	UNION ALL
	SELECT * FROM #UndeterminedSDVNoInjuryInterruptedSBOR
	UNION ALL
	SELECT * FROM #SuicidalSDVPrepSBOR
	UNION ALL 
	SELECT * FROM #UndeterminedSDVPrepSBOR
	UNION ALL 
	SELECT * FROM #SuicideAttemptWithInjuryInterruptedMostLeth
	UNION ALL
	SELECT * FROM #SuicideAttemptWithInjuryMostLeth
	UNION ALL
	SELECT * FROM #SuicideAttemptNoInjuryMostLeth
	UNION ALL 
	SELECT * FROM #SuicideAttemptNoInjuryInterruptedMostLeth
	UNION ALL 
	SELECT * FROM #SuicideAttemptWithInjuryInterruptedCSRERecent
	UNION ALL
	SELECT * FROM #SuicideAttemptNoInjuryCSRERecent
	UNION ALL
	SELECT * FROM #SuicideAttemptNoInjuryInterruptedCSRERecent
	UNION ALL 
	SELECT * FROM #SuicideAttemptWithInjuryCSRERecent
	UNION ALL 
	SELECT * FROM #SuicidalSDVPrepCSRE

	DROP TABLE IF EXISTS #EventDetails_CSRE
	DROP TABLE IF EXISTS #EventDetails_LtCSRE
	DROP TABLE IF EXISTS #EventDetails_PrepCSRE
	DROP TABLE IF EXISTS #EventDetails_SBOR
	DROP TABLE IF EXISTS #DiedSBOR
	DROP TABLE IF EXISTS #InjuryYesCSRERecent
	DROP TABLE IF EXISTS #InjuryYesMostLeth
	DROP TABLE IF EXISTS #InjuryYesSBOR
	DROP TABLE IF EXISTS #InterruptedYesCSRERecent
	DROP TABLE IF EXISTS #InterruptedYesMostLeth
	DROP TABLE IF EXISTS #InterruptedYesSBOR
	DROP TABLE IF EXISTS #MissingIntent
	DROP TABLE IF EXISTS #PreparatoryCSRE
	DROP TABLE IF EXISTS #PreparatoryYesSBOR
	DROP TABLE IF EXISTS #SuicidalSDVPrepCSRE
	DROP TABLE IF EXISTS #SuicidalSDVPrepSBOR
	DROP TABLE IF EXISTS #SuicideAttemptMostLeth
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryCSRERecent
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedCSRERecent
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedMostLeth
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryInterruptedSBOR
	DROP TABLE IF EXISTS #SuicideAttemptNoInjuryMostLeth
	DROP TABLE IF EXISTS #SuicideAttemptNoInjurySBOR
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryCSRERecent
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedCSRERecent
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedMostLeth
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryInterruptedSBOR
	DROP TABLE IF EXISTS #SuicideAttemptWithInjuryMostLeth
	DROP TABLE IF EXISTS #SuicideAttemptWithInjurySBOR
	DROP TABLE IF EXISTS #SuicideIntentCSRERecent
	DROP TABLE IF EXISTS #SuicideIntentSBOR
	DROP TABLE IF EXISTS #SuicideSBOR
	DROP TABLE IF EXISTS #SuicideUndeterminedSBOR
	DROP TABLE IF EXISTS #UndeterminedSDVFatalSBOR
	DROP TABLE IF EXISTS #UndeterminedSDVNoInjuryInterruptedSBOR
	DROP TABLE IF EXISTS #UndeterminedSDVNoInjurySBOR
	DROP TABLE IF EXISTS #UndeterminedSDVPrepSBOR
	DROP TABLE IF EXISTS #UndeterminedSDVWithInjuryInterruptedSBOR
	DROP TABLE IF EXISTS #UndeterminedSDVWithInjurySBOR

	--SDV will be null for eventtype = accidental overdose and eventtype = adverse effect overdose	
	DROP TABLE IF EXISTS #SDVFinal
	SELECT DISTINCT b.EntryDateTime
		  ,b.DocIdentifier
		  ,b.EventCategory
		  ,b.List
		  ,CASE WHEN SDVClass = '1'  THEN 'Suicide'
				WHEN SDVClass = '2'  THEN 'Undetermined Self-Directed Violence, Fatal'
				WHEN SDVClass = '11' THEN 'Suicidal Self-Directed Violence, Preparatory'
				WHEN SDVClass = '12' THEN 'Undetermined Self-Directed Violence, Preparatory'
				WHEN SDVClass = '3'  THEN 'Suicide Attempt, With Injury, Interrupted by Self or Other'
				WHEN SDVClass = '4'  THEN 'Undetermined Self-Directed Violence, With Injury, Interrupted by Self or Other' 
				WHEN SDVClass = '5'  THEN 'Suicide Attempt, With Injury'
				WHEN SDVClass = '6'  THEN 'Undetermined Self-Directed Violence, With Injury'
				WHEN SDVClass = '7'  THEN 'Suicide Attempt, Without Injury'
				WHEN SDVClass = '8'  THEN 'Undetermined Self-Directed Violence, Without Injury' 
				WHEN SDVClass = '9'  THEN 'Suicide Attempt, Without Injury, Interrupted by Self or Other'
				WHEN SDVClass = '10' THEN 'Undetermined Self-Directed Violence, Without Injury, Interrupted by Self or Other'
				ELSE 'Undetermined Self-Directed Violence, Without Injury'
				END SDVClassification
			,row_number() OVER (PARTITION BY b.DocIdentifier, b.EventCategory, b.EntryDateTime ORDER BY SDVClass) AS RowNum
	INTO #SDVFinal
	FROM (
		SELECT DISTINCT DocIdentifier
			  ,EntryDateTime
			  ,EventCategory
		FROM #EventDetailsCombined
		WHERE RowNum = 1
		) a
	INNER JOIN #SDVClass b ON 
		a.DocIdentifier = b.DocIdentifier
		AND a.EventCategory = b.EventCategory
	;  
	DELETE FROM #SDVFinal WHERE RowNum>1

	CREATE NONCLUSTERED INDEX SDVIndex ON #SDVFinal (DocIdentifier); 

	--Step 5: Match Methods for each event with corresponding method categories and comments
	DROP TABLE IF EXISTS #MethodCategory
	SELECT DISTINCT s.DocIdentifier
		,s.TIUDocumentDefinition
		,s.rownum
		,s.EventCategory
		,s.EntryDateTime
		,s.PrintName AS MethodCategory
		,s.Comments AS MethodCategoryComments
	INTO #MethodCategory
	FROM (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Method Category') AS s

	DROP TABLE IF EXISTS #Method
	SELECT DISTINCT s.DocIdentifier
		,s.TIUDocumentDefinition
		,s.rownum
		,s.EventCategory
		,s.EntryDateTime
		,CASE WHEN s.PrintName = 'Other' THEN 'Other'
			WHEN s.PrintName IN ('Acetaminophen/Tylenol/NSAID','Alcohol','Amphetamines','Anticonvulsants','Antidepressants','Antihistamines','Antipsychotics','Benzodiazepines','Cannabis','Cocaine','Mood Stabilizers'
				,'Central Muscle Relaxants','Non-Benzodiazepine Sedatives','Non-Rx Opioids','Other Non-Opioids','Rx Opioids','Stimulants','Other Substance','Unknown Substance') THEN 'Overdose'
			WHEN s.PrintName IN ('Burned Self','Physical Injury (Details Unknown)','Carbon Monoxide','Physical Injury-Other','Jump from Height','Drowning','Hanging','Jump in front of Auto/Train'
				,'Ingest Poison/Chemical','Suffocation','Stabbed/Cut Self or Slit Wrist','Electrocution','Explosion') THEN 'Physical Injury'
			WHEN s.PrintName IN ('Injury by Other','Injury by Other (Details Unknown)','Patient Induced Law Enforcement into Killing Him/Her') THEN 'Injury by Other'
			WHEN s.PrintName IN ('Automobile (Details Unknown)','Automobile-Other','Carbon Monoxide','Drove Into Object','Drove Off Road') THEN 'Motor Vehicle'
			WHEN s.PrintName LIKE 'Firearm%' THEN 'Firearm'
			WHEN s.PrintName = 'Not Applicable' THEN 'Not Applicable'
			END AS MethodCategory
		,CASE WHEN s.PrintName in ('Amphetamines','Cocaine','Stimulants') THEN 'Stimulants' ELSE s.PrintName END AS Method
		,ISNULL(s.Comments,s.PrintName) AS MethodComments
	INTO #Method
	FROM #EventDetailsCombined AS s
	WHERE Category LIKE 'SBOR Method I'

	DROP TABLE IF EXISTS #OverdoseSubTypes
	SELECT DISTINCT m2.DocIdentifier
		,m2.TIUDocumentDefinition
		,m2.rownum
		,m2.EventCategory
		,m2.EntryDateTime
		,c.MethodCategory
		,CASE WHEN m2.PrintName in ('Barbiturates','Gabapentin', 'Unknown Anticonvulsants','Other Anticonvulsants') THEN 'Anticonvulsants'
			WHEN m2.PrintName in ('Tricyclic Antidepressants','SSRI','SNRI','Atypical Antidepressants','MAO Inhibitor','Unknown Antidepressants','Other Antidepressants') THEN 'Antidepressants'
			WHEN m2.PrintName in ('Diphenhydramine','Other Antihistamines','Unknown Antihistamines') THEN 'Antihistamines'
			WHEN m2.PrintName in ('Typical Antipsychotics','Atypical Antipsychotics','Clozapine','Other Antipsychotics','Unknown Antipsychotics') THEN 'Antipsychotics'
			WHEN m2.PrintName in ('Alprazolam','Chlordiazepoxide','Clonazepam','Estazolam','Midazolam','Other Benzodiazepines','Unknown Benzodiazepines') THEN 'Benzodiazepines'
			WHEN m2.PrintName in ('Eszopliclone','Ramelteon','Zolpidem','Zaleplon','Other Non-Benzo Sedatives','Unknown Sedatives') THEN 'Non-Benzodiazepine Sedatives'
			WHEN m2.PrintName in ('Baclofen','Cyclobenzaprine','Metaxolone','Methocarbamol','Tizanidine','Other Muscle Relaxants','Unknown Muscle Relaxants') THEN 'Central Muscle Relaxants'
			WHEN m2.PrintName in ('Carbamazepine','Divalproex/Valproate/Valproic Acid','Lamotrigine','Lithium','Other Mood Stabilizers','Unknown Mood Stabilizers') THEN 'Mood Stabilizers'
			WHEN m2.PrintName in ('Rx Fentanyl','Hydrocodone','Methadone','Morphine','Oxycodone','Suboxone, Subutex, Buprenorphine','Other Rx Opioids','Unknown Rx Opioids') THEN 'Rx Opioids'
			WHEN m2.PrintName in ('Heroin','Carfentanil','Illicit Fentanyl','Other Non-Rx Opioids','Unknown Non-Rx Opioids') THEN 'Non-Rx Opioids'
			WHEN m2.PrintName in ('Antihypertensives','Anticoagulants','Antidiabetic Agents','Other Non-Opioids') THEN 'Other Non-Opioids'
			WHEN m2.PrintName in ('Amphetamines','Cocaine','Stimulants') THEN 'Stimulants'
			WHEN m2.PrintName in ('Acetaminophen/Tylenol/NSAID','Alcohol','Cannabis','Unknown Substance','Not Applicable') THEN m2.PrintName
				END AS Method
		,ISNULL(m2.Comments,m2.PrintName) AS MethodComments
	INTO #OverdoseSubTypes
	FROM (SELECT * FROM #EventDetailsCombined WHERE Category LIKE 'SBOR Method II') AS m2
	LEFT JOIN #MethodCategory AS c ON m2.DocIdentifier = c.DocIdentifier  AND m2.EventCategory = c.EventCategory and c.MethodCategory='Overdose'

	UPDATE #OverdoseSubTypes 
	SET MethodComments = NULL
	WHERE MethodComments = Method

	DROP TABLE IF EXISTS #BringTypesTogether
	SELECT ISNULL(m.DocIdentifier, m1.DocIdentifier) AS DocIdentifier
		,ISNULL(m.TIUDocumentDefinition, m1.TIUDocumentDefinition) AS TIUDocumentDefinition
		,ISNULL(m.rownum, m1.RowNum) AS RowNum
		,ISNULL(m.EventCategory, m1.EventCategory) AS EventCategory
		,ISNULL(m.EntryDateTime, m1.EntryDateTime) AS EntryDateTime
		,ISNULL(m.MethodCategory, m1.MethodCategory) AS MethodType
		,COALESCE(od.Method, m1.Method, m.MethodCategory) AS Method
		,COALESCE(od.MethodComments, m1.MethodComments,m.MethodCategoryComments) AS MethodComments
	INTO #BringTypesTogether
	FROM #MethodCategory m
	FULL OUTER JOIN #Method m1 ON m.DocIdentifier = m1.DocIdentifier  AND m.EventCategory = m1.EventCategory and m.MethodCategory=m1.MethodCategory
	LEFT JOIN #OverdoseSubTypes od
		ON m.DocIdentifier = od.DocIdentifier  AND m.EventCategory = od.EventCategory and m.MethodCategory=od.MethodCategory
		
	UPDATE #BringTypesTogether 
	SET MethodComments = NULL
	WHERE MethodComments = Method

	DROP TABLE IF EXISTS #MethodDuplicates
	SELECT DISTINCT DocIdentifier
		,TIUDocumentDefinition
		,EventCategory
		,EntryDateTime
		,MethodType
		,Method
		,MethodComments 
	INTO #MethodDuplicates
	FROM
		(SELECT *, row_number() OVER (PARTITION BY DocIdentifier, EventCategory, MethodType, Method ORDER BY MethodComments DESC) as droprows
			FROM #BringTypesTogether) a
		WHERE droprows=1

	DROP TABLE IF EXISTS #MethodsWithRows
	SELECT DISTINCT *
		,row_number() OVER (PARTITION BY DocIdentifier, EventCategory ORDER BY Method) AS RowNum
	INTO #MethodsWithRows
	FROM #MethodDuplicates

	DROP TABLE IF EXISTS #GroupMethods
	SELECT a.DocIdentifier
	,a.EventCategory
	,a.EntryDateTime
	,a.Methodtype AS Methodtype1
	,a.Method AS Method1
	,a.MethodComments AS MethodComments1
	,b.Methodtype AS Methodtype2
	,b.Method AS Method2
	,b.MethodComments AS MethodComments2
	,c.Methodtype AS Methodtype3
	,c.Method AS Method3
	,c.MethodComments AS MethodComments3
	,CASE WHEN d.MethodType IS NOT NULL THEN 'Yes'
	  		ELSE 'No' END AS AdditionalMethodsReported
	INTO #GroupMethods
	FROM (SELECT * FROM #MethodsWithRows WHERE rownum=1) a
	LEFT JOIN (SELECT * FROM #MethodsWithRows WHERE rownum=2) b
		on a.DocIdentifier=b.DocIdentifier and a.EventCategory=b.EventCategory --and a.EntryDateTime=b.EntryDateTime
	LEFT JOIN (SELECT * FROM #MethodsWithRows WHERE rownum=3) c 
		on a.DocIdentifier=c.DocIdentifier and a.EventCategory=c.EventCategory --and a.EntryDateTime=c.EntryDateTime
	LEFT JOIN (SELECT * FROM #MethodsWithRows WHERE rownum=4) d
		on a.DocIdentifier=d.DocIdentifier and a.EventCategory=d.EventCategory --and a.EntryDateTime=d.EntryDateTime
	
	CREATE NONCLUSTERED INDEX MethodIndex ON #GroupMethods (DocIdentifier); 

	DROP TABLE IF EXISTS #DistinctNotes
	SELECT DISTINCT MVIPersonSID
		  ,Sta3n
		  ,ChecklistID
		  ,VisitSID
		  ,DocFormActivitySID
		  ,EntryDateTime
		  ,HealthFactorDateTime
		  ,EventCategory
		  ,TIUDocumentDefinition
		  ,DocIdentifier
	INTO #DistinctNotes
	FROM #EventDetailsCombined

	DROP TABLE IF EXISTS #GroupDetails
	SELECT DISTINCT a.MVIPersonSID
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.DocFormActivitySID
		,a.DocIdentifier
		,a.HealthFactorDateTime
		,a.TIUDocumentDefinition
		,a.EventCategory
		,a.EntryDateTime
		,CASE WHEN a.EventCategory LIKE 'CSRE%' THEN 'Suicide Event'
			WHEN j.PrintName IS NOT NULL THEN j.PrintName 
			ELSE 'Possible Suicide Event (Intent Undetermined)' -- if event type is missing then classify as undetermined intent
			END AS EventType
		,CASE WHEN j.PrintName in ('Accidental Overdose','Adverse Effect Overdose') THEN NULL --only applies to suicide-related events
			WHEN a.EventCategory = 'CSRE Preparatory' THEN 'Yes' -- if reported in CSRE most recent preparatory behavior section, yes
			WHEN d.PrintName = 'Yes' THEN 'No' --if there was an injury, event cannot be preparatory only
			WHEN e.PrintName = 'Died' THEN 'No' --if the patient died, event cannot be preparatory only
			WHEN f.PrintName = 'Died' THEN 'No'
			WHEN b.PrintName IS NULL THEN 'No'
			ELSE b.PrintName END AS Preparatory
		,c.PrintName AS Interrupted
		,c.Comments AS InterruptedComments
		,CASE WHEN d.PrintName IS NULL and a.EventCategory='CSRE Preparatory' THEN 'No'
			ELSE d.PrintName END AS Injury
		,d.Comments AS InjuryComments
		,e.PrintName AS Outcome1
		,e.Comments AS Outcome1Comments
		,f.PrintName AS Outcome2
		,f.Comments AS Outcome2Comments
		,g.PrintName AS Setting
		,g.Comments AS SettingComments
		,CASE WHEN h.PrintName IS NOT NULL THEN h.PrintName
			WHEN g.PrintName IN ('MH RRTP', 'CLC', 'VA Contracted Community Residential or Transitional Bed') THEN 'Yes' --CSRE template does not ask if the event occurred on VA property if one of these settings is selected; the answer is assumed to be 'yes'
			ELSE 'Unknown' END AS VAProperty
		,i.PrintName AS SevenDaysDx
		,k.MethodType1
		,k.Method1
		,k.MethodComments1
		,k.MethodType2
		,k.Method2
		,k.MethodComments2
		,k.MethodType3
		,k.Method3
		,k.MethodComments3
		,k.AdditionalMethodsReported
	INTO #GroupDetails
	FROM #DistinctNotes a
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Preparatory' AND RowNum=1) b
		on a.DocIdentifier=b.DocIdentifier AND a.EventCategory=b.EventCategory --AND a.EntryDateTime=b.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Interrupted' AND RowNum=1) c
		on a.DocIdentifier=c.DocIdentifier AND a.EventCategory=c.EventCategory --AND a.EntryDateTime=c.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Injury' AND RowNum=1) d
		on a.DocIdentifier=d.DocIdentifier AND a.EventCategory=d.EventCategory --AND a.EntryDateTime=d.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Outcome' AND rownum = 1) e
		on a.DocIdentifier=e.DocIdentifier AND a.EventCategory=e.EventCategory --AND a.EntryDateTime=e.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR Outcome' AND rownum = 2) f
		on a.DocIdentifier=f.DocIdentifier AND a.EventCategory=f.EventCategory --AND a.EntryDateTime=f.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR PatientStatus' AND rownum = 1) g
		on a.DocIdentifier=g.DocIdentifier AND a.EventCategory=g.EventCategory --AND a.EntryDateTime=g.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR VAProperty' AND rownum = 1) h
		on a.DocIdentifier=h.DocIdentifier AND a.EventCategory=h.EventCategory --AND a.EntryDateTime=h.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR 7Days' AND rownum = 1) i
		on a.DocIdentifier=i.DocIdentifier AND a.EventCategory=i.EventCategory --AND a.EntryDateTime=i.EntryDateTime
	LEFT JOIN (SELECT * FROM #EventDetailsCombined WHERE Category = 'SBOR EventType' AND rownum = 1) j
		on a.DocIdentifier=j.DocIdentifier AND a.EventCategory=j.EventCategory --AND a.EntryDateTime=j.EntryDateTime
	LEFT JOIN #GroupMethods k
		on a.DocIdentifier=k.DocIdentifier AND a.EventCategory=k.EventCategory --AND a.EntryDateTime=k.EntryDateTime
	
	
	DROP TABLE IF EXISTS #BringTypesTogether
	DROP TABLE IF EXISTS #GroupMethods
	DROP TABLE IF EXISTS #Method
	DROP TABLE IF EXISTS #MethodCategory
	DROP TABLE IF EXISTS #MethodDuplicates
	DROP TABLE IF EXISTS #MethodsWithRows
	DROP TABLE IF EXISTS #OverdoseSubTypes
	DROP TABLE IF EXISTS #SDVClass
	

	--Step 5: Pull together relevant health factors for each event

	DROP TABLE IF EXISTS #CombineDetails
	SELECT DISTINCT a.MVIPersonSID
		  ,a.Sta3n
		  ,a.ChecklistID
		  ,a.VisitSID
		  ,a.DocFormActivitySID
		  ,a.EntryDateTime
		  ,a.HealthFactorDateTime
		  ,a.EventCategory
		  ,a.TIUDocumentDefinition
		  ,CASE WHEN c.CernerDate IS NOT NULL THEN CAST(c.CernerDate AS varchar)
			ELSE c.Comments END AS EventDate
		  ,CAST(c.FinalDate AS DATE) AS EventDateFormatted
		  ,c.EventYear AS Year
		  ,b.EventType
		  ,b.Setting
		  ,b.SettingComments
		  ,b.VAProperty
		  ,b.SevenDaysDx
		  ,b.Preparatory
		  ,b.Interrupted
		  ,b.InterruptedComments
		  ,b.Injury
		  ,b.InjuryComments
		  ,b.Outcome1
		  ,b.Outcome1Comments
		  ,b.Outcome2
		  ,b.Outcome2Comments
		  ,b.MethodType1
		  ,b.Method1
		  ,b.MethodComments1
		  ,b.MethodType2
		  ,b.Method2
		  ,b.MethodComments2
		  ,b.MethodType3
		  ,b.Method3
		  ,b.MethodComments3
		  ,b.AdditionalMethodsReported
		  ,a.DocIdentifier
	INTO #CombineDetails
	FROM #DistinctNotes a
	LEFT JOIN #FormattedDateFinal c ON 
		--a.EntryDateTime = c.EntryDateTime 
		 a.DocIdentifier = c.DocIdentifier
		AND a.EventCategory = c.EventCategory
	LEFT JOIN #GroupDetails b ON
		--a.EntryDateTime = b.EntryDateTime 
		a.DocIdentifier = b.DocIdentifier
		AND a.EventCategory = b.EventCategory
	
	DROP TABLE IF EXISTS #AddSDV
	SELECT a.*, b.SDVClassification 
	INTO #AddSDV
	FROM #CombineDetails a
	LEFT JOIN #SDVFinal b ON 
		--a.EntryDateTime = b.EntryDateTime 
		a.DocIdentifier = b.DocIdentifier
		AND a.EventCategory = b.EventCategory

	DROP TABLE IF EXISTS #ODProvReview
	SELECT DISTINCT min(b.HealthFactorDateTime) OVER (PARTITION BY a.MVIPersonSID, a.VisitSID) AS ODReviewDate
		,a.DocIdentifier
		,a.EventCategory
		,CASE WHEN b.HealthFactorDateTime IS NOT NULL THEN 1 ELSE 0 END AS ODProvReview
		,a.HealthFactorDateTime
		,a.MVIPersonSID
	INTO #ODProvReview
	FROM #AddSDV a
	LEFT JOIN (SELECT * FROM OMHSP_Standard.HealthFactorSuicPrev WITH (NOLOCK) WHERE List LIKE 'SBOR_ODRisk%') b 
		ON a.MVIPersonSID=b.MVIPersonSID AND b.HealthFactorDateTime>=a.HealthFactorDateTime
	WHERE a.EventCategory='SBOR'
	AND (a.MethodType1='Overdose' OR a.MethodType2='Overdose' OR a.MethodType3='Overdose')


	DROP TABLE IF EXISTS #SBORCSRECombined
	SELECT MAX(a.MVIPersonSID) AS MVIPersonSID
		  ,MAX(a.Sta3n) AS Sta3n
		  ,MAX(a.ChecklistID) AS ChecklistID
		  ,a.VisitSID
		  ,a.DocFormActivitySID
		  ,MAX(a.EntryDateTime) AS EntryDateTime
		  ,MAX(a.HealthFactorDateTime) AS HealthFactorDateTime
		  ,a.EventCategory
		  ,MAX(a.TIUDocumentDefinition) AS TIUDocumentDefinition
		  ,MAX(a.EventDate) AS EventDate
		  ,MAX(a.EventDateFormatted) AS EventDateFormatted
		  ,MAX(a.Year) AS Year
		  ,MAX(a.EventType) AS EventType
		  ,MAX(a.Setting) AS Setting
		  ,MAX(a.SettingComments) AS SettingComments
		  ,MAX(a.SDVClassification) AS SDVClassification
		  ,MAX(a.VAProperty) AS VAProperty
		  ,MAX(a.SevenDaysDx) AS SevenDaysDx
		  ,MAX(a.Preparatory) AS Preparatory
		  ,MAX(a.Interrupted) AS Interrupted
		  ,MAX(a.InterruptedComments) AS InterruptedComments
		  ,MAX(a.Injury) AS Injury
		  ,MAX(a.InjuryComments) AS InjuryComments
		  ,MAX(a.Outcome1) AS Outcome1
		  ,MAX(a.Outcome1Comments) AS Outcome1Comments
		  ,MAX(a.Outcome2) AS Outcome2
		  ,MAX(a.Outcome2Comments) AS Outcome2Comments
		  ,MAX(a.MethodType1) AS MethodType1
		  ,MAX(a.Method1) AS Method1
		  ,MAX(a.MethodComments1) AS MethodComments1
		  ,MAX(a.MethodType2) AS MethodType2
		  ,MAX(a.Method2) AS Method2 
		  ,MAX(a.MethodComments2) AS MethodComments2
		  ,MAX(a.MethodType3) AS MethodType3
		  ,MAX(a.Method3) AS Method3
		  ,MAX(a.MethodComments3) AS MethodComments3
		  ,MAX(a.AdditionalMethodsReported) AS AdditionalMethodsReported
		  ,MAX(b.ODProvReview) AS ODProvReview
		  ,MAX(b.ODReviewDate) AS ODReviewDatePoss
		  ,a.DocIdentifier
	INTO #SBORCSRECombined
	FROM #AddSDV a
	LEFT JOIN #ODProvReview b ON a.DocIdentifier=b.DocIdentifier and a.EventCategory=b.EventCategory
	GROUP BY a.DocIdentifier, a.EventCategory, a.VisitSID, a.DocFormActivitySID

	DROP TABLE IF EXISTS #AdjustReviewDates
	SELECT a.* 
		,CASE WHEN DATEDIFF(day,CAST(a.EntryDateTime AS date),CAST(a.ODReviewDatePoss as date))<0 
				AND t.VisitSID IS NOT NULL THEN a.EntryDateTime-- If healthfactor time for provider section is before SBOR entry date, but they share a visitsid, use the entrydate of the SBOR
			WHEN DATEDIFF(day,CAST(a.EntryDateTime AS date),CAST(a.ODReviewDatePoss as date))>=0  THEN ODReviewDatePoss --If healthfactor time for provider section is after SBOR entry date, use healthfactor time
			WHEN ODProvReview=1 THEN a.EntryDateTime
			ELSE NULL END AS ODReviewDate
	INTO #AdjustReviewDates
	FROM #SBORCSRECombined a
	LEFT JOIN [TIU].[TIUDocument] t WITH (NOLOCK)  
		ON t.EntryDateTime>a.EntryDateTime AND a.VisitSID=t.VisitSID AND t.DeletionDateTime IS NULL AND t.EntryDateTime >= @BeginDate

	DROP TABLE IF EXISTS #EventDetailsCombined
	DROP TABLE IF EXISTS #FormattedDateFinal
	DROP TABLE IF EXISTS #DistinctNotes
	DROP TABLE IF EXISTS #GroupDetails
	DROP TABLE IF EXISTS #SDVFinal
	DROP TABLE IF EXISTS #AddSDV
	DROP TABLE IF EXISTS #CombineDetails
	DROP TABLE IF EXISTS #ODProvReview
	DROP TABLE IF EXISTS #SBORCSRECombined

	--Step 6: Drop duplicates
	--If more than one event is reported with the same event DATE, event type, SDV classification, setting, and outcome, drop everything but the most recently reported.  
	--This also filters out cases where an SBOR and a CSRE were documented in the same VisitSID but a suicide event was not reported in the CSRE
	--DROP TABLE IF EXISTS #DropDuplicates
	--SELECT * 
	--INTO #DropDuplicates
	--FROM (
	--	SELECT *
	--		,row_number() over (PARTITION BY MVIPersonSID, EventType, SDVClassification, Outcome1, MethodType1, EventDateFormatted 
	--			ORDER BY cast(EntryDateTime AS DATE) DESC
	--			,CASE WHEN EventCategory = 'SBOR' THEN 1 
	--			WHEN EventCategory LIKE 'CSRE%' THEN 2 END) AS RN1
	--	FROM #AdjustReviewDates
	--	) a
	--WHERE RN1=1
	;

	--Step 7: Create final table
	DROP TABLE IF EXISTS #SBOREventFinal
	SELECT DISTINCT MVIPersonSID
		  ,Sta3n
		  ,ChecklistID
		  ,VisitSID
		  ,DocFormActivitySID
		  ,IsNull(EntryDateTime, HealthFactorDateTime) AS EntryDateTime
		  ,HealthFactorDateTime
		  ,TIUDocumentDefinition
		  ,EventCategory
		  ,EventDate
		  ,EventDateFormatted
		  ,Year
		  ,EventType
		  ,Setting
		  ,SettingComments
		  ,SDVClassification
		  ,VAProperty
		  ,SevenDaysDx
		  ,Preparatory
		  ,Interrupted
		  ,InterruptedComments
		  ,Injury
		  ,InjuryComments
		  ,Outcome1
		  ,Outcome1Comments
		  ,Outcome2
		  ,Outcome2Comments
		  ,MethodType1
		  ,Method1
		  ,MethodComments1
		  ,MethodType2
		  ,Method2
		  ,MethodComments2
		  ,MethodType3
		  ,Method3
		  ,MethodComments3
		  ,AdditionalMethodsReported
		  ,ODProvReview
		  ,ODReviewDate
		  ,DATEDIFF(day,CAST(EntryDateTime AS date),CAST(ODReviewDate as date)) AS DaysBetween
	INTO #SBOREventFinal
	FROM #AdjustReviewDates ;

	DROP TABLE IF EXISTS #AdjustReviewDates
	   	 
	--	DECLARE @InitialBuild BIT = 0, @BeginDate DATE = DATEADD(Day,-365,CAST(GETDATE() AS DATE))
	IF @InitialBuild = 1 
	BEGIN
		EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.SBOR','#SBOREventFinal'
	END
	ELSE
	BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DELETE [OMHSP_Standard].[SBOR] WITH (TABLOCK)
			WHERE HealthFactorDateTime >= @BeginDate
			INSERT INTO [OMHSP_Standard].[SBOR] WITH (TABLOCK) (
				MVIPersonSID,Sta3n,ChecklistID,VisitSID,DocFormActivitySID,EntryDateTime,HealthFactorDateTime,TIUDocumentDefinition,EventCategory
			,EventDate,EventDateFormatted,Year,EventType,Setting,SettingComments,SDVClassification,VAProperty,SevenDaysDx,Preparatory,Interrupted
			,InterruptedComments,Injury,InjuryComments,Outcome1,Outcome1Comments,Outcome2,Outcome2Comments,MethodType1,Method1,MethodComments1
			,MethodType2,Method2,MethodComments2,MethodType3,Method3,MethodComments3,AdditionalMethodsReported,ODProvReview,ODReviewDate,DaysBetween
				)
			SELECT MVIPersonSID,Sta3n,ChecklistID,VisitSID,DocFormActivitySID,EntryDateTime,HealthFactorDateTime,TIUDocumentDefinition,EventCategory
			,EventDate,EventDateFormatted,Year,EventType,Setting,SettingComments,SDVClassification,VAProperty,SevenDaysDx,Preparatory,Interrupted
			,InterruptedComments,Injury,InjuryComments,Outcome1,Outcome1Comments,Outcome2,Outcome2Comments,MethodType1,Method1,MethodComments1
			,MethodType2,Method2,MethodComments2,MethodType3,Method3,MethodComments3,AdditionalMethodsReported,ODProvReview,ODReviewDate,DaysBetween
			FROM #SBOREventFinal 
	
			DECLARE @AppendRowCount INT = (SELECT COUNT(*) FROM #SBOREventFinal)
			EXEC [Log].[PublishTable] 'OMHSP_Standard','SBOR','#SBOREventFinal','Append',@AppendRowCount
		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error publishing to SBOR; transaction rolled back';
			DECLARE @ErrorMsg VARCHAR(1000) = ERROR_MESSAGE()
		EXEC [Log].[ExecutionEnd] 'Error' -- Log end of SP
		;THROW 	
	END CATCH

	END;

	DROP TABLE IF EXISTS #SBOREventFinal

	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END