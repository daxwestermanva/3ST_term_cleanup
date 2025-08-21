

-- =============================================
-- Author:		Liam Mina
-- Create date: 3/24/2023
-- Description:	Writeback SP for HRF Caring Letters report
-- =============================================
CREATE PROCEDURE [App].[PRF_HRS_CaringLettersWriteback]

	@MVIPersonSID int,
	@User varchar(100),
	@DoNotSend tinyint,
	@DoNotSendReason varchar(20),
	@PreferredName tinyint,
	@UpdateFullName varchar(100),
	@UpdateFirstName varchar(50),
	@UpdateAddress1 varchar(100),
	@UpdateAddress2 varchar(100),
	@UpdateAddress3 varchar(50),
	@UpdateCity varchar(100),
	@UpdateState varchar(22),
	@UpdateZip varchar(10),
	@UpdateCountry varchar(100)


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	
BEGIN TRANSACTION;

UPDATE [CaringLetters].[HRF_Mailings]
WITH (TABLOCKX, HOLDLOCK)
SET MVIPersonSID = NULL WHERE 1 = 2


	--For inline testing
	--DECLARE
	--@MVIPersonSID int=64783,
	--@User varchar(100)='vha21\vhapalminal',
	--@DoNotSend tinyint=0,
	--@DoNotSendReason varchar(20)='N/A',
	--@PreferredName tinyint=0,
	--@UpdateFullName varchar(100)='GARY SILVERNAIL',
	--@UpdateFirstName varchar(50)='GARY',
	--@UpdateAddress1 varchar(100)='2800 S SEACREST BLVD RM 10-1',
	--@UpdateAddress2 varchar(100)='',
	--@UpdateAddress3 varchar(50)='',
	--@UpdateCity varchar(100)='BOYNTON BEACH',
	--@UpdateState varchar(22)='FL',
	--@UpdateZip varchar(10)='33435',
	--@UpdateCountry varchar(100)='United States'

IF --((LEN(@UpdateAddress1)=0 AND @UpdateAddress1<>' ') OR (LEN(@UpdateCity)=0 AND @UpdateCity<>' ') OR (LEN(@UpdateState)<>2 AND @UpdateState<>' ') OR (LEN(@UpdateZip)<>5 AND @UpdateZip <> ' ') OR (LEN(@UpdateCountry)=0 AND @UpdateCountry <>' '))
	LEN(@UpdateState)>2 OR LEN(@UpdateZip)>5
	OR (@DoNotSend=0 AND @DoNotSendReason<>'N/A') OR (@DoNotSend=1 AND @DoNotSendReason='N/A')
	--OR (@PreferredName=1 AND (SELECT SUM(PreferredName) FROM [PRF_HRS].[CaringLettersMailings] WHERE MVIPersonSID=@MVIPersonSID)=0)
BEGIN;
	IF LEN(@UpdateState) > 2 
		THROW 50000, 'Error: Invalid value for state abbreviation. Please enter a two-character state abbreviation',1;
	IF LEN(@UpdateZip) > 5
		THROW 50001, 'Error: Invalid value for zip code. Please enter a five-digit zip code',1;
	--IF (LEN(@UpdateAddress1)=0 OR LEN(@UpdateCity)=0 OR LEN(@UpdateState)<>2 OR LEN(@UpdateZip)<>5 OR @UpdateCountry IS NULL) 
	--	THROW 50002, 'Error: Incomplete Address. If updating patient address, ensure values for Address1, City, State, Zip, and Country are populated',1;
	IF (@DoNotSend=0 AND @DoNotSendReason<>'N/A') OR (@DoNotSend=1 AND @DoNotSendReason='N/A') 
		THROW 50003, 'Error: Inconsistent values between Remove from Future Mailings and Reason. If removing from mailings, select a reason other than N/A. If not removing from mailings, ensure N/A is selected for Reason',1;
	--IF @PreferredName=1 AND (SELECT SUM(PreferredName) FROM [PRF_HRS].[CaringLettersMailings] WHERE MVIPersonSID=@MVIPersonSID)=0
	--	THROW 50004, 'Error: No available data for preferred name',1;
