-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report
-- Modifications:
	-- 08/30/18 SM -added most recent service separation date
	-- 2019/01/09 - Jason Bacani - Added NOLOCKs; Formatting
	-- 2019/03/26 - LM - pulled in date of birth, race, and service connection
	-- 2019/05/22 - LM - Added homeless status and homeless services
	-- 2019/06/07 - LM - Added height and weight, moved homeless provider to App.MBC_Providers_LSV sp
	-- 2019/12/27 - LM - Added MVIPersonSID
	-- 2020/02/27 - LM - Added temporary address
	-- 2020-08-07 - RAS - V02 - altered to point to Common.MasterPatient, combines fields from MBC_Patient and MBC_PatientContact
	-- 2020-09-08 - CLB - Added CAN 90day risk score
	-- 2020-10-15 - LM - Added SourceEHR to indicate potential Cerner data
	-- 2020-11-30 - LM - Added OFR cohort - Outreach to Facilitate Return to Care (OFR Care)
	-- 2021-01-07 - LM - Added PeriodOfService, BranchOfService, and OEF/OIF Status
	-- 2022-05-20 - LM - Added EDIPI and PatientSSN_Hyphen
	-- 2022-08-22 - LM - Changed to use DisplayGender from Common.MasterPatient
	-- 2023-07-25 - LM - Added Alias
	-- 2024-09-16 - LM - Updated to new CAN score data source
	-- 2024-10-16 - LM - Moved contact info to separate procedure
	-- 2025-01-31 - TG - Adding patient initials to the dataset.
-- Sample execution:
--		EXEC [App].[MBC_Patient_LSV_v02] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009044641'
--		EXEC [App].[MBC_Patient_LSV_v02] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009044641'
-- =============================================
CREATE PROCEDURE [App].[MBC_Patient_LSV_v02]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
) 
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = '1002058830'
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = '1010769033'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	
	SELECT DISTINCT mp.PatientName
		  ,mp.PreferredName
		  ,LEFT(mp.FirstName, 1) + LEFT(mp.LastName, 1) AS PatientInitials
		  ,mp.PatientSSN
		  ,mp.PatientSSN_Hyphen
		  ,mp.EDIPI
		  ,mp.SensitiveFlag
		  ,mp.PatientICN
		  ,mp.MVIPersonSID
		  ,mp.Age
		  ,CASE WHEN mp.DisplayGender IS NULL THEN 'Unknown'
			ELSE mp.DisplayGender END AS Gender
		  ,mp.Pronouns
		  ,mp.SexualOrientation
		  ,mp.DateOfBirth
		  ,CASE WHEN mp.Race IS NULL THEN 'Unknown'
			ELSE mp.Race END AS Race
		  ,mp.PatientHeight as Height
		  ,mp.PatientWeight as Weight
		  ,mp.MaritalStatus
		  ,mp.PercentServiceConnect
		  ,mp.PeriodOfService
		  ,mp.BranchOfService
		  ,CASE WHEN mp.OEFOIFStatus IS NULL THEN 'N/A' ELSE mp.OEFOIFStatus END AS OEFOIFStatus
		  ,mp.ServiceSeparationDate
		  ,mp.Homeless
		  ,CAST(c.MortRiskDate AS DATE) AS CAN_MortRiskDate
		  ,ISNULL(CAST(c.cMort_90d AS varchar),'N/A') AS CAN_90dMort_Score
		  ,CAST(c.HospRiskDate AS DATE) AS CAN_HospRiskDate
		  ,ISNULL(CAST(c.cHosp_90d AS varchar),'N/A') AS CAN_90dHosp_Score
		  ,CASE WHEN MAX(ofr.Top1_RiskTier) OVER (PARTITION BY ofr.PatientICN)=1 AND s.StartDate IS NOT NULL THEN 1 ELSE 0 END AS OFRCareTop1
		  ,CASE WHEN ofr.PatientICN IS NOT NULL THEN 1 ELSE 0 END OFRCareAll
		  ,CASE WHEN p.MVIPersonSID IS NULL OR (MAX(ofr.Top1_RiskTier) OVER (PARTITION BY ofr.PatientICN)=1 AND s.StartDate IS NOT NULL) THEN ofr.LastVisitDate ELSE NULL END AS OFRLastVisit
		  ,mp.SourceEHR
		  ,CASE WHEN mp.DateOfDeath_Combined IS NOT NULL THEN 1 ELSE 0 END AS Deceased
	FROM [Common].[MasterPatient_Patient] mp WITH(NOLOCK)
	LEFT JOIN [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] c WITH(NOLOCK)
		ON mp.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN [PDW].[SMITR_SMITREC_DOEx_SPNowPlank3_PBNRVets] ofr WITH(NOLOCK) 
		ON mp.PatientICN=ofr.PatientICN
	LEFT JOIN [Config].[SPPRITE_OFRCare] s WITH(NOLOCK)  
		ON ofr.ChecklistID=s.ChecklistID
	LEFT JOIN [Present].[AppointmentsPast] p WITH (NOLOCK)
		ON mp.MVIPersonSID = p.MVIPersonSID
	WHERE mp.PatientICN = @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		 
END