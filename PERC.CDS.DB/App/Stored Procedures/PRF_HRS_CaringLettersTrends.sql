

/* =============================================
-- Author: Liam Mina		 
-- Create date: 2023-02-17
-- Description:	
-- Modifications:

   ============================================= */
CREATE PROCEDURE [App].[PRF_HRS_CaringLettersTrends]
	@User varchar(50),
	@BeginDate date,
	@EndDate date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Declare @BeginDate date = '2023-06-30'; DECLARE @EndDate date= '2023-07-15'; DECLARE @User varchar(50) ='vha21\vhapalminal'

DROP TABLE IF EXISTS #CaringLetterCounts
SELECT CountGroup = 'Week'
	  ,WeekBegin
      ,WeekEnd
      ,ActiveFlagCountAll
	  ,ActivationCountAll
      ,InactivationCountAll
	  ,ActiveFlagCountActiveCL
	  ,ActivationCountActiveCL
      ,InactivationCountActiveCL
	  ,NotEnrolledCount
	  ,NotEnrolledDeceased
	  ,NotEnrolledAddress
	  ,NotEnrolledIneligible
	  ,NotEnrolledVCLCL
	  ,NotEnrolledOptOut
	  ,NotEnrolledHRFCL
	  ,NotEnrolledFlagReactivated
      ,EnrolledCount
      ,MailingsSentCount
	  ,DeceasedCount
      ,OptOutCount
	  ,DataSetOptOutCount
	  ,BadAddressCount
      ,CompletedInterventionCount
INTO #CaringLetterCounts
FROM [CaringLetters].[HRF_Trends] a WITH (NOLOCK)
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE WeekBegin BETWEEN @BeginDate AND @EndDate
--AND (d.UserName IS NOT NULL OR @User IN ('VHA19\vhafhmhalloj','VHA01\VHABHSGARRIM','VA\VHACANHillJ','VHA12\VHAHINKalinA@va.gov','VHA16\VHALITLandeS'
--,'VHA11\VHAANNLauveM','VHA20\VHAPUGManchC','VHA20\vhapugRegerM','DVA\VACOTheriN','VHA01\VHABHSFigueS1','VHA20\vhapugChenJ1')) --limit access to PERC and CL team
 AND (d.UserName IS NOT NULL OR @User IN 
  (select NetworkId from [Config].[ReportUsers] where project like 'HRF Caring Letters'))

DROP TABLE IF EXISTS #CaringLetterTotals
SELECT CountGroup = 'Total'
	  ,MIN([WeekBegin]) AS WeekBegin
      ,MAX([WeekEnd]) AS WeekEnd
      ,ActiveFlagCountAll=NULL
	  ,SUM([ActivationCountAll]) AS ActivationCountAll
      ,SUM([InactivationCountAll]) AS InactivationCountAll
	  ,ActiveFlagCountActiveCL=NULL
	  ,SUM([ActivationCountActiveCL]) AS ActivationCountActiveCL
      ,SUM([InactivationCountActiveCL]) AS InactivationCountActiveCL
	  ,SUM([NotEnrolledCount]) AS NotEnrolledCount
	  ,SUM([NotEnrolledDeceased]) AS NotEnrolledDeceased
	  ,SUM([NotEnrolledAddress]) AS NotEnrolledAddress
	  ,SUM([NotEnrolledIneligible]) AS NotEnrolledIneligible
	  ,SUM([NotEnrolledVCLCL]) AS NotEnrolledVCLCL
	  ,SUM([NotEnrolledOptOut]) AS NotEnrolledOptOut
	  ,SUM([NotEnrolledHRFCL]) AS NotEnrolledHRFCL
	  ,SUM([NotEnrolledFlagReactivated]) AS NotEnrolledFlagReactivated
      ,SUM([EnrolledCount]) AS EnrolledCount
      ,SUM([MailingsSentCount]) AS MailingsSentCount
      ,SUM([DeceasedCount]) AS DeceasedCount
	  ,SUM([OptOutCount]) AS OptOutCount
	  ,SUM([DataSetOptOutCount]) AS DataSetOptOutCount
	  ,SUM([BadAddressCount]) AS BadAddressCount
      ,SUM([CompletedInterventionCount]) AS CompletedInterventionCount
INTO #CaringLetterTotals
FROM [CaringLetters].[HRF_Trends] WITH (NOLOCK)
WHERE WeekBegin BETWEEN @BeginDate AND @EndDate

UPDATE #CaringLetterTotals
SET ActiveFlagCountAll = (SELECT COUNT(DISTINCT MVIPersonSID) 
FROM [PRF_HRS].[EpisodeDates] 
WHERE EpisodeBeginDateTime BETWEEN @BeginDate AND @EndDate
OR EpisodeEndDateTime BETWEEN @BeginDate AND @EndDate
OR (EpisodeBeginDateTime <= @BeginDate AND (EpisodeEndDateTime >= @EndDate OR EpisodeEndDateTime IS NULL)))

UPDATE #CaringLetterTotals
SET ActiveFlagCountActiveCL = (SELECT COUNT(DISTINCT a.MVIPersonSID) 
FROM [PRF_HRS].[EpisodeDates] a
LEFT JOIN [Config].[PRF_HRS_CaringLetterRollout] r WITH (NOLOCK)
	ON a.OwnerChecklistID=r.ChecklistID
WHERE  r.StartDate='2023-06-30' AND
(EpisodeBeginDateTime BETWEEN @BeginDate AND @EndDate
OR EpisodeEndDateTime BETWEEN @BeginDate AND @EndDate
OR (EpisodeBeginDateTime <= @BeginDate AND (EpisodeEndDateTime >= @EndDate OR EpisodeEndDateTime IS NULL))) )

SELECT * FROM #CaringLetterCounts
UNION ALL
SELECT * FROM #CaringLetterTotals
  
  
  ;

END