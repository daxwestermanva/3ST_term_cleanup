 
 
-- =============================================
-- Author:  Liam Mina
-- Create date: 2020-06-11
-- Description: VCL and HRF Caring Letters programs
-- Updates
--  2020-09-22 - LM - Changed initial query to use MasterPatient instead of StationAssignments.
--  2020-10-19 - LM - Differentiated cases where veteran opted out vs. where there is an incorrect address
--	2022-03-23 - LM - Fixed errors in code; added code for Caring Letters extension
--	2023-06-12 - LM - Pointed to table that harmonizes VCL caring letters and HRF caring letters
--	2024-08-08 - LM - Added link to VCL caring letters report
 
-- EXEC [App].[MBC_CaringLetters_LSV] @User = 'VHA21\VHAPALMINAL', @Patient = 1001083051
-- EXEC [App].[MBC_CaringLetters_LSV] @User = 'VHA21\VHAPALMINAL', @Patient = 1005171957
-- =============================================
CREATE   PROCEDURE [App].[MBC_CaringLetters_LSV]
(
	@User VARCHAR(100),
	@Patient VARCHAR(1000)
)
AS
BEGIN
	SET  NOCOUNT ON;
	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = 1001790839
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = 1043186211
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
 
DROP TABLE IF EXISTS #Patient;
SELECT PatientICN, MVIPersonSID
INTO #Patient
FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
WHERE a.PatientICN = @Patient
	and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
 
SELECT DISTINCT a.[PatientICN]
      ,a.MVIPersonSID
	  ,CASE WHEN cl.Program IS NULL THEN 'VCL & HRF Caring Letters'
		ELSE cl.Program END AS Program
	  ,cl.EligibleDate
	  ,CASE WHEN cl.DoNotSend_Date IS NOT NULL AND cl.CurrentEnrolled=1 THEN CONCAT('Current: Do Not Send - ',cl.DoNotSend_Reason)
		WHEN cl.DoNotSend_Date IS NOT NULL AND cl.PastYearEnrolled=1 THEN CONCAT('Past Year: Do Not Send - ',cl.DoNotSend_Reason)
		WHEN cl.DoNotSend_Date IS NOT NULL AND EverEnrolled=1 THEN CONCAT('Prior to Past Year: Do Not Send - ',cl.DoNotSend_Reason)
	    WHEN cl.CurrentEnrolled=1 THEN 'Currently Enrolled'
		WHEN cl.PastYearEnrolled=1 THEN 'Previously Enrolled - Past Year'
		WHEN cl.LastScheduledLetterDate IS NOT NULL THEN 'Previously Enrolled - Prior to Past Year'
		WHEN cl.DoNotSend_Reason IS NOT NULL THEN CONCAT('Not Enrolled - ',cl.DoNotSend_Reason)
		ELSE 'Not Enrolled' END AS Status
	  ,CASE WHEN (d.UserName IS NOT NULL OR r.NetworkId IS NOT NULL)
			AND cl.Program = 'HRF Caring Letters' AND EverEnrolled=1 THEN 1 
		WHEN (d.UserName IS NOT NULL OR r.NetworkId IS NOT NULL)
			AND cl.Program = 'VCL Caring Letters' AND EverEnrolled=1 THEN 1
		ELSE 0 END AS LinkToCL
  FROM #Patient  a
  LEFT JOIN [Present].[CaringLetters] cl WITH (NOLOCK)
	ON a.MVIPersonSID = cl.MVIPersonSID
  LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
  LEFT JOIN Config.ReportUsers r WITH (NOLOCK)
	ON @User = r.NetworkId AND r.Project = cl.Program

END