END;
ELSE
BEGIN;

DROP TABLE IF EXISTS #WritebackRecords
SELECT  
	@MVIPersonSID as MVIPersonSID
	,@DoNotSend AS DoNotSend
	,CASE WHEN @DoNotSendReason = 'N/A' THEN NULL ELSE @DoNotSendReason END AS DoNotSendReason
	,@PreferredName AS UsePreferredName
	,TRIM(@UpdateFirstName) AS UpdateFirstName
	,UPPER(TRIM(@UpdateFullName)) AS UpdateFullName
	,UPPER(TRIM(@UpdateAddress1)) AS UpdateStreetAddress1
	,UPPER(TRIM(@UpdateAddress2)) AS UpdateStreetAddress2
	,UPPER(TRIM(@UpdateAddress3)) AS UpdateStreetAddress3
	,UPPER(TRIM(@UpdateCity)) AS UpdateCity
	,UPPER(TRIM(@UpdateState)) AS UpdateState
	,TRIM(@UpdateZip) AS UpdateZip
	,UPPER(TRIM(@UpdateCountry)) AS UpdateCountry 
	,GetDate() as InsertDate
	,@User as UserID
INTO #WritebackRecords



DROP TABLE IF EXISTS #RecordChanges
SELECT a.MVIPersonSID
	,a.DoNotSend
	,a.DoNotSendReason
	,a.UsePreferredName
	,UpdateName = CASE WHEN a.UsePreferredName=0 AND b.PreferredName=1 
				AND (a.UpdateFirstName=b.FirstNameLegal COLLATE SQL_Latin1_General_CP1_CS_AS AND a.UpdateFullName=b.FullNameLegal) THEN 0
		WHEN (a.UsePreferredName=1 AND (a.UpdateFirstName <>ISNULL(b.FirstNamePreferred COLLATE SQL_Latin1_General_CP1_CS_AS,'') OR a.UpdateFullName<>ISNULL(b.FullNamePreferred,''))
		--OR (a.UsePreferredName=0 AND (a.UpdateFirstName<>b.FirstNameLegal COLLATE SQL_Latin1_General_CP1_CS_AS OR a.UpdateFullName<>b.FullNameLegal))
		)
		THEN 1 ELSE 0 END
	,a.UpdateFirstName
	,a.UpdateFullName
	,UpdateAddress = CASE WHEN (a.UpdateStreetAddress1<>b.StreetAddress1 
		OR ISNULL(a.UpdateStreetAddress2,'')<>ISNULL(b.StreetAddress2,'')
		OR ISNULL(a.UpdateStreetAddress3,'')<>ISNULL(b.StreetAddress3,'')
		OR a.UpdateCity<>b.City
		OR a.UpdateState<>b.State
		OR a.UpdateZip<>b.Zip
		OR a.UpdateCountry<>b.Country) THEN 1 ELSE 0 END
	,a.UpdateStreetAddress1
	,a.UpdateStreetAddress2
	,a.UpdateStreetAddress3
	,a.UpdateCity
	,a.UpdateState
	,a.UpdateZip
	,a.UpdateCountry
	,a.InsertDate
	,a.UserID
INTO #RecordChanges
FROM #WritebackRecords a
INNER JOIN [CaringLetters].[HRF_Mailings] b
	ON a.MVIPersonSID = b.MVIPersonSID AND b.ActiveRecord=1
