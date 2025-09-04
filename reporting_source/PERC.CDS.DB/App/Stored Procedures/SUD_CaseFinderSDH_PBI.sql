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
CREATE PROCEDURE [App].[SUD_CaseFinderSDH_PBI]
AS
BEGIN

	SELECT DISTINCT MVIPersonSID
		,RiskType
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (19,20,21,22)
	
	UNION

	--test patient data
	SELECT MVIPersonSID
	,RiskType= --SDHType
		CASE WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Justice Involvement'
				   WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'Food Insecurity - Positive Screen'
				   WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Relationship Health and Safety - Positive Screen' 
				   WHEN MVIPersonSID IN (49605020,9279280,46113976,46455441,36668998) THEN 'Homeless - Positive Screen' END
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE MVIPersonSID in (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976) --TestPatient=1


END