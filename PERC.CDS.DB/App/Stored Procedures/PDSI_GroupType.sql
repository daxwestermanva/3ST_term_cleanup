-- =============================================
-- Author:		<Sara Tavakoli>
-- Create date: <9/15/16>

-- =============================================
CREATE PROCEDURE [App].[PDSI_GroupType]



AS
BEGIN

	SET NOCOUNT ON;


Select distinct grouptype, groupid from PDSI.GroupType
where groupid < 8
--where groupid <> 7
union 

select 'Station' as grouptype , -5 as groupID
END