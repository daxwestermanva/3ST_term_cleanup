/* =============================================
-- Author:		Catherine Barry/Rebecca Stephens
-- Create date: 2018-06-21
-- Description:	Release date parameter list for Reach_HistoricMetricBaseTable report
-- Updates:
--	2020-06-26	LM	Changed to get most recent release date from REACH.MonthlyMetrics
-- =============================================*/
CREATE PROCEDURE [App].[p_REACH_ReleaseDate]
AS
BEGIN
SELECT DISTINCT 
	ReleaseDate
	,convert(varchar(12),ReleaseDate,101) as DisplayDate --101 is format style mm/dd/yyyy
FROM [REACH].[MonthlyMetrics]
WHERE (ReleaseDate > '2017-03-01')
ORDER BY ReleaseDate DESC
END