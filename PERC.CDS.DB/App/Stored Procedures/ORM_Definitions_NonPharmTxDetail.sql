


-- =============================================
-- Author:		Pooja Sohoni
-- Create date: 2019-11-14
-- Description: Changing from direct query to SP for the report
-- Modifications:
	-- 2020-03-06	RAS	Changed where statement to use "=" instead of "IN" (single-value parameter).  Cleaned up formatting.

-- EXEC [App].[ORM_Definitions_NonPharmTxDetail] @VariableName = 'Chiropractic Care'
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_NonPharmTxDetail]
	-- Add the parameters for the stored procedure here
	@VariableName VARCHAR(100)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
SELECT [Non-Pharmacological Pain Treatment]
	  ,Description
	  ,Rationale
	  ,CPTCohort
	  ,StopCodeCohort
	  ,ICD10Proc
	  ,Exclusion
	  ,Category1
FROM [ORM].[NonPharmPainTxDetails]
WHERE [Non-Pharmacological Pain Treatment] = @VariableName

END