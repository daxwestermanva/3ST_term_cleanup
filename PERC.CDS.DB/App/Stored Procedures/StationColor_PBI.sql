/* =============================================
-- Author: Amy Robinson	 
-- Create date: 2021-10-12

-- Description:	Pull in station colors for PBI reports
 

   ============================================= */

CREATE PROCEDURE [App].[StationColor_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;


Select a.*,b.VISN, b.Facility as Facility2
From Lookup.StationColors as a 
inner join lookup.checklistid as b on a.checklistid = b.checklistid
Where len(a.Checklistid) >=3



END