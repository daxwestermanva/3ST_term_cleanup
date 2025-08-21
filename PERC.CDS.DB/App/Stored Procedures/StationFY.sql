/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12
-- Description:	Facility Report - all FY

 EXEC [App].[StationFY]
   ============================================= */
CREATE PROCEDURE [App].[StationFY]

AS
BEGIN
	
	SET NOCOUNT ON;

--FY
Select Distinct FYID= cast(a.FYID as varchar), FY=ConCat('FY',FYID)
from Lookup.ChecklistidCumulative   as a 
order by  FYID desc



END