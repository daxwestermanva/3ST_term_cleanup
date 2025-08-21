
-- =============================================
-- Author: Elena Cherkasova 
-- Create date: 2021-12-03
-- Description: Data Set for the EBPTemplates_MonthlySummary and EBPTemplates_QuarterlySummary report parameters (Template).
-- =============================================
-- EXEC [App].[p_EBP_Template] 
-- =============================================
CREATE PROCEDURE [App].[p_EBP_Template]  
AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT  TemplateNameClean, TemplateName 
FROM Config.EBP_TemplateLookUp
ORDER BY TemplateName

END