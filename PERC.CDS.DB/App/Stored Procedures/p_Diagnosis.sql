-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	
-- Modifications:
	--	2020-05-01	RAS	Removed union with LookUp ICD10_Vertical. 
						--Made no sense and caused "CRISTAL" to appear in parameter list, which if chosen caused error.
	--  2021-06-28  PS  Reworked this to just use project type as the parameter
  --  2025-05-14  AER Adding ALEX definitions for RV2
-- =============================================
CREATE PROCEDURE [App].[p_Diagnosis]

	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT --Category,
	ColumnName,PrintName
FROM [LookUp].[ColumnDescriptions] a WITH (NOLOCK)
WHERE TableName = 'ICD10' 

UNION  

 
select distinct 
  case when InstanceVariable = 'DEPRESSION_OTHER'  then 'Depress' 
  when InstanceVariable = 'HALLUCINOGEN_USE_DISORDER' then 'CannabisUD_HallucUD' 
  when InstanceVariable = 'ALCOHOL_USE_DISORDER' then 'AUD' else CDS_Lookup end CDS_Lookup
	,COALESCE(d.PrintName,b.ALEX2_PrintName,a.PrintName) AS PrintName
FROM Config.REACH_ClinicalSignalsNightly as a  WITH (NOLOCK)
left outer join  LookUp.CDS_ALEX as c  WITH (NOLOCK) on replace(a.InstanceVariable,'_','') = c.SetTerm 
left outer join Library.XLA_XLA2_Metadata as b  WITH (NOLOCK) on c.SetTerm = b.ObjectTerm AND b.Vocabulary='Dx'
left outer join Lookup.ColumnDescriptions d  WITH (NOLOCK) ON c.CDS_Lookup=d.ColumnName AND d.TableName='ICD10'
where c.CDS_Lookup is not null OR InstanceVariable IN ('DEPRESSION_OTHER','HALLUCINOGEN_USE_DISORDER','ALCOHOL_USE_DISORDER')

UNION  
SELECT
	ColumnName='CRISTAL'
	,PrintName='CRISTAL'

UNION 
SELECT 
	ColumnName='STORM'
	,PrintName='STORM'

UNION 
SELECT 
	ColumnName='SuicideAttempt'
	,PrintName='Suicide Attempt'
 UNION 
SELECT 
	ColumnName='NonSuicideOverdose'
	,PrintName='Overdose'
   
    
UNION 

 select distinct a.SetTerm, b.ALEX2_PrintName
   from [XLA].[Lib_SetValues_RiskNightly] as a WITH (NOLOCK)
   inner join [Library].[XLA_XLA2_Metadata] as b  WITH (NOLOCK) on a.SetTerm = b.ObjectTerm
   left outer join  LookUp.CDS_ALEX as c  WITH (NOLOCK) on a.SetTerm = c.SetTerm
   where a.Vocabulary = 'icd10cm' and 
   a.setterm in (
    'Amputation','AnxietyGeneralized','EatingDisorder','IntentionalSelfHarmIdeation','MoodDisorderOther'
    ,'PainAbdominal','PainOther','PainSystemicDisorder','Parkinsons','PsychosocialProblemsNOS'
    ,'PsychoticDisorderOther','DrugUseDisorderOther','ExternalSelfHarm','IntentionalOverdosePoison'
	) 

UNION 
	select distinct s.SuperSet
		, ALEX2_PrintName=CASE WHEN SuperSet='EatingDisorder' THEN 'Eating Disorder'
								WHEN SuperSet='SAEAllDrug' THEN 'Severe Adverse Drug Event'
								END
	   from xla.Lib_SuperSets_ALEX s WITH (NOLOCK)
	   INNER JOIN [XLA].[Lib_SetValues_RiskNightly] as a WITH (NOLOCK)
		ON s.ALEXGUID=a.ALEXGUID
	   inner join [Library].[XLA_XLA2_Metadata] as b  WITH (NOLOCK) on a.SetTerm = b.ObjectTerm
	   left outer join  LookUp.CDS_ALEX as c  WITH (NOLOCK) on a.SetTerm = c.SetTerm
	   where a.Vocabulary = 'icd10cm' and 
		 superset IN ('EatingDisorder','SAEAllDrug')
ORDER BY PrintName

--select * from #test where columnname= 'DRUG_USE_DISORDER_OTHER'

END


--go 
--exec [dbo].[sp_SignAppObject] @ObjectName = 'p_Diagnosis' --Edit the name here to equal you procedure name above EXACTLY