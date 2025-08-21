

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <02-10-2022>
-- Description:	Dataset contains concepts and strings extracted from chart notes via NLP -- used in CRISTAL
-- Updates
--	2024-11-25	LM	Broaden query to top ten per patient/concept and include additional concepts for new NLP drill through report
--	2025-01-06	LM	Add note author and entry date
--	2025-05-21	LM	Add language for tooltips for 3ST concepts
--  2025-06-11  CW  Updating Concept labels per SPP guidance
--
-- EXEC [App].[MBC_NLP_LSV] @User = 'vha21\vhapalminal'	, @Patient = '1000686893'
-- =============================================
CREATE PROCEDURE [App].[MBC_NLP_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000),
	@Concept VARCHAR(5000),
	@Report VARCHAR (50)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1000686770'
	--DECLARE @User varchar(max)='vha21\vhapalminal', @Patient varchar(1000)='1016519937', @Concept VARCHAR(5000)='Financial Issues', @Report VARCHAR (50)='NLP'

	
	--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		a.MVIPersonSID,a.PatientICN
	INTO #Patient
	FROM [Common].[vwMVIPersonSIDPatientICN] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;
	--Step 2 - get list of concepts being queried
	DECLARE @ConceptList TABLE ([Concept] VARCHAR(max))
	INSERT @ConceptList  SELECT value FROM string_split(@Concept, ',')

	--Step 3 - pull NLP snippets
	DROP TABLE IF EXISTS #Snippets
	SELECT a.MVIPersonSID
		,b.PatientICN
		,CASE WHEN a.Concept IN ('LONELINESS','LIVES ALONE') THEN 'LONELINESS/LIVES ALONE' --same recommendations for these two concepts; use this to group so recs don't display twice
			ELSE ISNULL(a.SubclassLabel,a.Concept) END AS ConceptRecommendationGroup 
		,ISNULL(a.SubclassLabel,a.Concept) AS Concept
		,CASE WHEN a.SubclassLabel IS NOT NULL THEN a.Concept ELSE NULL END AS ConceptGroup
		,a.TIUDocumentDefinition
		,a.StaffName
		,a.EntryDateTime
		,a.ReferenceDateTime
		,a.Term
		,a.Snippet
		,CASE WHEN a.SubclassLabel='Repeated Exposure to Painful/Provocative Events' 
				THEN 'Reduced fear about death and an elevated tolerance of physical pain resulting from habituation to painful and/or provocative events (e.g., history of self-harm, combat exposure)'
			WHEN a.SubclassLabel='Genetic/Temperamental Risk Factors' 
				THEN 'Genetics, temperaments, and personality factors that may increase or decrease capability (e.g., impulsivity, family history of suicide)'
			WHEN a.SubclassLabel='Acute/Situational Risk Factors' 
				THEN 'Conditions that may create periods of elevated risk of suicide (e.g., substance use, psychosis)'
			WHEN a.SubclassLabel='Access to Lethal Means' 
				THEN 'Factors that increase knowledge of and access to lethal means (e.g., access to guns, previous suicide attempts)'
			--WHEN l.RELATIONSHIP='is_a_potential_cause' THEN CONCAT('May contribute to ',a.Concept)
			--WHEN l.RELATIONSHIP='is_an_expression' THEN CONCAT('May be an expression of ',a.Concept)
			--WHEN l.RELATIONSHIP='is_a_psychological_need' THEN CONCAT('May relate to an unmet psychological need causing ',a.Concept)
			--WHEN a.Concept IN ('Psychological Pain','Capacity for Suicide') THEN CONCAT('May indicate ',a.Concept)
			END AS ExplainerText
		,(MAX(a.CountDesc) OVER (PARTITION BY a.MVIPersonSID, a.Concept, a.SubclassLabel) - CASE WHEN @Report<>'CRISTAL' THEN 15 ELSE 3 END) AS AdditionalNotes
		,MAX(a.CountDesc) OVER (PARTITION BY a.MVIPersonSID, a.Concept, a.SubclassLabel) AS TotalNotes
		,a.CountDesc
		,c.Facility
		,c.Code
		,Recommendation1=NULL
		--,CASE WHEN a.Concept IN ('LONELINESS','LIVES ALONE') THEN 'Consider Referral to Compassionate Contact Corps' 
		--		ELSE NULL END AS Recommendation1
		,Recommendation2=NULL
			--,CASE WHEN a.Concept IN ('LONELINESS','LIVES ALONE') THEN 'Instruct Veteran to ask their VA Primary Care Provider or Social Worker for referral.' 
			--	ELSE NULL END AS Recommendation2
		,LinkText1=NULL
			--,CASE WHEN a.Concept IN ('LONELINESS','LIVES ALONE') THEN 'Info for Veterans' 
			--	ELSE NULL END AS LinkText1
		,LinkText2=NULL
			--,CASE WHEN a.Concept IN ('LONELINESS','LIVES ALONE') THEN 'Info for Providers' 
			--	ELSE NULL END AS LinkText2
	INTO #Snippets
	FROM [Present].[NLP_Variables] a WITH (NOLOCK)
	INNER JOIN #Patient b ON a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [Lookup].[StationColors] AS c WITH (NOLOCK) ON a.ChecklistID = c.ChecklistID
	LEFT JOIN Config.NLP_3ST_subclass_labels AS l WITH (NOLOCK) ON a.SubclassLabel=l.SUBCLASS
	INNER JOIN @ConceptList cl ON ISNULL(a.SubclassLabel,a.Concept)=cl.Concept

	SELECT *
	FROM #Snippets
	WHERE (CountDesc<=15 AND @Report<>'CRISTAL')
		OR (CountDesc<=3 AND @Report='CRISTAL') 
	
	;

END