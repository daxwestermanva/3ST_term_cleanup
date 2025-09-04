

/********************************************************************************************************************
-- Author:		Liam Mina
-- Create date: 2025-07-17
-- Description:	Trend report for VCL lethal means safety mailings
-- Updates:
********************************************************************************************************************/
CREATE PROCEDURE [Code].[CaringLetters_VCL_LMS_Trends] 
AS
BEGIN 

--CL data is run on Saturdays, to capture inactivations the preceding week ending on Friday.
DROP TABLE IF EXISTS #WeekEpisodes
SELECT CAST(Date AS date) AS WeekBegin
	,CAST(DateAdd(day,6,Date) AS date) AS WeekEnd
	,CAST(DateAdd(day,8,Date) AS date) AS DataPullDate
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=7 --Saturday
AND Date BETWEEN '2025-08-09' AND getdate() --program launches on 8/10; Saturday prior is 8/9

UPDATE #WeekEpisodes
SET WeekBegin='2025-08-10' 
WHERE WeekBegin='2025-08-09' 

DROP TABLE IF EXISTS #GunlocksOffered
SELECT DISTINCT DataPullDate
	,[Declined To Answer] AS DeclinedToAnswer
	,[No] AS Refused
	,[Yes] AS Accepted
	,[Declined To Answer]+[No]+[Yes] AS TotalOffered
INTO #GunlocksOffered
FROM 
	(SELECT b.DataPullDate
		,a.AcceptedGunLock
		,COUNT(DISTINCT VCL_ID) AS Count
	FROM[CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
	INNER JOIN #WeekEpisodes b WITH (NOLOCK)
		ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
	GROUP BY DataPullDate,AcceptedGunLock
	) as a
PIVOT(SUM(Count) FOR AcceptedGunLock IN(
	[Declined To Answer]
	,[No] 
	,[Yes]
	) )as c

DROP TABLE IF EXISTS #MailingsRequestedCount
SELECT b.DataPullDate
	,COUNT(DISTINCT VCL_ID) AS MailingsRequestedCount
	,SUM(GunlockQuantity) GunlocksRequested
	,SUM(MedEnvelopeQuantity) AS MedEnvelopesRequested
INTO #MailingsRequestedCount
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE AcceptedGunLock='Yes'
GROUP BY DataPullDate
ORDER BY DataPullDate

DROP TABLE IF EXISTS #MailingsSentCount
SELECT b.DataPullDate
	,COUNT(DISTINCT VCL_ID) AS MailingsSentCount
	,SUM(GunlockQuantity) GunlocksMailed
	,SUM(MedEnvelopeQuantity) AS MedEnvelopesMailed
INTO #MailingsSentCount
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.DoNotSend = 0
GROUP BY DataPullDate
ORDER BY DataPullDate

DROP TABLE IF EXISTS #Refusals
SELECT b.DataPullDate
	,COUNT(DISTINCT VCL_ID) AS RefusalCount
	,SUM(Refuse_DontWant) [Refuse_DontWant]
	,SUM(Refuse_HaveStorageNotUsed) AS [Refuse_HaveStorageNotUsed]
	,SUM(Refuse_Defense) [Refuse_Defense]
	,SUM(Refuse_AlreadySecured) AS [Refuse_AlreadySecured]
	,SUM(Refuse_Other) [Refuse_Other]
	,SUM(Refuse_Unknown) AS [Refuse_Unknown]
	,SUM(Refuse_NotOffered) AS [Refuse_NotOffered]
INTO #Refusals
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
WHERE a.AcceptedGunLock <> 'Yes'
GROUP BY DataPullDate
ORDER BY DataPullDate

DROP TABLE IF EXISTS #FirearmStorage
SELECT b.DataPullDate
	,SUM([Storage_CableLockVCL]) [Storage_CableLockVCL]
	,SUM([Storage_CableLockOther]) AS [Storage_CableLockOther]
	,SUM([Storage_Disassemble]) [Storage_Disassemble]
	,SUM([Storage_GunSafe]) AS [Storage_GunSafe]
	,SUM([Storage_RemoveFromHome]) [Storage_RemoveFromHome]
	,SUM([Storage_Other]) AS [Storage_Other]
INTO #FirearmStorage
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b WITH (NOLOCK)
	ON CAST(a.VCL_Call_Date AS date) BETWEEN b.WeekBegin AND b.WeekEnd
GROUP BY DataPullDate
ORDER BY DataPullDate


DROP TABLE IF EXISTS #StageTrends
SELECT DISTINCT a.WeekBegin
	,a.WeekEnd
	,a.DataPullDate
	,g.TotalOffered
	,g.Accepted
	,g.Refused
	,g.DeclinedToAnswer
	,e.MailingsRequestedCount
	,e.GunlocksRequested
	,e.MedEnvelopesRequested
	,f.MailingsSentCount
	,f.GunlocksMailed
	,f.MedEnvelopesMailed
	,r.RefusalCount
	,r.[Refuse_DontWant]
	,r.[Refuse_HaveStorageNotUsed]
	,r.[Refuse_Defense]
	,r.[Refuse_AlreadySecured]
	,r.[Refuse_Other]
	,r.[Refuse_Unknown]
	,r.[Refuse_NotOffered]
	,s.[Storage_CableLockVCL]
	,s.[Storage_CableLockOther]
	,s.[Storage_Disassemble]
	,s.[Storage_GunSafe]
	,s.[Storage_RemoveFromHome]
	,s.[Storage_Other]
INTO #StageTrends
FROM #WeekEpisodes a
LEFT JOIN #MailingsRequestedCount e ON a.DataPullDate=e.DataPullDate
LEFT JOIN #MailingsSentCount f ON a.DataPullDate=f.DataPullDate
LEFT JOIN #Refusals r ON a.DataPullDate=r.DataPullDate
LEFT JOIN #FirearmStorage s ON a.DataPullDate=s.DataPullDate
LEFT JOIN #GunlocksOffered g ON a.DataPullDate=g.DataPullDate

DELETE FROM #StageTrends WHERE TotalOffered IS NULL

EXEC [Maintenance].[PublishTable] 'CaringLetters.VCL_LMS_Trends','#StageTrends'

END --END OF PROCEDURE