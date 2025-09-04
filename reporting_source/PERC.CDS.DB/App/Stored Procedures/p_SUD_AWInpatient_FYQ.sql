

-- =============================================
-- Author: Elena Cherkasova
-- Create date: 12/5/24
-- Description: Data Set for SUD AW Inpatient report parameter (FYQ).
-- =============================================
-- EXEC [App].[p_SUD_AWInpatient_FYQ]  
-- =============================================
CREATE PROCEDURE [App].[p_SUD_AWInpatient_FYQ]  
AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT FYQ
		,FYlabel = CASE WHEN FYQ LIKE 'YTD%' THEN CONCAT('YTD-',RIGHT(FYQ,6))
						ELSE CONCAT(FYQ,' ONLY') END
FROM [SUD].[AW_Inpatient_Metrics] WITH(NOLOCK)
ORDER BY FYQ DESC 

END