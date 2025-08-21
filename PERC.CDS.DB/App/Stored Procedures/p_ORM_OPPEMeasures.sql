
-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2/15/22
-- Description:	OPPE measure parameter based on ORM measure parameter
--
-- 06-08-2023 CW Adding MeasureID12
-- =============================================
CREATE PROCEDURE [App].[p_ORM_OPPEMeasures]
	

AS
BEGIN

	SET NOCOUNT ON;

SELECT MeasureNameClean
	  ,cast(MeasureID as int) as MeasureID
	  ,MeasureName ,PrintName
FROM [ORM].[MeasureDetails] WITH (NOLOCK)
WHERE MeasureID IN (3,5,10,12)
ORDER BY PrintName 

END