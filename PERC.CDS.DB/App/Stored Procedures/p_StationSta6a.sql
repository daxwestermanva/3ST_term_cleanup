/* =============================================
-- Author: Shalini Gupta 		 
-- Create date: 2021-10-12

-- Description:	Facility Cumulative for the Sta6a report 
-- From 2021 
 
EXEC [App].[p_StationSta6a] '541', 2021
   ============================================= */

CREATE PROCEDURE [App].[p_StationSta6a]

@ChecklistID nvarchar(1000)
,@FY nvarchar(500)
AS
BEGIN
	
	SET NOCOUNT ON;

-- Main_Sta6a
SELECT FYID
	,ChecklistID
	,Sta6a
	,DIVISION_FCDM
FROM [LookUp].[Sta6aCumulative]
WHERE ChecklistID IN (SELECT value FROM string_split(@ChecklistID ,','))
	AND FYID IN (SELECT value FROM string_split(@FY ,','))


END