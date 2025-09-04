


-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/26/2021
-- Description:	Updated Writeback SP for PDSI Patient Table
-- =============================================
CREATE PROCEDURE [App].[PDSI_Writeback_Action]
	-- Add the parameters for the stored procedure here

@Measures varchar(max)


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT * FROM 
(
	SELECT '' as MeasureActionTaken

	UNION

	SELECT  VariableName + ': ' + ActionTaken as MeasureActionTaken
	FROM [PDSI].[Definitions]
  INNER JOIN (SELECT 'No change required' as ActionTaken UNION 
			  SELECT 'Change required; action not taken yet' UNION 
			  SELECT 'Change in progress' UNION 
			  SELECT 'Change complete' UNION 
			  SELECT 'Patient refused medication changes' UNION 
			  SELECT 'Notification sent to provider' ) as a on 1=1
				 WHERE VariableName in (SELECT value FROM string_split(@Measures,','))
				 and DimensionID > 3

) as a 
ORDER BY MeasureActionTaken

END