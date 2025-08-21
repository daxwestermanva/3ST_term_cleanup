

/********************************************************************************************************************
-- Author:		Liam Mina
-- Create date: 2/27/2023
-- Description:	Trend report for HRF caring letters
-- Updates:
	2023-09-19	LM	Fixed bug causing duplicate rows
	2024-03-11	LM	Fix to get accurate counts post phase 2 launch in January 
********************************************************************************************************************/
CREATE PROCEDURE [Code].[CaringLetters_HRF_Trends] 
AS
BEGIN 

--CL data is run on Saturdays, to capture inactivations the preceding week ending on Friday.
DROP TABLE IF EXISTS #WeekEpisodes
SELECT CAST(Date AS date) AS WeekBegin
	,CAST(DateAdd(day,6,Date) AS date) AS WeekEnd
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=7 --Saturday
and date < getdate()
--AND CAST(DateAdd(day,6,Date) AS date) < GETDATE()
AND Date > '2023-06-30'
UNION ALL --special case because program starts on 6/30 instead of at the start of a week
SELECT WeekBegin = '2023-06-30'
	,WeekEnd = '2023-06-30'
	
DROP TABLE IF EXISTS #ActiveFlags
SELECT DISTINCT b.WeekBegin
	,count(DISTINCT a.MVIPersonSID) AS ActiveFlagCount
	,CASE WHEN r.StartDate='2023-06-30' OR b.WeekEnd>='2024-01-31' THEN 1 ELSE 0 END AS ActiveSite
INTO #ActiveFlags
from PRF_HRS.EpisodeDates a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b on CAST(a.EpisodeBeginDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
	OR CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
	OR (CAST(a.EpisodeBeginDateTime AS date) <= WeekBegin AND (CAST(a.EpisodeEndDateTime AS date) >= WeekEnd OR EpisodeEndDateTime IS NULL)) 
LEFT JOIN [Config].[PRF_HRS_CaringLetterRollout] r WITH (NOLOCK)
	ON a.OwnerChecklistID=r.ChecklistID
GROUP BY b.WeekBegin, CASE WHEN r.StartDate='2023-06-30' OR b.WeekEnd>='2024-01-31' THEN 1 ELSE 0 END WITH ROLLUP

DROP TABLE IF EXISTS #ActivationCount
SELECT DISTINCT b.WeekBegin, count(DISTINCT a.MVIPersonSID) AS ActivationCount
	,CASE WHEN r.StartDate='2023-06-30' OR b.WeekEnd>='2024-01-31'  THEN 1 ELSE 0 END AS ActiveSite
INTO #ActivationCount
FROM PRF_HRS.EpisodeDates a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeBeginDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
LEFT JOIN [Config].[PRF_HRS_CaringLetterRollout] r WITH (NOLOCK)
	ON a.OwnerChecklistID=r.ChecklistID
GROUP BY WeekBegin, CASE WHEN r.StartDate='2023-06-30' OR b.WeekEnd>='2024-01-31'  THEN 1 ELSE 0 END WITH ROLLUP
ORDER BY WeekBegin

DROP TABLE IF EXISTS #InactivationCount
SELECT DISTINCT b.WeekBegin, count(DISTINCT a.MVIPersonSID) AS InactivationCount
	,CASE WHEN r.StartDate='2023-06-30' OR b.WeekEnd>='2024-01-31' THEN 1 ELSE 0 END AS ActiveSite
INTO #InactivationCount
FROM PRF_HRS.EpisodeDates a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
LEFT JOIN [Config].[PRF_HRS_CaringLetterRollout] r WITH (NOLOCK)
	ON a.OwnerChecklistID=r.ChecklistID
GROUP BY WeekBegin, CASE WHEN r.StartDate='2023-06-30'OR b.WeekEnd>='2024-01-31'  THEN 1 ELSE 0 END WITH ROLLUP
ORDER BY WeekBegin

DROP TABLE IF EXISTS #NotEnrolledCount
SELECT DISTINCT b.WeekBegin, count(DISTINCT a.MVIPersonSID) AS Count
	,CASE WHEN DoNotSendReason IN ('Bad Address','Unable to receive mail') THEN 'Bad Address' ELSE DoNotSendReason END AS DoNotSendReason
INTO #NotEnrolledCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE FirstLetterDate IS NULL AND DoNotSend=1
GROUP BY WeekBegin, CASE WHEN DoNotSendReason IN ('Bad Address','Unable to receive mail') THEN 'Bad Address' ELSE DoNotSendReason END WITH ROLLUP
ORDER BY WeekBegin, DoNotSendReason

DROP TABLE IF EXISTS #EnrolledCount
SELECT b.WeekBegin, COUNT(DISTINCT a.MVIPersonSID) AS EnrolledCount
INTO #EnrolledCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.FirstLetterDate IS NOT NULL --indicates they are enrolled
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #MailingsSentCount
SELECT b.WeekBegin, COUNT(*) AS MailingsSentCount
INTO #MailingsSentCount
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.MailingDate AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.ActiveMailingRecord = 1 AND a.DoNotSend = 0
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #DeceasedCount
SELECT b.WeekBegin, Count(*) AS DeceasedCount
INTO #DeceasedCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.DoNotSend=1 AND DoNotSendReason LIKE '%Deceased%' AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #OptOutCount
SELECT b.WeekBegin, Count(*) AS OptOutCount
INTO #OptOutCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.DoNotSend=1 AND DoNotSendReason IN ('Patient Opt Out','Opted out') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #DataSetOptOutCount
SELECT b.WeekBegin, Count(*) AS DataSetOptOutCount
INTO #DataSetOptOutCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.DoNotSend=1 AND DoNotSendReason IN ('Data Set Opt Out') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #BadAddressCount
SELECT b.WeekBegin, Count(*) AS BadAddressCount
INTO #BadAddressCount
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.DoNotSend=1 AND (DoNotSendReason LIKE '%Mail%' OR DoNotSendReason LIKE '%Address%') AND a.FirstLetterDate IS NOT NULL
GROUP BY WeekBegin
ORDER BY WeekBegin

DROP TABLE IF EXISTS #InterventionCompleteCount
SELECT b.WeekBegin, COUNT(*) AS CompletedInterventionCount
INTO #InterventionCompleteCount
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.MailingDate AS date) BETWEEN b.WeekBegin AND b.WeekEnd
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK)
	ON a.MVIPersonSID=c.MVIPersonSID
