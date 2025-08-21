


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2024-07-06
-- Description:	
-- Modifications:
   ============================================= */
CREATE PROCEDURE [App].[VCL_CaringLettersMailingList]
	@User varchar(50),
	@MailingDate varchar(1000),
	@LetterNumber varchar(20), 
	@ReviewRecordReason varchar(1000),
	@PatientName varchar(100),
	@DoNotSend varchar(4),
	@PastYearSeparation varchar(10)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50) = 'vha21\vhapalminal', @MailingDate varchar(max) = '2025-08-18', @LetterNumber varchar(20) = '1,2,3,4,5,6,7,8', @ReviewRecordReason varchar(1000)='n/a', @DoNotSend varchar(4)='0,1', @PatientName varchar(100)=NULL, @PastYearSeparation varchar(10)='Yes,No';


DECLARE @MailingDateList TABLE ([MailingDate] VARCHAR(max))
INSERT @MailingDateList  SELECT value FROM string_split(@MailingDate, ',')

DECLARE @LetterNumberList TABLE ([LetterNumber] varchar)
INSERT @LetterNumberList  SELECT value FROM string_split(@LetterNumber, ',')

DECLARE @ReviewRecordReasonList TABLE ([ReviewRecordReason] varchar(1000))
INSERT @ReviewRecordReasonList  SELECT value FROM string_split(@ReviewRecordReason, ',')

DECLARE @DoNotSendList TABLE ([DoNotSend] varchar(2))
INSERT @DoNotSendList  SELECT value FROM string_split(@DoNotSend, ',')

DECLARE @PastYearSeparationList TABLE ([PastYearSeparation] varchar(10))
INSERT @PastYearSeparationList  SELECT value FROM string_split(@PastYearSeparation, ',')

--Users who can access report - check for national access
--Traditional row-level security does not work because not all patients have an associated station that we can check permissions against
DROP TABLE IF EXISTS #ReportUsers
SELECT UserName 
INTO #ReportUsers
FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%'
UNION
SELECT NetworkId 
FROM [Config].[ReportUsers] WHERE Project = 'VCL Caring Letters'

DROP TABLE IF EXISTS #CheckPermissions
SELECT UserName, CASE WHEN COUNT(b.Sta3n)=130 THEN 1 ELSE 0 END AS NationalPermission 
INTO #CheckPermissions
FROM #ReportUsers a
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) AS b
	ON a.UserName = @User
GROUP BY UserName

DELETE FROM #CheckPermissions WHERE NationalPermission=0

DROP TABLE IF EXISTS #CaringLetterMailing
SELECT DISTINCT a.MailingDate
	,a.LetterNumber
	,a.VCL_ID
	,b.VCL_NearestFacilitySiteCode
	,a.MVIPersonSID
	,a.PatientICN
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
	,ReviewRecordReasonDisplay =
		CASE WHEN a.ReviewRecordReason='N/A' THEN NULL ELSE
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.ReviewRecordReason,'NameFlag','Name, '),'NameChange','Name Change, '),'AddressFlag','Address, '),'AddressChange','Address Change, '),'Transgender','Transgender, '),'DuplicateSSN','Duplicate SSN, '),'DuplicateName4','Duplicate Name Last4, ')
		END
	,b.LetterFrom
	,a.InsertDate
	,a.ActiveRecord
	,mp.ServiceSeparationDate
	,CASE WHEN mp.ServiceSeparationDate BETWEEN DateAdd(day,-366,getdate()) AND getdate() THEN 'Yes' ELSE 'No' END AS PastYearSeparation
FROM [CaringLetters].[VCL_Mailings] a WITH (NOLOCK) 
INNER JOIN [CaringLetters].[VCL_Cohort] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID AND b.FirstLetterDate IS NOT NULL
	AND a.VCL_ID = b.VCL_ID
INNER JOIN #CheckPermissions c
	ON c.UserName = @User
INNER JOIN @MailingDateList m
	ON CAST(a.MailingDate AS date) = CAST(m.MailingDate AS date)
INNER JOIN @LetterNumberList l
	ON a.LetterNumber = l.LetterNumber
INNER JOIN @ReviewRecordReasonList r
	ON a.ReviewRecordReason LIKE CONCAT('%',r.ReviewRecordReason,'%')
INNER JOIN @DoNotSendList ds
	ON a.DoNotSend = ds.DoNotSend
INNER JOIN Common.MasterPatient mp WITH (NOLOCK)
	ON a.MVIPersonSID=mp.MVIPersonSID
INNER JOIN @PastYearSeparationList s
	ON (CASE WHEN mp.ServiceSeparationDate BETWEEN DateAdd(day,-366,getdate()) AND getdate() THEN 'Yes' ELSE 'No' END) = s.PastYearSeparation
WHERE a.ActiveMailingRecord = 1
	AND (a.FullNameLegal LIKE CONCAT('%',@PatientName,'%') OR a.FullNamePreferred LIKE CONCAT('%',@PatientName,'%') OR @PatientName='' OR @PatientName IS NULL)

  ;
  
END