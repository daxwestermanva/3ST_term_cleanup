




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

CREATE VIEW [App].[PBIReports_Screening] AS

	SELECT DISTINCT s.MVIPersonSID, s.ChecklistID, s.Category, s.Score, s.ScreenType, s.EvidenceDate, c.Code, c.Facility
	FROM PBIReports.Screening s WITH (NOLOCK)
	LEFT JOIN LookUp.StationColors as c WITH (NOLOCK)
		ON s.ChecklistID = c.CheckListID

	UNION
	
	SELECT MVIPersonSID
		,ChecklistID
		,ScreenCategory
		,ScreenScore
		,ScreenType
		,ScreenDate
		,Code
		,Facility
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)