-- =============================================
-- Author:		Amy Robinson
-- Create date: 7/20/17
-- Description:	Group type parameter
-- =============================================
CREATE PROCEDURE [App].[p_ORM_GroupType]



AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT  
	GroupType
	,GroupID
FROM [ORM].[GroupType]
--WHERE GroupType not like 'Unassigned'

UNION ALL

SELECT 'Station Level' as GroupType
	,-5 as GroupID

ORDER BY GroupID

END