WHERE a.ActiveMailingRecord= 1 AND a.LetterNumber = 8
GROUP BY WeekBegin
ORDER BY WeekBegin



DROP TABLE IF EXISTS #StageTrends
SELECT DISTINCT a.WeekBegin
	,a.WeekEnd
	,b.ActiveFlagCount AS ActiveFlagCountAll
	,c.ActivationCount AS ActivationCountAll
	,d.InactivationCount AS InactivationCountAll
	,q.ActiveFlagCount AS ActiveFlagCountActiveCL
	,r.ActivationCount AS ActivationCountActiveCL
	,s.InactivationCount AS InactivationCountActiveCL
	,k.Count AS NotEnrolledCount
	,l.Count AS NotEnrolledDeceased
	,m.Count AS NotEnrolledAddress
	,n.Count AS NotEnrolledIneligible
	,o.Count AS NotEnrolledVCLCL
	,p.Count AS NotEnrolledOptOut
	,t.Count AS NotEnrolledHRFCL
	,u.Count AS NotEnrolledFlagReactivated
	,e.EnrolledCount
	,f.MailingsSentCount
	,g.DeceasedCount
	,h.OptOutCount
	,ds.DataSetOptOutCount
	,i.BadAddressCount
	,j.CompletedInterventionCount
INTO #StageTrends
FROM #WeekEpisodes a
INNER JOIN #ActiveFlags b ON a.WeekBegin=b.WeekBegin AND b.ActiveSite IS NULL
LEFT JOIN #ActivationCount c ON a.WeekBegin=c.WeekBegin AND c.ActiveSite IS NULL
LEFT JOIN #InactivationCount d ON a.WeekBegin=d.WeekBegin AND d.ActiveSite IS NULL
LEFT JOIN #EnrolledCount e ON a.WeekBegin=e.WeekBegin
LEFT JOIN #MailingsSentCount f ON a.WeekBegin=f.WeekBegin
LEFT JOIN #DeceasedCount g ON a.WeekBegin=g.WeekBegin
LEFT JOIN #OptOutCount h ON a.WeekBegin=h.WeekBegin
LEFT JOIN #DataSetOptOutCount ds ON a.WeekBegin=ds.WeekBegin
LEFT JOIN #BadAddressCount i ON a.WeekBegin=i.WeekBegin
LEFT JOIN #InterventionCompleteCount j ON a.WeekBegin=j.WeekBegin
LEFT JOIN #NotEnrolledCount k ON a.WeekBegin=k.WeekBegin AND k.DoNotSendReason IS NULL
LEFT JOIN #NotEnrolledCount l ON a.WeekBegin=l.WeekBegin AND l.DoNotSendReason ='Deceased'
LEFT JOIN #NotEnrolledCount m ON a.WeekBegin=m.WeekBegin AND m.DoNotSendReason = 'Bad Address'
LEFT JOIN #NotEnrolledCount n ON a.WeekBegin=n.WeekBegin AND n.DoNotSendReason = 'Ineligible former service member'
LEFT JOIN #NotEnrolledCount o ON a.WeekBegin=o.WeekBegin AND o.DoNotSendReason = 'Enrolled in VCL CL'
LEFT JOIN #NotEnrolledCount p ON a.WeekBegin=p.WeekBegin AND p.DoNotSendReason = 'Opted out'
LEFT JOIN #NotEnrolledCount t ON a.WeekBegin=t.WeekBegin AND t.DoNotSendReason = 'Previously Enrolled in HRF CL'
LEFT JOIN #NotEnrolledCount u ON a.WeekBegin=u.WeekBegin AND u.DoNotSendReason = 'Reactivated'
LEFT JOIN #ActiveFlags q ON a.WeekBegin=q.WeekBegin AND q.ActiveSite = 1
LEFT JOIN #ActivationCount r ON a.WeekBegin=r.WeekBegin AND r.ActiveSite = 1
LEFT JOIN #InactivationCount s ON a.WeekBegin=s.WeekBegin AND s.ActiveSite = 1


UPDATE #StageTrends 
SET ActiveFlagCountAll=NULL
	,ActivationCountAll=NULL
	,InactivationCountAll=NULL
	,ActiveFlagCountActiveCL=NULL
	,ActivationCountActiveCL=NULL
	,InactivationCountActiveCL=NULL
WHERE WeekEnd > GetDate()

EXEC [Maintenance].[PublishTable] 'CaringLetters.HRF_Trends','#StageTrends'

END --END OF PROCEDURE