-- ============================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to High Risk Behaviors:
--					- Overdose Event
--					- Suicide Event 
--					- CSRE Acute Risk (Intermed/High) 
--					- Current Active PRF
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- ============================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderSuiOD_PBI]
AS
BEGIN

	SELECT MVIPersonSID
		,TreeRiskType=CASE WHEN SortKey IN (13, 14, 15, 16) THEN 'Overdose Event' ELSE RiskType END
	FROM SUD.CaseFinderRisk
	WHERE SortKey IN (8,13,14,15,16,17,18)

	UNION

	--test patient data
	SELECT MVIPersonSID
		,TreeRiskType= --SuicideODType
			CASE WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Overdose Event'
				 WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'CSRE Acute Risk (Intermed/High)'
				 WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Current Active PRF - Suicide' 
				 WHEN MVIPersonSID IN (49605020,9279280,46113976,46455441,36668998) THEN 'Suicide Event' END
	FROM Common.MasterPatient
	WHERE MVIPersonSID in (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976); --TestPatient=1


END