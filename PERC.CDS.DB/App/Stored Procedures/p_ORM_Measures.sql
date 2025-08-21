-- =============================================
-- Author:		Amy Robinson
-- Create date: 5/9/17
-- Description:	ORM measure parameter
-- =============================================
CREATE PROCEDURE [App].[p_ORM_Measures]

@RiskGroup varchar(100)
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
--select distinct cast(rtrim(ltrim(sta6aid)) as int) as sta6aid from datatable order by cast(rtrim(ltrim(sta6aid)) as int)
(Select MeasureNameClean
	  ,cast(MeasureID as int) as MeasureID
	  ,MeasureName ,PrintName
from [ORM].[MeasureDetails]
where MeasureID <> 9 and  ((('5' =  @RiskGroup ) and OUD = 1) or ('5' <>  @RiskGroup))

UNION 

select 
'All Patients' as MeasureNameClean
,-5 as measureid
,'All Patients' as MeasureNameClean,'All Patients' as PrintName)

order by PrintName 





END