
/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	distinct checklistID in all FY for the report 
 
EXEC [App].[StationFYChecklistid]
   ============================================= */

CREATE PROCEDURE [App].[StationFYChecklistid]

AS
BEGIN
	
	SET NOCOUNT ON;


--p_FYChecklistid -- current 
Select FYID, Checklistid
From Lookup.ChecklistidCumulative 
Where len(Checklistid) >=3
order by FYID, Checklistid



END