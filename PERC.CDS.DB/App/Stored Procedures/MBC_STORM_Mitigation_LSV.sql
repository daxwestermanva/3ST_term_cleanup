

-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: Main data date for the Persceptive Reach report
--  2018-12-27 - PS completely redid this to pull from ORM.RiskMitigation instead of replicating the existing logic
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--	2020-09-16 - LM - Pointed to _VM tables
--  2020-09-22 - LM - Changed initial query to use MasterPatient instead of StationAssignments.
--  2023-05-11 - TG - Made changes to account for patients in the STORM cohort who do not have risk mitigation populated.
--  2024-01-08 - TG - Pulling latest UDS dates where it's not required.
--  2024-03-12 - CW - Adding concatenated EntryDateTime for use where Overdose Event is not null. The field has asked 
--					  for the date of event as well as date of report.
-- 2025-01-10  - TG - Implementing PMOP changes to risk mitigation
-- 2025-01-13  - TG - Fixing Rx risk mitigation inclusion bug.
-- EXEC [App].[MBC_STORM_Mitigation_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653382
-- EXEC [App].[MBC_STORM_Mitigation_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1000653709
-- =============================================
CREATE PROCEDURE [App].[MBC_STORM_Mitigation_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000653382
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 1000653709

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE PatientICN = @ICN
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT 
		p.PatientICN
		,a.MitigationID
		,CASE 
			WHEN a.PrintName IS NULL AND a.MitigationID IS NULL
			THEN 'The patient may be opioid naïve; consider Informed Consent, PDMP, Data-based Risk Review, Drug Screening, and/or other appropriate risk mitigation strategies.'
			WHEN a.PrintName LIKE 'MEDD%' 
			THEN CONCAT(a.PrintName,' (30 Day Avg)') 
		ELSE a.PrintName END AS PrintName
		,a.DetailsText
		,a.DetailsDate 
		,a.Checked
		,a.Red
		,[MitigationIDRx]
      ,a.[PrintNameRx]
      ,a.[CheckedRx]
      ,a.[RedRx]
		,a.MetricInclusion
		,CASE WHEN c.Hospice IS NULL THEN 0 ELSE c.Hospice END AS Hospice
		,CASE WHEN c.Bowel_Rx IS NULL THEN 0 ELSE c.Bowel_Rx END AS Bowel_Rx
		,CASE WHEN c.Anxiolytics_Rx IS NULL THEN 0 ELSE c.Anxiolytics_Rx END AS Anxiolytics_Rx	  
		,CASE WHEN c.SUDdx_poss IS NULL THEN 0 ELSE c.SUDdx_poss END AS SUDdx_poss
		,COUNT(a.MitigationID) OVER (PARTITION BY a.MVIPersonSID) AS MaxMitigations
		,SUM(ISNULL(a.Checked,0))  OVER (PARTITION BY a.MVIPersonSID) AS RiskMitScore
		,CASE WHEN a.DetailsText='Overdose Event On'
			  THEN CONCAT('Overdose Reported On ',FORMAT(sp.EntryDateTime,'M/d/yyyy'))
			  ELSE NULL END AS OverdoseReportDetails
	FROM #Patient AS p
	LEFT JOIN [ORM].[RiskMitigation] AS a WITH (NOLOCK)
		ON p.MVIPersonSID = a.MVIPersonSID AND ((a.MetricInclusion = 1) OR (a.MitigationID IN (1, 3, 5, 8, 10) AND a.MetricInclusion=0))
	LEFT JOIN SUD.Cohort AS c with (NOLOCK)
		ON a.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN OMHSP_Standard.SuicideOverdoseEvent sp WITH (NOLOCK)
		ON a.MVIPersonSID=sp.MVIPersonSID 
		AND CAST(a.DetailsDate as DATE)=CAST(ISNULL(sp.EventDateFormatted,sp.EntryDateTime) as date) 
		AND Overdose=1
	WHERE p.PatientICN = @ICN 
	;
 
END