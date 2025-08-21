-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to the following EBPs, which the SUD casefinder cohort has engaged with:
/*
	SELECT DISTINCT EBPType=CASE WHEN l.PrintName IS NULL THEN CONCAT(REPLACE(REPLACE(TemplateGroup,'EBP_',''),'_Tracker',''), ' (', DiagnosticGroup, ')')
					   ELSE CONCAT(l.PrintName, ' (', DiagnosticGroup, ')') END
	FROM EBP.TemplateVisits e
	LEFT JOIN ( SELECT DISTINCT List, REPLACE(PrintName, ' Templates','') AS PrintName 
				FROM Lookup.List 
				WHERE List LIKE 'EBP%Template' AND List <> 'EBP_Other_Template') l
		ON e.TemplateGroup=l.List
*/
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 2/11/2025 - CW   Updating method for pulling EBP information. 
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderEBPs_PBI]
AS
BEGIN

	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID
	INTO #Cohort
	FROM SUD.CaseFinderRisk WITH (NOLOCK);

	SELECT DISTINCT c.MVIPersonSID
		,EBPType= CASE WHEN l.PrintName IS NULL THEN CONCAT(REPLACE(REPLACE(TemplateGroup,'EBP_',''),'_Tracker',''), ' (', DiagnosticGroup, ')')
					   ELSE CONCAT(l.PrintName, ' (', DiagnosticGroup, ')') END
	FROM #Cohort c
	INNER JOIN EBP.TemplateVisits e WITH (NOLOCK)
		ON c.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN ( SELECT DISTINCT List, REPLACE(PrintName, ' Templates','') AS PrintName 
				FROM Lookup.List WITH (NOLOCK) 
				WHERE List LIKE 'EBP%Template' AND List <> 'EBP_Other_Template') l
		ON e.TemplateGroup=l.List

	UNION
	
	--test patient data
	SELECT MVIPersonSID
		,EBPType=
			CASE WHEN MVIPersonSID=15258421	THEN 'CBT-SUD'
				 WHEN MVIPersonSID=9382966	THEN 'CPT'
				 WHEN MVIPersonSID=36728031	THEN 'PE'
				 WHEN MVIPersonSID=13066049	THEN 'EMDR'
				 WHEN MVIPersonSID=14920678	THEN 'PEI'
				 WHEN MVIPersonSID=9160057	THEN 'BFT'
				 WHEN MVIPersonSID=9097259	THEN 'WNE'
				 WHEN MVIPersonSID=40746866	THEN 'CBT-I'
				 WHEN MVIPersonSID=43587294	THEN 'CBT-PTSD'
				 WHEN MVIPersonSID=42958478	THEN 'CBT-D' 
				 WHEN MVIPersonSID=46455441	THEN 'WET'
				 WHEN MVIPersonSID=36668998	THEN 'CBT-SP'
				 WHEN MVIPersonSID=49627276	THEN 'ACT'
				 WHEN MVIPersonSID=13426804	THEN 'SST'
				 WHEN MVIPersonSID=16063576	THEN 'IBCT'
				 WHEN MVIPersonSID=9415243	THEN 'DBT'
				 WHEN MVIPersonSID=9144260	THEN 'PST'
				 WHEN MVIPersonSID=46028037	THEN 'IPT'
				 WHEN MVIPersonSID=49605020	THEN 'CM' 				 
				 WHEN MVIPersonSID=9279280	THEN 'CBT-SUD'
				 WHEN MVIPersonSID=46113976	THEN 'CBT-SUD' END	
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976); --TestPatient=1


END