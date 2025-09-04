
-- =============================================
-- Author:		Liam Mina
-- Create date: 2021-11-04
-- Description: 

-- Modifications:
-- 
-- 10-17-23		CW		Adding in Detox rules
-- 10-18-23		VJ		Removed all group notes from IVDU as per SME feedback 9/26, 9/29
--						Removed sexual health inventory template from IVDU as per SME feedback 9/21
-- 12-05-23		VJ		Removed additional notes from IVDU as per KR feedback (12/4)
-- 01-04-24		CW/VJ	Removed additional notes from IVDU as per KR feedback (1/3)
-- 04-03-24		LM		Broke up initial query for faster run time
-- 01-06-25		LM		Added staff name and entrydate
-- 05-12-25		LM		Added initial data for 3ST concepts Capacity and Psychological Pain
-- 05-28-25     CW      Updated exclusionary criteria re: IDU concept
-- 06-11-25     CW      Added Xylazine to concepts. Updating Concept labels per SPP guidance.
-- 06-12-25		LM		Refresh only past 30 days nightly (rest of year is static) for efficiency
-- =======================================================================================================

--EXEC Code.Present_NLP_Variables @InitialBuild=1

CREATE PROCEDURE [Code].[Present_NLP_Variables]
	@InitialBuild BIT = 0
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.Present_NLP_Variables','Execution of SP Code.Present_NLP_Variables'	

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SBOR','Execution of Code.OMHSP_Standard_SBOR SP'

	--DECLARE @InitialBuild BIT = 0
	DECLARE @BeginDate DATE 

	IF (SELECT COUNT(*) FROM Present.NLP_Variables)=0 --if table is empty, populate with all data
	BEGIN SET @InitialBuild = 1
	END;

	IF @InitialBuild = 1 
	BEGIN
		SET @BeginDate = DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
	END
	ELSE 
	BEGIN
		SET @BeginDate = DATEADD(DAY,-30,CAST(GETDATE() AS DATE))
	END

--For 3ST concepts, limit on subclass and TIU Standard Title
DROP TABLE IF EXISTS #Subclass 
SELECT Instance_ID, Class, SUBCLASS, Preferred_Label, SUBCLASS_GROUPING
INTO #Subclass
FROM Config.NLP_3ST_subclass_labels WITH (NOLOCK)
WHERE Polarity='indicates_presence'
AND (Class='Psychological Pain' AND Subclass IN ('Pain exceeds tolerance','Housing issues','Sleep issues','Financial issues','Legal issues')
	OR (Class='Capacity for Suicide'))

DROP TABLE IF EXISTS #TIU
SELECT s.TIUStandardTitle
	,s.TIUStandardTitleSID
	,c.TIUDocumentDefinition
	,c.TIUDocumentDefinitionSID
	,CASE WHEN t.TIUStandardTitle IS NOT NULL --StandardTitle inclusions for 3ST
		AND TIUDocumentDefinition NOT IN ('MH TMS NURSE NOTE') --DocumentDefinition exclusions for 3ST
		THEN 1 ELSE 0 END AS TIU_3ST
INTO #TIU
FROM Dim.TIUStandardTitle s WITH (NOLOCK)
INNER JOIN Dim.TIUDocumentDefinition c WITH (NOLOCK)
	ON s.TIUStandardTitleSID = c.TIUStandardTitleSID
LEFT JOIN Config.NLP_3ST_TIUStandardTitle t WITH (NOLOCK)
	ON t.TIUStandardTitle=s.TIUStandardTitle


--Pull in concepts of interest for CDS projects
DROP TABLE IF EXISTS #GetConcepts
SELECT d.MVIPersonSID
	,a.TargetClass
	,CASE WHEN s.PREFERRED_LABEL IS NOT NULL THEN s.PREFERRED_LABEL
		ELSE a.TargetSubClass
		END AS SubclassLabel
	,a.Term
	,a.ReferenceDateTime
	,a.TIUStandardTitle
	,a.TIUDocumentSID
	,a.NoteAndSnipOffset
	,TRIM(REPLACE(a.Snippet,'SNIPPET:','')) AS Snippet
	,CASE WHEN a.TargetClass IN ('PPAIN','CAPACITY','JOBINSTABLE','JUSTICE','SLEEP','FOODINSECURE','DEBT','HOUSING') 
		THEN '3ST' ELSE NULL END AS Category
