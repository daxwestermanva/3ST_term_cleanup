 
 
-- =============================================
-- Author: Elena Cherkasova 
-- Create date: 4/19/2017
-- Description: Main Data Set for the EBPTemplates_Clinician, EBPTemplates_Clinician_PDF, and EBPTemplates_Clinician_National reports
-- Modifications:
	-- 2018? - RAS - Renamed from [App].[EBP_EBPTemplates_Clinician]. Pointed to EBP.Clinicians instead of old app.EBP_DashboardBaseTable_Clinician
	-- 20190325 - EC - Added MH_CM_Patients and MH_CM_Sessions
	-- 20191210 - EC - Changed @Clinician parameter to use StaffSID instead of old "LTRIM(RTRIM(c.Clinician1)) = LTRIM(RTRIM(REPLACE(a.Clinician,',','|')))"
	-- 20191211 - RAS - Formatting and removed unnecessary subquery.
	-- 20191211 - RAS - Simplified @Clinicians query by replacing "LTRIM(RTRIM(REPLACE(CAST(Item AS VARCHAR(MAX)),',','|')))" with "Item"
	-- 20210511 - RAS - Combined logic for Clinician_National using IF statement so only 1 SP is needed for both versions of report.
	-- 20210518 - JEB - Enclave work - updated SStaff Synonym use. No logic changes made.	
	-- 20210924 - EC - Adding 2 new templates: CBT-SP and DBT
	-- 20220121 - EC - Adding PST Templates and switching to StaPa
	-- 20240821 - EC - Adding EMDR and WET/WNE Templates
-- =============================================
/*  Testing:
	EXEC [App].[EBP_Clinician]	
	@Facility = '640' ,
	@Clinician = '',
	@Month = 1
*/
 
CREATE PROCEDURE [App].[EBP_Clinician] 
	@Facility NVARCHAR (15),
	@Clinician VARCHAR(MAX),
	@Month FLOAT
AS
BEGIN	
 
DECLARE @Clinicians TABLE (StaffSID VARCHAR(153))
 
IF @Facility = '0' -- Clinicians w/multiple facilities
	BEGIN
		INSERT @Clinicians
		SELECT DISTINCT a.StaffSID
		FROM [EBP].[Clinician] AS a 
		INNER JOIN [SStaff].[SStaff] AS b ON a.StaffSSN=b.StaffSSN
		WHERE b.StaffSID=@Clinician;
	END
 
ELSE 	--Create a table from the list of clinicians selected in the parameter
	BEGIN
	INSERT @Clinicians SELECT value FROM string_split(@Clinician, ',')
	END
 
SELECT a.ClinicianLastName
	  ,a.ClinicianFirstName
	  ,a.ClinicianMiddleName
	  ,CONCAT(a.ClinicianLastName, ',', a.ClinicianFirstName) as ClinicianName
	  ,a.VISN
	  ,a.ADMPARENT_FCDM
	  ,a.StaPa
	  ,CASE WHEN a.ReportingPeriod LIKE 'YTD' THEN 'Last 12 Months' ELSE a.ReportingPeriod END AS ReportingPeriod
	  ,rp.ReportingPeriodID
	  ,CASE WHEN Month LIKE 'NULL' THEN 'YTD' ELSE Month END AS Month
	  ,a.Year
	  ,a.TotalSessionsAllEBPs
	  ,a.TotalPatientsAllEBPs
	  ,a.MH_ACT_Sessions
	  ,a.MH_ACT_Patients
	  ,a.MH_BFT_Sessions
	  ,a.MH_BFT_Patients
	  ,a.MH_CB_SUD_Sessions
	  ,a.MH_CB_SUD_Patients
	  ,a.MH_CBT_D_Sessions
	  ,a.MH_CBT_D_Patients
	  ,a.MH_CBT_I_Sessions
	  ,a.MH_CBT_I_Patients
	  ,a.MH_CBTSP_Sessions      
	  ,a.MH_CBTSP_Patients  
	  ,a.MH_CM_Sessions      
	  ,a.MH_CM_Patients
	  ,a.MH_CPT_Sessions
	  ,a.MH_CPT_Patients
	  ,a.MH_DBT_Sessions      
	  ,a.MH_DBT_Patients 
	  ,a.MH_EMDR_Sessions      
	  ,a.MH_EMDR_Patients 
	  ,a.MH_IBCT_Sessions
	  ,a.MH_IBCT_Patients
	  ,a.MH_IPT_For_Dep_Sessions
	  ,a.MH_IPT_For_Dep_Patients
	  ,a.MH_PEI_Sessions
	  ,a.MH_PEI_Patients
	  ,a.MH_PST_Sessions      
	  ,a.MH_PST_Patients 
	  ,a.MH_SST_Sessions
	  ,a.MH_SST_Patients
	  ,a.MH_WET_Sessions      
	  ,a.MH_WET_Patients 
	  ,a.Clinician
	  ,a.StaffSID
FROM [EBP].[Clinician] as a 
LEFT JOIN [App].[EBP_ReportingPeriodID]  AS rp ON a.Reportingperiod = rp.ReportingPeriod
INNER JOIN @Clinicians AS c ON c.StaffSID=a.StaffSID 
WHERE rp.ReportingPeriodID = @Month
	AND (a.StaPa = @Facility OR @Facility = '0') 
ORDER BY a.VISN
	,a.StaPa
	,a.ClinicianLastName
	,a.ClinicianFirstName
 
END