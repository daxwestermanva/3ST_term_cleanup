-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/20/2017
-- Description: Main Data Set for the EBPTemplates_Clinician_Detail report
-- =============================================
/* 
	EXEC [App].[EBP_ClinicianDetail]  	
	@Facility = '640' ,
	@Clinician = ''
	
*/
-- =============================================
CREATE PROCEDURE [App].[EBP_ClinicianDetail]
@Facility NVARCHAR (15),
@Clinician VARCHAR(MAX)

AS
BEGIN	
SET NOCOUNT ON

DECLARE @Clinicians TABLE (Clinician1 VARCHAR(153))
INSERT @Clinicians SELECT LTRIM(RTRIM(REPLACE(value,',','|'))) FROM string_split(@Clinician, ',')
	--	SELECT * FROM @Clinicians

SELECT [ClinicianLastName]
,[ClinicianFirstName]
,[ClinicianMiddleName]
,CONCAT(ClinicianLastName, ',', ClinicianFirstName) as ClinicianName
,[VISN]
,[admparent_fcdm]
,[StaPa]
,CASE WHEN a.[Reportingperiod] LIKE 'YTD' THEN 'Last 12 Months' ELSE a.ReportingPeriod END AS ReportingPeriod
,reportingperiodid
,CASE WHEN [Month] LIKE 'NULL' THEN 'YTD' ELSE [Month] END AS Month
,[year]
,[TotalSessionsAllEBPs]
,[TotalPatientsAllEBPs]
,[MH_ACT_Sessions]
,[MH_ACT_Patients]
,[MH_BFT_Sessions]
,[MH_BFT_Patients]
,[MH_CB_SUD_Sessions]
,[MH_CB_SUD_Patients]
,[MH_CBT_D_Sessions]
,[MH_CBT_D_Patients]
,[MH_CBT_I_Sessions]
,[MH_CBT_I_Patients]
,[MH_CBTSP_Sessions]          
,[MH_CBTSP_Patients] 
,[MH_CM_Sessions]          
,[MH_CM_Patients] 
,[MH_CPT_Sessions]
,[MH_CPT_Patients]
,[MH_DBT_Sessions]          
,[MH_DBT_Patients]
,[MH_EMDR_Sessions]
,[MH_EMDR_Patients]
,[MH_IBCT_Sessions]
,[MH_IBCT_Patients]
,[MH_IPT_For_Dep_Sessions]
,[MH_IPT_For_Dep_Patients]
,[MH_PEI_Sessions]
,[MH_PEI_Patients]
,[MH_PST_Sessions]          
,[MH_PST_Patients]
,[MH_SST_Sessions]
,[MH_SST_Patients]
,[MH_WET_Sessions]
,[MH_WET_Patients]
,a.[Clinician]
,a.[StaffSID]
FROM EBP.Clinician AS a 
LEFT JOIN App.EBP_ReportingPeriodID  AS b ON a.reportingperiod = b.reportingperiod 
INNER JOIN @Clinicians AS c ON c.Clinician1=a.StaffSID
WHERE StaPa = @Facility 
ORDER BY VISN, StaPa, ClinicianLastName

END