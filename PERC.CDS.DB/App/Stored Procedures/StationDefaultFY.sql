/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	DefaultFY for the report 

 EXEC [App].[StationDefaultFY]
   ============================================= */
CREATE PROCEDURE [App].[StationDefaultFY]

AS
BEGIN
	
	SET NOCOUNT ON;


--DefaultFY
select FYID=cast(max(FYID) as varchar) 
from Lookup.ChecklistidCumulative 
order by  FYID desc


END