INTO #GetConcepts
FROM [PDW].[HDAP_NLP_OMHSP] a WITH (NOLOCK)
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID d WITH (NOLOCK)
	ON a.PatientSID = d.PatientPersonSID
INNER JOIN Common.MasterPatient mvi WITH (NOLOCK)
	ON d.MVIPersonSID=mvi.MVIPersonSID
LEFT JOIN #Subclass s
	ON TRY_CAST(a.TargetSubClass AS INT)=s.INSTANCE_ID
WHERE mvi.DateOfDeath_Combined IS NULL
AND a.Label = 'POSITIVE'
AND ((a.TargetClass IN ('PPAIN','CAPACITY') AND s.INSTANCE_ID IS NOT NULL)-- AND t.TIUStandardTitleSID IS NOT NULL)
	OR (a.TargetClass IN ('XYLA') AND (a.TargetSubClass='SUS' OR a.TargetSubClass='SUS-P')) --only suspected IDU and suspected xylazine, not other types of mentions e.g., education
	OR a.TargetClass IN ('LIVESALONE','LONELINESS','DETOX','IDU'
						,'CAPACITY' --Capacity (3ST)
						,'JOBINSTABLE','JUSTICE','SLEEP','FOODINSECURE','DEBT','HOUSING' --PPAIN (3ST)
						)
					)
AND CAST(a.ReferenceDateTime AS date) >= @BeginDate

DROP TABLE IF EXISTS #Subclass

DROP TABLE IF EXISTS #IdentifyTemplates
SELECT Snippet
	,TargetClass
	,COUNT(DISTINCT MVIPersonSID) AS PatientCount
	,COUNT(DISTINCT TIUDocumentSID) AS DocumentCount
INTO #IdentifyTemplates
FROM #GetConcepts
GROUP BY Snippet, TargetClass

