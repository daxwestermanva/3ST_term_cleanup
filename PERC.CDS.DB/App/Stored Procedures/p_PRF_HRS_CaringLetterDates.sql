
/* =============================================
-- Author:		Liam Mina
-- Create date: 2023-03-20
-- Description:	Release date parameter list for PRF_HRS Caring Letter reports
-- Updates:
--	
-- =============================================*/
CREATE PROCEDURE [App].[p_PRF_HRS_CaringLetterDates]
AS
BEGIN
SELECT DISTINCT 
	CONVERT(varchar(12),WeekBegin,101) AS BeginDate
	,CONVERT(varchar(12),WeekEnd,101) AS EndDate
	,WeekBegin
	,CASE WHEN b.MailingDate IS NOT NULL THEN 1 ELSE 0 END AS ActiveMailings
	,b.MailingDate
	,CONVERT(varchar(12),b.MailingDate,101) AS MailingDateDisplay
	,CONVERT(varchar(12),MAX(WeekBegin) OVER (PARTITION BY NULL ORDER BY WeekBegin DESC),101) AS DefaultBeginDate
	,CONVERT(varchar(12),MAX(WeekEnd) OVER (PARTITION BY NULL ORDER BY WeekBegin DESC),101) AS DefaultEndDate
	--,MAX(MailingDate) OVER (PARTITION BY NULL ORDER BY MailingDate DESC) AS DefaultMailingDate
	,CAST(CONVERT(varchar(10),MAX(b.MailingDate) OVER (PARTITION BY NULL ORDER BY b.MailingDate DESC),126) as date) AS DefaultMailingDate
FROM [CaringLetters].[HRF_Trends] a WITH (NOLOCK)
LEFT JOIN [CaringLetters].[HRF_Mailings] b WITH (NOLOCK) 
	ON b.MailingDate BETWEEN a.WeekBegin AND a.WeekEnd--DateAdd(day,6,a.WeekBegin) AND DateAdd(Day,6,a.WeekEnd)
WHERE a.WeekBegin >= '2023-01-01'
ORDER BY WeekBegin DESC
END