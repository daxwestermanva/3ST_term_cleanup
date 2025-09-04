

/*=============================================
-- Author:		Liam Mina
-- Create date: 2025-02-19
-- Description:	Combined address pull for HRF and VCL caring letters programs
-- Modifications:

Testing Execution - EXECUTE [Code].[CaringLetters_Mailings]
  =============================================*/
CREATE   PROCEDURE [Code].[CaringLetters_Mailings](
@RunType varchar(10)= NULL
)
AS
BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.CaringLetters_Mailings', @Description = 'Execution of Code.CaringLetters_Mailings SP'
	
DROP TABLE IF EXISTS #Today
SELECT CAST(GETDATE() AS DATE) AS Today
INTO #Today

--Get week dates for previous week Saturday-Friday
DROP TABLE IF EXISTS #WeekEpisodes
SELECT TOP 1
	CAST(DateAdd(day,-6,Date) AS date) AS WeekBegin
	,CAST(Date AS date) AS WeekEnd
	,CAST(DateAdd(day,3,Date) AS date) AS MailingDate
	,CAST(DateAdd(day,10,Date) AS date) AS NextMailingDate
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=6 --Friday - week end
AND Date < (SELECT * FROM #Today) 
ORDER BY Date DESC



DROP TABLE IF EXISTS #FullCohort
SELECT VCL_ID
	,MVIPersonSID
	,PatientICN
	,ICNSource
	,DoNotSend
	,DoNotSendDate
	,DoNotSendReason
	,FirstLetterDate
	,SecondLetterDate
	,ThirdLetterDate
	,FourthLetterDate
	,FifthLetterDate
	,SixthLetterDate
	,SeventhLetterDate
	,EighthLetterDate
	,InsertDate
	,LetterFrom
INTO #FullCohort
FROM [CaringLetters].[VCL_Cohort] WITH (NOLOCK) WHERE @RunType='VCL'
UNION ALL
SELECT VCL_ID=NULL
	,MVIPersonSID
	,PatientICN
	,ICNSource=NULL
	,DoNotSend
	,DoNotSendDate
	,DoNotSendReason
	,FirstLetterDate
	,SecondLetterDate
	,ThirdLetterDate
	,FourthLetterDate
	,FifthLetterDate
	,SixthLetterDate
	,SeventhLetterDate
	,EighthLetterDate
	,InsertDate
	,LetterFrom=NULL
FROM [CaringLetters].[HRF_Cohort] WITH (NOLOCK) WHERE @RunType='HRF'

----Get name and address data.  Run this part prior to each letter run to get most current name and address
DROP TABLE IF EXISTS #MailingDates
SELECT DISTINCT
	CAST(date as date) AS MailingDate
INTO #MailingDates
FROM [Dim].[Date] a WITH (NOLOCK)
INNER JOIN (SELECT MIN(FirstLetterDate) AS MinDate
			,MAX(EighthLetterDate) AS MaxDate
			FROM #FullCohort 
			)b
	ON a.Date BETWEEN b.MinDate AND b.MaxDate
WHERE DayOfWeek=2 --Mondays, when letters are sent

DROP TABLE IF EXISTS #NextMailingDate
SELECT TOP 1
	CAST(date as date) AS MailingDate
	,CAST(DateAdd(day,6,date) as date) AS WeekEndDate
INTO #NextMailingDate
FROM [Dim].[Date] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b ON a.Date > b.WeekEnd
WHERE DayOfWeek=2 --lists for mailings are pulled on Mondays
ORDER BY ROW_NUMBER() OVER (PARTITION BY DayOfWeek ORDER BY Date)

--Get list of patients for current week's mailing
DROP TABLE IF EXISTS #NextMailingGroup
SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 1
	,a.FirstLetterDate AS LetterDate
	,a.ICNSource
INTO #NextMailingGroup
FROM #FullCohort a
INNER JOIN #NextMailingDate b on a.FirstLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 2
	,a.SecondLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.SecondLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 3
	,a.ThirdLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.ThirdLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 4
	,a.FourthLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.FourthLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 5
	,a.FifthLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.FifthLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 6
	,a.SixthLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a
INNER JOIN #NextMailingDate b on a.SixthLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 7
	,a.SeventhLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.SeventhLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0

UNION ALL

SELECT b.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,LetterNumber = 8
	,a.EighthLetterDate AS LetterDate
	,a.ICNSource
FROM #FullCohort a 
INNER JOIN #NextMailingDate b on a.EighthLetterDate BETWEEN b.MailingDate AND b.WeekEndDate
WHERE a.DoNotSend=0


--Pull past mailings sent to this cohort
DROP TABLE IF EXISTS #PastMailings
SELECT a.MVIPersonSID
	,a.VCL_ID
	,a.LetterNumber
	,FirstNameLegal
	,FullNameLegal
	,FirstNamePreferred
	,FullNamePreferred
	,PreferredName
	,NameSource
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,State
	,Zip
	,Country
	,AddressSource
	,InsertDate
INTO #PastMailings
FROM [CaringLetters].[VCL_Mailings] a WITH (NOLOCK)
INNER JOIN #NextMailingGroup b ON a.MVIPersonSID=b.MVIPersonSID AND a.VCL_ID=b.VCL_ID AND @RunType='VCL'
UNION ALL
SELECT a.MVIPersonSID
	,VCL_ID=NULL
	,a.LetterNumber
	,FirstNameLegal
	,FullNameLegal
	,FirstNamePreferred
	,FullNamePreferred
	,PreferredName
	,NameSource
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,State
	,Zip
	,Country
	,AddressSource
	,InsertDate
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK)
INNER JOIN #NextMailingGroup b ON a.MVIPersonSID=b.MVIPersonSID AND @RunType='HRF'



DROP TABLE IF EXISTS #AddName
SELECT a.*
	,b.FirstName
	,b.MiddleName
	,b.PreferredName
	,CASE WHEN PreferredName IN ('PREFER NOT TO ANSWER','SAME AS GIVEN','NONE') OR PreferredName LIKE 'NO% GIVEN' THEN NULL
		WHEN (PreferredName LIKE '%JR' AND b.NameSuffix LIKE 'J%') THEN TRIM(REPLACE(REPLACE(PreferredName,'JR',''),b.LastName,'')) 
		WHEN PreferredName LIKE CONCAT('% ',b.LastName) OR PreferredName LIKE CONCAT(b.LastName, ' %') THEN TRIM(REPLACE(PreferredName,b.LastName,''))
		ELSE PreferredName END AS PreferredNameNoLast
	,b.LastName
	,CASE WHEN b.NameSuffix LIKE 'JR%' OR b.NameSuffix LIKE 'JUNIOR%' THEN 'JR'
		WHEN b.NameSuffix IN ('II','III','IV','V','VI','VII','VIII','IX','X') THEN b.NameSuffix
		WHEN b.NameSuffix LIKE 'II %' THEN 'II'
		WHEN b.NameSuffix LIKE 'SR%' OR b.NameSuffix = 'SENIOR' THEN 'SR'
		ELSE NULL END AS NameSuffix
INTO #AddName
FROM #NextMailingGroup a
LEFT JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID

--Fields to be added back in after the name is formatted
DROP TABLE IF EXISTS #AddFields
CREATE TABLE #AddFields (String varchar(20), SearchString varchar(20), ReplaceWith varchar(20))
INSERT INTO #AddFields VALUES 
	('MR','MR %','')
	,('MS','MS %','') 
	,('MRS','MRS %','')
	,('MISS','MISS %','')
	,('DR', 'DR %','')
	,('SGT', 'SGT %','')
	--,('JR','JR%','')

