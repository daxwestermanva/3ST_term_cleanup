-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
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
--				Row duplication is expected in this dataset.
--
--
-- Modifications:
-- 
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderSUDRiskFactors_PBI]
AS
BEGIN

	SELECT DISTINCT MVIPersonSID, RiskType
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (1,2,3,4,5,6,7,9,10,11,12)

	UNION

	--test patient data
	SELECT MVIPersonSID
		,RiskType= --SUDRiskFactorsType
			CASE WHEN MVIPersonSID IN (15258421,9382966) THEN 'Detox/Withdrawal Health Factor'
				 WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN '> 2 Adverse Events'
				 WHEN MVIPersonSID IN (42958478,46455441,36668998) THEN 'Confirmed IDU'
				 WHEN MVIPersonSID IN (49627276,13426804) THEN 'Detox/Withdrawal Note Mentions'
				 WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'CIWA'
				 WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Hx of SUD Dx | No SUD Tx'
				 WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN 'Positive Audit-C'
				 WHEN MVIPersonSID IN (13066049,14920678) THEN 'IVDU Note Mentions'
				 WHEN MVIPersonSID IN (36728031,43587294) THEN 'COWS'
				 WHEN MVIPersonSID IN (16063576) THEN 'Positive Drug Screen' END
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE MVIPersonSID in (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976) --TestPatient=1;


END