 
 
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report
-- Description:	Main data date for the Measurement based care report; Used by CRISTAL SSRS reports
-- Updates
	--2019-01-09	JB	Refactored to use MVIPersonSID for future when CDS tables have MVIPersonSID; Performance tuning; formatting; NOLOCKs
	--2019-04-01	RAS	Removed comments from initial section
	--2019-04-05 - LM - Added MVIPersonSID to initial select statement
	--2019-06-07 - LM - added HOMES providers
	--2020-09-22 - LM - Changed initial query to use MasterPatient instead of StationAssignments.
	--2022-03-10 - SG - update RelationshipStartDateTime to RelationshipStartDate
--
-- EXEC [App].[MBC_Providers_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001092794
-- EXEC [App].[MBC_Providers_LSV] @User = 'VHA21\VHAPALMINAL', @Patient = 1021908648
-- =============================================
CREATE   PROCEDURE [App].[MBC_Providers_LSV]
(
    @User VARCHAR(MAX),
    @Patient VARCHAR(1000)
) 
AS
BEGIN
	SET NOCOUNT ON;
 
	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1001092794
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = 1021908648
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;
 
	SELECT  
		d.Facility, a.Team, a.TeamRole, a.StaffName AS ProviderName, a.RelationshipStartDate, NULL AS Comments
	FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
	INNER JOIN #Patient AS b 
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	INNER JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
		ON c.checklistID = d.ChecklistID
	UNION
	SELECT c.Facility
		,CASE WHEN b.Program = 'VJO' THEN 'Veterans Justice Outreach (VJO)' 
			WHEN b.Program = 'HCRV' THEN 'Health Care for Re-Entry Veterans (HCRV)'
			WHEN b.Program = 'HCHV Case Management' THEN 'Health Care for Homeless Veterans (HCHV) Case Management'
			ELSE b.PROGRAM END AS Program
		,'Lead Case Manager' AS TeamRole
		,b.LeadCaseManager AS ProviderName
		,b.PROGRAM_ENTRY_DATE AS RelationshipStartDate
		,HET_HOUSING_STATUS AS Comments
	FROM #patient a WITH (NOLOCK)
	INNER JOIN [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] b WITH (NOLOCK)
		ON a.PatientICN = b.PatientICN
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
		ON b.Program_Entry_Sta3n = c.Sta3n
	;
 
END
GO

