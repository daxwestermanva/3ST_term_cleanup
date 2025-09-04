

-- =============================================
-- Author:  Pooja Sohoni
-- Create date: 2019-05-23
-- Description: STORM has a different set of relevant diagnoses than other dashboards; this pulls the required diagnoses
-- Modifications:
	--	2020-04-01	RAS	Changed diagnosis column name Psych_poss to Other_MH_STORM for corrected definition.
	--	2020-11-17	LM	Pointed to _VM tables
	--	2020-12-17	RAS	Changed StationAssignments reference to MasterPatient. Added aliases to select list, other formatting.
						-- Removed left join to ORM.Cohort because no columns were being used from this table.
						-- Removed DISTINCT from query.
	--  2023-03-07  CW  Added [SUDdx_poss] as category

-- EXEC [App].[ORM_Diagnosis_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000651761
-- EXEC [App].[ORM_Diagnosis_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653709
-- =============================================
CREATE PROCEDURE [App].[ORM_Diagnosis_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000649095
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000651761

--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
DROP TABLE IF EXISTS #Patient;
SELECT
	a.MVIPersonSID
	,a.PatientICN
INTO #Patient
FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
WHERE a.PatientICN =  @ICN
	and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
;

/*This is aligned with ORM.PatientDetails logic*/
SELECT  
	a.PrintName
	,a.DxCategory
	,CASE WHEN a.Category='Substance Use Disorder - Duplicate' THEN 'Substance Use Disorder' ELSE a.Category END AS Category
	,a.MVIPersonSID
	,pat.PatientICN
FROM (
	SELECT a.MVIPersonSID
		  ,b.PrintName
		  ,b.ColumnName as DxCategory
		  ,b.Category
	FROM (
		SELECT a.MVIPersonSID
			  ,a.[EH_AIDS]
			  ,a.[EH_CHRNPULM] 
			  ,a.[EH_COMDIAB] 
			  ,a.[EH_ELECTRLYTE]
			  ,a.[EH_HYPERTENS] 
			  ,a.[EH_LIVER] 
			  ,a.[EH_NMETTUMR] 
			  ,a.[EH_OTHNEURO] 
			  ,a.[EH_PARALYSIS] 
			  ,a.[EH_PEPTICULC] 
			  ,a.[EH_PERIVALV] 
			  ,a.[EH_RENAL] 
			  ,a.[EH_HEART] 
			  ,a.[EH_ARRHYTH]  
			  ,a.[EH_VALVDIS] 
			  ,a.[EH_PULMCIRC] 
			  ,a.[EH_HYPOTHY]   
			  ,a.[EH_RHEUMART] 
			  ,a.[EH_COAG] 
			  ,a.[EH_WEIGHTLS]  
			  ,a.[EH_DefANEMIA]
			  ,a.[SAE_Falls]
			  ,a.[SAE_OtherAccident]
			  ,a.[SAE_OtherDrug]
			  ,a.[SAE_Vehicle]
			  ,a.[SAE_Acet]
			  ,a.[SAE_sed]
			  ,a.[OUD]
			  ,a.[OpioidOverdose]
			  ,a.[SleepApnea]
			  ,a.[Osteoporosis]
			  ,a.[NicDx_Poss]
			  ,a.[EH_LYMPHOMA]
			  ,a.[Suicide]
			  ,a.[EH_OBESITY] 
			  ,a.[EH_BLANEMIA]
			  ,a.[PTSD]
			  ,a.[BIPOLAR]
			  ,a.[SedativeUseDisorder]
 			  ,a.[AUD_ORM]  
			  ,a.[AnySAE]
			  ,a.[Other_MH_STORM]
			  ,a.[SUD_NoOUD_NoAUD] 
			  ,a.[SUDdx_poss]
			  ,a.[MDD] 
			  ,a.[OtherSUD_RiskModel]
			  ,a.[CannabisUD_HallucUD]
			  ,a.[CocaineUD_AmphUD]
			  ,a.[EH_UNCDIAB] 			
			  ,a.[EH_METCANCR]
		FROM [ORM].[RiskScore] as a
		) AS p
	UNPIVOT (Flag FOR DxCategory IN 
			   (EH_AIDS
				,EH_CHRNPULM 
				,EH_COMDIAB 
				,EH_ELECTRLYTE
				,EH_HYPERTENS 
				,EH_LIVER 
				,EH_NMETTUMR 
				,EH_OTHNEURO 
				,EH_PARALYSIS 
				,EH_PEPTICULC 
				,EH_PERIVALV 
				,EH_RENAL 
				,EH_HEART 
				,EH_ARRHYTH  
				,EH_VALVDIS 
				,EH_PULMCIRC 
				,EH_HYPOTHY   
				,EH_RHEUMART 
				,EH_COAG 
				,EH_WEIGHTLS  
				,EH_DefANEMIA
				,SAE_Falls
				,SAE_OtherAccident
				,SAE_OtherDrug
				,SAE_Vehicle
				,SAE_Acet
				,SAE_sed
				,OUD
				,OpioidOverdose
				,SleepApnea
				,Osteoporosis
				,NicDx_Poss
				,EH_LYMPHOMA
				,Suicide
				,EH_OBESITY 
				,EH_BLANEMIA
				,PTSD
				,BIPOLAR
				,SedativeUseDisorder
 				,AUD_ORM 
				,AnySAE 
				,Other_MH_STORM 
				,SUD_NoOUD_NoAUD 
				,SUDdx_poss
				,MDD
				,OtherSUD_RiskModel
				,CannabisUD_HallucUD 
				,CocaineUD_AmphUD 
				,EH_UNCDIAB 	
				,EH_METCANCR 
				)
			) as a 
	INNER JOIN (
		SELECT ColumnName,PrintName,Category
		FROM [LookUp].[ColumnDescriptions] 
		WHERE TableName = 'ICD10'
		) as b on a.DxCategory = b.ColumnName
	WHERE a.Flag > 0
	) as a
INNER JOIN #Patient pat on a.MVIPersonSID = pat.MVIPersonSID
 
END