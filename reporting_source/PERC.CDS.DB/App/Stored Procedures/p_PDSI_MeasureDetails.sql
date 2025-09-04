-- =============================================
-- Author:		<Amy Robinson/SaraTavakoli
-- Create date: <03/27/2014>
-- Description:	<Creates table for patient medication detail report>
-- Modifications

-- =============================================
CREATE PROCEDURE [App].[p_PDSI_MeasureDetails]



AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


SELECT distinct 
       [VariableNameClean]
      ,[VariableName]
      ,[DimensionID]
  FROM [PDSI].[definitions]
  WHERE DashboardOrder not like 12
  order by [DimensionID] desc, VariableName



;
END