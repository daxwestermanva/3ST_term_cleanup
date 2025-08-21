
/********************************************************************************************************************
DESCRIPTION: Risk factor list for SPPRITE parameter
TEST:
	EXEC [App].[p_SPPRITE_RiskFactors]
UPDATE:
	2019-09-04	RAS	Created procedure to use new table in Config schema
********************************************************************************************************************/

CREATE PROCEDURE [App].[p_SPPRITE_RiskFactors]

AS
BEGIN
SET NOCOUNT ON

 SELECT ID
	  ,DisplayOrder
	  ,Label
FROM [Config].[SPPRITE_RiskFactors] a
WHERE Active=1
ORDER BY DisplayOrder

END