DROP TABLE IF EXISTS #FormatName1
SELECT TOP 1 WITH TIES MVIPersonSID
	,FirstName
	,MiddleName
	,LastName
	,PreferredName
	,NameSuffix
	,CASE WHEN PreferredNameRefined = '' THEN NULL ELSE PreferredNameRefined
		END AS PreferredNameRefined
	,PreferredNameNoLast
INTO #FormatName1
FROM (
	SELECT a.MVIPersonSID
		,FirstName
		,MiddleName
		,LastName
		,PreferredName
		,NameSuffix
		,CASE WHEN b.String IS NOT NULL THEN TRIM(REPLACE(a.PreferredNameNoLast,String,ReplaceWith))
			ELSE a.PreferredNameNoLast
			END AS PreferredNameRefined
		,PreferredNameNoLast
	FROM #AddName a
	LEFT JOIN #AddFields b 
		ON a.PreferredNameNoLast LIKE b.SearchString OR a.PreferredNameNoLast = b.String
	) a
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY PreferredName) --to prevent explosion if patient's name matches multiple strings

DROP TABLE IF EXISTS #FormatName2
SELECT a.MVIPersonSID
	,a.FirstName AS FirstNameLegal
	,a.PreferredNameRefined
	,a.PreferredName
	,CASE WHEN a.PreferredName = 'Jr' THEN 'Jr'
		WHEN b.String IS NOT NULL AND a.FirstName = a.PreferredNameRefined THEN CONCAT(b.String,' ', a.LastName)
		WHEN b.String IS NOT NULL THEN CONCAT(b.String,' ', ISNULL(a.PreferredNameRefined,a.LastName))
		ELSE a.PreferredNameRefined END AS FirstNamePreferred
	,CASE WHEN a.PreferredName = 'Jr' AND a.MiddleName IS NOT NULL THEN CONCAT(a.FirstName, ' ', a.MiddleName, ' ', a.LastName, ' ', a.NameSuffix)
		WHEN a.PreferredName = 'Jr' THEN CONCAT(a.FirstName, ' ', a.LastName, ' ', a.NameSuffix)
		WHEN b.String IS NOT NULL AND a.PreferredNameRefined IS NOT NULL THEN CONCAT(b.String, ' ', a.PreferredNameRefined, ' ', a.LastName, ' ', a.NameSuffix)
		WHEN b.String IS NOT NULL THEN CONCAT(b.String, ' ', a.LastName, ' ', a.NameSuffix)
		WHEN a.PreferredName IS NOT NULL THEN CONCAT(a.PreferredNameRefined, ' ', a.LastName, ' ', a.NameSuffix) END AS FullNamePreferred
	,CASE WHEN a.NameSuffix IS NOT NULL AND a.MiddleName IS NOT NULL THEN CONCAT(a.FirstName, ' ', a.MiddleName, ' ', a.LastName, ' ', a.NameSuffix) --only include middle name if patient is a Jr or Sr, etc.
		WHEN a.NameSuffix IS NOT NULL THEN CONCAT(a.FirstName, ' ', a.LastName, ' ', a.NameSuffix)
		WHEN a.FirstName IS NULL AND a.MiddleName IS NOT NULL THEN CONCAT(a.MiddleName, ' ', a.LastName)
		WHEN a.FirstName IS NULL THEN a.LastName
		ELSE CONCAT(a.FirstName, ' ', a.LastName) END AS FullNameLegal
INTO #FormatName2
FROM #FormatName1 a
LEFT JOIN #AddFields b ON a.PreferredNameNoLast LIKE b.SearchString OR a.PreferredNameNoLast = b.String

--Select which of the patient's addresses should be used. Prioritize Temp, then Mail, then Home
DROP TABLE IF EXISTS #States
SELECT DISTINCT StateAbbrev
INTO #States
FROM NDim.MVIState WITH (NOLOCK)
WHERE TRY_CAST(VAStateCode AS int)<60 --US states
OR TRY_CAST(VAStateCode AS int) IN (60,66,69,72,78,85,87,88) --US territories and armed forces

DROP TABLE IF EXISTS #Philippines
SELECT DISTINCT StateAbbrev
INTO #Philippines
FROM NDim.MVIState WITH (NOLOCK)
WHERE TRY_CAST(VAStateCode AS int) = 96 --Philippines

DROP TABLE IF EXISTS #AllAddresses
SELECT DISTINCT
		mvi.MVIPersonSID
	,ad.StreetAddress1
	,CASE WHEN ad.StreetAddress2=ad.StreetAddress1 AND ad.StreetAddress1 <> ad.StreetAddress3 
		THEN ad.StreetAddress3 ELSE ad.StreetAddress2 END AS StreetAddress2
	,CASE WHEN ad.StreetAddress2=ad.StreetAddress1 OR ad.StreetAddress3=ad.StreetAddress1 OR ad.StreetAddress3=ad.StreetAddress2 
		THEN NULL ELSE StreetAddress3 END AS StreetAddress3
	,ad.City
	,COALESCE(LEFT(ad.Zip, 5), LEFT(ad.Zip4,5), LEFT(ad.PostalCode,5)) AS Zip
	,CASE WHEN st.StateAbbrev IN ('*','*Missing*') THEN z.StateCode
		ELSE COALESCE(st.StateAbbrev,z.StateCode, ad.Province) END AS State
	,Country = CASE WHEN c.PostalName='<NULL>' THEN c.PostalDescription ELSE c.PostalName END
	,POBox=CASE WHEN StreetAddress1 LIKE '%BOX %' OR StreetAddress2 LIKE '%BOX %' THEN 1 ELSE 0 END
	,ad.AddressChangeDateTime
	,AddressType=CASE WHEN OrdinalNumber=14 THEN 'Home'
		WHEN OrdinalNumber=13 THEN 'Mail'
		WHEN OrdinalNumber=4 THEN 'Temp' END
	,Source='EHR'
	,CleanAddress=0
INTO #AllAddresses
FROM #NextMailingGroup m 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON m.MVIPersonSID=mvi.MVIPersonSID
INNER JOIN [SPatient].[SPatientAddress] ad WITH (NOLOCK)
	ON ad.PatientSID = mvi.PatientPersonSID 
LEFT JOIN [Dim].[State] st WITH (NOLOCK) 
	ON st.StateSID = ad.StateSID
LEFT JOIN [Dim].[Country] c WITH (NOLOCK)
	ON ad.CountrySID = c.CountrySID
LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
	ON LEFT(ad.Zip,5)=z.ZipCode
WHERE ad.OrdinalNumber = 14 --Residential address
	OR ad.OrdinalNumber = 13  --Mailing address
	OR (ad.OrdinalNumber=4 AND (CAST(GETDATE() AS DATE) BETWEEN CAST(ad.AddressStartDateTime AS DATE) AND CAST(ad.AddressEndDateTime AS DATE) --temp address
		OR (ad.AddressStartDateTime <= CAST(CAST(GETDATE() AS DATE) AS DATETIME2) AND ad.AddressEndDateTime IS NULL)
		OR (ad.AddressStartDateTime IS NULL AND ad.AddressEndDateTime > CAST(CAST(GETDATE() AS DATE) AS DATETIME2))
		OR (ad.AddressStartDateTime IS NULL AND ad.AddressEndDateTime IS NULL)
		) AND ad.StreetAddress1 IS NOT NULL AND ad.City IS NOT NULL)
	AND ad.BadAddressIndicator NOT IN ('HOMELESS','ADDRESS NOT FOUND','UNDELIVERABLE')
