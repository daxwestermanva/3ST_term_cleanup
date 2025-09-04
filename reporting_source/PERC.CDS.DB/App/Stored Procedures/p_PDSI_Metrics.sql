-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	PDSI Measure Parameter
-- TESTING:
	--	EXEC  [App].[p_PDSI_Metrics] @MetricGrouping = '4,5,6,7,8'
-- Modifications: 
--	20211014 MCP - Updating for use with PDSI revamp
--	20241202 MCP - Updating for Phase 6, adding MHIS measure names and original PDSI measure names
-- =============================================
CREATE PROCEDURE [App].[p_PDSI_Metrics]

  @MetricGrouping varchar(50)
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT 
		VariableName AS Measure
		-- CASE WHEN DimensionID = 8 THEN MeasureMnemonic ELSE VariableName END AS Measure
		,VariableNameClean
		,MeasureID
		,Dimension
		,DimensionID
		,MeasureMnemonic AS MHISMeasureMnemonic
		,VariableName AS PDSIMeasureName
FROM [PDSI].[Definitions]
WHERE DimensionID > 3 
	AND DimensionID IN (SELECT value FROM string_split(@MetricGrouping ,',')) 
	AND MeasureID <> 5117
ORDER BY DimensionID,MeasureID 

END