WHERE  (a.DoNotSend <> b.DoNotSend
OR a.UsePreferredName <> b.PreferredName
OR (a.UsePreferredName=1 AND (a.UpdateFirstName <>ISNULL(b.FirstNamePreferred COLLATE SQL_Latin1_General_CP1_CS_AS,'') OR a.UpdateFullName<>ISNULL(b.FullNamePreferred,'')))
OR (a.UsePreferredName=0 AND (a.UpdateFirstName<>b.FirstNameLegal COLLATE SQL_Latin1_General_CP1_CS_AS OR a.UpdateFullName<>b.FullNameLegal))
OR (a.UpdateStreetAddress1<>b.StreetAddress1
		OR ISNULL(a.UpdateStreetAddress2,'')<>ISNULL(b.StreetAddress2,'')
		OR ISNULL(a.UpdateStreetAddress3,'')<>ISNULL(b.StreetAddress3,'')
		OR a.UpdateCity<>b.City
		OR a.UpdateState<>b.State
		OR a.UpdateZip<>b.Zip
		OR a.UpdateCountry<>b.Country)
	)
--UNION 
--SELECT a.* 
--FROM #WritebackRecords a
--INNER JOIN [PRF_HRS].[CaringLettersWriteback] b
--	ON a.MVIPersonSID = b.MVIPersonSID AND a.InsertDate >= b.InsertDate
--WHERE a.DoNotSend <> b.DoNotSend
--OR a.UsePreferredName <> b.UsePreferredName
;
UPDATE #RecordChanges
SET UpdateFirstName=NULL
	,UpdateFullName=NULL
FROM #RecordChanges
WHERE UpdateName=0

UPDATE #RecordChanges
SET UpdateStreetAddress1=NULL
	,UpdateStreetAddress2=NULL
	,UpdateStreetAddress3=NULL
	,UpdateCity=NULL
	,UpdateState=NULL
	,UpdateZip=NULL
	,UpdateCountry=NULL
FROM #RecordChanges
WHERE UpdateAddress=0


INSERT INTO [CaringLetters].[HRF_Writeback]
SELECT * FROM #RecordChanges


UPDATE [CaringLetters].[HRF_Mailings] 
SET ActiveRecord = 2
	,ActiveMailingRecord = 2
FROM [CaringLetters].[HRF_Mailings] a
INNER JOIN #RecordChanges b ON a.MVIPersonSID = b.MVIPersonSID 
WHERE a.ActiveRecord = 1
AND (a.DoNotSend <> b.DoNotSend OR b.UpdateAddress=1 OR b.UpdateName=1
		OR (a.PreferredName <> b.UsePreferredName AND a.FullNamePreferred IS NOT NULL))

INSERT INTO [CaringLetters].[HRF_Mailings]
SELECT a.MailingDate
	,a.LetterNumber
	,a.MVIPersonSID
	,a.PatientICN
	,a.FirstNameLegal
	,a.FullNameLegal
	,CASE WHEN b.UpdateName=1 THEN b.UpdateFirstName ELSE a.FirstNamePreferred END AS FirstNamePreferred
	,CASE WHEN b.UpdateName=1 THEN b.UpdateFullName ELSE a.FullNamePreferred END AS FullNamePreferred
	,CASE WHEN b.UpdateName=1 THEN 1 ELSE b.UsePreferredName END AS PreferredName
	,b.UpdateName AS NameChange
	,CASE WHEN b.UpdateName=1 THEN 'WB' ELSE a.NameSource END AS NameSource
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateStreetAddress1 ELSE a.StreetAddress1 END AS StreetAddress1
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateStreetAddress2 ELSE a.StreetAddress2 END AS StreetAddress2
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateStreetAddress3 ELSE a.StreetAddress3 END AS StreetAddress3
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateCity ELSE a.City END AS City
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateState ELSE a.State END AS State
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateZip ELSE a.Zip END AS Zip
	,CASE WHEN b.UpdateAddress=1 THEN b.UpdateCountry ELSE a.Country END AS Country
	,b.UpdateAddress AS AddressChange
	,CASE WHEN b.UpdateAddress=1 THEN 'WB' ELSE a.AddressSource END AS AddressSource
	,b.DoNotSend
	,b.DoNotSendReason
	,a.ReviewRecordFlag
	,a.ReviewRecordReason
	,ActiveRecord=1
	,ActiveMailingRecord=1
	,b.InsertDate
