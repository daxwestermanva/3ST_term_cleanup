



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	6/9/2025
-- Description:	To be used for location, provider, and team slicers. 
--				Code adapted from [App].[SUD_CaseFinderEBPs_PBI].
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- =======================================================================================================

CREATE VIEW [App].[SUDCaseFinderEBPTypes_PBI] AS 

	SELECT DISTINCT c.MVIPersonSID
		,EBPType= CASE WHEN l.PrintName IS NULL THEN CONCAT(REPLACE(REPLACE(TemplateGroup,'EBP_',''),'_Tracker',''), ' (', DiagnosticGroup, ')')
					   ELSE CONCAT(l.PrintName, ' (', DiagnosticGroup, ')') END
	FROM SUD.CaseFinderRisk c WITH (NOLOCK)
	INNER JOIN EBP.TemplateVisits e WITH (NOLOCK)
		ON c.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN ( SELECT DISTINCT List, REPLACE(PrintName, ' Templates','') AS PrintName 
				FROM Lookup.List 
				WHERE List LIKE 'EBP%Template' AND List <> 'EBP_Other_Template') l
		ON e.TemplateGroup=l.List

	UNION
	
	--test patient data
	SELECT MVIPersonSID
		,EBPType
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)