--Remove notes that are likely templates - exact snippet documented >=10 times on >=10 patients
DELETE FROM #GetConcepts
WHERE Snippet IN (SELECT Snippet FROM #IdentifyTemplates WHERE PatientCount>=10 AND DocumentCount>=10)

DROP TABLE IF EXISTS #IdentifyTemplates

--Additional deletions identifying irrelevant snippets
DELETE FROM #GetConcepts 
--3ST Concepts
WHERE (Category='3ST'
		AND (Term IN ('armed', 'blade', 'razor', 'ice', 'molly', 'drinks', 'drank', 'coc', 'cutting', 'snap', 'spice', 'busted','mushrooms','one puff','tripping'
						,'mad','use alcohol','knife','in his car','in her car','in their car','coke','bleach','hanging','sentence','wires','cut his','rope','blunt') --1418020
			OR Snippet LIKE CONCAT('%denies ',Term,'%')
			OR Snippet LIKE CONCAT('%no ',Term,'%') 
			OR Snippet LIKE CONCAT('%without ',Term,'%')
			OR Snippet LIKE CONCAT('%avoid ',Term,'%')
			OR (Term='irritable' AND Snippet LIKE '%bowel%')
			OR (Term='with a plan' AND (Snippet NOT LIKE '%suicid%' AND Snippet NOT LIKE '% si%'))--8864
			OR (TargetClass='PPAIN' AND Snippet LIKE '%NALOXONE HCL 4MG/SPRAY SOLN NASAL SPRAY%')
			OR (TargetClass='CAPACITY' AND Snippet LIKE '%Indication: FOR OPIOID overdose%')
			OR ((Snippet LIKE '% 988%' OR Snippet LIKE '%1-800-273%') AND SubclassLabel='Pain exceeds tolerance' AND Term IN ('feeling suicidal', 'feel suicidal', 'feel like hurting himself'))
			OR (Snippet LIKE '%www.%' AND Term='loneliness') --LM - not sure this one is worth it - only 63 rows 
			OR (Snippet LIKE '%www.%' AND Snippet LIKE  '%911%') 
			OR (Snippet LIKE '%Veteran was reminded to contact the Mental Health Clinic%' AND SubclassLabel='Acquired capacity for suicide' AND Term='thoughts of self-harm') 
			OR (Snippet LIKE '%Motivational Interviewing (MI)%' AND SubclassLabel='Situational capacity for suicide' AND Term='substance use') 
			OR (Snippet LIKE '% 988%' AND Term='illicit substances')
		))
--Detox Concepts
OR (TargetClass='DETOX' AND
 ((TERM IN ('detoxification') AND TIUstandardTitle IN ('ACUPUNCTURE NOTE'))
 OR (TERM IN ('saws') AND TIUstandardTitle IN ('NURSING PROCEDURE NOTE','SURGERY NOTE','SURGERY NURSING NOTE','SURGERY RN NOTE'))
 OR (TERM IN ('sews') AND TIUstandardTitle IN ('CONSENT'))
 OR TERM IN ('Minds')
 ))

--Add TIU joins
DROP TABLE IF EXISTS #AddTIU
SELECT a.MVIPersonSID
	,e.StaPa AS ChecklistID
	,a.TargetClass
	,a.SubclassLabel
	,a.Term
	,a.ReferenceDateTime
	,b.EntryDateTime
	,a.TIUStandardTitle
	,c.TIUDocumentDefinition
	,a.TIUDocumentSID
	,a.NoteAndSnipOffset
	,a.Snippet
	,s.StaffName
INTO #AddTIU
FROM #GetConcepts a WITH (NOLOCK)
INNER JOIN TIU.TIUDocument b WITH (NOLOCK)
	ON a.TIUDocumentSID=b.TIUDocumentSID
INNER JOIN #TIU c WITH (NOLOCK)
	ON b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
INNER JOIN Dim.Institution e WITH (NOLOCK)
	ON b.InstitutionSID = e.InstitutionSID
LEFT JOIN SStaff.SStaff s WITH (NOLOCK)
	ON b.SignedByStaffSID=s.StaffSID
WHERE ((a.Category='3ST' AND SubclassLabel IS NOT NULL AND c.TIU_3ST = 1)
	OR a.TargetClass IN ('LIVESALONE','LONELINESS','IDU','DETOX', 'XYLA'))


--Additional exclusions based on TIU
DELETE FROM #AddTIU
WHERE (
--IVDU Concepts
(TargetClass='IDU' AND 
	(TIUstandardTitle = 'Gastroenterology Nursing Note'
		OR TIUstandardTitle like '%ACCOUNT%DISCLOSURE%'
		OR TIUstandardTitle like '%GROUP%NOTE%'
		OR TIUDocumentDefinition IN ('CCC: CLINICAL TRIAGE','EDUCATION NOTE','EMERGENCY DEPARTMENT DISCHARGE INSTRUCTIONS','SUICIDE PREVENTION LETTER','PATIENT LETTER (AUTO-MAIL)','STORM DATA-BASED OPIOID RISK REVIEW','CARDIOLOGY DEVICE IMPLANTATION REPORT')
		OR TIUDocumentDefinition LIKE 'VISN 4 RN%' 
		OR TIUDocumentDefinition LIKE 'OAKLAND CLINIC%'
		OR (Snippet like '%ssp%' AND NOT (Snippet like '%needle%' OR Snippet LIKE '%syringe%'))
		OR Snippet like '%(-) IVDU%'
		OR Snippet like '%(MSM, ivdu, liver dz, travel):%'
	))
--Detox Concepts
OR (TargetClass='DETOX' AND 
	(TIUDocumentDefinition IN ('ACUITY SCALE')
		OR TIUDocumentDefinition LIKE '%discharge instruction%'
		OR TIUDocumentDefinition LIKE '%acupuncture%'
	))
--Xylazine Concepts
OR (TargetClass='XYLA' AND 
	(Snippet LIKE '%provided%education%provided%'
	))
)

DROP TABLE IF EXISTS #TIU

DROP TABLE IF EXISTS #GetConcepts

DROP TABLE IF EXISTS #OneRecordPerNote
SELECT TOP 1 WITH TIES MVIPersonSID
	,ChecklistID
	,TargetClass
	,SubclassLabel
	,Term
	,EntryDateTime
	,ReferenceDateTime
	,TIUDocumentDefinition
	,Snippet
	,StaffName
INTO #OneRecordPerNote
FROM #AddTIU
ORDER BY ROW_NUMBER() OVER (PARTITION BY TIUDocumentSID, TargetClass ORDER BY NoteAndSnipOffset)


DROP TABLE IF EXISTS #StageVariables
SELECT MVIPersonSID
	,ChecklistID
	,CASE WHEN TargetClass = 'LIVESALONE'	THEN 'Lives Alone'
		WHEN TargetClass='CAPACITY' THEN 'Capacity for Suicide'
		WHEN TargetClass='PPAIN' THEN 'Psychological Pain'
		ELSE TargetClass 
		END AS Concept
	,SubclassLabel= CASE
		WHEN SubclassLabel='Acquired capacity for suicide' OR Subclasslabel = 'practical' THEN 'Repeated Exposure to Painful/Provocative Events'
		WHEN SubclassLabel='Dispositional capacity for suicide' OR SubclassLabel='dispositional' THEN 'Genetic/Temperamental Risk Factors'
		WHEN SubclassLabel='Situational capacity for suicide' OR Subclasslabel = 'situational' THEN 'Acute/Situational Risk Factors'
		WHEN SubclassLabel='Practical capacity for suicide' OR Subclasslabel= 'acquired' THEN 'Access to Lethal Means'
		WHEN TargetClass='CAPACITY' THEN NULL
		WHEN TargetClass='Sleep' THEN 'Sleep issues'
		WHEN TargetClass='Debt' THEN 'Financial issues'
		WHEN TargetClass='Justice' THEN 'Legal issues'
		WHEN TargetClass='FoodInsecure' THEN 'Food insecurity'
		WHEN TargetClass='Housing' THEN 'Housing issues'
		WHEN TargetClass='JobInstable' THEN 'Job instability'
		WHEN TargetClass='Loneliness' THEN 'Loneliness'
		WHEN TargetClass='LivesAlone' THEN 'Lives Alone'
		WHEN TargetClass='XYLA' THEN 'Suspected Xylazine Exposure'
		WHEN TargetClass='IDU' THEN 'Suspected Injection Drug Use'
		ELSE SubclassLabel
	END	
	,Term
	,EntryDateTime
	,ReferenceDateTime
	,TIUDocumentDefinition
	,StaffName
	,REPLACE(Snippet,Term,Term) AS Snippet --do this to allow for proper formatting in report when term may not be all lowercase within the snippet
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, TargetClass, SubclassLabel ORDER BY ReferenceDateTime DESC, EntryDateTime DESC) AS CountDesc
INTO #StageVariables
FROM #OneRecordPerNote 

