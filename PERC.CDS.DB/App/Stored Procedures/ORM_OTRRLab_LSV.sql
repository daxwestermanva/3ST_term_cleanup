
-- =============================================
-- =============================================
-- Author:  Tolessa Gurmessa
-- Create date: 11/22/2021
-- Description: Lab Results subreport for Opioid Therapy Risk Report; adapted from app.mbc_stormhypo_lsv
--
-- Modifications:
--  3/7/2023 - CW - Updating data source for drug screen results
--
-- EXEC [App].[ORM_OTRRLab_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1031379110
-- EXEC [App].[ORM_OTRRLab_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 1032619262
-- =============================================
CREATE PROCEDURE [App].[ORM_OTRRLab_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;
 
 ----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK) 
	WHERE b.PatientICN =  @ICN
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

		SELECT 
		PatientICN
		,LabGroup
		,LabDate
		,CONCAT(PrintNameLabResults, UnspecifiedNAResults) as Results
		,CASE WHEN LabScore=1 THEN 1 ELSE 0 END AS PosFlag --flag positive screens
	FROM (
		SELECT DISTINCT 
			p.PatientICN
			,r.LabGroup
			,r.LabDate
			,CASE WHEN r.Labscore IN (2, -1) THEN CONCAT(' (',r.LabResults,')') ELSE NULL END AS UnspecifiedNAResults
			,r.PrintNameLabResults
			,r.LabScore
		FROM #Patient AS p
		INNER JOIN Present.UDSLabResults r WITH (NOLOCK)
			ON p.MVIPersonSID=r.MVIPersonSID
		LEFT OUTER JOIN [ORM].[PatientReport] AS b WITH (NOLOCK)
			ON p.MVIPersonSID = b.MVIPersonSID  
		WHERE r.LabRank=1
		) x 
	ORDER BY PatientICN, LabGroup, LabDate DESC
 
END