UNION ALL
SELECT m.MVIPersonSID
		,Mail_StreetAddress as MailStreetAddress1
		,CASE WHEN Mail_StreetAddress=Mail_StreetAddress2 THEN NULL ELSE Mail_StreetAddress2 END AS MailStreetAddress2
		,StreetAddress3=NULL
		,DerivedMail_City as MailCity
		,LEFT(Mail_Zipcode, 5) as MailZip
		,ISNULL(DerivedMail_State,z.StateCode) as MailState
		,Country=NULL
		,POBox=CASE WHEN Mail_StreetAddress LIKE '%BOX %' OR Mail_StreetAddress2 LIKE '%BOX %' THEN 1 ELSE 0 END
		,Mail_ModifiedDateTime as ModifiedDateTime
		,AddressType='Mail'
		,Source='EHR'
		,CleanAddress=0
FROM #NextMailingGroup m 
INNER JOIN [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
	ON i.MVIPersonSID=m.MVIPersonSID
LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
		ON LEFT(i.Mail_Zipcode,5)=z.ZipCode
WHERE Mail_StreetAddress IS NOT NULL 
UNION ALL
SELECT m.MVIPersonSID
		,Temp_StreetAddress as TempStreetAddress1
		,CASE WHEN Temp_StreetAddress=Temp_StreetAddress2 THEN NULL ELSE Temp_StreetAddress2 END AS TempStreetAddress2
		,StreetAddress3=NULL
		,DerivedTemp_City as TempCity
		,LEFT(Temp_Zipcode, 5) as TempZip
		,ISNULL(DerivedTemp_State,z.StateCode) as TempState
		,Country=NULL
		,POBox=CASE WHEN Temp_StreetAddress LIKE '%BOX %' OR Temp_StreetAddress2 LIKE '%BOX %' THEN 1 ELSE 0 END
		,Temp_ModifiedDateTime as ModifiedDateTime
		,AddressType='Temp'
		,Source='EHR'
		,CleanAddress=0
FROM #NextMailingGroup m 
INNER JOIN [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
	ON i.MVIPersonSID=m.MVIPersonSID
LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
		ON LEFT(i.Temp_Zipcode,5)=z.ZipCode
WHERE Temp_StreetAddress IS NOT NULL
UNION ALL
SELECT m.MVIPersonSID
		,Home_StreetAddress as StreetAddress1
		,CASE WHEN Home_StreetAddress=Home_StreetAddress2 THEN NULL ELSE Home_StreetAddress2 END AS StreetAddress2
		,StreetAddress3=NULL
		,DerivedHome_City  as City
		,LEFT(Home_Zipcode, 5) as Zip
		,ISNULL(DerivedHome_State,z.StateCode) as State 
		,Country=NULL
		,POBox=CASE WHEN Home_StreetAddress LIKE '%BOX %' OR Home_StreetAddress2 LIKE '%BOX %' THEN 1 ELSE 0 END
		,Home_ModifiedDateTime as ModifiedDateTime
		,AddressType='Home'
		,Source='EHR'
		,CleanAddress=0
FROM #NextMailingGroup m 
INNER JOIN [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
	ON i.MVIPersonSID=m.MVIPersonSID
LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
	ON LEFT(i.Home_Zipcode,5)=z.ZipCode
	
INSERT INTO #AllAddresses
SELECT mp.MVIPersonSID
	,mp.StreetAddress1
	,CASE WHEN mp.StreetAddress2=mp.StreetAddress1 AND mp.StreetAddress1 <> mp.StreetAddress3 
		THEN mp.StreetAddress3 ELSE mp.StreetAddress2 END AS StreetAddress2
	,CASE WHEN mp.StreetAddress2=mp.StreetAddress1 OR mp.StreetAddress3=mp.StreetAddress1 OR mp.StreetAddress3=mp.StreetAddress2 
		THEN NULL ELSE mp.StreetAddress3 END AS StreetAddress3
	,mp.City
	,LEFT(mp.Zip4,5) AS Zip
	,s.StateAbbrev
	,c.CountryDescription
	,POBox=CASE WHEN mp.StreetAddress1 LIKE '%BOX %' OR mp.StreetAddress1 LIKE '%BOX %' THEN 1 ELSE 0 END
	,ISNULL(a.AddressChangeDateTime,mp.PersonModifiedDateTime) AS ModifiedDateTime
	,CASE WHEN mp.StreetAddress1 LIKE '%BOX %' OR mp.StreetAddress1 LIKE '%BOX %' THEN 'Mail' ELSE 'Home' END AS AddressType
	,Source='MPI'
	,CleanAddress=0
FROM SVeteran.SMVIPerson mp WITH (NOLOCK)
INNER JOIN #NextMailingGroup m WITH (NOLOCK)
	ON mp.MVIPersonSID=m.MVIPersonSID
LEFT JOIN #AllAddresses a
	ON a.MVIPersonSID=mp.MVIPersonSID AND a.StreetAddress1=mp.StreetAddress1
LEFT JOIN NDim.MVIState s WITH (NOLOCK)
	ON mp.MVIStateSID=s.MVIStateSID
LEFT JOIN NDim.MVICountryCode c WITH (NOLOCK)
	ON mp.MVICountrySID=c.MVICountryCodeSID

UPDATE #AllAddresses
SET State='PH'
WHERE Country='Philippines'

UPDATE #AllAddresses
SET CleanAddress = 1 WHERE StreetAddress1 IS NOT NULL AND TRIM(StreetAddress1) NOT LIKE '*%' AND TRIM(StreetAddress1) NOT LIKE '%Do Not Mail%' AND TRIM(StreetAddress1) NOT LIKE 'XX%' 
		AND TRIM(StreetAddress1) NOT LIKE '(%' AND TRIM(StreetAddress1) NOT LIKE '0%0' AND TRIM(StreetAddress1) NOT LIKE '...%' AND TRIM(StreetAddress1) NOT LIKE '?%'  
		AND TRIM(StreetAddress1) NOT IN ('N/A','NONE','','Homeless','UKNOWN') AND TRIM(StreetAddress1) NOT LIKE '//%' AND TRIM(StreetAddress1) NOT LIKE '%Unknown%'
		AND TRIM(City) NOT IN ('') AND TRIM(City) NOT LIKE '...%'
		AND LEN(City)>2
		AND (State IN (SELECT StateAbbrev FROM #States) OR State IN (SELECT StateAbbrev FROM #Philippines))

DROP TABLE IF EXISTS #ChooseAddress
SELECT TOP 1 WITH TIES *
INTO #ChooseAddress
FROM #AllAddresses
WHERE CleanAddress=1
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, AddressType ORDER BY AddressChangeDateTime DESC, POBox DESC)

--1.	If the temp address has been updated more recently than the MPI record or most recent VistA address, use temp address
--2.	Otherwise, if the MPI address is a PO box, use MPI address
--3.	Otherwise, if most recent VistA address is a PO box, use most recent VistA address
--4.	Otherwise, if most recent VistA address has been updated more recently than the MPI record, use most recent VistA address
--5.	Otherwise use MPI address

DROP TABLE IF EXISTS #ChooseAddress2
SELECT g.MVIPersonSID
	,CASE WHEN t.AddressChangeDateTime > h.AddressChangeDateTime AND t.AddressChangeDateTime > m.AddressChangeDateTime THEN 'Temp'
		WHEN h.POBox=1 THEN 'Home'
		WHEN m.POBox=1 THEN 'Mail'
		WHEN m.AddressChangeDateTime > h.AddressChangeDateTime THEN 'Mail'
		WHEN h.MVIPersonSID IS NOT NULL THEN 'Home' 
		WHEN m.MVIPersonSID IS NOT NULL THEN 'Mail' 
		WHEN t.MVIPersonSID IS NOT NULL THEN 'Temp'
		END AS AddressSource
	,CASE WHEN h.MVIPersonSID IS NULL AND m.MVIPersonSID IS NULL AND t.MVIPersonSID IS NULL THEN 1 ELSE 0 END AS BadAddress
INTO #ChooseAddress2
FROM #NextMailingGroup g
LEFT JOIN #ChooseAddress h ON g.MVIPersonSID=h.MVIPersonSID AND h.AddressType='Home'
LEFT JOIN #ChooseAddress m ON g.MVIPersonSID=m.MVIPersonSID AND m.AddressType='Mail'
LEFT JOIN #ChooseAddress t ON g.MVIPersonSID=t.MVIPersonSID AND t.AddressType='Temp'
;
--Disenroll people with no mailing address
IF @RunType='VCL'
UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend=1
	,DoNotSendReason='Bad Address'
	,DoNotSendDate=(SELECT Today FROM #Today)
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #ChooseAddress2 WHERE BadAddress=1)
ELSE
IF @RunType='HRF'
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend=1
	,DoNotSendReason='Bad Address'
	,DoNotSendDate=(SELECT Today FROM #Today)
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #ChooseAddress2 WHERE BadAddress=1)
;

DROP TABLE IF EXISTS #AddAddress
SELECT a.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,a.LetterNumber
	,b.FirstNameLegal
	,b.FullNameLegal
	,b.FirstNamePreferred
	,b.FullNamePreferred
	,m.LastName
	,ad.StreetAddress1
	,ad.StreetAddress2
	,ad.StreetAddress3
	,ad.City
	,ad.[State]
	,ad.Zip
	,ad.Country
	,c.AddressSource AS PatientAddress
	,m.PatientSSN
	,m.CellPhoneNumber
	,m.PhoneNumber
	,m.LastFour
	,a.ICNSource
	,ad.AddressChangeDateTime
INTO #AddAddress
FROM #NextMailingGroup a
INNER JOIN #ChooseAddress2 c
	ON a.MVIPersonSID = c.MVIPersonSID
INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK)
	ON a.MVIPersonSID = m.MVIPersonSID
INNER JOIN #ChooseAddress ad 
	ON a.MVIPersonSID=ad.MVIPersonSID AND ad.AddressType=c.AddressSource
LEFT JOIN #FormatName2 b 
	ON a.MVIPersonSID = b.MVIPersonSID

--Address formatting for mailing
UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'DRIVE','DR')
WHERE StreetAddress1 LIKE '% DRIVE'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'DRIVE','DR')
WHERE StreetAddress2 LIKE '% DRIVE'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'ROAD','RD')
WHERE StreetAddress1 LIKE '% ROAD'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'ROAD','RD')
WHERE StreetAddress2 LIKE '% ROAD'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'STREET','ST')
WHERE StreetAddress1 LIKE '% STREET'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'STREET','ST')
WHERE StreetAddress2 LIKE '% STREET'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'AVENUE','AVE')
WHERE StreetAddress1 LIKE '% AVENUE'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'AVENUE','AVE')
WHERE StreetAddress2 LIKE '% AVENUE'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'APARTMENT','APT')
WHERE StreetAddress1 LIKE '%APARTMENT%'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'APARTMENT','APT')
WHERE StreetAddress2 LIKE '%APARTMENT%'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'BUILDING','BLDG')
WHERE StreetAddress1 LIKE '%BUILDING%' 

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'BUILDING','BLDG')
WHERE StreetAddress2 LIKE '%BUILDING%' 

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'ROOM','RM')
WHERE StreetAddress1 LIKE '% ROOM %'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'ROOM','RM')
WHERE StreetAddress2 LIKE '% ROOM %'

