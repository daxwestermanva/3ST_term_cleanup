


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Providers]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Providers] AS


	SELECT DISTINCT a.ChecklistID, a.MVIPersonSID, a.TeamRole, a.ProviderName, s.Code, s.Facility
	FROM (	SELECT d.ChecklistID
				,b.MVIPersonSID
				,a.TeamRole
				,ProviderName=a.StaffName 
			FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
			INNER JOIN [Common].[PBIReportsCohort] AS b 
				ON a.MVIPersonSID = b.MVIPersonSID
			INNER JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
				ON a.Sta6a = c.Sta6a
			INNER JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
				ON c.checklistID = d.ChecklistID

			UNION

			SELECT c.ChecklistID
				,a.MVIPersonSID
				,TeamRole='Lead Case Manager'
				,ProviderName=b.LeadCaseManager
			FROM [Common].[PBIReportsCohort] a WITH (NOLOCK)
			INNER JOIN [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] b WITH (NOLOCK)
				ON a.PatientICN = b.PatientICN
			INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
				ON b.Program_Entry_Sta3n = c.Sta3n
		) a
	INNER JOIN LookUp.StationColors as s WITH (NOLOCK)
		ON s.ChecklistID = a.CheckListID

	UNION

	SELECT
		 ChecklistID
		,MVIPersonSID
		,TeamRole
		,ProviderName
		,Code
		,Facility	
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)