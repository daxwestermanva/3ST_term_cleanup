

-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	VISN 21 Stations with National and VISN21 choices
-- =============================================
CREATE PROCEDURE [App].[PDSI_MeasureDefinitions]
  --@FiscalYear varchar(50)
  @VariableName varchar(2000)
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		/***
exec [dbo].[sp_SignAppObject] @ObjectName = 'p_VISN_LSV'
***/



Select a.*
 from PDSI.[Definitions] as a

where 
VariableName in  (SELECT value FROM string_split(@VariableName ,',')) 



/*

Select a.* from (
Select distinct measure, Dimension, Case when Dimension like '%CLC%' then '3' when Dimension like '%Outpatient%' then '2'
 when Dimension like '%Original%' then '1' when Dimension like 'Geri%' then '5'
 when Dimension like '%3%' then  '4' end as DimensionID
FROM [App].[MetricBasetablePhase3]) as a
Where  dimensionID in  (SELECT value FROM string_split(@MetricGrouping ,','))
order by measure
*/
END