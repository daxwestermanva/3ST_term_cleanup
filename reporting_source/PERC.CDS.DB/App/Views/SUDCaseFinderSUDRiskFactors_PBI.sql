-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	6/9/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to SUD related risk factors:
--					- Confirmed IDU
--					- Positive Audit-C
--					- CIWA
--					- COWS
--					- Detox/Withdrawal Health Factor
--					- Positive Drug Screen
--					- Hx of SUD Dx | No SUD Tx
--					- > 2 Adverse Events
--
--				Code adapted from [App].[SUD_CaseFinderSUDRiskFactors_PBI].
--
--				Row duplication is expected in this dataset.
--
--
-- Modifications:
-- 
--
-- =======================================================================================================
CREATE VIEW [App].[SUDCaseFinderSUDRiskFactors_PBI] AS

	SELECT DISTINCT MVIPersonSID, RiskType
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (1,2,3,4,5,6,7,9,10,11,12)

	UNION

	--test patient data
	SELECT MVIPersonSID
		,RiskType=SUDRiskFactorsType
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)