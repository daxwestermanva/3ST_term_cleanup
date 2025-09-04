/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	Facility Cumulative for the report 
 
EXEC [App].[p_StationChecklistIDCumulative] 640, 2020
   ============================================= */
CREATE PROCEDURE [App].[p_StationChecklistIDCumulative]

@ChecklistID nvarchar(1000)
,@FY nvarchar(500)

AS
BEGIN
	
SET NOCOUNT ON;

--ChecklistIDCumulative
Select
      FYID=cast(FYID as varchar),  
      ChecklistID, 
      STA6AID, 
      VISN_FCDM, 
      VISN, 
      ADMPARENT_FCDM, 
      ADMParent_Key, 
      CurSTA3N, 
      District, 
      STA3N, 
      FacilityID, 
      FacilityLevel, 
      FacilityLevelID, 
      Nepec3n, 
      Facility,
	  StaPa,
      ADMPSortKey,
      MCGName,
      MCGKey 
FROM [LookUp].[ChecklistidCumulative] a
WHERE ChecklistID IN (SELECT value FROM string_split(@ChecklistID ,','))
    AND FYID IN (SELECT value FROM string_split(@FY ,','))
ORDER BY FYID desc, VISN, ChecklistID


END