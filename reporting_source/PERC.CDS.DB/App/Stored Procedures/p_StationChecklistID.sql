/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	distinct checklistID in all FY for the report 
 
EXEC [App].[p_StationChecklistID] 2020
   ============================================= */
CREATE PROCEDURE [App].[p_StationChecklistID] 

@FY nvarchar(500)

AS
BEGIN
	
SET NOCOUNT ON;


--ChecklistIDCumulative
Select Distinct Visn,
      ChecklistID
From Lookup.ChecklistidCumulative 
where  FYID in  (SELECT value FROM string_split(@FY ,','))
Order by Visn, ChecklistID
 
END