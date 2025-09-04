

-- =============================================
-- Author:	Liam Mina	 
-- Create date: 05/12/2022
-- Description:	Crosswalk between Health Factors and DTAs
-- =============================================
CREATE PROCEDURE [App].[Definitions_HealthFactorDTACrosswalk]

	@Category varchar(max)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
 

SELECT a.List
	,a.Category
	,a.PrintName
	,a.Description
	,b.SearchTerm AS HealthFactorType
	,b.SearchType AS HealthFactorSearchType
	,c.Attribute AS DTAorComment
	,c.SearchTerm AS DTAEvent
	,c.SearchTerm2 AS DTAEventResult
	,c.SearchType AS DTASearchType
FROM Lookup.List a
LEFT JOIN (SELECT * FROM Lookup.ListMappingRule WHERE Domain='HealthFactorType') b ON a.List=b.List
LEFT JOIN (SELECT * FROM Lookup.ListMappingRule WHERE Domain='PowerForm') c ON a.List=c.List
WHERE (b.List IS NOT NULL OR c.List IS NOT NULL)
AND a.Category IN (SELECT value FROM string_split(@Category ,','))


END