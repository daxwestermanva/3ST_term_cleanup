

-- =============================================
-- Author:		<Claire Hannemann>
-- Create date: <4/8/22>
-- Description:	<App.p_SPPRITE_GroupAssignments>

-- EXEC  [App].[p_SMI_GroupAssignments] '508', '1'
-- =============================================
create PROCEDURE [App].[p_SMI_GroupAssignments]
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
FROM [Present].[GroupAssignments_SMI] as a --want the same Group Assignments as what STORM uses
WHERE @GroupType <>-5 
	and (a.ChecklistID=@Station) 
	and (GroupID = @GroupType)

UNION ALL

SELECT -9 as  ProviderSID
	  ,'All Providers/Teams'  as  ProviderName
WHERE @GroupType = -5
ORDER BY ProviderName 
	
END