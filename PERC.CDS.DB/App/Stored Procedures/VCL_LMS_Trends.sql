



/* =============================================
-- Author: Liam Mina	 
-- Create date: 2025-07-22
-- Description:	Trend report for VCL Lethal Means Safety mailings
-- Modifications:
--    

   ============================================= */
CREATE PROCEDURE [App].[VCL_LMS_Trends]
	@User varchar(50),
	@BeginDate date,
	@EndDate date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Test results
 	--Declare @BeginDate date = '2025-08-10'; DECLARE @EndDate date= '2025-08-21'; DECLARE @User varchar(50) ='VHA21\VHAPALMINAL'

DROP TABLE IF EXISTS #CaringLetterCounts
SELECT CountGroup = 'Week'
    ,[WeekBegin]
    ,[WeekEnd]
	,[DataPullDate]
	,[TotalOffered]
	,[Accepted]
	,[Refused]
	,[DeclinedToAnswer]
	,[MailingsRequestedCount]
	,[GunlocksRequested]
	,[MedEnvelopesRequested]
	,[MailingsSentCount]
	,[GunlocksMailed]
	,AvgGunlocksPerMailing = CAST(CAST([GunlocksMailed] as decimal(10,2))/CAST([MailingsSentCount] AS decimal(10,2)) AS decimal(10,2))
	,[MedEnvelopesMailed]
	,[RefusalCount]
	,[Refuse_DontWant]
	,[Refuse_HaveStorageNotUsed]
	,[Refuse_Defense]
	,[Refuse_AlreadySecured]
	,[Refuse_Other]
	,[Refuse_Unknown]
	,[Refuse_NotOffered]
	,[Storage_CableLockVCL]
	,[Storage_CableLockOther]
	,[Storage_Disassemble]
	,[Storage_GunSafe]
	,[Storage_RemoveFromHome]
	,[Storage_Other]
INTO #CaringLetterCounts
FROM [CaringLetters].[VCL_LMS_Trends] a WITH (NOLOCK)
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE [DataPullDate] BETWEEN @BeginDate AND @EndDate
 AND (d.UserName IS NOT NULL OR @User IN  (select NetworkId from [Config].[ReportUsers] where project like 'VCL LMS'))
 
 

DROP TABLE IF EXISTS #CaringLetterTotals
SELECT CountGroup = 'Total'
	  ,MIN([WeekBegin]) AS WeekBegin
      ,MAX([WeekEnd]) AS WeekEnd
	  ,MAX([DataPullDate]) AS DataPullDate
	  ,MAX([TotalOffered]) AS [TotalOffered]
	  ,MAX([Accepted]) AS [Accepted]
	  ,MAX([Refused]) AS [Refused]
	  ,MAX([DeclinedToAnswer]) AS [DeclinedToAnswer]
	  ,SUM([MailingsRequestedCount]) AS [MailingsRequestedCount]
	  ,SUM([GunlocksRequested]) AS [GunlocksRequested]
	  ,SUM([MedEnvelopesRequested]) AS [MedEnvelopesRequested]
	  ,SUM([MailingsSentCount]) AS [MailingsSentCount]
	  ,SUM([GunlocksMailed]) AS [GunlocksMailed]
	  ,AvgGunlocksPerMailing = CAST(CAST(SUM([GunlocksMailed]) as decimal(10,2))/CAST(SUM([MailingsSentCount]) AS decimal(10,2)) AS decimal(10,2))
	  ,SUM([MedEnvelopesMailed]) AS [MedEnvelopesMailed]
	  ,SUM([RefusalCount]) AS [RefusalCount]
	  ,SUM([Refuse_DontWant]) AS [Refuse_DontWant]
	  ,SUM([Refuse_HaveStorageNotUsed]) AS [Refuse_HaveStorageNotUsed]
	  ,SUM([Refuse_Defense]) AS [Refuse_Defense]
	  ,SUM([Refuse_AlreadySecured]) AS [Refuse_AlreadySecured]
	  ,SUM([Refuse_Other]) AS [Refuse_Other]
	  ,SUM([Refuse_Unknown]) AS [Refuse_Unknown]
	  ,SUM([Refuse_NotOffered]) AS [Refuse_NotOffered]
	  ,SUM([Storage_CableLockVCL]) AS [Storage_CableLockVCL]
	  ,SUM([Storage_CableLockOther]) AS [Storage_CableLockOther]
	  ,SUM([Storage_Disassemble]) AS [Storage_Disassemble]
	  ,SUM([Storage_GunSafe]) AS [Storage_GunSafe]
	  ,SUM([Storage_RemoveFromHome]) AS [Storage_RemoveFromHome]
	  ,SUM([Storage_Other]) AS [Storage_Other]
INTO #CaringLetterTotals
FROM [CaringLetters].[VCL_LMS_Trends] a WITH (NOLOCK)
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WITH (NOLOCK) WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE [DataPullDate] BETWEEN @BeginDate AND @EndDate
 AND (d.UserName IS NOT NULL OR @User IN  (select NetworkId from [Config].[ReportUsers] WITH (NOLOCK) where project like 'VCL LMS'))


 
SELECT * FROM #CaringLetterCounts
UNION ALL
SELECT * FROM #CaringLetterTotals
  
  
  ;

END