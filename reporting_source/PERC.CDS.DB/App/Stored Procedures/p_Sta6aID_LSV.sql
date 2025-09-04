-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/25/2016
-- Description:	Station list for user's LSV access stations only
	--	EXEC [App].[p_Sta6aID_LSV] @User='VHA21\VHAPALSTEPHR6', @VISN='1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23'
-- =============================================
CREATE PROCEDURE [App].[p_Sta6aID_LSV]
  @User varchar(50),
  @VISN varchar(60) --Changed from 10 to allow for multiple VISN selection where applicable
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
SELECT DISTINCT 
	a.STA6AID
	,a.ChecklistID
    ,a.Facility
	,a.ADMPARENT_FCDM
	,a.STA3N
	,a.FacilityLevelID
	,a.VISN
FROM [LookUp].[ChecklistID] as a WITH (NOLOCK)
INNER JOIN (select sta3n from app.access (@User)) as Access on left(a.STA6AID,3) = Access.sta3n 
WHERE VISN in  (SELECT value FROM string_split(@VISN ,','))  
ORDER BY VISN,STA6AID 


END
