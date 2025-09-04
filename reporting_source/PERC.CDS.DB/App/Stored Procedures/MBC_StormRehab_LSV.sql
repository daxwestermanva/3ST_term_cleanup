 
 
-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: Main data date for the Persceptive Reach report
-- Updates
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--	2020-09-16 - LM - Pointed to _VM tables
--
-- EXEC [App].[MBC_StormRehab_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000649095
-- EXEC [App].[MBC_StormRehab_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653709
-- =============================================
CREATE   PROCEDURE [App].[MBC_StormRehab_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET  NOCOUNT ON;
 
	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000649095
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000653709
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK) 
	WHERE b.PatientICN =  @ICN
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;
 
 
	SELECT DISTINCT TOP 100
		a.MVIPersonSID
		,a.RM_ActiveTherapies_Key
		,a.RM_ActiveTherapies_Date
		,a.RM_ChiropracticCare_Key
		,a.RM_ChiropracticCare_Date
		,a.RM_OccupationalTherapy_Key
		,a.RM_OccupationalTherapy_Date
		,a.RM_OtherTherapy_Key
		,a.RM_OtherTherapy_Date
		,a.RM_PhysicalTherapy_Key
		,a.RM_PhysicalTherapy_Date
		,a.RM_SpecialtyTherapy_Key
		,a.RM_SpecialtyTherapy_Date
		,a.RM_PainClinic_Key
		,a.RM_PainClinic_Date
		,a.CAM_Key
		,a.CAM_Date
	FROM #Patient AS p
	INNER JOIN [ORM].[Rehab] AS a WITH (NOLOCK) 
	ON p.MVIPersonSID = a.MVIPersonSID
 
	;
 
END