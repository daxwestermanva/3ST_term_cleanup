/****************************************************
Author: Tolessa Gurmessa
Date: 10/8/2021
Description: Stop code crosswalk
*****************************************************/

CREATE PROCEDURE [App].[StopCodeCategories]
	
AS
BEGIN

	SET NOCOUNT ON;


SELECT distinct

      [StopCodeDescription] 
      ,[StopCode] 
      ,[stop] as Stop1
  FROM ORM.DefinitionsReportStopCode

END