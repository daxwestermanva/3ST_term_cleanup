

-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	6/9/2025
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
--				Code adapted from [App].[SUD_CaseFinderRx_PBI].
--
--				Row duplication is expected in this dataset.
--
--
-- Modifications:
--
--
-- =======================================================================================================
CREATE VIEW [App].[SUDCaseFinderMedTypes_PBI] AS

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
		,MedType
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)