FROM (SELECT * FROM [CaringLetters].[HRF_Mailings] WHERE ActiveRecord=2) a
INNER JOIN #RecordChanges b ON a.MVIPersonSID = b.MVIPersonSID 
WHERE (a.DoNotSend <> b.DoNotSend OR b.UpdateAddress=1 OR UpdateName=1 OR a.PreferredName <> b.UsePreferredName)

UPDATE [CaringLetters].[HRF_Mailings]
SET ActiveRecord = 0
	,ActiveMailingRecord=0
FROM [CaringLetters].[HRF_Mailings] a 
INNER JOIN #RecordChanges b ON a.MVIPersonSID = b.MVIPersonSID 
WHERE ActiveRecord = 2 OR ActiveMailingRecord=2

END;
COMMIT TRANSACTION

--Update Cohort table with DoNotSend details
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend=0
	,DoNotSendReason=NULL
	,DoNotSendDate=NULL
FROM [CaringLetters].[HRF_Cohort] a
INNER JOIN #RecordChanges b ON a.MVIPersonSID = b.MVIPersonSID 
WHERE b.DoNotSend = 0 AND a.DoNotSend = 1

UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend= b.DoNotSend
	,DoNotSendReason=b.DoNotSendReason
	,DoNotSendDate=b.InsertDate
FROM [CaringLetters].[HRF_Cohort] a
INNER JOIN #RecordChanges b ON a.MVIPersonSID = b.MVIPersonSID 
WHERE b.DoNotSend = 1 AND a.DoNotSend = 0
;



SELECT a.MailingDate
	,a.LetterNumber
	,a.MVIPersonSID
	,a.PatientICN
	,a.FirstNameLegal
	,a.FirstNamePreferred
	,a.FullNameLegal
	,a.FullNamePreferred
	,a.PreferredName
	,CASE WHEN a.NameChange = 1 AND a.LetterNumber<>'1'  THEN 'Yes' ELSE NULL END AS NameChange
	,CASE WHEN a.FullNamePreferred IS NULL THEN NULL
		WHEN a.NameSource = 'WB' THEN 'Modified by writeback' ELSE a.NameSource END AS NameSource
	,a.StreetAddress1
	,a.StreetAddress2
	,a.StreetAddress3
	,a.City
	,a.State
	,a.Zip
	,a.Country
	,CASE WHEN a.AddressChange = 1 AND a.LetterNumber<>'1'  THEN 'Yes' ELSE NULL END AS AddressChange
	,CASE WHEN a.AddressSource = 'WB' THEN 'Modified by writeback' ELSE a.AddressSource END AS AddressSource
	,a.DoNotSend
	,a.DoNotSendReason
	,a.InsertDate
	,a.ActiveRecord
	,wb.UserID AS ModifiedBy
	,b.DoNotSend AS CurrentDoNotSend
	,b.DoNotSendReason AS CurrentDoNotSendReason
	,b.DoNotSendDate AS CurrentDoNotSendDate
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK)
INNER JOIN [CaringLetters].[HRF_Cohort] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID AND b.FirstLetterDate IS NOT NULL
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) AS Access 
	ON LEFT(b.OwnerChecklistID,3) = Access.sta3n
LEFT JOIN [CaringLetters].[HRF_Writeback] AS wb WITH (NOLOCK)
	ON wb.MVIPersonSID = a.MVIPersonSID AND wb.InsertDate=a.InsertDate
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WITH (NOLOCK) WHERE UserName LIKE 'vha21\vhapal%') AS e 
	ON @User=e.UserName
WHERE @MVIPersonSID = a.MVIPersonSID
 AND (e.UserName IS NOT NULL OR @User IN 
  (select NetworkId from [Config].[ReportUsers] WITH (NOLOCK) where project = 'HRF Caring Letters'))

END