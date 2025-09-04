


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2025-05-19
-- Description:	Stored proc for VCL Lethal Means Safety mailing report
-- Modifications:
   ============================================= */
CREATE PROCEDURE [App].[VCL_LMS_MailingList]
	@User varchar(50),
	@MailingDate varchar(1000),
	@ReviewRecordReason varchar(1000),
	@PatientName varchar(100),
	@DoNotSend varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @MailingDate varchar(max), @ReviewRecordReason varchar(1000), @DoNotSend varchar(4), @PatientName varchar(100); SET @User = 'vha21\vhapalminal'; SET @MailingDate = '2025-08-11'; SET @ReviewRecordReason='Address'; SET @DoNotSend='0'; SET @PatientName=NULL

DECLARE @MailingDateList TABLE ([MailingDate] VARCHAR(max))
INSERT @MailingDateList  SELECT value FROM string_split(@MailingDate, ',')

DECLARE @ReviewRecordReasonList TABLE ([ReviewRecordReason] varchar(1000))
INSERT @ReviewRecordReasonList  SELECT REPLACE(value,' ','') FROM string_split(@ReviewRecordReason, ',')

DECLARE @DoNotSendList TABLE ([DoNotSend] varchar(2))
INSERT @DoNotSendList  SELECT value FROM string_split(@DoNotSend, ',')

--Users who can access report - check for national access
--Traditional row-level security does not work because not all patients have an associated station that we can check permissions against
DROP TABLE IF EXISTS #ReportUsers
SELECT UserName 
INTO #ReportUsers
FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%'
UNION
SELECT NetworkId 
FROM [Config].[ReportUsers] WHERE Project = 'VCL LMS'

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
	,a.VCL_ID
	,a.MVIPersonSID
	,a.PatientICN
	,a.FirstName
	,UPPER(a.FullName) AS FullName
	,a.Name_CDW
	,a.Name_VCL_Vet
	,a.Name_VCL_Caller
	,mp.PreferredName
	,UPPER(a.StreetAddress) AS StreetAddress
	,UPPER(a.City) AS City
	,UPPER(a.State) AS State
	,a.Zip
	,UPPER(a.Country) AS Country
	,a.GunlockQuantity
	,a.MedEnvelopeQuantity
	,a.DoNotSend
	,a.ReviewRecordFlag
	,a.ReviewRecordReason
	,RecordModified = CASE WHEN a.RecordModified=1 THEN 'Yes' ELSE NULL END
	,a.InsertDate
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK) 
INNER JOIN #CheckPermissions c
	ON c.UserName = @User
INNER JOIN @MailingDateList m
	ON CAST(a.MailingDate AS date) = CAST(m.MailingDate AS date)
INNER JOIN @ReviewRecordReasonList r
	ON a.ReviewRecordReason LIKE CONCAT('%',REPLACE(r.ReviewRecordReason,' ',''),'%')
INNER JOIN @DoNotSendList ds
	ON a.DoNotSend = ds.DoNotSend
LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
	ON a.MVIPersonSID=mp.MVIPersonSID
WHERE a.MailingDate IS NOT NULL
	AND (a.FullName LIKE CONCAT('%',@PatientName,'%') OR @PatientName='' OR @PatientName IS NULL)

  ;
  
END