
-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: Main data date for the Persceptive Reach report
-- Updates
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
--  2019-04-05 - LM - Added PatientGID to initial select statement
--  2019-05-16 - LM - Added fields from REACH.History
--  2019-12-27 - LM - Added MVIPersonSID
--	2020-01-31 - LM - Updated to V02 versions of REACH tables
--	2020-09-16 - LM - Pointed to _VM tables
--	2022-06-21 - LM - Reordered joins to ensure RV history for deceased pts (who are no longer in PatientReport table) is pulled in
--
-- EXEC [App].[MBC_Reach_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653382
-- EXEC [App].[MBC_Reach_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653709
-- =============================================
CREATE PROCEDURE [App].[MBC_Reach_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1002949783
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @ICN = 1013860335

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK)
	WHERE b.PatientICN =  @ICN
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT 
		a.MVIPersonSID
		,CAST(h.Top01Percent AS tinyint) AS Top01Percent
		,c.ProviderType
		,c.UserName
		,CASE WHEN h.LastIdentifiedExcludingCurrentMonth < DATEADD(year,-1,getdate()) OR h.LastIdentifiedExcludingCurrentMonth IS NULL THEN NULL
			WHEN h.MonthsIdentified12 IS NULL THEN 0 ELSE h.MonthsIdentified12 END AS MonthsIdentified12
		,CASE WHEN h.LastIdentifiedExcludingCurrentMonth < DATEADD(year,-2,getdate()) OR h.LastIdentifiedExcludingCurrentMonth IS NULL THEN NULL
			WHEN h.MonthsIdentified24 IS NULL THEN 0 ELSE h.MonthsIdentified24 END AS MonthsIdentified24
		,ISNULL(CONVERT(varchar, h.LastIdentifiedExcludingCurrentMonth, 101), 'Never') AS LastIdentifiedExcludingCurrentMonth
	FROM #Patient AS a WITH (NOLOCK)
	LEFT JOIN [REACH].[History] AS h WITH (NOLOCK) ON a.MVIPersonSID = h.MVIPersonSID
	LEFT JOIN 
		(
			SELECT	
				h.MVIPersonSID
				,CASE WHEN h.CoordinatorName IS NOT NULL THEN 'REACH VET Coordinator' ELSE NULL END AS ProviderType
				,h.CoordinatorName AS UserName 
			FROM [REACH].[QuestionStatus] AS h WITH (NOLOCK)
			WHERE h.CoordinatorName IS NOT NULL
			UNION ALL
			SELECT	
				h.MVIPersonSID
				,CASE WHEN h.ProviderName IS NOT NULL THEN 'REACH VET Provider' ELSE NULL END AS ProviderType
				,h.ProviderName AS UserName 
			FROM [REACH].[QuestionStatus] AS h WITH (NOLOCK)
			WHERE h.ProviderName IS NOT NULL
		) AS c ON a.MVIPersonSID = c.MVIPersonSID
	;

END