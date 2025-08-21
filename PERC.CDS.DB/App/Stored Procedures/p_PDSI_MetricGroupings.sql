-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/18/2021
-- Description:	Report dataset for PDSI Phase groupings

-- Updates: 
	-- 01/07/2025	MCP: Only getting Phase 4 and up (Phase 3 measures SUD16 and ALC_top1 rolled up into Phase 6 now)
-- =============================================
CREATE PROCEDURE [App].[p_PDSI_MetricGroupings]
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
WHERE DimensionID > 4
ORDER BY [DimensionID]

END