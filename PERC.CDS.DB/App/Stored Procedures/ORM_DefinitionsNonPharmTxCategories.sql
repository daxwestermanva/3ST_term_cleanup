

-- =============================================
-- Author:		Pooja Sohoni
-- Create date: 2019-11-14
-- Description: Changing from direct query to SP for the report
-- =============================================
CREATE PROCEDURE [App].[ORM_DefinitionsNonPharmTxCategories]
	-- Add the parameters for the stored procedure here

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
Select [Non-Pharmacological Pain Treatment]
as VariableName,
Category1
 from ORM.NonPharmPainTxDetails
Where [Non-Pharmacological Pain Treatment] is Not Null
order by [Non-Pharmacological Pain Treatment]

END