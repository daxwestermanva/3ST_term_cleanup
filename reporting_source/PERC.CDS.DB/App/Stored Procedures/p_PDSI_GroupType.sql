-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/14/2021
-- Description:	Group type parameter for PDSI
-- =============================================
CREATE PROCEDURE [App].[p_PDSI_GroupType]
	@Station VARCHAR(100)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--	DECLARE @Station VARCHAR(100) = '21,640,612A4'
	--	DECLARE @Station VARCHAR(100) = '21'

DECLARE @StationList TABLE (ChecklistID VARCHAR(5))
INSERT @StationList SELECT value FROM string_split(@Station,',')

SELECT  
	 GroupType
	,CASE WHEN GroupType like 'PDSI Prescriber' THEN 1
	 ELSE GroupID END GroupID
FROM [PDSI].[GroupType]
WHERE GroupID in (2,3,4,5,6,7,9)
--WHERE GroupType not like 'Unassigned'
	-- RAS: Added the below in order to HIDE the provider-specific options if no station is selected
		-- i.e., if you choose VISN or National, you can only view station level data
		-- if you want a specific group, you need to choose a station
	AND (SELECT MAX(LEN(ChecklistID)) FROM @StationList)>2 

UNION ALL

SELECT 'Station Level' as GroupType
	,-5 as GroupID

ORDER BY GroupID

END