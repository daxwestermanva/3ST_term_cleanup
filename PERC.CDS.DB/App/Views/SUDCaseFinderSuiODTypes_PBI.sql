-- ============================================================================
-- Author:		Christina Wade
-- Create date:	6/9/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to High Risk Behaviors:
--					- Overdose Event
--					- Suicide Event 
--					- CSRE Acute Risk (Intermed/High) 
--					- Current Active PRF
--				
--				Code is adapted from [App].[SUD_CaseFinderSuiOD_PBI].
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- ============================================================================
CREATE VIEW [App].[SUDCaseFinderSuiODTypes_PBI] AS


	SELECT MVIPersonSID
		,TreeRiskType=CASE WHEN SortKey IN (13, 14, 15, 16) THEN 'Overdose Event' ELSE RiskType END
	FROM SUD.CaseFinderRisk
	WHERE SortKey IN (8,13,14,15,16,17,18)

	UNION

	--test patient data
	SELECT MVIPersonSID
		,TreeRiskType= SuicideODType
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)