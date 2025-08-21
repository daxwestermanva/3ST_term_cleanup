/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	distinct checklistID in all FY for the station report 
 
EXEC [App].[p_StationDefaultChecklistID] '2020'
   ============================================= */
CREATE PROCEDURE [App].[p_StationDefaultChecklistID]

@FY nvarchar(500)
AS
BEGIN
	
	SET NOCOUNT ON;


--DefaultChecklistID
Select FYID, Checklistid
From Lookup.ChecklistidCumulative 
where  FYID in  (SELECT value FROM string_split(@FY ,','))
order by FYID, Checklistid




END