UPDATE #AddAddress
	SET StreetAddress1 = REPLACE(StreetAddress1,'P O','PO')
WHERE StreetAddress1 LIKE '%P O Box%'

UPDATE #AddAddress
	SET StreetAddress2 = REPLACE(StreetAddress2,'P O','PO')
WHERE StreetAddress2 LIKE '%P O Box%'

UPDATE #AddAddress
SET StreetAddress2=StreetAddress3
	,StreetAddress3=NULL 
WHERE StreetAddress1=StreetAddress2

UPDATE #AddAddress
	SET StreetAddress1 = CONCAT(StreetAddress1,' ',StreetAddress2)
	,StreetAddress2 = StreetAddress3
	,StreetAddress3 = NULL
WHERE (StreetAddress2 LIKE 'APT%' OR StreetAddress2 LIKE 'UNIT%' OR StreetAddress2 LIKE 'BLDG%')
AND (StreetAddress1 NOT LIKE '% APT%' AND StreetAddress1 NOT LIKE '% UNIT%' AND StreetAddress1 NOT LIKE '% BLDG%')

UPDATE #AddAddress
SET StreetAddress1=REPLACE(StreetAddress1,'POBOX','PO BOX')
	,StreetAddress2=REPLACE(StreetAddress2,'POBOX','PO BOX')
WHERE StreetAddress1 LIKE '%POBOX%' OR StreetAddress2 LIKE '%POBOX%'

UPDATE #AddAddress
SET StreetAddress1=CONCAT(StreetAddress1,' ',REPLACE(StreetAddress2,' ',''))
	,StreetAddress2=NULL
WHERE StreetAddress2 LIKE '#%'

UPDATE #AddAddress
SET StreetAddress1=StreetAddress2
	,StreetAddress2=StreetAddress1
WHERE StreetAddress2 LIKE 'C/O%'

UPDATE #AddAddress
SET StreetAddress1=StreetAddress2
	,StreetAddress2=StreetAddress1
WHERE StreetAddress1 LIKE 'PO%'  
AND StreetAddress2 LIKE '[1-9]%'

--Naval Training Center - add address
UPDATE #AddAddress
	SET StreetAddress1 = '2601 PAUL JONES ST STE A'
	,StreetAddress2 = 'NAVAL TRAINING CENTER'
	,StreetAddress3 = NULL
	,City='GREAT LAKES'
	,Zip='60088'
	,Country='UNITED STATES'
WHERE StreetAddress1 IN ('NTC','NAVAL TRAINING CENTER', 'NTC GREAT LAKES') AND State='IL'

--Clean cases where Junior appears twice in the name
UPDATE #AddAddress
SET FullNameLegal=REPLACE(REPLACE(FullNameLegal,'JUNIOR',''),'  ',' ')
WHERE FullNameLegal LIKE '%Junior%JR' AND FullNameLegal NOT LIKE 'Junior%'

DROP TABLE IF EXISTS #LastCDWAddress
SELECT TOP 1 WITH TIES MVIPersonSID
	,VCL_ID
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,State
	,Zip
	,Country
INTO #LastCDWAddress
FROM #PastMailings
WHERE AddressSource='CDW'
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, VCL_ID ORDER BY InsertDate DESC)

