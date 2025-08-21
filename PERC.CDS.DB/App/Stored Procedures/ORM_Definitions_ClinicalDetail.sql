
-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 7/2/2017
-- Description: Main Data Set for the ORM_Definitions_ClinicalDetail report
-- =============================================
/* 
	EXEC [App].[ORM_Definitions_ClinicalDetail] 
	@VariableName = '1,2,3,4'
	
*/
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_ClinicalDetail] 
@VariableName VARCHAR(500)

AS
BEGIN	
SET NOCOUNT ON

DECLARE @VariableNames TABLE (VariableName INT)

INSERT @VariableNames SELECT value FROM string_split(@VariableName, ',')

SELECT rd.[ClinicalDetailCategory]
      ,rd.[DiseaseDisorder]
      ,rd.[Description]
      ,rd.[DiagnosisCohort]
      ,rd.[StopCodeCohort]
      ,rd.[Exclusion]
      ,rd.[DxMeasureID]
FROM [ORM].[DefinitionsReportRelevantDx] rd
INNER JOIN @VariableNames AS v ON v.VariableName  = rd.DxMeasureID


END