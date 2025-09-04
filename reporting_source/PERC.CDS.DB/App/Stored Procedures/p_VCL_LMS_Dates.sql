

/* =============================================
-- Author:		Liam Mina
-- Create date: 2025-07-22
-- Description:	Date parameter for VCL Lethal Means Safety mailing reports
-- Updates: 

--	
-- =============================================*/
CREATE PROCEDURE [App].[p_VCL_LMS_Dates]
AS
BEGIN

DROP TABLE IF EXISTS #BeginEndDates
SELECT
	CONVERT(varchar(12),WeekBegin,101) AS BeginDate
	,CONVERT(varchar(12),WeekEnd,101) AS EndDate
	,CAST(WeekBegin AS date) AS WeekBegin
	,CONVERT(varchar(12),MAX(WeekBegin) OVER (PARTITION BY NULL ORDER BY WeekBegin DESC),101) AS DefaultBeginDate
	,CONVERT(varchar(12),MAX(WeekEnd) OVER (PARTITION BY NULL ORDER BY WeekBegin DESC),101) AS DefaultEndDate
INTO #BeginEndDates
FROM [CaringLetters].[VCL_LMS_Trends] a WITH (NOLOCK)

DROP TABLE IF EXISTS #MailingDates
SELECT DISTINCT MailingDate
	,CONVERT(varchar(12),MailingDate,101) AS MailingDateDisplay
INTO #MailingDates
FROM  [CaringLetters].[VCL_LMS_Cohort] WITH (NOLOCK)

SELECT DISTINCT 
	a.BeginDate
	,a.EndDate
	,a.WeekBegin
	,CASE WHEN b.MailingDate IS NOT NULL THEN 1 ELSE 0 END AS ActiveMailings
	,b.MailingDate
	,b.MailingDateDisplay
	,a.DefaultBeginDate
	,a.DefaultEndDate
	,CAST(CONVERT(varchar(10),MAX(b.MailingDate) OVER (PARTITION BY NULL ORDER BY b.MailingDate DESC),126) as date) AS DefaultMailingDate
FROM #BeginEndDates a WITH (NOLOCK)
LEFT JOIN #MailingDates b WITH (NOLOCK) 
	ON b.MailingDate BETWEEN a.BeginDate AND a.EndDate
ORDER BY WeekBegin DESC

END