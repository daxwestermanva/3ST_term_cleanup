-- =============================================
-- Author:		Liam Mina
-- Create date: 2025-02-07
-- Description:	Providers for COMPACT Cohort
-- =============================================
CREATE PROCEDURE [App].[COMPACT_Providers_PBI]

AS
BEGIN
	SET NOCOUNT ON;


	SELECT DISTINCT
		a.MVIPersonSID
		,a.Team
		,a.TeamRole
		,REPLACE(a.StaffName,',',', ') AS ProviderName
		,c.ChecklistID
	    ,a.TeamType
	FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
	INNER JOIN [COMPACT].[Episodes]  AS b WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	
  UNION ALL
  
	SELECT DISTINCT a.MVIPersonSID
		,CASE WHEN b.Program = 'VJO' THEN 'Veterans Justice Outreach (VJO)' 
			WHEN b.Program = 'HCRV' THEN 'Health Care for Re-Entry Veterans (HCRV)'
			WHEN b.Program = 'HCHV Case Management' THEN 'Health Care for Homeless Veterans (HCHV) Case Management'
			ELSE b.PROGRAM END AS Program
		,'Lead Case Manager' AS TeamRole
		,REPLACE(b.LeadCaseManager,',',', ') AS ProviderName
		,c.ChecklistID
		 ,'Homeless'
	FROM [COMPACT].[Episodes]  AS a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientICN] AS mvi WITH (NOLOCK) 
		ON a.MVIPersonSID = mvi.MVIPersonSID
	INNER JOIN  [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] b WITH (NOLOCK)
		ON mvi.PatientICN = b.PatientICN
	INNER JOIN [Lookup].[Sta6a] c WITH (NOLOCK)
		ON b.Program_Entry_Sta6a = c.Sta6a

  UNION ALL

	SELECT DISTINCT a.MVIPersonSID
		,Program='SP Team'
		 ,TeamRole='Suicide Prevention Coordinator'
		,p.AssignedSPC AS ProviderName
		,p.OwnerChecklistID
		 ,'SP Team'
	FROM [COMPACT].[Episodes]  AS a WITH (NOLOCK)
	INNER JOIN [PRF_HRS].[PatientReport_v02] AS p WITH (NOLOCK) 
		ON a.MVIPersonSID = p.MVIPersonSID
	;
 
END