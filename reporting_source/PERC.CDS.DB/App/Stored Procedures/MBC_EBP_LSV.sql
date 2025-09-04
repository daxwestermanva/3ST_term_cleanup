



-- =============================================
-- Author:		<Liam Mina>
-- Create date: <08/12/2022>
-- Description:	Pulls current and former enrollment in Evidence-Based Psychotherapies

-- EXEC [App].[MBC_EBP_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1046399445'
-- =============================================
CREATE PROCEDURE [App].[MBC_EBP_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1048691883'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1042755629'

	
--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT DISTINCT a.IntakeDate
		,ISNULL(a.TemplateGroup,'Suicide Prevention 2.0 Clinical Telehealth Program') AS TemplateGroup
		,a.FirstSessionDate
		,a.MostRecentSessionDate
		,a.DischargeDate
		,a.DischargeType
	FROM [Present].[SPTelehealth] a WITH (NOLOCK)
	INNER JOIN #Patient p 
		ON p.MVIPersonSID=a.MVIPersonSID
	UNION ALL
	SELECT DISTINCT 
		IntakeDate = CAST(NULL AS date)
		,CASE WHEN a.TemplateGroup = 'EBP_ACT_Template' THEN 'Acceptance and Commitment Therapy for Depression'
			WHEN a.TemplateGroup = 'EBP_BFT_Template' THEN 'Behavioral Family Therapy for Serious Mental Illness'
			WHEN a.TemplateGroup = 'EBP_CBSUD_Template' THEN 'Cognitive Behavioral Therapy for Substance Use Disorders'
			WHEN a.TemplateGroup = 'EBP_CBTD_Template' THEN 'Cognitive Behavioral Therapy for Depression'
			WHEN a.TemplateGroup = 'EBP_CBTI_Template' THEN 'Cognitive Behavioral Therapy for Insomnia'
			WHEN a.TemplateGroup = 'EBP_CM_Template' THEN 'Contingency Management for Substance Use Disorder'
			WHEN a.TemplateGroup = 'EBP_CPT_Template' THEN 'Cognitive Processing Therapy for PTSD'
			WHEN a.TemplateGroup = 'EBP_IBCT_Template' THEN 'Integrative Behavioral Couples Therapy'
			WHEN a.TemplateGroup = 'EBP_IPT_Template' THEN 'Interpersonal Therapy for Depression'
			WHEN a.TemplateGroup = 'EBP_PEI_Template' THEN 'Prolonged Exposure for PTSD'
			WHEN a.TemplateGroup = 'EBP_SST_Template' THEN 'Social Skills Training Program for SMI'
			ELSE a.TemplateGroup END AS TemplateGroup
		,MIN(a.VisitDateTime) AS FirstSessionDate
		,MAX(a.VisitDateTime) AS MostRecentSessionDate
		,DischargeDate=CAST(NULL AS date)
		,DischargeType=CAST(NULL AS varchar)
	FROM [EBP].[TemplateVisits] a WITH (NOLOCK)
	INNER JOIN #Patient p ON a.MVIPersonSID = p.MVIPersonSID
	WHERE a.DiagnosticGroup <> 'SuicidePrevention' OR a.DiagnosticGroup IS NULL
	GROUP BY a.MVIPersonSID, a.TemplateGroup

END