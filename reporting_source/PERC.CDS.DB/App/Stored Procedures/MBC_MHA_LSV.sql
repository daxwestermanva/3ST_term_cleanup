

/* =============================================
-- Author:		<Liam Mina>
-- Create date: <02/08/2024>
-- Description:	Dataset pulls mental health screens-- used in CRISTAL
				Data was previously pulled from App.MBC_HealthFactors_TIU_LSV
				
-- Updates
--
-- EXEC [App].[MBC_MHA_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1001092794'
-- EXEC [App].[MBC_MHA_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1024359271'
 ============================================= */
CREATE PROCEDURE [App].[MBC_MHA_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1005591999'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1024359271'

	
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

	--Find most recent MHA items for the patient (PHQ-I9, C-SSRS)
	SELECT TOP (1) WITH TIES a.*, c.Facility
	FROM (SELECT
		pat.PatientICN
		,mh.ChecklistID
		,Comments=CASE WHEN RawScore IS NOT NULL THEN CONCAT(' (',CAST(RawScore AS varchar),')') ELSE NULL END
		,Category='MHA'
		,mh.SurveyName AS List
		,mh.DisplayScore AS Printname 
		,CAST(mh.SurveyGivenDatetime AS DATE) AS SurveyDate
		,TIUDocumentDefinition=
			CASE WHEN mh.Display_AUDC>-1 THEN 'AUDIT-C'
			WHEN mh.Display_CSSRS>-1 THEN 'C-SSRS'
			WHEN mh.display_I9>-1 THEN 'I9'
			WHEN mh.display_PHQ2>-1 THEN 'PHQ-2'
			WHEN mh.display_PHQ9>-1 THEN 'PHQ-9'
			WHEN mh.display_COWS>-1 THEN 'COWS'
			WHEN mh.display_CIWA>-1 THEN 'CIWA'
			WHEN mh.display_PTSD>-1 THEN 'PC-PTSD-5'
			END
		,Description = 
			CASE WHEN mh.Display_AUDC>-1 THEN 'Risky Drinking'
			WHEN mh.Display_CSSRS>-1 THEN 'Suicide Risk'
			WHEN mh.display_I9>-1 THEN 'Suicidal Ideation' 
			WHEN mh.display_PHQ2>-1 THEN 'Depression-Brief Screen'
			WHEN mh.display_PHQ9>-1 THEN 'Depression-Full Screen'
			WHEN mh.display_COWS>-1 THEN 'Opioid Withdrawal'
			WHEN mh.display_CIWA>-1 THEN 'Alcohol Withdrawal'
			WHEN mh.display_PTSD>-1 THEN 'PTSD'
			END
		,RawScore
		FROM #Patient AS pat
		INNER JOIN  [OMHSP_Standard].[MentalHealthAssistant_v02] AS mh WITH (NOLOCK) 
			ON pat.MVIPersonSID = mh.MVIPersonSID
		UNION ALL
		SELECT
			pat.PatientICN
			,h.ChecklistID
			,h.Comments
			,Category='MHA'
			,h.List
			,CASE WHEN s.Score=0 THEN 'Negative'
				WHEN s.Score=1 THEN 'Positive'
				ELSE NULL END AS Printname
			,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
			,TIUDocumentDefinition = 'MST Screen'
			,Description='Military Sexual Trauma'
			,s.Score
		FROM #Patient AS pat
		INNER JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) ON pat.MVIPersonSID = h.MVIPersonSID
		LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON h.MVIPersonSID=s.MVIPersonSID AND h.HealthFactorDateTime=s.ScreenDateTime
		WHERE h.Category='MST Screen' 
	) a 
	LEFT JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK) ON a.ChecklistID = c.ChecklistID --left join to expose HFs/DTAs with NULL ChecklistID 
	WHERE a.PrintName IS NOT NULL
	ORDER BY ROW_NUMBER() OVER (PARTITION BY TIUDocumentDefinition ORDER BY SurveyDate DESC, a.RawScore DESC)

	

END