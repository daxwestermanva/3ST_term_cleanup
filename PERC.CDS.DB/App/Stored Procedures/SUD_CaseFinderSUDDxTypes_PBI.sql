-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to SUD related diagnoses:
--					- Alcohol Use
--					- Opioid Use
--					- Amphetamine Use
--					- Cocaine Use
--					- Cannabis Use
--					- Sedative, Hypnotic or Anxiolytic Use
--					- Hallucinogen Use
--					- Inhalant Use
--					- Tobacco Use
--					- Other Psychoactive Use
--				
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 1/6/2025  CW  Updating SUDType method
-- 6/9/2025  CW  Adding in Demo patients from view
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderSUDDxTypes_PBI]
AS
BEGIN

	--Substance Use Types
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID
	INTO #Cohort
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	WHERE SUDDx=1;

	DROP TABLE IF EXISTS #SUDDx
	SELECT DISTINCT c.MVIPersonSID
	,SUDType=
			CASE WHEN i.AUD=1 THEN 'Alcohol Use'
				 WHEN i.OUD=1 OR i.ICD10Description LIKE '%Opioid%' THEN 'Opioid Use'
				 WHEN i.AmphetamineUseDisorder=1 THEN 'Amphetamine Use'
				 WHEN i.COCNdx=1 THEN 'Cocaine Use'
				 WHEN i.COCNdx=0 AND i.AmphetamineUseDisorder=0 AND i.CocaineUD_AmphUD=1 THEN 'Other Stimulant Use'
				 WHEN i.Cannabis=1 THEN 'Cannabis Use'
				 WHEN i.ICD10Description LIKE '%Sedative, Hypnotic or Anxiolytic%' OR
					  i.ICD10Description LIKE '%Sedative, Hypnotic, or Anxiolytic%' THEN 'Sedative, Hypnotic or Anxiolytic Use'
				 WHEN i.Cannabis=0 AND i.CannabisUD_HallucUD=1 THEN 'Hallucinogen Use'
				 WHEN i.ICD10Description like '%inhalant%' THEN 'Inhalant Use'
				 WHEN i.Nicdx_poss=1 THEN 'Tobacco Use'
				 WHEN i.ICD10Description LIKE '%Other psychoactive%' THEN 'Other Psychoactive Use'
				 ELSE NULL END
		,SUDTypeSort=
			CASE WHEN i.AUD=1 THEN 1
				 WHEN i.OUD=1 OR i.ICD10Description LIKE '%Opioid%' THEN 2
				 WHEN i.AmphetamineUseDisorder=1 THEN 3
				 WHEN i.COCNdx=1 THEN 4
				 WHEN i.COCNdx=0 AND i.AmphetamineUseDisorder=0 AND i.CocaineUD_AmphUD=1 THEN 5
				 WHEN i.Cannabis=1 THEN 6
				 WHEN i.ICD10Description LIKE '%Sedative, Hypnotic or Anxiolytic%' OR
					  i.ICD10Description LIKE '%Sedative, Hypnotic, or Anxiolytic%' THEN 7
				 WHEN i.Cannabis=0 AND i.CannabisUD_HallucUD=1 THEN 8
				 WHEN i.ICD10Description like '%inhalant%' THEN 9
				 WHEN i.Nicdx_poss=1 THEN 10
				 WHEN i.ICD10Description LIKE '%Other psychoactive%' THEN 11
				 ELSE NULL END
	INTO #SUDDx
	FROM #Cohort c
	INNER JOIN Present.DiagnosisDate dd WITH (NOLOCK)
		ON c.MVIPersonSID=dd.MVIPersonSID
	INNER JOIN LookUp.ICD10 i WITH (NOLOCK)
		ON dd.ICD10Code=i.ICD10Code;

	DROP TABLE IF EXISTS #SUDDx_AdditionalConsiderations
	SELECT DISTINCT d.MVIPersonSID
		,lc.PrintName
		,SUDType=
			CASE WHEN lc.PrintName LIKE '%Alcohol%' THEN 'Alcohol Use'
				 WHEN lc.PrintName LIKE '%Opioid%' THEN 'Opioid Use'
				 WHEN lc.PrintName = 'Cocaine' THEN 'Cocaine Use'
				 WHEN lc.PrintName = 'Non Cocaine Stimulant Use Disorder' THEN 'Other Stimulant Use'
				 WHEN lc.PrintName = 'Cannabis' THEN 'Cannabis Use'
				 WHEN lc.PrintName LIKE '%Sedative%' THEN 'Sedative, Hypnotic or Anxiolytic Use'
				 WHEN lc.PrintName = 'Cannabis/Hallucinogen' THEN 'Hallucinogen Use'
				 ELSE 'Other Psychoactive Use'  END --If not clearly labeled via PrintName, Other Psychoactive Use
		,SUDTypeSort=
			CASE WHEN lc.PrintName LIKE '%Alcohol%' THEN 1
				 WHEN lc.PrintName LIKE '%Opioid%' THEN 2
				 WHEN lc.PrintName = 'Cocaine' THEN 4
				 WHEN lc.PrintName = 'Non Cocaine Stimulant Use Disorder' THEN 5
				 WHEN lc.PrintName = 'Cannabis' THEN 6
				 WHEN lc.PrintName LIKE '%Sedative%' THEN 7
				 WHEN lc.PrintName = 'Cannabis/Hallucinogen' THEN 8
				 ELSE 11 END
	INTO #SUDDx_AdditionalConsiderations
	FROM Present.Diagnosis d WITH (NOLOCK)
	INNER JOIN [LookUp].[ColumnDescriptions] lc WITH (NOLOCK)
		ON d.DxCategory = lc.ColumnName
	WHERE lc.Category='Substance Use Disorder';

	UPDATE #SUDDx 
	SET SUDType=a.SUDType, 
		SUDTypeSort=a.SUDTypeSort
	FROM #SUDDx s
	LEFT JOIN #SUDDx_AdditionalConsiderations a
		On s.MVIPersonSID=a.MVIPersonSID
	WHERE s.SUDType IS NULL;

	--Final table for Power BI report
	SELECT MVIPersonSID, SUDType, SUDTypeSort
	FROM #SUDDx

	UNION

	--test patient data
	SELECT MVIPersonSID
		,SUDType
		,SUDTypeSort
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)


END