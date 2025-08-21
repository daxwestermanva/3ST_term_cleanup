
CREATE PROCEDURE [App].[PDSI_Station]
AS
------------------------------------------------------------------------------------------------------------------------
-- Last Update:
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
------------------------------------------------------------------------------------------------------------------------
BEGIN

SET NOCOUNT ON;

Select distinct VISN, 
case when Checklistid like '596%' then '596' when checklistid like '612%' then '612' else checklistid end as Integratedsta3n,
admparent_fcdm as Facility from [LookUp].[Sta6a]
ORDER BY VISN

END