
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <12/07/2018>
-- Description:	Dataset pulls patient healthfactors and TIU that are suicide related-- used in CRISTAL
-- Updates
--	2019-01-15 - LM - Modified code to point to Present.HealthFactors_SR table for faster performance; added NOLOCK
--	2019-01-15 - Jason Bacani - Formatting; Used [App].[PDW_DWS_PatientSIDToMVISID] as implemented across all MBC SPs
--	2019-01-17 - LM - Added MHA items from Present.MentalHealthAssistant
--  2019-01-30 - LM - Added 'Safety Plan Lethal Means' category
--  2019-11-05 - LM - Changed reference to OMHSP_Standard.MentalHealthAssistant instead of Present.MentalHealthAssistant
--	2019-11-25 - LM - Added Community Status Note
--	2020-01-06 - RAS - Added code to exclude safety plan declines from #PatientTIU
--	2020-06-17 - LM - Added AUDIT-C score
--  2020-09-22 - LM - Changed initial query to use MasterPatient instead of StationAssignments.
--	2021-05-27 - LM - Updated reference to MentalHealthAssistant_v02
--	2022-08-23 - CW	- Updated final query to expose HFs/DTAs with NULL ChecklistID
--	2022-09-12 - LM - Removed CSRE health factors from this stored proc
--	2023-08-22 - LM - Added COWS, CIWA, PHQ9, and MST screen
--	2024-02-08 - LM - Moved MHA items and MST screen to separate procedure; added IPV screen; Removed Community Status Note
--
-- EXEC [App].[MBC_HealthFactors_TIU_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1001092794'
-- EXEC [App].[MBC_HealthFactors_TIU_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1009833981'
-- =============================================
CREATE PROCEDURE [App].[MBC_HealthFactors_TIU_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1005591999'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1013673699'

	
	--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

--Step 2: Find most recent suicide prevention health factors for the patient
	DROP TABLE IF EXISTS #SuicideHealthFactors;
	SELECT
		pat.PatientICN
		,h.ChecklistID
		,h.Comments
		,h.Category
		,h.List
		,h.Printname
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,TIUDocumentDefinition=CAST(NULL AS varchar)
		,Description='SP'
		,c.Facility
		,c.Code
	INTO #SuicideHealthFactors
	FROM #Patient AS pat
	INNER JOIN [OMHSP_Standard].[HealthFactorSuicPrev] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID
	LEFT JOIN [LookUp].[StationColors] AS c WITH (NOLOCK) ON h.ChecklistID = c.ChecklistID --left join to expose HFs/DTAs with NULL ChecklistID 
	WHERE h.OrderDesc=1--get only one (most recent) of each h.printname
	AND (h.Category IN ('Safety Plan', 'Safety Plan Decline', 'Safety Plan Lethal Means')
		OR h.List LIKE 'Naloxone_Rx%' OR List LIKE 'CSRE_LethalMeans%')
	;
	
	--Step 3: Find Most Recent TIU Safety Plan for the patient
	DROP TABLE IF EXISTS #PatientTIU;
	SELECT TOP (1) 
		pat.PatientICN
		,sp.ChecklistID
		,Comments=CAST(NULL AS varchar)
		,Category='Safety Plan'
		,sp.List AS List 
		,Printname='Suicide Prevention Safety Plan'
		,CAST(sp.SafetyPlanDateTime AS DATE) AS SurveyDate
		,sp.TIUDocumentDefinition 
		,Description='SafetyPlan'
		,c.Facility
		,c.Code
	INTO #PatientTIU
	FROM #Patient AS pat
	INNER JOIN [OMHSP_Standard].[SafetyPlan] AS sp WITH (NOLOCK) 
		ON pat.MVIPersonSID = sp.MVIPersonSID
	LEFT JOIN [LookUp].[StationColors] AS c WITH (NOLOCK) ON sp.ChecklistID = c.ChecklistID --left join to expose HFs/DTAs with NULL ChecklistID 
	WHERE sp.SafetyPlanDateTime >= '2016-01-01' 
		AND SP_RefusedSafetyPlanning_HF=0
	ORDER BY sp.SafetyPlanDateTime DESC
	;
	
	--Step 4: Get health factors for homeless and food insecurity screenings	
	DROP TABLE IF EXISTS #SocialDeterminantsHealthFactors;
	SELECT
		pat.PatientICN
		,h.ChecklistID
		,h.Comments
		,Category = 'Homeless Screening'
		,h.List
		,h.Printname
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN s.Score=0 THEN 'Negative'
			WHEN s.Score=1 THEN 'Positive'
			ELSE 'Not Performed' END AS TIUDocumentDefinition
		,Description = 'SDH'
	INTO #SocialDeterminantsHealthFactors
	FROM #Patient AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID AND  h.Category IN ('Homeless Screen')--limited to most recent screen
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime AND h.Category=s.Category
	UNION ALL
	SELECT
		pat.PatientICN
		,h.ChecklistID
		,h.Comments
		,Category =  'Food Insecurity Screening'
		,h.List
		,h.Printname
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN s.Score=0 THEN 'Negative'
			WHEN s.Score=1 THEN 'Positive'
			ELSE 'Not Performed' END AS TIUDocumentDefinition
		,Description = 'SDH'
	FROM #Patient AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID AND h.Category ='Food Insecurity Screen'--limited to most recent screen
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime AND h.Category=s.Category
	UNION ALL
	SELECT
		pat.PatientICN
		,h.ChecklistID
		,h.Comments
		,Category = 'Social Risk Sreening (ACORN)'
		,h.List
		,h.Printname
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,TIUDocumentDefinition=NULL
		,Description = 'SDH'
	FROM #Patient AS pat
	INNER JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID --inner join - only display if this is done as opposed to 
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime AND h.Category=s.Category
	WHERE h.Category IN ('ACORN')
	UNION ALL
	SELECT
		pat.PatientICN
		,h.ChecklistID
		,h.Comments
		,Category = 'Relationship Health & Safety Screening'
		,h.List
		,h.Printname
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN i.ScreeningScore>=6 THEN 'Positive'
			WHEN i.ViolenceIncreased=1 OR i.Choked=1 OR i.BelievesMayBeKilled=1 THEN 'Positive'
			WHEN i.ScreeningScore<6 THEN 'Negative'
			ELSE 'Not Performed'
			END AS TIUDocumentDefinition
		,Description = 'SDH'
	FROM #Patient AS pat
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID  AND h.Category='IPV' --limited to most recent screen
	LEFT JOIN [SDH].[IPV_Screen] AS i WITH (NOLOCK) ON h.MVIPersonSID = i.MVIPersonSID AND h.HealthFactorDateTime = i.ScreenDateTime
	;
	--Step 5: Union temp tables created above
	SELECT 
		PatientICN
		,Facility
		,Comments
		,Category
		,List
		,Printname
		,SurveyDate
		,TIUDocumentDefinition
		,Description
		,Code
	FROM #SuicideHealthFactors s
	UNION ALL
	SELECT 
		PatientICN
		,Facility
		,Comments
		,Category
		,List
		,Printname
		,SurveyDate
		,TIUDocumentDefinition 
		,Description
		,Code
	FROM #PatientTIU s
	UNION ALL
	SELECT 
		PatientICN
		,Facility
		,Comments
		,Category
		,List
		,Printname
		,SurveyDate
		,TIUDocumentDefinition
		,Description
		,c.Code
	FROM #SocialDeterminantsHealthFactors s
	LEFT JOIN [LookUp].[StationColors] AS c WITH (NOLOCK) ON s.ChecklistID = c.ChecklistID --left join to expose HFs/DTAs with NULL ChecklistID 
	;

END