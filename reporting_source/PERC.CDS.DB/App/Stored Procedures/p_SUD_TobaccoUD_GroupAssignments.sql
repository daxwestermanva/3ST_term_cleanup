

-- =============================================
-- Author:		<Claire Hannemann>
-- Create date: <4/5/2024>
-- Description:	<App.p_SUD_TobaccoUD_GroupAssignments>

-- EXEC  [App].[p_SUD_TobaccoUD_GroupAssignments] '508', '2'
-- =============================================
CREATE PROCEDURE [App].[p_SUD_TobaccoUD_GroupAssignments]
	@Station varchar(5),
	@GroupType as varchar(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	SELECT DISTINCT
	 ProviderSID
	,case when ProviderSID=-1 then '*Unassigned' else ProviderName end as ProviderName
FROM [Present].[GroupAssignments] as a 
WHERE @GroupType <>-5 
	and (a.ChecklistID=@Station) 
	and (GroupID = @GroupType)
	and GroupID in (2,3,4,5)

UNION ALL

SELECT -9 as  ProviderSID
	  ,'All Providers/Teams'  as  ProviderName
WHERE @GroupType = -5
ORDER BY ProviderName 
	
END