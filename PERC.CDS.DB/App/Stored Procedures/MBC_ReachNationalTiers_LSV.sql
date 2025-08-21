
-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: REACH VET National Risk Tiers
-- Updates
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
--  2019-04-05 - Liam Mina - Added MVIPersonSID to initial select statement
--  2019-06-20 - Liam Mina - changed order of final join so that patients not in REACH.RiskScore have 'baseline' displayed instead of nothing
--  2020-01-23 - RAS - Changed query to pull from view Reach.NationalTiers, which had the same logic.
--  2020-09-21 - RAS - Changed initial #patient to use Common.MasterPatient instead of Present.StationAssignments
--	2021-01-15 - LM - Changed displayed language for patients who don't have a calculated risk score

-- EXEC [App].[MBC_ReachNationalTiers_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653382
-- EXEC [App].[MBC_ReachNationalTiers_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653709
-- =============================================
CREATE PROCEDURE [App].[MBC_ReachNationalTiers_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET  NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000653382
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1024127549

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @ICN
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT p.PatientICN
		 ,CASE WHEN r.RiskTier IS NULL THEN 'Undetermined' ELSE r.RiskTier END AS RiskTier 
		 ,CASE WHEN r.RiskTierDescription IS NULL THEN 'Risk tier could not be calculated for this patient. Close clinical review is encouraged to assess suicide risk.'
		  ELSE r.RiskTierDescription END AS RiskTierDescription
	FROM #Patient as p
	LEFT JOIN [REACH].[NationalTiers] r WITH (NOLOCK)
		ON p.PatientICN=r.PatientICN

END