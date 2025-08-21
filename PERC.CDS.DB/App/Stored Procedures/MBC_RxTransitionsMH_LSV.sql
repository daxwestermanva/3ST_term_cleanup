

-- =============================================
-- Author:		<Cora Bernard>
-- Create date: <4/16/2020>
-- Description:	Used by CRISTAL SSRS reports to identify psychotropic and controlled substance 
--		Rx that currently have no pills on hand (PoH)
-- Updates
--	2020-06-12	LM	Updated to reflect new column names in [Present].[RxTransitionsMH]
--  2020-09-22  LM  Changed initial query to use MasterPatient instead of StationAssignments.
--
-- EXEC [App].[MBC_RxDisc_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001092794
-- EXEC [App].[MBC_RxDisc_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1012614757
-- =============================================
CREATE PROCEDURE [App].[MBC_RxTransitionsMH_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)	
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1001092794
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1039254042 
	
	
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)


	SELECT DISTINCT rx.MVIPersonSID
		,p.PatientICN
		,rx.[PrescribingFacility]
		,rx.[DrugNameWithDose]
		,rx.[DrugChange]
		,rx.[PreviousDrugNameWithDose]
		,rx.[DaysSinceRelease]
		,rx.[NoPoH_RxDisc]
		,rx.[NoPoH_RxActive]
		,rx.[DaysWithNoPoH]
		,rx.[TrialLength]
	FROM [Present].[RxTransitionsMH] rx WITH (NOLOCK)
	INNER JOIN #Patient p	
		ON p.MVIPersonSID = rx.MVIPersonSID



END