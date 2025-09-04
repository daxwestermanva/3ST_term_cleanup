

/********************************************************************************************************************
-- Author:		Grace Chung
-- Create date: 5/20/2024
-- Description:	Trend report for VCL caring letters
-- Updates:	7/03/2024: GC  Remove NotEnrolledFlagReactivated column
--                     GC  Remove date limit to pull historic data 
--          8/20/2024  GC  Update date range to start from June 2020 
********************************************************************************************************************/
CREATE PROCEDURE [Code].[CaringLetters_VCL_Trends] 
AS
BEGIN 

--CL data is run on Saturdays, to capture inactivations the preceding week ending on Friday.
DROP TABLE IF EXISTS #WeekEpisodes
SELECT CAST(Date AS date) AS WeekBegin
	,CAST(DateAdd(day,6,Date) AS date) AS WeekEnd
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=7 --Saturday
and date Between '2020-06-01' and  getdate()
--AND CAST(DateAdd(day,6,Date) AS date) < GETDATE()
--AND Date >= '2024-05-18'
 
	
DROP TABLE IF EXISTS #NotEnrolledCount --currently no donotsend reason
SELECT DISTINCT b.WeekBegin, count(DISTINCT a.MVIPersonSID) AS Count
	,CASE WHEN DoNotSendReason IN ('Bad Address','Unable to receive mail') THEN 'Bad Address' ELSE DoNotSendReason END AS DoNotSendReason
INTO #NotEnrolledCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE FirstLetterDate IS NULL AND DoNotSend=1
AND DoNotSendReason is not null
GROUP BY WeekBegin, CASE WHEN DoNotSendReason IN ('Bad Address','Unable to receive mail') THEN 'Bad Address' ELSE DoNotSendReason END  
ORDER BY WeekBegin, DoNotSendReason

DROP TABLE IF EXISTS #EnrolledCount
SELECT b.WeekBegin, COUNT(DISTINCT a.MVIPersonSID) AS EnrolledCount
INTO #EnrolledCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.FirstLetterDate IS NOT NULL --indicates they are enrolled
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #MailingsSentCount
SELECT b.WeekBegin, COUNT(*) AS MailingsSentCount
INTO #MailingsSentCount
FROM [CaringLetters].[VCL_Mailings] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.MailingDate AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.ActiveMailingRecord = 1 AND a.DoNotSend = 0
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #DeceasedCount --no donotsend reason
SELECT b.WeekBegin, Count(*) AS DeceasedCount
INTO #DeceasedCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.DoNotSend=1 AND DoNotSendReason LIKE '%Deceased%' AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #OptOutCount
SELECT b.WeekBegin, Count(*) AS OptOutCount
INTO #OptOutCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.DoNotSend=1 AND DoNotSendReason IN ('Patient Opt Out','Opted out') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #DataSetOptOutCount
SELECT b.WeekBegin, Count(*) AS DataSetOptOutCount
INTO #DataSetOptOutCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.DoNotSend=1 AND DoNotSendReason IN ('Data Set Opt Out') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #BadAddressCount
SELECT b.WeekBegin, Count(*) AS BadAddressCount
INTO #BadAddressCount
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.DoNotSend=1 AND (DoNotSendReason LIKE '%Mail%' OR DoNotSendReason LIKE '%Address%') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #InterventionCompleteCount   
SELECT b.WeekBegin, COUNT(*) AS CompletedInterventionCount
INTO #InterventionCompleteCount
FROM [CaringLetters].[VCL_Mailings] a WITH (NOLOCK) 
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.MailingDate AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.ActiveMailingRecord= 1 AND a.LetterNumber = 8
GROUP BY WeekBegin
ORDER BY WeekBegin



