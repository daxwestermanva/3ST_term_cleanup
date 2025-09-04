
/********************************************************************************************************************
DESCRIPTION: ORM Definitions - CPT subreport

TEST:
	EXEC [App].[ORM_Definitions_CPT] 'Psych_Assessment,Psych_Therapy'

UPDATE:
	2019-10-11	RAS	Changed to pivot LookUp.CPT directly
	2022-05-02	RAS	Refactored to use LookUp.ListMember instead of LookUp CPT
********************************************************************************************************************/

CREATE PROCEDURE [App].[ORM_Definitions_CPT]
	@CPTCategory VARCHAR(500) 
AS
BEGIN

	SET NOCOUNT ON;

  DECLARE @CPTList TABLE (CPTCategory VARCHAR(100))
  -- Add values to the table
  INSERT @CPTList SELECT value FROM string_split(@CPTCategory, ',')

SELECT DISTINCT 
	d.CPTName
	,d.CPTDescription
    ,d.CPTCode
    ,CPTCategory = lm.List
FROM [LookUp].[ListMember] lm
-- it works OK to only join to VistA dim data because returned dataset 
	-- is not at SID level (as long as all CPTCodes are accounted for)
INNER JOIN [Dim].[CPT] d ON d.CPTSID = lm.ItemID
INNER JOIN @CPTList l on l.CPTCategory = lm.List
WHERE Domain = 'CPT'

END