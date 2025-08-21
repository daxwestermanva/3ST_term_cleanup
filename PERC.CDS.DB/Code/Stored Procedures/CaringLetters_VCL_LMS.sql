

/*=============================================
-- Author:		Liam Mina
-- Create date: 2025-07-11
-- Description:	VCL Lethal Means Safety mailing list to send gun locks to patients who have called VCL and requested them
-- Updates:

=========================================================================================================================================*/
CREATE PROCEDURE [Code].[CaringLetters_VCL_LMS]


AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.CaringLetters_VCL_LMS', @Description = 'Execution of Code.CaringLetters_VCL_LMS SP'


DROP TABLE IF EXISTS #Today
SELECT CAST(GETDATE() AS DATE) AS Today
INTO #Today


BEGIN

--Get week dates for previous week Saturday-Friday
DROP TABLE IF EXISTS #WeekEpisodes
SELECT TOP 1
	 CAST(DateAdd(day,-13,Date) AS date) AS WeekLookBack
	,CAST(DateAdd(day,-6,Date) AS date) AS WeekBegin
	,CAST(Date AS date) AS WeekEnd
	,CAST(DateAdd(day,3,Date) AS date) AS MailingDate
	,CAST(DateAdd(day,10,Date) AS date) AS NextMailingDate
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=6 --Friday - week end
AND Date < (SELECT * FROM #Today) 
ORDER BY Date DESC

--Find existing data for release date(s) of interest
DROP TABLE IF EXISTS #existingdata
SELECT TOP 1 a.InsertDate
INTO #existingdata
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b on 
	a.InsertDate > b.WeekEnd
ORDER BY a.InsertDate DESC

IF EXISTS (SELECT * FROM #existingdata)
BEGIN

	DECLARE @msg0 varchar(250) = 'Data for this period already exists in CaringLetters.VCL_LMS_Cohort.'
	PRINT @msg0
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg0

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END

DROP TABLE IF EXISTS #VCLHotlineCalls
SELECT h.PatientICN
	  ,h.ICNSource
	  ,h.Name
	  ,h.vcl_ID
	  ,h.VCL_Call_Date
      ,h.VCL_NearestFacilitySiteCode
      ,h.VCL_IsVet
      ,h.VCL_IsActiveDuty
	  ,h.VCL_VeteranStatus
      ,h.VCL_MilitaryBranch
	  ,h.VeteranName
	  ,h.CallerName
	  ,CASE WHEN h.CaringLetterEligible=1 THEN 'Self' ELSE 'Other' END AS RelationshipToVeteran
	 ,ROW_NUMBER() OVER (PARTITION BY h.MVIPersonSID ORDER BY VCL_Call_Date) AS RN
INTO #VCLHotlineCalls
FROM [CaringLetters].[VCL_PatientMapping] h WITH (NOLOCK)
WHERE VCL_Call_Date BETWEEN (SELECT WeekLookBack FROM #WeekEpisodes) AND (SELECT WeekEnd FROM #WeekEpisodes)


--Check for VCL pre-emptive opt outs - these are deceased patients that VCL has identified who should never be enrolled in caring letters
DROP TABLE IF EXISTS #PreEmptiveOptOut
SELECT b.PatientICN, a.DateAdded
INTO #PreEmptiveOptOut
FROM [CaringLetters].[VCL_PreEmptiveOptOuts] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.SSN = b.PatientSSN AND a.LastName = b.LastName AND a.FirstName = b.FirstName


DROP TABLE IF EXISTS #Cohort
SELECT DISTINCT b.MVIPersonSID
	,b.PatientICN
	,a.RelationshipToVeteran
	,FirstName = dflt.propercase(TRIM(CASE WHEN b.PreferredName<>b.FirstName THEN b.PreferredName
		WHEN a.VeteranName=b.PatientName THEN b.FirstName
		WHEN a.VeteranName NOT LIKE '% %' AND a.VeteranName NOT LIKE '%,%' THEN a.VeteranName
		WHEN a.VeteranName LIKE '% %' AND a.VeteranName NOT LIKE '%,%' THEN TRIM(SUBSTRING(a.VeteranName,1,CHARINDEX(' ',a.VeteranName)))
		WHEN a.VeteranName LIKE '%,%'  THEN SUBSTRING(a.VeteranName,CHARINDEX(',',a.VeteranName)+1,LEN(a.VeteranName))
		ELSE ISNULL(b.FirstName,a.VeteranName)
		END))
	,FullName = UPPER(TRIM(CASE WHEN b.PreferredName<>b.FirstName THEN CONCAT(b.PreferredName,' ',b.LastName)
		WHEN VeteranName=PatientName AND b.PatientName IS NOT NULL THEN CONCAT(b.FirstName,' ',b.LastName)
		WHEN a.VeteranName NOT LIKE '% %' AND a.VeteranName NOT LIKE '%,%' THEN CONCAT(a.VeteranName,' ',b.LastName) --VCL name is first name only. Use full name from CDW
		WHEN a.VeteranName LIKE '% %' AND a.VeteranName NOT LIKE '%,%' THEN a.VeteranName --VCL name is already formatted as First Last
		WHEN a.VeteranName LIKE '%,%' THEN CONCAT(SUBSTRING(a.VeteranName,CHARINDEX(',',a.VeteranName)+1,LEN(a.VeteranName)),' ',TRIM(SUBSTRING(a.VeteranName,0,CHARINDEX(',',a.VeteranName))))
		WHEN b.PatientName IS NOT NULL THEN CONCAT(b.FirstName,' ',b.LastName) 
		ELSE a.VeteranName
		END)) 						
	,b.PreferredName
	,b.PatientName
	,a.VeteranName
	,a.CallerName
	,a.ICNSource
	,a.VCL_ID
	,CAST(a.VCL_Call_Date AS date) AS VCL_Call_Date
	,a.VCL_NearestFacilitySiteCode
	,a.VCL_IsVet
	,a.VCL_IsActiveDuty
	,a.VCL_VeteranStatus
	,a.VCL_MilitaryBranch
	,Deceased = CASE WHEN b.DateOfDeath_Combined IS NOT NULL OR p.PatientICN IS NOT NULL THEN 1 ELSE 0 END
	,PreviousMailing = CASE WHEN v.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
	,InsertDate = CAST(getdate() AS date)
	,MailingDate = (SELECT MailingDate FROM #WeekEpisodes)
INTO #Cohort
FROM #VCLHotlineCalls a
LEFT JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.PatientICN=b.PatientICN
LEFT JOIN [CaringLetters].[VCL_LMS_Cohort] v WITH (NOLOCK) --Patient may recieve multiple LMS mailings but subsequent mailings should be flagged
	ON b.MVIPersonSID = v.MVIPersonSID
LEFT JOIN [CaringLetters].[VCL_LMS_Cohort] v2 WITH (NOLOCK) --This join is to prevent duplicate mailings generated from the same call
	ON a.VCL_ID=v2.VCL_ID
LEFT JOIN #PreEmptiveOptOut p
	ON a.PatientICN = p.PatientICN
WHERE v2.MVIPersonSID IS NULL AND p.PatientICN IS NULL AND b.DateOfDeath_SVeteran IS NULL

DROP TABLE IF EXISTS #RequestFormData
SELECT c.VCL_ID
	,a.*
INTO #RequestFormData
FROM [PDW].[VCL_Medoraforce_Perc_VCL_Form_Data__c] a WITH (NOLOCK)
INNER JOIN PDW.VCL_Medoraforce_Perc_VCL_Call__c b WITH (NOLOCK)
	ON a.Call__c=b.ID
INNER JOIN #VCLHotlineCalls c 
	ON b.Name=c.Name

DROP TABLE IF EXISTS #FirearmStorage
SELECT DISTINCT value AS FirearmStorage, VCL_ID
INTO #FirearmStorage
FROM #RequestFormData a
CROSS APPLY STRING_SPLIT(Past_Secure_Storage_of_Firearms__c,';')
WHERE Past_Secure_Storage_of_Firearms__c <>''

DROP TABLE IF EXISTS #RefusalReason
SELECT DISTINCT value AS RefusalReason, VCL_ID
INTO #RefusalReason
FROM #RequestFormData
CROSS APPLY STRING_SPLIT(Why_Didnt_the_Veteran_Accept__c,';')
WHERE Why_Didnt_the_Veteran_Accept__c <>''

--Get details of whether a gun lock was offered, what safe storage the Veteran has currently, and whether/why the Veteran refused a gun lock
DROP TABLE IF EXISTS #GunLockOffered_Storage_Refusal
SELECT DISTINCT a.VCL_ID
	,MAX(Accepted_Gun_Lock__c) AS AcceptedGunLock
	,MAX(CASE WHEN s.FirearmStorage='Cable lock from VCL' THEN 1 ELSE 0 END) AS Storage_CableLockVCL
	,MAX(CASE WHEN s.FirearmStorage='Cable or trigger lock from other source' THEN 1 ELSE 0 END) AS Storage_CableLockOther
	,MAX(CASE WHEN s.FirearmStorage='Disassembling' THEN 1 ELSE 0 END) AS Storage_Disassemble
	,MAX(CASE WHEN s.FirearmStorage='Gun safe' THEN 1 ELSE 0 END) AS Storage_GunSafe
	,MAX(CASE WHEN s.FirearmStorage='Removing from home' THEN 1 ELSE 0 END) AS Storage_RemoveFromHome
	,MAX(CASE WHEN s.FirearmStorage='Other' THEN 1 ELSE 0 END) AS Storage_Other
	,MAX(CASE WHEN r.RefusalReason='Don''t want/wouldn''t use' THEN 1 ELSE 0 END) AS Refuse_DontWant
	,MAX(CASE WHEN r.RefusalReason LIKE 'Have a way to store already (not currently%' THEN 1 ELSE 0 END) AS Refuse_HaveStorageNotUsed --typo in this string that will be corrected; using pattern match to catch before and after correction
	,MAX(CASE WHEN r.RefusalReason='Protection of others/ self-defense' THEN 1 ELSE 0 END) AS Refuse_Defense
	,MAX(CASE WHEN r.RefusalReason='Weapon already securely stored' THEN 1 ELSE 0 END) AS Refuse_AlreadySecured
	,MAX(CASE WHEN r.RefusalReason='Other' THEN 1 ELSE 0 END) AS Refuse_Other
	,MAX(CASE WHEN r.RefusalReason='Unknown/Did not provide a reason' THEN 1 ELSE 0 END) AS Refuse_Unknown
	,MAX(CASE WHEN r.RefusalReason='Responder unable to offer' THEN 1 ELSE 0 END) AS Refuse_NotOffered
INTO #GunLockOffered_Storage_Refusal
FROM #RequestFormData a
LEFT JOIN #FirearmStorage s ON a.VCL_ID=s.VCL_ID
LEFT JOIN #RefusalReason r ON a.VCL_ID=r.VCL_ID
GROUP BY a.VCL_ID


--For Veterans who accepted a gun lock, get address details
DROP TABLE IF EXISTS #RequestDetails
SELECT d.VCL_ID
	,UPPER(d.Mailing_Address__Street__s) AS StreetAddress
	,UPPER(d.Mailing_Address__City__s) AS City
	,UPPER(d.Mailing_Address__StateCode__s) AS [State]
	,UPPER(d.Mailing_Address__PostalCode__s) AS Zip
	,UPPER(d.Mailing_Address__CountryCode__s) AS Country
	,d.Number_of_Locks_Accepted__c AS GunlockQuantity
	,MedEnvelopeQuantity=NULL --not yet part of the program
	,CASE WHEN c.MVIPersonSID IS NOT NULL THEN ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY c.VCL_Call_Date) ELSE 1 END AS RN
INTO #RequestDetails
FROM #RequestFormData d 
INNER JOIN #Cohort c 
	ON d.VCL_ID=c.VCL_ID
WHERE d.Accepted_Gun_Lock__c = 'Yes'

DROP TABLE IF EXISTS #ReviewRecordReason
SELECT DISTINCT VCL_ID, String_Agg(ReviewRecordReason,', ') WITHIN GROUP (ORDER BY ReviewRecordReason) AS ReviewRecordReason
INTO #ReviewRecordReason 
FROM (
	SELECT VCL_ID,ReviewRecordReason='Received previous mailing'
	FROM #Cohort WHERE PreviousMailing=1 
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Third party caller'
	FROM #Cohort WHERE RelationshipToVeteran='Other'
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Is Veteran - No'
	FROM #Cohort WHERE VCL_IsVet='No'
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Is Veteran - Refused'
	FROM #Cohort WHERE VCL_IsVet LIKE 'Ref%'
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Preferred name'
	FROM #Cohort WHERE PreferredName IS NOT NULL AND VeteranName <> PreferredName
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Non-US country'
	FROM #RequestDetails WHERE Country <> 'US' 
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Address'
	FROM #RequestDetails WHERE LEN(City)<3 OR LEN(Zip)<5 OR StreetAddress IS NULL
	UNION ALL
	SELECT VCL_ID,ReviewRecordReason='Name'
	FROM #Cohort WHERE LEN(FirstName)<3 OR FirstName LIKE '%"%' OR FirstName LIKE '%(%' OR FirstName=FullName
	UNION ALL
	SELECT VCL_ID, ReviewRecordReason='Multiple Requests'
	FROM #RequestDetails
	WHERE RN>1
	) a
GROUP BY VCL_ID

DROP TABLE IF EXISTS #AddMailingInfo
SELECT c.VCL_ID
	,CASE WHEN AcceptedGunLock='Yes' THEN c.MailingDate ELSE NULL END AS MailingDate
	,c.MVIPersonSID
	,c.PatientICN
	,c.VCL_Call_Date
	,c.VCL_IsVet
	,c.VCL_IsActiveDuty
	,c.VCL_VeteranStatus
	,c.VCL_MilitaryBranch
	,c.VeteranName AS Name_VCL_Vet
	,c.CallerName AS Name_VCL_Caller
	,c.PatientName AS Name_CDW
	,c.PreferredName
	,c.FirstName
	,c.FullName
	,d.StreetAddress
	,d.City
	,d.[State]
	,d.Zip
	,d.Country
	,g.AcceptedGunLock
	,g.Storage_CableLockVCL
	,g.Storage_CableLockOther
	,g.Storage_Disassemble
	,g.Storage_GunSafe
	,g.Storage_RemoveFromHome
	,g.Storage_Other
	,g.Refuse_DontWant
	,g.Refuse_HaveStorageNotUsed
	,g.Refuse_Defense
	,g.Refuse_AlreadySecured
	,g.Refuse_Other
	,g.Refuse_Unknown
	,g.Refuse_NotOffered
	,d.GunlockQuantity
	,MedEnvelopeQuantity=NULL --not yet part of the program
	,ReviewRecordFlag = CASE WHEN r.VCL_ID IS NOT NULL THEN 1 ELSE 0 END
	,ISNULL(r.ReviewRecordReason,'N/A') AS ReviewRecordReason
	,RecordModified=0
	,DoNotSend=CASE WHEN Deceased=1 THEN 1 
		WHEN AcceptedGunLock='Yes' THEN 0
		ELSE 1 END
	,InsertDate = (SELECT Today FROM #Today)
INTO #AddMailingInfo
FROM #Cohort c
INNER JOIN #GunLockOffered_Storage_Refusal g
	ON g.VCL_ID=c.VCL_ID
LEFT JOIN #RequestDetails d 
	ON c.VCL_ID=d.VCL_ID
LEFT JOIN #ReviewRecordReason r
	ON c.VCL_ID=r.VCL_ID


INSERT INTO [CaringLetters].[VCL_LMS_Cohort] (
	[VCL_ID]
    ,[MVIPersonSID]
    ,[PatientICN]
    ,[MailingDate]
    ,[VCL_Call_Date]
    ,[VCL_IsVet]
    ,[VCL_IsActiveDuty]
    ,[VCL_VeteranStatus]
    ,[VCL_MilitaryBranch]
	,[AcceptedGunLock]
	,[Storage_CableLockVCL]
	,[Storage_CableLockOther]
	,[Storage_Disassemble]
	,[Storage_GunSafe]
	,[Storage_RemoveFromHome]
	,[Storage_Other]
	,[Refuse_DontWant]
	,[Refuse_HaveStorageNotUsed]
	,[Refuse_Defense]
	,[Refuse_AlreadySecured]
	,[Refuse_Other]
	,[Refuse_Unknown]
	,[Refuse_NotOffered]
    ,[FirstName]
    ,[FullName]
    ,[PreferredName]
    ,[Name_VCL_Vet]
	,[Name_VCL_Caller]
    ,[Name_CDW]
    ,[StreetAddress]
    ,[City]
    ,[State]
    ,[Zip]
    ,[Country]
    ,[GunlockQuantity]
    ,[MedEnvelopeQuantity]
    ,[ReviewRecordFlag]
    ,[ReviewRecordReason]
    ,[RecordModified]
    ,[DoNotSend]
	,[InsertDate]
	)
SELECT DISTINCT
	[VCL_ID]
    ,[MVIPersonSID]
    ,[PatientICN]
    ,[MailingDate]
    ,[VCL_Call_Date]
    ,[VCL_IsVet]
    ,[VCL_IsActiveDuty]
    ,[VCL_VeteranStatus]
    ,[VCL_MilitaryBranch]
	,[AcceptedGunLock]
	,[Storage_CableLockVCL]
	,[Storage_CableLockOther]
	,[Storage_Disassemble]
	,[Storage_GunSafe]
	,[Storage_RemoveFromHome]
	,[Storage_Other]
	,[Refuse_DontWant]
	,[Refuse_HaveStorageNotUsed]
	,[Refuse_Defense]
	,[Refuse_AlreadySecured]
	,[Refuse_Other]
	,[Refuse_Unknown]
	,[Refuse_NotOffered]
    ,[FirstName]
    ,[FullName]
    ,[PreferredName]
    ,[Name_VCL_Vet]
	,[Name_VCL_Caller]
    ,[Name_CDW]
    ,[StreetAddress]
    ,[City]
    ,[State]
    ,[Zip]
    ,[Country]
    ,[GunlockQuantity]
    ,[MedEnvelopeQuantity]
    ,[ReviewRecordFlag]=CASE WHEN DoNotSend=1 THEN 0 ELSE ReviewRecordFlag END
    ,[ReviewRecordReason]=CASE WHEN DoNotSend=1 THEN NULL ELSE ReviewRecordReason END
    ,[RecordModified]
    ,[DoNotSend]
	,InsertDate = (SELECT * FROM #Today)
FROM #AddMailingInfo


EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END;

END