DROP TABLE IF EXISTS #AddressUpdates_NCOA
SELECT TOP 1 WITH TIES *
INTO #AddressUpdates_NCOA 
FROM (
SELECT b.MVIPersonSID
	,a.VCL_ID
	,a.Letter
	,TRY_CAST(a.Letter_toPrinter_Date_Scheduled AS date) AS Letter_toPrinter_Date_Scheduled
	,a.[NCOA ADDRESS1]
	,a.[NCOA ADDRESS2]
	,a.[NCOA ADDRESS3]
	,a.[NCOA CITY]
	,a.[NCOA STATE]
	,[NCOA Zip]=LEFT(a.[NCOA ZIP +4],5)
FROM [CaringLetters].[VCL_NCOA_UpdateAddress] a WITH (NOLOCK)
INNER JOIN [CaringLetters].[VCL_Cohort] b WITH (NOLOCK)
	ON a.VCL_ID=b.VCL_ID
WHERE @RunType='VCL'
UNION ALL
SELECT a.MVIPersonSID
	,VCL_ID=NULL
	,a.LetterNumber
	,TRY_CAST(a.DataPullDate AS date) AS DataPullDate
	,a.UpdatedStreetAddress1
	,a.UpdatedStreetAddress2
	,UpdatedStreetAddress3=NULL
	,a.UpdatedCity
	,a.UpdatedState
	,Zip=LEFT(a.UpdatedZipCode,5)
FROM [CaringLetters].[HRF_NCOA_UpdateAddress] a WITH (NOLOCK)
WHERE @RunType='HRF'
) x
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, VCL_ID ORDER BY Letter DESC)

DROP TABLE IF EXISTS #LastCDWName
SELECT TOP 1 WITH TIES MVIPersonSID
	,VCL_ID
	,FullNameLegal
	,FullNamePreferred
	,FirstNamePreferred
INTO #LastCDWName
FROM #PastMailings
WHERE NameSource='CDW' 
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, VCL_ID ORDER BY InsertDate DESC)

DROP TABLE IF EXISTS #ChangesFromLastRun
SELECT a.MailingDate
	,a.MVIPersonSID
	,a.VCL_ID
	,a.PatientICN
	,a.LetterNumber
	,a.FirstNameLegal
	,a.FullNameLegal
	,a.FirstNamePreferred
	,a.FullNamePreferred
	,CASE WHEN a.FullNamePreferred IS NOT NULL THEN 1 ELSE 0 END AS PreferredName
	,a.LastName
	,CASE WHEN a.LetterNumber = 1 THEN NULL
		WHEN a.FullNameLegal <> c.FullNameLegal AND a.FullNamePreferred IS NULL THEN 1 ELSE 0 
		END AS LegalNameChange --Legal name change since last mailing
	,CASE WHEN a.FullNamePreferred IS NOT NULL AND 
			(a.FullNamePreferred <> c.FullNamePreferred OR a.FirstNamePreferred <> c.FirstNamePreferred
				OR ((a.FullNamePreferred IS NULL AND c.FullNamePreferred IS NOT NULL) OR (c.FullNamePreferred IS NULL AND a.FullNamePreferred IS NOT NULL))) THEN 1 
		ELSE 0 END AS PreferredNameChange --Preferred name change since last mailing
	,a.StreetAddress1
	,a.StreetAddress2
	,a.StreetAddress3
	,a.City
	,a.[State]
	,a.Zip
	,a.Country
	,a.PatientAddress
	,a.AddressChangeDateTime
	,CASE WHEN a.LetterNumber = 1 THEN NULL
		WHEN (a.StreetAddress1<>b.StreetAddress1 OR a.City<>b.City 
			OR a.[State]<>b.[State] OR a.Zip<>b.Zip) THEN 1 
		ELSE 0 END AS AddressChange --address has changed since last mailing
	,Address1Num = CASE WHEN a.StreetAddress1 LIKE '%[0-9]%' 
		THEN LEFT(SubString(a.StreetAddress1, PatIndex('%[0-9]%', a.StreetAddress1), 10), PatIndex('%[^0-9/]%', SubString(a.StreetAddress1, PatIndex('%[0-9/]%', a.StreetAddress1), 10) + 'X')-1)
		ELSE NULL END
	,Address2Num = CASE WHEN a.StreetAddress2 LIKE '%[0-9]%'  
		THEN LEFT(SubString(a.StreetAddress2, PatIndex('%[0-9]%', a.StreetAddress2), 10), PatIndex('%[^0-9/]%', SubString(a.StreetAddress2, PatIndex('%[0-9/]%', a.StreetAddress2), 10) + 'X')-1)
		ELSE NULL END
	,Address3Num = CASE WHEN a.StreetAddress3 LIKE '%[0-9]%'  
		THEN LEFT(SubString(a.StreetAddress3, PatIndex('%[0-9]%', a.StreetAddress3), 10), PatIndex('%[^0-9/]%', SubString(a.StreetAddress3, PatIndex('%[0-9/]%', a.StreetAddress3), 10) + 'X')-1)
		ELSE NULL END
	,CASE WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource IN ('Full SSN','Exact SSN') THEN 1 
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN Full Name Phone' AND a.FirstNameLegal = vm.FirstName AND a.LastName = vm.LastName AND (a.CellPhoneNumber = vm.CellPhoneNumber OR a.PhoneNumber = vm.PhoneNumber) THEN 1
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN Last Name Phone' AND a.LastName = vm.LastName AND (a.CellPhoneNumber = vm.CellPhoneNumber OR a.PhoneNumber = vm.PhoneNumber) THEN 1
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN Phone' AND (a.CellPhoneNumber = vm.CellPhoneNumber OR a.PhoneNumber = vm.PhoneNumber) THEN 1
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN Full Name' AND a.FirstNameLegal = vm.FirstName AND a.LastName = vm.LastName THEN 1
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN Last Name' AND a.LastName = vm.LastName THEN 1
		WHEN vm.MVIPersonSID IS NOT NULL AND a.ICNSource = 'Exact SSN First Name' AND a.FirstNameLegal = vm.FirstName THEN 1
		ELSE 0 END AS SSNDuplicate
	,CASE WHEN vm2.MVIPersonSID IS NOT NULL and a.ICNSource = 'Full Name Last 4' THEN 1 ELSE 0 END AS NameLast4Duplicate
INTO #ChangesFromLastRun
FROM #AddAddress a
LEFT JOIN #LastCDWAddress b --Most recent CDW address
	ON a.MVIPersonSID = b.MVIPersonSID AND (a.VCL_ID=b.VCL_ID OR @RunType='HRF')
LEFT JOIN #LastCDWName c --Most recent CDW name
	ON a.MVIPersonSID = c.MVIPersonSID AND (a.VCL_ID=c.VCL_ID OR @RunType='HRF')
LEFT JOIN [Common].[MasterPatient] vm WITH (NOLOCK) --Check for duplicate matches on full SSN
	ON vm.PatientSSN = a.PatientSSN AND vm.MVIPersonSID <> a.MVIPersonSID AND vm.DateOfDeath_Combined IS NULL
LEFT JOIN [Common].[MasterPatient] vm2 WITH (NOLOCK) --Check for duplicate matches on full SSN
	ON vm2.FirstName = a.FirstNameLegal AND vm2.LastName = a.LastName AND vm2.LastFour = a.LastFour AND vm2.MVIPersonSID <> a.MVIPersonSID AND vm2.DateOfDeath_Combined IS NULL
	

