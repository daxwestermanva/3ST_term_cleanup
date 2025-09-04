


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2023-03-20
-- Description:	
-- Modifications:
	-- 11/29/2023: Grace Chung: added [Config].[ReportUsers] table and updated code to select users from this table
	-- 2024-07-13	LM		Added parameter to allow filtering by patient name
	-- 2024-08-09	LM		Added parameter for review record flag
   ============================================= */
CREATE PROCEDURE [App].[PRF_HRS_CaringLettersMailingList]
	@User varchar(50),
	@MailingDate varchar(max),
	@LetterNumber varchar(20),
	@ReviewRecordReason varchar(1000),
	@PatientName varchar(100),
	@DoNotSend varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @MailingDate varchar(max), @LetterNumber varchar(20); SET @User = 'vha21\vhapalminal'; SET @MailingDate = '2023-04-24,2023-04-03'; SET @LetterNumber = '1,2'

DECLARE @MailingDateList TABLE ([MailingDate] VARCHAR(max))
INSERT @MailingDateList  SELECT DISTINCT value FROM string_split(@MailingDate, ',')

DECLARE @LetterNumberList TABLE ([LetterNumber] varchar)
INSERT @LetterNumberList  SELECT DISTINCT value FROM string_split(@LetterNumber, ',')

DECLARE @ReviewRecordReasonList TABLE ([ReviewRecordReason] varchar(1000))
INSERT @ReviewRecordReasonList  SELECT value FROM string_split(@ReviewRecordReason, ',')

DECLARE @DoNotSendList TABLE ([DoNotSend] varchar(2))
INSERT @DoNotSendList  SELECT value FROM string_split(@DoNotSend, ',')

DROP TABLE IF EXISTS #CaringLetterMailing
SELECT DISTINCT a.MailingDate
	,a.LetterNumber
	,a.MVIPersonSID
	,a.PatientICN
	,ch.ADMPARENT_FCDM AS Facility
	,a.FirstNameLegal
	,a.FirstNamePreferred
	,a.FullNameLegal
	,a.FullNamePreferred
	,a.PreferredName
	,CASE WHEN a.NameChange = 1 AND a.LetterNumber<>'1' THEN 'Yes' ELSE NULL END AS NameChange
	,CASE WHEN a.FullNamePreferred IS NULL THEN NULL
		WHEN a.NameSource = 'WB' THEN 'Modified by writeback' ELSE a.NameSource END AS NameSource
	,a.StreetAddress1
	,a.StreetAddress2
	,a.StreetAddress3
	,a.City
	,a.State
	,a.Zip
	,a.Country
	,CASE WHEN a.AddressChange = 1 AND a.LetterNumber<>'1' THEN 'Yes' ELSE NULL END AS AddressChange
	,CASE WHEN a.AddressSource = 'WB' THEN 'Modified by writeback' ELSE a.AddressSource END AS AddressSource
	,a.DoNotSend
	,a.DoNotSendReason
	,a.ReviewRecordFlag
	,a.ReviewRecordReason
	,a.InsertDate
	,a.ActiveRecord
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK) 
INNER JOIN [CaringLetters].[HRF_Cohort] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID AND b.FirstLetterDate IS NOT NULL
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON b.OwnerChecklistID = ch.ChecklistID
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) AS Access 
	ON LEFT(b.OwnerChecklistID,3) = Access.sta3n
INNER JOIN @MailingDateList m
	ON CAST(a.MailingDate AS date) = CAST(m.MailingDate AS date)
INNER JOIN @LetterNumberList l
	ON a.LetterNumber = l.LetterNumber
INNER JOIN @ReviewRecordReasonList r
	ON a.ReviewRecordReason LIKE CONCAT('%',r.ReviewRecordReason,'%')
INNER JOIN @DoNotSendList ds
	ON a.DoNotSend = ds.DoNotSend
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE a.ActiveMailingRecord = 1
	AND (d.UserName IS NOT NULL OR @User IN (select NetworkId from [Config].[ReportUsers] where project like 'HRF Caring Letters'))
  AND (a.FullNameLegal LIKE CONCAT('%',@PatientName,'%') OR a.FullNamePreferred LIKE CONCAT('%',@PatientName,'%') OR @PatientName='' OR @PatientName IS NULL)

  ;

END