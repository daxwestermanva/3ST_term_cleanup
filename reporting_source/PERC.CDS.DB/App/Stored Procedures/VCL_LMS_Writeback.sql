



-- =============================================
-- Author:		Liam Mina
-- Create date: 2025-05-20
-- Description:	Writeback SP for VCL Caring Letters report
-- Modifications:
-- =============================================
CREATE PROCEDURE [App].[VCL_LMS_Writeback]

	@VCL_ID int,
	@User varchar(100),
	@DoNotSend tinyint,
	@UpdateFullName varchar(100),
	@UpdateFirstName varchar(50),
	@UpdateAddress varchar(100),
	@UpdateCity varchar(100),
	@UpdateState varchar(22),
	@UpdateZip varchar(10),
	@UpdateCountry varchar(2),
	@UpdateGunlockQuantity smallint
	--@UpdateMedEnvelopeQuantity smallint


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--For inline testing
	--DECLARE
	--@VCL_ID int=,
	--@User varchar(100)='vha21\vhapalminal',
	--@DoNotSend tinyint=0,
	--@UpdateFullName varchar(100)='',
	--@UpdateFirstName varchar(50)='',
	--@UpdateAddress varchar(100)='',
	--@UpdateCity varchar(100)='',
	--@UpdateState varchar(22)='',
	--@UpdateZip varchar(10)='',
	--@UpdateCountry varchar(2)='US',
	--@UpdateGunlockQuantity smallint=6
	----@UpdateMedEnvelopeQuantity smallint=''

BEGIN TRANSACTION
UPDATE [CaringLetters].[VCL_LMS_Cohort]
WITH (TABLOCKX, HOLDLOCK)
SET MVIPersonSID = NULL WHERE 1 = 2

BEGIN;

DROP TABLE IF EXISTS #WritebackRecords
SELECT  
	@VCL_ID AS VCL_ID
	,@DoNotSend AS DoNotSend
	,TRIM(@UpdateFirstName) AS UpdateFirstName
	,UPPER(TRIM(@UpdateFullName)) AS UpdateFullName
	,UPPER(TRIM(@UpdateAddress)) AS UpdateStreetAddress
	,UPPER(TRIM(@UpdateCity)) AS UpdateCity
	,UPPER(TRIM(@UpdateState)) AS UpdateState
	,UPPER(TRIM(@UpdateCountry)) AS UpdateCountry
	,TRIM(@UpdateZip) AS UpdateZip
	,@UpdateGunlockQuantity AS UpdateGunlockQuantity
	--,@UpdateMedEnvelopeQuantity AS UpdateMedEnvelopeQuantity
	,GetDate() as InsertDate
	,@User as UserID
INTO #WritebackRecords

--Identify records that have changed
DROP TABLE IF EXISTS #RecordChanges
SELECT b.MVIPersonSID
	,a.VCL_ID
	,a.DoNotSend
	,UpdateName = CASE WHEN (a.UpdateFirstName=ISNULL(b.FirstName,0) COLLATE SQL_Latin1_General_CP1_CS_AS AND a.UpdateFullName=ISNULL(b.FullName,0))
		THEN 0 ELSE 1 END
	,a.UpdateFirstName AS UpdateFirstName
	,UPPER(a.UpdateFullName) AS UpdateFullName
	,UpdateAddress = CASE WHEN (a.UpdateStreetAddress<>ISNULL(b.StreetAddress,0)
		OR a.UpdateCity<>ISNULL(b.City,0)
		OR a.UpdateState<>ISNULL(b.State ,0)
		OR a.UpdateZip<>ISNULL(b.Zip,0)
		OR a.UpdateCountry<>ISNULL(b.Country,0)
			) THEN 1 ELSE 0 END
	,UPPER(a.UpdateStreetAddress) AS UpdateStreetAddress
	,UPPER(a.UpdateCity) AS UpdateCity
	,UPPER(a.UpdateState) AS UpdateState
	,a.UpdateZip
	,UPPER(a.UpdateCountry) AS UpdateCountry
	,a.UpdateGunlockQuantity
	--,a.UpdateMedEnvelopeQuantity
	,a.InsertDate
	,a.UserID
INTO #RecordChanges
FROM #WritebackRecords a
INNER JOIN [CaringLetters].[VCL_LMS_Cohort] b
	ON a.VCL_ID=b.VCL_ID
WHERE  (a.DoNotSend <> b.DoNotSend
OR (	a.UpdateFirstName<>ISNULL(b.FirstName,0) COLLATE SQL_Latin1_General_CP1_CS_AS 
		OR a.UpdateFullName<>ISNULL(b.FullName,0)
		OR a.UpdateStreetAddress<>ISNULL(b.StreetAddress,0)
		OR a.UpdateCity<>ISNULL(b.City,0)
		OR a.UpdateState<>ISNULL(b.State,0)
		OR a.UpdateZip<>ISNULL(b.Zip,0)
		OR a.UpdateCountry<>ISNULL(b.Country,0)
		OR a.UpdateGunlockQuantity<>ISNULL(b.GunlockQuantity,0)
		--OR a.UpdateMedEnvelopeQuantity<>b.MedEnvelopeQuantity
		)
	)
	
