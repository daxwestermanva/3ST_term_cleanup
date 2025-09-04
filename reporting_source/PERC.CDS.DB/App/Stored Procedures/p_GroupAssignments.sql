/* =============================================
-- Author:		Amy Robinson
-- Date:		12/19/2017 
-- Description:	<Description,,>
-- TEST: EXEC [App].[p_GroupAssignments] '640',-1,-5
-- Modifications:
	20181011 RAS: Formatting. Changed Outbox reference to Present GroupAssignments STORM

-- ============================================*/
CREATE PROCEDURE [App].[p_GroupAssignments]

  -- Add the parameters for the stored procedure here
  @Station as varchar(max),
  @NoPHI as varchar(10),
  @GroupType as varchar(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT
	 CASE WHEN @NoPHI = 1 or @GroupType = -5 THEN  0 ELSE isnull (ProviderSID,-1) END ProviderSID
	,CASE WHEN @NoPHI = 1 THEN 'Dr Zhivago' 
		  WHEN  @GroupType = -5 THEN 'All Providers/Teams'  
		  ELSE ProviderName END ProviderName
	,0 as prescriberorder
	,CASE WHEN @NoPHI = 1 THEN 'Fake' ELSE ProviderName END as providertypedropdown
FROM [Present].[GroupAssignments_STORM] as a
WHERE @GroupType <>-5 
	and a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
	and (GroupID = @GroupType)

UNION ALL

SELECT 0 as  ProviderSID
	  ,'All Providers/Teams'  as  ProviderName
	  ,0 as PrescriberOrder
	  ,'All Providers/Teams' as  ProviderTypeDropDown
WHERE @GroupType = -5
ORDER BY ProviderName 

END