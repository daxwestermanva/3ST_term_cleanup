

-- =============================================
-- Author:		Pooja Sohoni
-- Create date: 2019-11-14
-- Description: Changing from direct query to SP for the report
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_MedicationDetail]
	-- Add the parameters for the stored procedure here
	@VariableName NUMERIC

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
SELECT [MedicationCategory]
      ,[Description]
      ,NationalDrug_PrintName
	  ,Exclusions
      ,[RxMeasureID]
  FROM ORM.DefinitionsReportRx
where [MedicationCategory] is not null
and [RxMeasureID] in (@VariableName)

END