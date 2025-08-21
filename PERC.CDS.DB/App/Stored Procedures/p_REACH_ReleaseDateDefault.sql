/* =============================================
-- Author:		Catherine Barry/Rebecca Stephens
-- Create date: 2018-06-21
-- Description:	Provides parameter default of most recent release date for Reach_HistoricMetricBaseTable report
-- Updates:
-- 2020-06-26	LM	Changed to get most recent release date from REACH.MonthlyMetrics
-- =============================================*/

CREATE PROCEDURE [App].[p_REACH_ReleaseDateDefault]
AS
BEGIN
SELECT TOP (1) ReleaseDate
FROM [REACH].[MonthlyMetrics]
ORDER BY ReleaseDate DESC
END