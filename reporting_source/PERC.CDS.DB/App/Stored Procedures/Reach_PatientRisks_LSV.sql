-- =============================================
-- Author:		<Liam Mina>
-- Create date: <02/03/2025>
-- Description:	Data for REACH risk subreport
-- Modifications:
---2025.05.21 - AER  Updating CDS lookup name for join to diagnosis drill
-- =============================================
CREATE PROCEDURE [App].[Reach_PatientRisks_LSV]
 
    @User varchar(max),
	@Patient INT
 
AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
SET NOCOUNT ON;
 
 --DECLARE @user varchar(max)='vha21\vhapalminal', @patient int=5154530

--identifying the PatientICN to which the user has permission
DROP TABLE IF EXISTS #Patient;
SELECT pat.MVIPersonSID,pat.PatientICN
INTO  #Patient
FROM [Present].[StationAssignments] as pat  WITH (NOLOCK)
INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) as Access on pat.Sta3n_Loc = Access.Sta3n
WHERE pat.MVIPersonSID = @Patient
 
-- selecting data to display based on MVIPersonSID
DROP TABLE IF EXISTS #risks
SELECT TOP 1 WITH TIES a.MVIPersonSID
	,b.PrintName
	,b.DashboardCategory
	,v.Domain
	,CASE WHEN v.Suffix = 'PatOn' THEN 0
		WHEN v.Suffix = '0to90days' THEN 3
		WHEN v.Suffix='0to180days' THEN 6
		WHEN v.Suffix IN ('0to365days','91to365days','181to365days') THEN 12
		WHEN v.Suffix IN ('0to730days','366to730days') THEN 24
		ELSE 99 
		END AS Timeframe
	,v.InstanceVariable
	,CASE WHEN v.InstanceVariable IN ('BINGE_EATING_DISORDER','EATING_DISORDER_UNSPECIFIED','OTHER_SPECIFIED_EATING_DISORDERS') THEN 'EatingDisorder'
		WHEN v.InstanceVariable IN ('SAE_Acetaminophen','SAE_DRUG_OTHER','SAE_SEDATING_DRUGS') THEN 'SAEAllDrug'
		END AS SuperSet
	,CASE WHEN v.Variable LIKE '%_SAE_%' AND v.InstanceVariable NOT LIKE 'SAE_%' THEN 1 
		 WHEN v.Domain='MHA' AND m.MVIPersonSID IS NULL THEN 1 --don't display negative MHA results even if they contributed to the score due to confusion from the field
		 ELSE 0 END AS Ignore
	,replace(v.InstanceVariable,'_','') as SetTerm
	,b.DashboardColumn
	,b.DisplayWithoutHeader
INTO #risks
FROM REACH.ClinicalSignals_Nightly a WITH (NOLOCK)
INNER JOIN Config.Risk_Variable v WITH (NOLOCK) 
	ON a.VariableID=v.VariableID 
INNER JOIN Config.REACH_ClinicalSignalsNightly b WITH (NOLOCK) 
	ON v.InstanceVariable=b.InstanceVariable
INNER JOIN #Patient p 
	ON a.MVIPersonSID=p.MVIPersonSID --correct access to patient
LEFT JOIN OMHSP_Standard.MentalHealthAssistant_v02 m
	ON p.MVIPersonSID=m.MVIPersonSID 
	AND m.SurveyGivenDatetime BETWEEN DATEADD(day,try_cast(v.TimeframeStart as int),getdate()) AND DATEADD(day,try_cast(v.TimeframeEnd as int),getdate())
	AND ((m.display_AUDC>0 AND v.InstanceVariable='AUDIT-C') OR (m.display_I9>0 AND v.InstanceVariable='PHQ_Question9') OR (m.display_PHQ9>0 AND v.InstanceVariable='PHQ') 
		OR (m.display_COWS>0 AND v.InstanceVariable='COWS') OR (m.display_CIWA>0 AND v.InstanceVariable='CIWA'))
	AND m.DisplayScore LIKE 'Positive%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, b.PrintName, DashboardCategory ORDER BY CASE WHEN Domain='OMHSP Standard Event' THEN 0 ELSE 1 END
																,CASE WHEN v.Suffix = 'PatOn' THEN 0
																WHEN v.Suffix = '0to90days' THEN 3
																WHEN v.Suffix='0to180days' THEN 6
																WHEN v.Suffix IN ('0to365days','91to365days','181to365days') THEN 12
																WHEN v.Suffix IN ('0to730days','366to730days') THEN 24
																ELSE 99 
																END, v.Suffix)