DROP TABLE IF EXISTS #StageTrends
SELECT DISTINCT a.WeekBegin
	,a.WeekEnd
	--,b.ActiveFlagCount AS ActiveFlagCountAll
	--,c.ActivationCount AS ActivationCountAll
	--,d.InactivationCount AS InactivationCountAll
	--,q.ActiveFlagCount AS ActiveFlagCountActiveCL
	--,r.ActivationCount AS ActivationCountActiveCL
	--,s.InactivationCount AS InactivationCountActiveCL
	,k.Total_Not_Enrolled AS NotEnrolledCount
	,l.Count AS NotEnrolledDeceased
	,m.Count AS NotEnrolledAddress
	,n.Count AS NotEnrolledIneligible
	,o.Count AS NotEnrolledVCLCL
	,p.Count AS NotEnrolledOptOut
	,t.Count AS NotEnrolledHRFCL
	--,u.Count AS NotEnrolledFlagReactivated
	,e.EnrolledCount
	,f.MailingsSentCount
	,g.DeceasedCount
	,h.OptOutCount
	,ds.DataSetOptOutCount
	,i.BadAddressCount
	,j.CompletedInterventionCount
INTO #StageTrends
FROM #WeekEpisodes a
--INNER JOIN #ActiveFlags b ON a.WeekBegin=b.WeekBegin AND b.ActiveSite IS NULL
--LEFT JOIN #ActivationCount c ON a.WeekBegin=c.WeekBegin AND c.ActiveSite IS NULL
--LEFT JOIN #InactivationCount d ON a.WeekBegin=d.WeekBegin AND d.ActiveSite IS NULL
LEFT JOIN #EnrolledCount e ON a.WeekBegin=e.WeekBegin
LEFT JOIN #MailingsSentCount f ON a.WeekBegin=f.WeekBegin
LEFT JOIN #DeceasedCount g ON a.WeekBegin=g.WeekBegin
LEFT JOIN #OptOutCount h ON a.WeekBegin=h.WeekBegin
LEFT JOIN #DataSetOptOutCount ds ON a.WeekBegin=ds.WeekBegin
LEFT JOIN #BadAddressCount i ON a.WeekBegin=i.WeekBegin
LEFT JOIN #InterventionCompleteCount j ON a.WeekBegin=j.WeekBegin
LEFT JOIN (select weekbegin, SUM(COUNT) Total_Not_Enrolled FROM #NotEnrolledCount Group by weekbegin) k ON a.WeekBegin=k.WeekBegin  
LEFT JOIN #NotEnrolledCount l ON a.WeekBegin=l.WeekBegin AND l.DoNotSendReason ='Deceased'
LEFT JOIN #NotEnrolledCount m ON a.WeekBegin=m.WeekBegin AND m.DoNotSendReason = 'Bad Address'
LEFT JOIN #NotEnrolledCount n ON a.WeekBegin=n.WeekBegin AND n.DoNotSendReason = 'Ineligible for VA Care'
LEFT JOIN #NotEnrolledCount o ON a.WeekBegin=o.WeekBegin AND o.DoNotSendReason = 'Previously Enrolled in VCL CL'
LEFT JOIN #NotEnrolledCount p ON a.WeekBegin=p.WeekBegin AND p.DoNotSendReason = 'Opted out'
LEFT JOIN #NotEnrolledCount t ON a.WeekBegin=t.WeekBegin AND t.DoNotSendReason = 'Previously Enrolled in HRF CL'
--LEFT JOIN #NotEnrolledCount u ON a.WeekBegin=u.WeekBegin AND u.DoNotSendReason = 'Reactivated'



--UPDATE #StageTrends 
--SET ActiveFlagCountAll=NULL
--	,ActivationCountAll=NULL
--	,InactivationCountAll=NULL
--	,ActiveFlagCountActiveCL=NULL
--	,ActivationCountActiveCL=NULL
--	,InactivationCountActiveCL=NULL
--WHERE WeekEnd > GetDate()

EXEC [Maintenance].[PublishTable] 'CaringLetters.VCL_Trends','#StageTrends'

END --END OF PROCEDURE