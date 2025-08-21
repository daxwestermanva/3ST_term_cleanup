




-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Code used to generate the data source is housed in [Code].[Common_PBIReportsCohort].
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_RiskFlags] AS

	SELECT DISTINCT f.MVIPersonSID
		,f.ChecklistID
		,f.FlagType
		,f.FlagInfo
		,f.FlagDate
		,s.Code
		,s.Facility
	FROM PBIReports.RiskFlags f WITH (NOLOCK)
	INNER JOIN LookUp.StationColors as s WITH (NOLOCK)
		ON f.ChecklistID = s.CheckListID

	UNION

	SELECT MVIPersonSID
		 ,ChecklistID
		,FlagType	
		,FlagInfo
		,FlagDate
		,Code
		,Facility
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)