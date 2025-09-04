
-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/29/2017
-- Description: Data Set for the EBPTemplates_Clinician report parameter (Clinician).
-- 2019-12-10: Changed parameter Value from LTRIM(RTRIM(REPLACE(Clinician,',','|'))) 
-- to StaffSID to accomodate staff names with an apostrophe.
-- =============================================
-- EXEC [App].[p_EBP_Clinician] @Facility = '640'
-- =============================================
CREATE PROCEDURE [App].[p_EBP_Clinician]  @Facility NVARCHAR(15) 

AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT Clinician AS Label
	,StaffSID AS Value 
FROM EBP.Clinician 
WHERE StaPa LIKE @Facility
ORDER BY Clinician

END