-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	VISN 21 Stations with National and VISN21 choices
-- =============================================
CREATE PROCEDURE [App].[pPDSI_MetricGroupings]
  --@FiscalYear varchar(50)
  @VISN varchar(50)
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


SELECT DISTINCT
     [Dimension]
    ,[DimensionID]
FROM [PDSI].[Definitions]
order by [DimensionID]

END