-- =============================================
-- Author: Elena Cherkasova
-- Create date: 4/22/2017
-- Description: Main Data Set for the EBPTemplates_Clinician_Lookup 
-- Modifications:
-- =============================================
/*  Testing:
	EXEC [App].[EBP_Clinician_Lookup]	
	@StaffLastName='tramm'
*/

CREATE PROCEDURE [App].[EBP_Clinician_Lookup] 

	@StaffLastName VARCHAR(MAX)
AS
BEGIN	

SELECT  distinct a.StaffSID
	  ,a.ClinicianLastName
	  ,a.ClinicianFirstName
	  ,a.ClinicianMiddleName
	  ,CONCAT(a.ClinicianLastName, ',', a.ClinicianFirstName) as ClinicianName
	  ,[VISN]
	  ,a.admparent_fcdm
	  ,a.StaPa    
	  ,a.Clinician
	  ,a.Year
FROM [EBP].[Clinician] as a 
WHERE Clinician like '%' + @StaffLastName + '%' and Year IS NULL
ORDER BY ClinicianLastName,ClinicianFirstName,VISN,StaPa

END