


-- =============================================
-- Author:		Pooja Sohoni
-- Create date: 2019-11-14
-- Description: Changing from direct query to SP for the report
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_ClinicalCategories]
	-- Add the parameters for the stored procedure here

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
SELECT [ClinicalDetailCategory]
      ,[DiseaseDisorder]
      ,[Description]
      ,[DxMeasureID]
FROM [ORM].[DefinitionsReportRelevantDx]
WHERE [ClinicalDetailCategory] IS NOT NULL

END