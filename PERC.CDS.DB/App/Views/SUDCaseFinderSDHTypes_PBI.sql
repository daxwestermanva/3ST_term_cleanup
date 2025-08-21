-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to SDH (social drivers):
--					- Justice Involvement
--					- Food Insecurity
--					- Relationship Health and Safety
--					- Homelessness
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- =======================================================================================================
CREATE VIEW [App].[SUDCaseFinderSDHTypes_PBI] AS

	SELECT DISTINCT MVIPersonSID
		,RiskType
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (19,20,21,22)
	
	UNION

	--test patient data
	SELECT MVIPersonSID
	,RiskType=SDHType
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)