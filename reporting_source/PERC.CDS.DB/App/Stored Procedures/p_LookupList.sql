-- =============================================
-- Author:		Liam Mina
-- Create date: 5/12/2022
-- Description:	Get categories from Lookup.List
-- =============================================
CREATE PROCEDURE  [App].[p_LookupList]
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
  
SELECT DISTINCT a.Category
From Lookup.List a
INNER JOIN Lookup.ListMappingRule b 
	ON a.List=b.List
WHERE b.Domain IN ('HealthFactorType','PowerForm')
ORDER BY Category
  
END