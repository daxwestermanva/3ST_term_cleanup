


/* =============================================
-- Author: Grace Chung		 
-- Create date: 2024-05-20
-- Description:	
-- Modifications:
--    07/03/2024: GC  Remove column [NotEnrolledFlagReactivated]

   ============================================= */
CREATE PROCEDURE [App].[VCL_CaringLettersTrends]
	@User varchar(50),
	@BeginDate date,
	@EndDate date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Test results
 	--Declare @BeginDate date = '2024-05-18'; DECLARE @EndDate date= '2024-06-21'; DECLARE @User varchar(50) ='VHA21\VHAPALChungH'

DROP TABLE IF EXISTS #CaringLetterCounts
SELECT CountGroup = 'Week'
      , [WeekBegin]
      ,[WeekEnd]
      ,[NotEnrolledCount]
      ,[NotEnrolledDeceased]
      ,[NotEnrolledAddress]
      ,[NotEnrolledIneligible]
      ,[NotEnrolledVCLCL]
      ,[NotEnrolledOptOut]
      ,[NotEnrolledHRFCL]
   --   ,[NotEnrolledFlagReactivated]
      ,[EnrolledCount]
      ,[MailingsSentCount]
      ,[DeceasedCount]
      ,[OptOutCount]
      ,[DataSetOptOutCount]
      ,[BadAddressCount]
      ,[CompletedInterventionCount]
INTO #CaringLetterCounts
FROM [CaringLetters].[VCL_Trends] a WITH (NOLOCK)
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE WeekBegin BETWEEN @BeginDate AND @EndDate
 AND (d.UserName IS NOT NULL OR @User IN  (select NetworkId from [Config].[ReportUsers] where project like 'VCL Caring Letters'))
 

 

DROP TABLE IF EXISTS #CaringLetterTotals
SELECT CountGroup = 'Total'
	  ,MIN([WeekBegin]) AS WeekBegin
      ,MAX([WeekEnd]) AS WeekEnd
	  ,SUM([NotEnrolledCount]) AS NotEnrolledCount
	  ,SUM([NotEnrolledDeceased]) AS NotEnrolledDeceased
	  ,SUM([NotEnrolledAddress]) AS NotEnrolledAddress
	  ,SUM([NotEnrolledIneligible]) AS NotEnrolledIneligible
	  ,SUM([NotEnrolledVCLCL]) AS NotEnrolledVCLCL
	  ,SUM([NotEnrolledOptOut]) AS NotEnrolledOptOut
	  ,SUM([NotEnrolledHRFCL]) AS NotEnrolledHRFCL
	--  ,SUM([NotEnrolledFlagReactivated]) AS NotEnrolledFlagReactivated
      ,SUM([EnrolledCount]) AS EnrolledCount
      ,SUM([MailingsSentCount]) AS MailingsSentCount
      ,SUM([DeceasedCount]) AS DeceasedCount
	  ,SUM([OptOutCount]) AS OptOutCount
	  ,SUM([DataSetOptOutCount]) AS DataSetOptOutCount
	  ,SUM([BadAddressCount]) AS BadAddressCount
      ,SUM([CompletedInterventionCount]) AS CompletedInterventionCount
INTO #CaringLetterTotals
FROM [CaringLetters].[VCL_Trends] WITH (NOLOCK)
WHERE WeekBegin BETWEEN @BeginDate AND @EndDate
 
SELECT * FROM #CaringLetterCounts
UNION ALL
SELECT * FROM #CaringLetterTotals
  
  
  ;

END