SELECT DISTINCT a.MVIPersonSID
	 	,CASE WHEN a.Domain='nonvameds' THEN CONCAT(a.PrintName, ' (Non-VA)')
		ELSE a.PrintName
		END AS PrintName
	,a.DashboardCategory
	,a.Domain
	,a.Timeframe AS TimeframeRank
	,CASE WHEN Timeframe=0 THEN 'Active'
		WHEN Timeframe = 3 THEN 'Prior 3 Months'
		WHEN Timeframe = 6 THEN 'Prior 6 Months'
		WHEN Timeframe = 12 THEN 'Prior 12 Months'
		WHEN Timeframe = 24 THEN 'Prior 24 Months'
		ELSE 'History'
		END AS Timeframe
 , a.InstanceVariable
  ,case when SuperSet IS NOT NULL THEN SuperSet
	  when InstanceVariable = 'PSYCHOSOCIAL_PROBLEMS_NOS' THEN 'PsychosocialProblemsNos'
	  when InstanceVariable = 'DEPRESSION_OTHER'  then 'Depress'  
	  when InstanceVariable = 'PSYCHOTIC_DISORDER_OTHER' THEN 'PsychoticDisorderOther'
	  when InstanceVariable = 'MOOD_DISORDER_OTHER' THEN 'MoodDisorderOther'
	  when InstanceVariable = 'INTENTIONAL_SELF_HARM_IDEATION' THEN 'IntentionalSelfHarmIdeation'
	  when InstanceVariable = 'ANXIETY_GENERALIZED' THEN 'AnxietyGeneralized'
	  when InstanceVariable = 'SuicideAttempt_Event' then  'SuicideAttempt'
	  when InstanceVariable = 'NonSuicideOverdose_Event' then  'NonSuicideOverdose'
	  when InstanceVariable = 'DRUG_USE_DISORDER_OTHER'  then 'DrugUseDisorderOther'  
	  when InstanceVariable = 'HALLUCINOGEN_USE_DISORDER' then 'CannabisUD_HallucUD' 
	  when InstanceVariable = 'ALCOHOL_USE_DISORDER' then 'AUD' 
	  WHEN InstanceVariable='EATING_DISORDER_UNSPECIFIED' THEN 'EatingDisorderNos'
	  WHEN InstanceVariable='MENTAL_HEALTH_OTHER' THEN 'OtherMH'
	  WHEN InstanceVariable='EXTERNAL_SELF_HARM' THEN 'ExternalSelfHarm'
	  WHEN InstanceVariable='INTENTIONAL_OVERDOSE_POISON' THEN 'SuicideAttempt'
	  WHEN InstanceVariable='OTHER_SPECIFIED_EATING_DISORDERS' THEN 'EatingDisorder'
	  WHEN InstanceVariable='SUICIDE_ATTEMPT' THEN 'SuicideAttempt'
	  else ISNULL(CDS_Lookup,REPLACE(CDS_Lookup,'_','')) end CDS_Lookup
	,DashboardColumn
	,DisplayWithoutHeader
FROM #risks as a 
left outer join  LookUp.CDS_ALEX as c WITH (NOLOCK) on a.SetTerm= c.SetTerm
WHERE a.Ignore=0

END