-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 7/5/2017
-- Description: VariableName parameter Data Set for the ORM_Definitions_Medications report
-- =============================================
/* 
	EXEC [App].[p_ORM_Definitions_Medications_VariableName] 
	
	
*/
-- =============================================
CREATE PROCEDURE [App].[p_ORM_Definitions_Medications_VariableName] 


AS
BEGIN	
SET NOCOUNT ON

Select [MedicationCategory] as VariableName, RxMeasureID
 from ORM.DefinitionsReportRx
Where [MedicationCategory] is Not Null
order by [MedicationCategory]


END