--Only flag as duplicate if record was not flagged in a previous week.  Duplicate record flagging is only for VCL Caring Letters
UPDATE #ChangesFromLastRun
SET SSNDuplicate=0
	,NameLast4Duplicate=0
FROM #ChangesFromLastRun a
INNER JOIN [CaringLetters].[VCL_Mailings] b WITH (NOLOCK) ON a.VCL_ID=b.VCL_ID AND a.MVIPersonSID=b.MVIPersonSID
WHERE b.ReviewRecordReason LIKE '%Duplicate%'
AND (a.SSNDuplicate=1 OR a.NameLast4Duplicate=1)
AND @RunType='VCL'



--If the CDW address has not changed since the last CDW address was pulled, then use the updated address from NCOA or the previous address (whether CDW, writeback). Otherwise use updated CDW address.
DROP TABLE IF EXISTS #AddWritebackChanges
SELECT DISTINCT a.MailingDate
	,a.MVIPersonSID
	,a.PatientICN
	,a.VCL_ID
	,a.LetterNumber
	,CASE WHEN a.LegalNameChange = 0 AND b.MVIPersonSID IS NOT NULL THEN b.FirstNameLegal ELSE dflt.propercase(a.FirstNameLegal) END AS FirstNameLegal
	,UPPER(CASE WHEN a.LegalNameChange = 0 AND b.MVIPersonSID IS NOT NULL THEN b.FullNameLegal ELSE a.FullNameLegal END) AS FullNameLegal
	,CASE WHEN a.PreferredNameChange = 0 AND b.MVIPersonSID IS NOT NULL THEN b.FirstNamePreferred ELSE dflt.propercase(a.FirstNamePreferred) END AS FirstNamePreferred
	,UPPER(CASE WHEN a.PreferredNameChange = 0 AND b.MVIPersonSID IS NOT NULL THEN b.FullNamePreferred ELSE a.FullNamePreferred END) AS FullNamePreferred
	,CASE WHEN a.PreferredNameChange = 0 THEN ISNULL(b.PreferredName,a.PreferredName) 
		ELSE ISNULL(a.PreferredName,0) END AS PreferredName
	,CASE WHEN a.LegalNameChange = 1 OR a.PreferredNameChange = 1 THEN 1 ELSE 0 END AS NameChange
	,CASE WHEN a.LegalNameChange = 0 AND a.PreferredName=0 THEN ISNULL(b.NameSource,'CDW') 
		WHEN a.PreferredNameChange=0 AND a.PreferredName=1 THEN ISNULL(b.NameSource,'CDW') 
		ELSE 'CDW' END AS NameSource
	,CASE WHEN a.LegalNameChange=1 OR a.PreferredNameChange=1 OR a.AddressChange=1 OR a.SSNDuplicate=1 OR a.NameLast4Duplicate=1 THEN 1 ELSE 0 END AS ReviewRecordFlag
	,CONCAT(	(CASE WHEN a.SSNDuplicate=1 THEN 'DuplicateSSN' ELSE '' END)
				,(CASE WHEN a.NameLast4Duplicate=1 THEN 'DuplicateName4' ELSE '' END)
				,(CASE WHEN a.LegalNameChange=1 OR a.PreferredNameChange=1 THEN 'NameChange' ELSE '' END)
				,(CASE WHEN a.AddressChange=1 THEN 'AddressChange' ELSE '' END)
				,(CASE WHEN a.FullNameLegal LIKE '%JUNIOR%' OR a.FullNamePreferred LIKE '%JUNIOR%' 
					OR a.PreferredName LIKE CONCAT('%',a.LastName,'%')
					OR a.FirstNameLegal IS NULL OR a.FullNameLegal NOT LIKE '% %'
					OR LEN(a.FirstNameLegal)<3 OR LEN(a.FirstNamePreferred)<3
					THEN 'NameFlag' ELSE '' END) 
				,(CASE WHEN a.City IS NULL OR a.State IS NULL OR a.Zip IS NULL 
					OR a.StreetAddress1 LIKE '%c/o%' OR a.StreetAddress2 LIKE '%c/o%' OR a.StreetAddress3 LIKE '%c/o%'
					OR a.StreetAddress1 LIKE 'Un%' OR a.StreetAddress2 LIKE 'Un%' OR a.StreetAddress3 LIKE 'Un%'
					OR a.StreetAddress1 LIKE '%Homeless%' OR a.StreetAddress2 LIKE '%Homeless%' OR a.StreetAddress3 LIKE '%Homeless%'
					OR a.StreetAddress1 LIKE '%None%' OR a.StreetAddress2 LIKE '%None%' OR a.StreetAddress3 LIKE '%None%'
					OR a.StreetAddress1 LIKE '%Bad%' OR a.StreetAddress2 LIKE '%Bad%' OR a.StreetAddress3 LIKE '%Bad%'
					OR a.Address1Num=a.Address2Num OR a.Address1Num=Address3Num OR a.Address2Num=Address3Num
					OR a.Country<>'United States' 
					THEN 'AddressFlag' ELSE '' END)) AS ReviewRecordReason
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL THEN u.[NCOA ADDRESS1]
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL  THEN b.StreetAddress1 
		ELSE a.StreetAddress1 END) AS StreetAddress1
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL THEN CASE WHEN u.[NCOA ADDRESS2] = '' THEN NULL ELSE u.[NCOA ADDRESS2] END
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN b.StreetAddress2 
		ELSE a.StreetAddress2 END) AS StreetAddress2
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL THEN CASE WHEN u.[NCOA ADDRESS3] = '' THEN NULL ELSE u.[NCOA ADDRESS3] END
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN b.StreetAddress3 
		ELSE a.StreetAddress3 END) AS StreetAddress3
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL THEN u.[NCOA CITY] 
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN b.City 
		ELSE a.City END) AS City
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL THEN u.[NCOA STATE]
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN b.[State]
		ELSE a.[State] END) AS [State]
	,CASE WHEN u.MVIPersonSID IS NOT NULL THEN LEFT(u.[NCOA Zip],5)
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN LEFT(b.Zip ,5)
		ELSE LEFT(a.Zip,5) END AS Zip
	,UPPER(CASE WHEN u.MVIPersonSID IS NOT NULL AND a.AddressChangeDateTime<u.Letter_toPrinter_Date_Scheduled THEN NULL
		WHEN a.AddressChange = 0 AND b.VCL_ID IS NOT NULL THEN b.Country 
		ELSE a.Country END) AS Country
	,a.PatientAddress
	,a.AddressChange
	,CASE WHEN u.MVIPersonSID IS NOT NULL THEN 'NCOA'
		WHEN a.AddressChange = 0 THEN ISNULL(b.AddressSource,'CDW') ELSE 'CDW' END AS AddressSource
INTO #AddWritebackChanges
FROM #ChangesFromLastRun a
LEFT JOIN (SELECT TOP 1 WITH TIES * FROM #PastMailings WITH (NOLOCK) WHERE StreetAddress1 IS NOT NULL AND StreetAddress1<>''
			ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, VCL_ID ORDER BY LetterNumber DESC, InsertDate DESC)) b 
	ON (a.VCL_ID=b.VCL_ID OR @RunType='HRF') AND a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN #AddressUpdates_NCOA u
	ON a.MVIPersonSID = u.MVIPersonSID AND (a.VCL_ID=u.VCL_ID OR @RunType='HRF') AND a.AddressChangeDateTime<u.Letter_toPrinter_Date_Scheduled

UPDATE #AddWritebackChanges
SET ReviewRecordFlag=1
WHERE ReviewRecordReason<>''

