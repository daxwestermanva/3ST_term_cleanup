
-- =======================================================================================================
---- Author:  Christina Wade
---- Create date: 2/14/2022
---- Description: Generating UDS Lab Results for STORM Lookup; ADS as the data source. 
----
---- Modifications:
----
---- 6/12/2023 - CW - Adding in flag for non-negative lab results
-- =======================================================================================================

CREATE PROCEDURE [App].[ORM_UDSLabResults_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;
 
 
	--Get PatientICNs based on user permissions
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		 MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK) 
	WHERE b.PatientICN =  @ICN
	AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0);


	--UDS lab results
	SELECT 
		PatientICN
		,LabGroup
		,LabDate
		,CASE WHEN Labscore <> 0 THEN 1 ELSE 0 END AS NonNegativeFlag
		,CONCAT(PrintNameLabResults, UnspecifiedNAResults) as Results
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
		WHERE r.LabDate  > DATEADD(day, -366, getdate())
		AND r.LabRank <=5
		) x 
	ORDER BY PatientICN, LabGroup, LabDate DESC

END