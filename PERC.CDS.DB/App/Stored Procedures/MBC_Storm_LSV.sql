 
 
-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: Main data date for the Persceptive Reach report
-- Updates
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
--  2019-04-05 - Liam Mina - Added MVIPersonSID to initial select statement
--	2020-09-16 - Liam Mina - Pointed to _VM tables
--
-- EXEC [App].[MBC_Storm_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1010021537
-- EXEC [App].[MBC_Storm_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1002452163
-- =============================================
CREATE   PROCEDURE [App].[MBC_Storm_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET  NOCOUNT ON;
 
	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1010021537
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1002452163
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK)
	WHERE b.PatientICN =  @ICN
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;
 
	SELECT DISTINCT  
		p.PatientICN
		,a.RiskScore
		,a.RiskCategory 
		,a.RiskCategoryLabel as RiskCategoryName
		,a.RIOSORDscore
		,a.RIOSORDriskclass
		,a.RiskScoreAny
		,a.RiskAnyCategory 
		,a.RiskAnyCategoryLabel as RiskAnyCategoryName
	FROM #Patient AS p
	INNER JOIN [ORM].[PatientReport] AS a WITH (NOLOCK)
	ON p.MVIPersonSID = a.MVIPersonSID
	;
 
END