UPDATE #RecordChanges
SET UpdateFirstName=NULL
	,UpdateFullName=NULL
FROM #RecordChanges
WHERE UpdateName=0

UPDATE #RecordChanges
SET UpdateStreetAddress=NULL
	,UpdateCity=NULL
	,UpdateState=NULL
	,UpdateZip=NULL
	,UpdateCountry=NULL
FROM #RecordChanges
WHERE UpdateAddress=0

INSERT INTO [CaringLetters].[VCL_LMS_Writeback] 
SELECT MVIPersonSID
	,VCL_ID
	,DoNotSend
	,UpdateName
	,UpdateFirstName
	,UpdateFullName
	,UpdateAddress
	,UpdateStreetAddress
	,UpdateCity
	,UpdateState
	,UpdateZip
	,UpdateCountry
	,UpdateGunlockQuantity
	,UpdateMedEnvelopeQuantity=NULL
	,InsertDate
	,UserID
FROM #RecordChanges

--Update records where the patient has been removed from mailing
UPDATE [CaringLetters].[VCL_LMS_Cohort]
SET DoNotSend=@DoNotSend
	,RecordModified=1
FROM [CaringLetters].[VCL_LMS_Cohort] a
INNER JOIN #RecordChanges b ON a.VCL_ID=b.VCL_ID
WHERE a.DoNotSend <> b.DoNotSend 

--Update records where the name has been modified
UPDATE [CaringLetters].[VCL_LMS_Cohort]
SET FirstName=@UpdateFirstName
	,FullName = @UpdateFullName
	,RecordModified=1
FROM [CaringLetters].[VCL_LMS_Cohort] a
INNER JOIN #RecordChanges b ON a.VCL_ID=b.VCL_ID 
WHERE b.UpdateName=1

--Update records where the address has been modified
UPDATE [CaringLetters].[VCL_LMS_Cohort]
SET StreetAddress=@UpdateAddress
	,City=@UpdateCity
	,State=@UpdateState
	,Zip=@UpdateZip
	,RecordModified=1
FROM [CaringLetters].[VCL_LMS_Cohort] a
INNER JOIN #RecordChanges b ON a.VCL_ID=b.VCL_ID 
WHERE b.UpdateAddress=1

--Update records where the count of gunlocks to be mailed has been modified
UPDATE [CaringLetters].[VCL_LMS_Cohort]
SET GunlockQuantity=@UpdateGunlockQuantity
	,RecordModified=1
FROM [CaringLetters].[VCL_LMS_Cohort] a
INNER JOIN #RecordChanges b ON a.VCL_ID=b.VCL_ID 
WHERE a.GunlockQuantity<>b.UpdateGunlockQuantity


--Update records where the count of medication envelopes to be mailed has been modified
--UPDATE [CaringLetters].[VCL_LMS_Cohort]
--SET MedEnvelopeQuantity=@UpdateGunlockQuantity
--	,RecordModified=1
--FROM [CaringLetters].[VCL_LMS_Cohort] a
--INNER JOIN #RecordChanges b ON a.VCL_ID=b.VCL_ID 
--WHERE a.MedEnvelopeQuantity<>b.UpdateMedEnvelopeQuantity

END;
COMMIT TRANSACTION


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


SELECT DISTINCT a.MailingDate
	,a.VCL_ID
	,a.MVIPersonSID
	,a.PatientICN
	,a.FirstName
	,UPPER(a.FullName) AS FullName
	,a.Name_CDW
	,a.Name_VCL_Vet
	,a.Name_VCL_Caller
	,b.PreferredName
	,a.StreetAddress
	,a.City
	,a.State
	,a.Zip
	,a.Country
	,a.GunlockQuantity
	--,a.MedEnvelopeQuantity
	,a.ReviewRecordFlag
	,a.ReviewRecordReason
	,RecordModified = CASE WHEN a.RecordModified=1 THEN 'Yes' ELSE NULL END
	,a.DoNotSend
	,CASE WHEN a.RecordModified=1 THEN w.InsertDate END AS LastUpdatedDate
	,CASE WHEN a.RecordModified=1 THEN w.UserID END AS ModifiedBy
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #CheckPermissions c
	ON c.UserName=@User
LEFT JOIN Common.MasterPatient b WITH (NOLOCK)
	ON a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN (SELECT TOP 1 WITH TIES * FROM CaringLetters.VCL_LMS_Writeback WITH (NOLOCK) 
									ORDER BY ROW_NUMBER() OVER (PARTITION BY VCL_ID ORDER BY InsertDate DESC)
			) w
	ON a.VCL_ID=w.VCL_ID
WHERE a.VCL_ID=@VCL_ID
AND a.MailingDate IS NOT NULL

END