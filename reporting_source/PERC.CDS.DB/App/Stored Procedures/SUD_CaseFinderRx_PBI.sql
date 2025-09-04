-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to Rx Current VA Rx / Medication Types:
--					- Buprenorphine
--					- Opioid
--					- Anxiolytic or Benzodiazepine
--					- Antidepressant
--					- Antipsychotic
--					- Mood Stabilizer
--					- Stimulant
--				
--				Row duplication is expected in this dataset.
--
--
-- Modifications:
--
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderRx_PBI]
AS
BEGIN

	SELECT DISTINCT 
		a.MVIPersonSID
		,CASE 
			WHEN a.DrugNameWithoutDose LIKE '%BUPRENORPHINE%' THEN 'Buprenorphine'
			WHEN a.OpioidForPain_rx	= 1 OR a.OpioidAgonist_Rx = 1  THEN 'Opioid'
			WHEN a.Anxiolytics_Rx = 1 OR a.Benzodiazepine_Rx = 1  THEN 'Anxiolytic or Benzodiazepine'
			WHEN a.Antidepressant_Rx = 1 THEN 'Antidepressant'
			WHEN a.Antipsychotic_Rx = 1 THEN 'Antipsychotic'
			WHEN a.MoodStabilizer_Rx = 1 THEN 'Mood Stabilizer'
			WHEN a.Stimulant_Rx = 1 THEN 'Stimulant'
		 END AS MedType
	FROM [Present].[Medications] AS a WITH (NOLOCK) 
	INNER JOIN SUD.CaseFinderCohort as s
		ON a.MVIPersonSID = s.MVIPersonSID 
	WHERE Psychotropic_Rx = 1 OR
		Benzodiazepine_Rx = 1 OR
		OpioidForPain_Rx = 1 OR	
		Stimulant_Rx = 1 OR
		OpioidAgonist_Rx = 1 OR 
		a.DrugNameWithoutDose like '%BUPRENORPHINE%'

	UNION

	--test patient data
	SELECT MVIPersonSID
		,MedType=
			CASE WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049) THEN 'Buprenorphine'
				 WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Antipsychotic'
				 WHEN MVIPersonSID IN (49627276,13426804,49605020) THEN 'Mood Stabilizer'
				 WHEN MVIPersonSID IN (9279280,46113976) THEN 'Opioid'
				 WHEN MVIPersonSID IN (46455441,36668998) THEN 'Antidepressant'
				 WHEN MVIPersonSID IN (14920678,46028037,9415243) THEN 'Stimulant'
				 WHEN MVIPersonSID IN (42958478,9144260,16063576) THEN 'Anxiolytic or Benzodiazepine' END
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976); --TestPatient=1

END