--Put full name in first name field if there is no first name
UPDATE #AddWritebackChanges
SET FirstNameLegal=FullNameLegal 
WHERE FirstNameLegal IS NULL

--Update records where city is entered in street address fields
UPDATE #AddWritebackChanges
SET StreetAddress3=NULL
WHERE StreetAddress3=City

UPDATE #AddWritebackChanges
SET StreetAddress2=StreetAddress3
WHERE StreetAddress2=City

--Update records where unit information is repeated in multiple address fields
UPDATE #AddWritebackChanges
SET StreetAddress3=NULL
WHERE StreetAddress1 LIKE CONCAT('%',StreetAddress3) 
AND StreetAddress3 <>''

UPDATE #AddWritebackChanges
SET StreetAddress2=StreetAddress3
WHERE StreetAddress1 LIKE CONCAT('%',StreetAddress2) 
AND StreetAddress2 <>''

--Remove email addresses
UPDATE #AddWritebackChanges
SET StreetAddress3=NULL
WHERE StreetAddress3 LIKE '%@%.com' OR StreetAddress2 LIKE '%@%.gov'

UPDATE #AddWritebackChanges
SET StreetAddress2=StreetAddress3
WHERE StreetAddress2 LIKE '%@%.com' OR StreetAddress2 LIKE '%@%.gov'


--Replace commas and periods with double spaces
UPDATE #AddWritebackChanges
	  SET StreetAddress1 = REPLACE(REPLACE(StreetAddress1,',',' '),'.',' ')
	 ,StreetAddress2 = REPLACE(REPLACE(StreetAddress2,',',' '),'.',' ')
	 ,StreetAddress3 = REPLACE(REPLACE(StreetAddress3,',',' '),'.',' ')
	 ,City = REPLACE(REPLACE(City,',',' '),'.',' ')

