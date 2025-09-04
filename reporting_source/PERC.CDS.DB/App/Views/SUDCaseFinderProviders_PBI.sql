



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/6/2025
-- Description:	To be used for location, provider, and team slicers. 
--				Code adapted from [App].[SUD_CaseFinderProviders_PBI].
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 6/9/2025  CW  Adding in Demo patients from view
--
-- =======================================================================================================

CREATE VIEW [App].[SUDCaseFinderProviders_PBI] AS

	--ProviderSlicers: Get list of Providers and their locations; When there is no provider or Team, output the ChecklistID for where SUD case factor occurred
	WITH ProviderSlicers AS (
	SELECT ChecklistID=x.ChecklistID
		,x.MVIPersonSID
		,Team=ISNULL(x.Team,CONCAT('Unassigned',' (', x.ChecklistID, ')'))
		,ProviderName=ISNULL(x.StaffName,CONCAT('Unassigned',' (', x.ChecklistID, ')'))
	FROM (
		SELECT ChecklistID=ISNULL(p.ChecklistID, co.ChecklistID) --If no provider (ChecklistID) is assigned, use ChecklistID for where SUD case factor occurred
			,co.MVIPersonSID
			,p.Team
			,p.StaffName
		FROM SUD.CaseFinderCohort AS co
		LEFT JOIN [Present].[Provider_Active] AS p WITH (NOLOCK)
			ON p.MVIPersonSID = co.MVIPersonSID
		UNION
		SELECT s.ChecklistID --Also add in any location of HUD provider (ChecklistID) who has had contact with SUDCaseFinder patient
			,co.MVIPersonSID
			,Team=
				CASE WHEN hud.Program = 'VJO' THEN 'Veterans Justice Outreach (VJO)' 
					 WHEN hud.Program = 'HCRV' THEN 'Health Care for Re-Entry Veterans (HCRV)'
					 WHEN hud.Program = 'HCHV Case Management' THEN 'Health Care for Homeless Veterans (HCHV) Case Management'
					 ELSE hud.PROGRAM END
			,StaffName=hud.LeadCaseManager 
		FROM [SUD].[CaseFinderCohort] co WITH (NOLOCK)
		INNER JOIN [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] hud WITH (NOLOCK)
			ON co.PatientICN=hud.PatientICN
		INNER JOIN LookUp.Sta6a s WITH (NOLOCK) 
			on hud.PROGRAM_ENTRY_STA6A=s.Sta6a			
			) x
		)

	--Final table for Power BI report
	SELECT DISTINCT c.MVIPersonSID
		,ChecklistID=c.ChecklistID
		,sc.VISN
		,sc.Facility
		,c.ProviderName
		,c.Team
	FROM ProviderSlicers c
	LEFT JOIN LookUp.ChecklistID sc WITH (NOLOCK)
		ON c.ChecklistID=sc.CheckListID

	UNION

	--Test patient data
	SELECT MVIPersonSID
		,ChecklistID
		,VISN
		,Facility
		,ProviderName
		,TeamName
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)