DELETE FROM #StageVariables WHERE Concept='CAPACITY FOR SUICIDE' AND SubclassLabel IS NULL

DROP TABLE IF EXISTS #OneRecordPerNote

--	DECLARE @InitialBuild BIT = 0, @BeginDate DATE = DATEADD(Day,-366,CAST(GETDATE() AS DATE))
	IF @InitialBuild = 1 
	BEGIN
		EXEC [Maintenance].[PublishTable] 'Present.NLP_Variables','#StageVariables'
	END
	ELSE
	BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DELETE [Present].[NLP_Variables] WITH (TABLOCK)
			WHERE ReferenceDateTime >= @BeginDate OR ReferenceDateTime <= DATEADD(DAY,-366,CAST(GETDATE() AS DATE))
			INSERT INTO [Present].[NLP_Variables] WITH (TABLOCK) (
				[MVIPersonSID],[ChecklistID],[Concept],[SubclassLabel],[Term],[EntryDateTime],[ReferenceDateTime],[TIUDocumentDefinition],[StaffName],[Snippet],[CountDesc]
				)
			SELECT [MVIPersonSID],[ChecklistID],[Concept],[SubclassLabel],[Term],[EntryDateTime],[ReferenceDateTime],[TIUDocumentDefinition],[StaffName],[Snippet],[CountDesc]
			FROM #StageVariables 
	
			DECLARE @AppendRowCount INT = (SELECT COUNT(*) FROM #StageVariables)
			EXEC [Log].[PublishTable] 'Present','NLP_Variables','#StageVariables','Append',@AppendRowCount
		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error publishing to Present.NLP_Variables; transaction rolled back';
			DECLARE @ErrorMsg VARCHAR(1000) = ERROR_MESSAGE()
		EXEC [Log].[ExecutionEnd] 'Error' -- Log end of SP
		;THROW 	
	END CATCH

	END;


DROP TABLE IF EXISTS #StageVariables

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END