--Replace multiple spaces with single spaces
UPDATE #AddWritebackChanges
SET FullNameLegal	=  REPLACE(REPLACE(REPLACE(FullNameLegal,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,FullNamePreferred	=  REPLACE(REPLACE(REPLACE(FullNamePreferred,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,FirstNameLegal 	=  REPLACE(REPLACE(REPLACE(FirstNameLegal,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,FirstNamePreferred	=  REPLACE(REPLACE(REPLACE(FirstNamePreferred,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,StreetAddress1 =  REPLACE(REPLACE(REPLACE(StreetAddress1,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,StreetAddress2 = REPLACE(REPLACE(REPLACE(StreetAddress2,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,StreetAddress3 = REPLACE(REPLACE(REPLACE(StreetAddress3,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')
	,City =			  REPLACE(REPLACE(REPLACE(City,' ','CHAR(17)CHAR(18)'),'CHAR(18)CHAR(17)',''),'CHAR(17)CHAR(18)',' ')

--If legal name exactly matches preferred name then remove preferred name and use legal name
UPDATE #AddWritebackChanges
SET FullNamePreferred = ''
	,FirstNamePreferred=''
	,PreferredName=0
WHERE TRIM(FullNameLegal)=TRIM(FullNamePreferred) AND TRIM(FirstNameLegal COLLATE SQL_Latin1_General_CP1_CS_AS)=TRIM(FirstNamePreferred COLLATE SQL_Latin1_General_CP1_CS_AS)

--If preferred first name exists and preferred full name is missing, use full legal name
UPDATE #AddWritebackChanges
SET FullNamePreferred=FullNameLegal
	,PreferredName=1
WHERE FullNamePreferred='' AND FirstNamePreferred<>''

--Final formatting on address fields before inserting
UPDATE #AddWritebackChanges
SET StreetAddress1=' '
WHERE StreetAddress1 IS NULL

UPDATE #AddWritebackChanges
SET City=' '
WHERE City IS NULL

UPDATE #AddWritebackChanges
SET State=' '
WHERE State IS NULL

UPDATE #AddWritebackChanges
SET Zip=' '
WHERE Zip IS NULL

UPDATE #AddWritebackChanges
SET Country='UNITED STATES'
WHERE State IN (SELECT * FROM #States)
AND (Country IS NULL OR TRIM(Country)='' OR Country LIKE '%Unknown%')

UPDATE #AddWritebackChanges
SET Country='PHILIPPINES'
WHERE State IN (SELECT * FROM #Philippines)
AND (Country IS NULL OR TRIM(Country)='' OR Country LIKE '%Unknown%')

UPDATE #AddWritebackChanges
SET Country=' '
WHERE Country IS NULL


IF (SELECT COUNT(DISTINCT MVIPersonSID) FROM #AddWritebackChanges) <> (SELECT COUNT(*) FROM #AddWritebackChanges)
BEGIN

	DECLARE @msg2 varchar(250) = 'Mailing List not published due to duplicate mailing record.'
	PRINT @msg2
	
	EXEC [Log].[Message] 'Error','Row Counts',@msg2
		,@msg2

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END


IF @RunType='VCL'
BEGIN
----Remove cases where the last mailing was returned and securely destroyed, and the patient has not had a change of address in the meantime
UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = (SELECT * FROM #Today)
	,DoNotSendReason = 'Bad Address'
FROM [CaringLetters].[VCL_Cohort] AS c WITH (NOLOCK)
INNER JOIN [CaringLetters].[VCL_NCOA_BadAddress] AS ad WITH (NOLOCK) 
	ON ad.VCL_ID = c.VCL_ID 
INNER JOIN #AddWritebackChanges AS w
	ON c.MVIPersonSID = w.MVIPersonSID AND w.VCL_ID = c.VCL_ID
LEFT JOIN (SELECT * FROM [CaringLetters].[VCL_Mailings] WITH (NOLOCK) WHERE AddressChange=1) AS m
	ON c.MVIPersonSID = m.MVIPersonSID
	AND m.LetterNumber > ad.Letter
WHERE c.DoNotSend = 0 --not previously identified as DoNotSend
	AND w.AddressChange = 0 -- address is not being updated in this current run of data
	AND m.AddressChange IS NULL --address has not been updated in a previous run since the letter that was returned and securely destroyed

DELETE FROM #AddWritebackChanges
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM [CaringLetters].[VCL_Cohort] WITH (NOLOCK) WHERE DoNotSend=1)


UPDATE [CaringLetters].[VCL_Mailings]
SET ActiveRecord = 0
FROM #AddWritebackChanges a
INNER JOIN [CaringLetters].[VCL_Mailings] b
	ON a.MVIPersonSID = b.MVIPersonSID AND a.VCL_ID=b.VCL_ID

INSERT INTO [CaringLetters].[VCL_Mailings] (
	MailingDate
	,LetterNumber
	,MVIPersonSID
	,PatientICN
	,VCL_ID
	,FirstNameLegal
	,FullNameLegal
	,FirstNamePreferred
	,FullNamePreferred
	,PreferredName
	,NameChange
	,NameSource
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,[State]
	,Zip
	,Country
	,PatientAddress
	,AddressChange
	,AddressSource
	,ReviewRecordFlag
	,ReviewRecordReason
	,DoNotSend
	,ActiveMailingRecord
	,ActiveRecord
	,InsertDate
	)
SELECT DISTINCT
	MailingDate
	,LetterNumber
	,MVIPersonSID
	,PatientICN
	,VCL_ID
	,TRIM(FirstNameLegal) AS FirstNameLegal
	,TRIM(FullNameLegal) AS FullNameLegal
	,TRIM(FirstNamePreferred) AS FirstNamePreferred
	 --if preferred name is just last name, use legal name for mailing and preferred name as first name for salutation
	,CASE WHEN TRIM(FullNamePreferred) = TRIM(FirstNamePreferred) AND FullNamePreferred IS NOT NULL AND FullNamePreferred <> ''
		THEN TRIM(FullNameLegal) ELSE TRIM(FullNamePreferred) END AS FullNamePreferred
	,PreferredName
	,NameChange
	,NameSource
	,TRIM(StreetAddress1) AS StreetAddress1
	,TRIM(StreetAddress2) AS StreetAddress2
	,TRIM(StreetAddress3) AS StreetAddress3
	,TRIM(City) AS City
	,TRIM(CASE WHEN [State] in ('*','*Missing*') OR [State] IS NULL THEN ' ' ELSE [State] END) AS [State]
	,TRIM(CASE WHEN Zip IS NULL THEN ' ' ELSE Zip END) AS Zip
	,TRIM(CASE WHEN Country IS NULL OR Country LIKE '*%' THEN ' ' ELSE Country END) AS Country
	,PatientAddress
	,AddressChange
	,AddressSource
	,ReviewRecordFlag
	,CASE WHEN ReviewRecordFlag = 1 THEN ReviewRecordReason ELSE 'N/A' END AS ReviewRecordReason
	,DoNotSend=0
	,ActiveMailingRecord=1
	,ActiveRecord=1
	,InsertDate = (SELECT * FROM #Today)
FROM #AddWritebackChanges

UPDATE [CaringLetters].[VCL_Mailings]
SET DoNotSend=1
	,DoNotSendReason = 'Bad Address'
	,ReviewRecordFlag=0
	,ReviewRecordReason='N/A'
WHERE ((StreetAddress1 IS NULL OR City IS NULL)
OR (Country NOT IN ('AMERICAN SAMOA','GUAM','NORTHERN MARIANA ISLANDS','PHILIPPINES','PUERTO RICO','UNITED STATES','VIRGIN ISLANDS')
	AND Country NOT LIKE 'ARMED FORCES%'
	AND Country IS NOT NULL
	AND TRIM(Country) <>''))
AND ActiveRecord=1 AND InsertDate=(SELECT * FROM #Today)

UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend=1
	,DoNotSendReason = 'Bad Address'
	,DoNotSendDate=(SELECT * FROM #Today)
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM [CaringLetters].[VCL_Mailings]
	WHERE ((StreetAddress1 IS NULL OR City IS NULL) 
		OR (Country NOT IN ('AMERICAN SAMOA','GUAM','NORTHERN MARIANA ISLANDS','PHILIPPINES','PUERTO RICO','UNITED STATES','VIRGIN ISLANDS')
		AND Country NOT LIKE 'ARMED FORCES%'
		AND Country IS NOT NULL
		AND TRIM(Country) <>''))
	AND ActiveRecord=1 AND InsertDate=(SELECT * FROM #Today))



END
ELSE


IF @RunType='HRF'

BEGIN

--Remove cases where the last mailing was returned and securely destroyed, and the patient has not had a change of address in the meantime
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = (SELECT Today FROM #Today)
	,DoNotSendReason = 'Bad Address'
FROM [CaringLetters].[HRF_Cohort] AS c 
INNER JOIN [CaringLetters].[HRF_NCOA_BadAddress_SecureDestroy] AS ad WITH (NOLOCK) 
	ON ad.MVIPersonSID = c.MVIPersonSID 
INNER JOIN #AddWritebackChanges AS w
	ON c.MVIPersonSID = w.MVIPersonSID
LEFT JOIN (SELECT * FROM [CaringLetters].[HRF_Mailings] WITH (NOLOCK) WHERE AddressChange=1) AS m
	ON c.MVIPersonSID = m.MVIPersonSID
	AND m.LetterNumber > ad.LetterNumber
WHERE c.DoNotSend = 0 --not previously identified as DoNotSend
	AND w.AddressChange = 0 -- address is not being updated in this current run of data
	AND m.AddressChange IS NULL --address has not been updated in a previous run since the letter that was returned and securely destroyed

DELETE FROM #AddWritebackChanges
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM [CaringLetters].[HRF_Cohort] WITH (NOLOCK) WHERE DoNotSend=1)


UPDATE [CaringLetters].[HRF_Mailings]
SET ActiveRecord = 0
FROM #AddWritebackChanges a
INNER JOIN [CaringLetters].[HRF_Mailings] b
	ON a.MVIPersonSID = b.MVIPersonSID

INSERT INTO [CaringLetters].[HRF_Mailings] (
	MailingDate
	,LetterNumber
	,MVIPersonSID
	,PatientICN
	,FirstNameLegal
	,FullNameLegal
	,FirstNamePreferred
	,FullNamePreferred
	,PreferredName
	,NameChange
	,NameSource
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,[State]
	,Zip
	,Country
	,AddressChange
	,AddressSource
	,ReviewRecordFlag
	,ReviewRecordReason
	,DoNotSend
	,ActiveMailingRecord
	,ActiveRecord
	,InsertDate
	)
SELECT DISTINCT
	MailingDate
	,LetterNumber
	,MVIPersonSID
	,PatientICN
	,TRIM(FirstNameLegal) AS FirstNameLegal
	,TRIM(FullNameLegal) AS FullNameLegal
	,TRIM(FirstNamePreferred) AS FirstNamePreferred
	 --if preferred name is just first name, use legal name for mailing and preferred name as first name for salutation
	,CASE WHEN TRIM(FullNamePreferred) = TRIM(FirstNamePreferred) AND FullNamePreferred IS NOT NULL AND FullNamePreferred <> ''
		THEN TRIM(FullNameLegal) ELSE TRIM(FullNamePreferred) END AS FullNamePreferred
	,PreferredName
	,NameChange
	,NameSource
	,StreetAddress1
	,StreetAddress2
	,StreetAddress3
	,City
	,CASE WHEN [State] in ('*','*Missing*') OR [State] IS NULL THEN ' ' ELSE [State] END AS [State]
	,CASE WHEN Zip IS NULL THEN ' ' ELSE Zip END AS Zip
	,CASE WHEN Country IS NULL OR Country LIKE '*%' THEN ' ' ELSE Country END AS Country
	,AddressChange
	,AddressSource
	,ReviewRecordFlag
	,CASE WHEN ReviewRecordFlag = 1 THEN ReviewRecordReason ELSE 'N/A' END AS ReviewRecordReason
	,DoNotSend=0
	,ActiveMailingRecord=1
	,ActiveRecord=1
	,InsertDate = (SELECT Today FROM #Today)
FROM #AddWritebackChanges


UPDATE [CaringLetters].[HRF_Mailings]
SET DoNotSend=1
	,DoNotSendReason = 'Bad Address'
	,ReviewRecordFlag=0
	,ReviewRecordReason='N/A'
WHERE (StreetAddress1 IS NULL OR City IS NULL)
AND ActiveRecord=1 AND InsertDate=(SELECT Today FROM #Today)

UPDATE [CaringLetters].[HRF_Cohort] 
SET DoNotSend=1
	,DoNotSendReason = 'Bad Address'
	,DoNotSendDate=(SELECT Today FROM #Today)
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM  [CaringLetters].[HRF_Mailings] WHERE (StreetAddress1 IS NULL OR City IS NULL) 
	AND ActiveRecord=1 AND InsertDate=(SELECT Today FROM #Today))


	END
	END