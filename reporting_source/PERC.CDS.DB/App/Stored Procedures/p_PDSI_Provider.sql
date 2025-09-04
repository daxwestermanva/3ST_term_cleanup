-- =============================================
-- Author:		<Robinson,Amy>
-- Create date: <9/15/16 provider parameter >
-- TEST: EXEC [App].[p_GroupAssignments] '402',-1,-5
-- Modifications: 
--	20211014 MCP: Overhaul for PDSI revamp; modeled after App.p_GroupAssignments
-- =============================================
CREATE PROCEDURE [App].[p_PDSI_Provider]

	@Station varchar(20),
	@NoPHI varchar(10),
	@GroupType varchar(20)

AS
BEGIN

	SET NOCOUNT ON;

SELECT DISTINCT
	 CASE WHEN @NoPHI = 1 or @GroupType = -5 THEN 0 ELSE isnull (ProviderSID,-1) END ProviderSID
	,CASE WHEN @NoPHI = 1 THEN 'Dr Zhivago' 
		  WHEN  @GroupType = -5 THEN 'All Providers/Teams'  
		  ELSE ProviderName END ProviderName
	,0 as PrescriberOrder
	,CASE WHEN @NoPHI = 1 THEN 'Fake' ELSE ProviderName END as providertypedropdown
FROM [Present].[GroupAssignments_PDSI] as a
WHERE @GroupType <>-5 
	and a.ChecklistID in (SELECT value FROM string_split(@Station ,',')) 
	and (GroupID = @GroupType)

UNION ALL

SELECT 0 as ProviderSID
	  ,'All Providers/Teams' as ProviderName
	  ,0 as PrescriberOrder
	  ,'All Providers/Teams' as ProviderTypeDropDown
WHERE @GroupType = -5
ORDER BY ProviderName 

END