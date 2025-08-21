


/*=============================================
-- Author:		Liam Mina
-- Create date: 3/7/2024
-- Description:	Mapping SSNs from VCL to MVIPersonSID for calls in the past 30 days.  Used in VCL Caring Letters and VCL LMS mailings
-- Updates:
--	2025-07-11	LM	Moved from Code.CaringLetters_VCL

=========================================================================================================================================*/
CREATE PROCEDURE [Code].[CaringLetters_VCL_PatientMapping]


AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.CaringLetters_VCL_PatientMapping', @Description = 'Execution of Code.CaringLetters_VCL_PatientMapping SP'


--Get VCL Hotline Calls for timeframe of interest
DROP TABLE IF EXISTS #Identifiers
SELECT Id=TRY_CAST(REPLACE(i.Name,'Call-','') AS int)
	,i.Name
	,TRIM(i.Veteran_Name__c) AS VeteranName
	,TRIM(i.Caller_Name__c) AS CallerName
	,TRIM(CASE WHEN i.Veteran_Name__c LIKE '%,%' THEN LEFT(i.Veteran_Name__c,charindex(',',i.Veteran_Name__c)-1)
		WHEN charindex(' ',i.Veteran_Name__c)>0 THEN STUFF(i.Veteran_Name__c,1,CHARINDEX(' ',i.Veteran_Name__c),'')
		ELSE i.Veteran_Name__c
		END) AS LastName
	,TRIM(CASE WHEN i.Veteran_Name__c LIKE '%,%' THEN STUFF(i.Veteran_Name__c,1,CHARINDEX(',',i.Veteran_Name__c),'')
		WHEN charindex(' ',i.Veteran_Name__c)>0 THEN  LEFT(i.Veteran_Name__c,charindex(' ',i.Veteran_Name__c)-1)
		ELSE i.Veteran_Name__c
		END) AS FirstName
	,CASE WHEN LEN(i.SSN__c)=9 THEN TRY_CAST(i.SSN__c AS bigint) ELSE NULL END  AS PatientSSN
	,CASE WHEN LEN(i.SSN__c)>=4 THEN TRY_CAST(RIGHT(i.SSN__c,4) AS int)END AS Last4
	,TRY_CAST(RIGHT(i.Caller_Phone__c,10) AS bigint) AS CallerPhoneNumber
	,f.Site_Id__c AS NearestFacilitySiteCode
	,i.Call_Start__c AS CallStart
    ,CASE WHEN i.Is_Veteran__c LIKE 'Refuse%' THEN 'Ref' ELSE i.Is_Veteran__c END AS VCL_IsVet
    ,CASE WHEN i.Active_Duty__c LIKE 'Refuse%' THEN 'Ref' ELSE i.Active_Duty__c END AS VCL_IsActiveDuty
	,CASE WHEN i.Veteran_Status__c='Unknown' THEN 1
		WHEN i.Veteran_Status__c='Not Registered' THEN 2
		WHEN i.Veteran_Status__c='Registered, not enrolled' THEN 3
		WHEN i.Veteran_Status__c='Enrolled, no service received from VA' THEN 4
		WHEN i.Veteran_Status__c='Enrolled, receives services' THEN 5
		WHEN i.Veteran_Status__c='Caller would not say' THEN 6
		END AS VCL_VeteranStatus
    ,CASE WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Air Force' THEN 1
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Army' THEN 2
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Coast Guard' THEN 3
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Marines' THEN 4
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'National Guard' THEN 5
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Navy' THEN 6
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'Reserves' THEN 7
		WHEN i.In_which_branch_did_the_Veteran_serve__c = 'None' THEN 8
		ELSE 0 END AS VCL_MilitaryBranch
	,i.Legacy_Call_ID__c
	,CASE WHEN i.Relationship_to_Veteran__c LIKE 'Vet%' OR i.Relationship_to_Veteran__c LIKE '%Self%' THEN 1 ELSE 0 END AS CaringLetterEligible
INTO #Identifiers
FROM PDW.VCL_Medoraforce_PERC_VCL_Call__c i WITH (NOLOCK) 
LEFT JOIN PDW.VCL_Medoraforce_PERC_VCL_Site__c f WITH (NOLOCK)
	ON i.Nearest_Facility_to_Veteran__c = f.Id
WHERE CAST(i.Call_Start__c AS date) BETWEEN Dateadd(day, -30, getdate()) AND getdate() --calls in 30 days prior
AND (i.What_was_the_outcome_of_the_call__c NOT IN ('Responder attempted to contact Veteran and left message','Responder attempted to contact Veteran and was unsuccessful') 
	OR i.What_was_the_outcome_of_the_call__c IS NULL) --Exclude calls where Responder attempted to contact Veteran and left a message or was unsuccessful
AND (i.Veteran_Name__c NOT IN ('Anonymous','Unknown') OR i.Caller_Name__c NOT IN ('Anonymous','Unknown') OR i.SSN__c IS NOT NULL)

--Pull and transform relevant fields from CDW data. This is faster than joining directly to the CDW tables later in the code
DROP TABLE IF EXISTS #SVeteran
SELECT MVIPersonSID
	,MVIPersonICN
	,TRY_CAST(PersonSSN AS bigint) AS PersonSSN
	,SSNVerificationStatus
	,FirstName
	,LastName
	,TRY_CAST(RIGHT(PersonSSN,4) AS int) AS LastFour
	,TRY_CAST(REPLACE(REPLACE(REPLACE(PhoneNumber,'(','' ),')',''),'-','') AS bigint) AS PhoneNumber
	,TRY_CAST(REPLACE(REPLACE(REPLACE(CellularPhoneNumber,'(','' ),')',''),'-','') AS bigint) AS CellularPhoneNumber
	,TRY_CAST(AssuranceLevelStatusCode as int) AS AssuranceLevelStatusCode --4 is highly confident, 3 is very confident, 2 is confident, 1 is not confident
	,CASE WHEN SSNVerificationStatus='VERIFIED' THEN 1
		WHEN SSNVerificationStatus='IN-PROCESS' THEN 2
		WHEN SSNVerificationStatus='NEW RECORD' THEN 3
		WHEN SSNVerificationStatus IN ('*Missing*','*Unknown at this time*') THEN 4
		WHEN SSNVerificationStatus IS NULL THEN 5
		WHEN SSNVerificationStatus='RESEND TO SSA' THEN 6
		WHEN SSNVerificationStatus='INVALID PER SSA' THEN 7
		ELSE 8
		END AS SSNVerificationPriority --when multiple matches exist, code will use SSN verification priority to try to get the best match
	,CASE WHEN InteroperabilityPersonType = 'VETERAN (per VA)' THEN 0 ELSE 1 END AS Veteran
	,CASE WHEN StreetAddress1 IS NOT NULL THEN 0 ELSE 1 END AS AddressPopulated
	,PersonModifiedDateTime
INTO #SVeteran 
FROM [SVeteran].[SMVIPerson] WITH (NOLOCK)
WHERE (DeathDateTime IS NULL OR DeathDateTime > DateAdd(month,-6,getdate()))
AND ICNStatusCode<>'D'
AND (TestRecordIndicatorCode NOT IN ('A','T','U') OR TestRecordIndicatorCode IS NULL)
AND PersonSSN<>'000000000'

DROP TABLE IF EXISTS #SPatient
SELECT DISTINCT sp.PatientICN
	,sp.Sta3n
	,TRY_CAST(sp.PatientSSN AS bigint) AS PatientSSN
	,sp.PatientFirstName
	,sp.PatientLastName
	,TRY_CAST(RIGHT(PatientSSN,4) AS int) AS LastFour
	,TRY_CAST(REPLACE(REPLACE(REPLACE(p.PhoneNumber,'(','' ),')',''),'-','') AS bigint) AS PhoneNumber
INTO #SPatient
FROM [SPatient].[SPatient] sp WITH (NOLOCK)
LEFT JOIN [SPatient].[SPatientPhone] p WITH (NOLOCK)
	ON sp.PatientSID = p.PatientSID AND p.OrdinalNumber IN (13,14) --Patient Residence, Patient Cell Phone
WHERE (DeathDateTime IS NULL OR DeathDateTime > DateAdd(month,-6,getdate()))
AND (sp.TestPatientFlag IS NULL OR sp.TestPatientFlag <>'Y')
AND PatientSSN<>'000000000'

--Matches on full SSN
DROP TABLE IF EXISTS #ICNMatch_SSN
SELECT TOP 1 WITH TIES 
	i.ID
	,CASE WHEN b.SSNVerificationStatus IN ('NEW RECORD','VERIFIED','IN-PROCESS') THEN b.MVIPersonICN --exact match on SSN
		ELSE COALESCE(p.PatientICN,b.MVIPersonICN)
		END AS PatientICN
	,CASE WHEN b.SSNVerificationStatus IN ('NEW RECORD','VERIFIED','IN-PROCESS') THEN 'Exact SSN - SVeteran'
		WHEN p.PatientICN IS NOT NULL THEN 'Exact SSN - SPatient'
		WHEN b.MVIPersonICN IS NOT NULL THEN 'Exact SSN - SVeteran'
		END AS ICNSource
	,b.SSNVerificationStatus
	,CASE WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName AND i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN ' FullName Phone'
			WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName AND i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN ' FullName Phone'
			WHEN p.PatientLastName=i.LastName AND p.PatientFirstName = i.FirstName AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN ' FullName Phone'
			WHEN b.LastName = i.LastName AND i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN ' LastName Phone'
			WHEN b.LastName = i.LastName AND i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN ' LastName Phone'
			WHEN p.PatientLastName=i.LastName AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN ' LastName Phone'
			WHEN i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN ' Phone'
			WHEN i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN ' Phone'
			WHEN i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN ' Phone'
			WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName 
				THEN ' FullName'
			WHEN p.PatientLastName=i.LastName AND p.PatientFirstName = i.FirstName
				THEN ' FullName'
			WHEN b.LastName = i.LastName 
				THEN ' LastName'
			WHEN p.PatientLastName=i.LastName 
				THEN ' LastName'
			WHEN b.FirstName = i.FirstName 
				THEN ' FirstName'
			WHEN p.PatientFirstName=i.FirstName 
				THEN ' FirstName'
			END AS PatientIDMatch --prioritize based on matches to patient name and phone number
INTO #ICNMatch_SSN
FROM  #Identifiers i 
LEFT JOIN #SVeteran b
	ON i.PatientSSN = b.PersonSSN
LEFT JOIN #SPatient p
	ON i.PatientSSN = p.PatientSSN 
ORDER BY ROW_NUMBER() OVER (PARTITION BY i.ID ORDER BY 
		CASE WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName AND i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN 1
			WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName AND i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN 2
			WHEN p.PatientLastName=i.LastName AND p.PatientFirstName = i.FirstName AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN 3
			WHEN b.LastName = i.LastName AND i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN 4
			WHEN b.LastName = i.LastName AND i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN 5
			WHEN p.PatientLastName=i.LastName AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN 6
			WHEN i.CallerPhoneNumber = b.PhoneNumber AND b.PhoneNumber<>9999999999 AND b.PhoneNumber>0 AND b.PhoneNumber IS NOT NULL 
				THEN 7
			WHEN i.CallerPhoneNumber = b.CellularPhoneNumber AND b.CellularPhoneNumber<>9999999999 AND b.CellularPhoneNumber>0 AND b.CellularPhoneNumber IS NOT NULL 
				THEN 8
			WHEN i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
				THEN 9
			WHEN b.LastName = i.LastName AND b.FirstName = i.FirstName 
				THEN 10
			WHEN p.PatientLastName=i.LastName AND p.PatientFirstName = i.FirstName
				THEN 11
			WHEN b.LastName = i.LastName 
				THEN 12
			WHEN p.PatientLastName=i.LastName 
				THEN 13
			WHEN b.FirstName = i.FirstName 
				THEN 14
			WHEN p.PatientFirstName=i.FirstName 
				THEN 15
			ELSE 16 END
	,b.AssuranceLevelStatusCode DESC, b.SSNVerificationPriority, b.Veteran, b.AddressPopulated, b.PersonModifiedDateTime DESC, CASE WHEN p.Sta3n=i.NearestFacilitySiteCode THEN 0 ELSE 1 END)

--Matches on Full name + Last 4, or last name + last 4 + phone.  Joining on Last Name + Last 4 without first name or phone produces unreliable matches
DROP TABLE IF EXISTS #ICNMatch_SSN_Last4
SELECT TOP 1 WITH TIES * INTO #ICNMatch_SSN_Last4 FROM (
	SELECT i.ID
		,CASE WHEN s.PatientICN IS NOT NULL THEN s.PatientICN
		WHEN (m.FirstName = i.FirstName OR m.FirstName LIKE CONCAT(i.FirstName,' %')) AND i.CallerPhoneNumber = m.CellularPhoneNumber AND m.CellularPhoneNumber<>9999999999 AND m.CellularPhoneNumber>0 AND m.CellularPhoneNumber IS NOT NULL
			THEN m.MVIPersonICN
		WHEN (m.FirstName = i.FirstName OR m.FirstName LIKE CONCAT(i.FirstName,' %')) AND i.CallerPhoneNumber = m.PhoneNumber AND m.PhoneNumber<>9999999999 AND m.PhoneNumber>0 AND m.PhoneNumber IS NOT NULL 
			THEN m.MVIPersonICN	
		WHEN (p.PatientFirstName = i.FirstName OR p.PatientFirstName LIKE CONCAT(i.FirstName,' %')) AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
			THEN p.PatientICN
		WHEN i.CallerPhoneNumber = m.CellularPhoneNumber AND m.CellularPhoneNumber<>9999999999 AND m.CellularPhoneNumber>0 AND m.CellularPhoneNumber IS NOT NULL
			THEN m.MVIPersonICN
		WHEN i.CallerPhoneNumber = m.PhoneNumber AND m.PhoneNumber<>9999999999 AND m.PhoneNumber>0 AND m.PhoneNumber IS NOT NULL 
			THEN m.MVIPersonICN
		WHEN i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
			THEN p.PatientICN
		WHEN m.FirstName = i.FirstName THEN m.MVIPersonICN
		WHEN p.PatientFirstName = i.FirstName THEN p.PatientICN
		WHEN p.PatientFirstName LIKE CONCAT(i.FirstName,' %') THEN p.PatientICN
		END AS PatientICN
	,CASE WHEN s.ICNSource IS NOT NULL THEN CONCAT(s.ICNSource,s.PatientIDMatch)
		WHEN m.FirstName = i.FirstName AND i.CallerPhoneNumber = m.PhoneNumber AND m.PhoneNumber<>9999999999 AND m.PhoneNumber>0 AND m.PhoneNumber IS NOT NULL 
			THEN 'FNameLast4 Phone - SVeteran'
		WHEN m.FirstName = i.FirstName AND i.CallerPhoneNumber = m.CellularPhoneNumber AND m.CellularPhoneNumber<>9999999999 AND m.CellularPhoneNumber>0 AND m.CellularPhoneNumber IS NOT NULL	
			THEN 'FNameLast4 Phone - SVeteran'
		WHEN (p.PatientFirstName = i.FirstName OR p.PatientFirstName LIKE CONCAT(i.FirstName,' %')) AND i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
			THEN 'FNameLast4 Phone - SPatient'
		WHEN i.CallerPhoneNumber = m.PhoneNumber AND m.PhoneNumber<>9999999999 AND m.PhoneNumber>0 AND m.PhoneNumber IS NOT NULL 
			THEN 'LNameLast4 Phone - SVeteran'
		WHEN i.CallerPhoneNumber = m.CellularPhoneNumber AND m.CellularPhoneNumber<>9999999999 AND m.CellularPhoneNumber>0 AND m.CellularPhoneNumber IS NOT NULL	
			THEN 'LNameLast4 Phone - SVeteran'
		WHEN i.CallerPhoneNumber = p.PhoneNumber AND p.PhoneNumber<>9999999999 AND p.PhoneNumber>0 AND p.PhoneNumber IS NOT NULL
			THEN 'LNameLast4 Phone - SPatient'
		WHEN m.FirstName = i.FirstName THEN 'Full Name Last 4 - SVeteran'
		WHEN (p.PatientFirstName = i.FirstName OR p.PatientFirstName LIKE CONCAT(i.FirstName,' %')) THEN 'Full Name Last 4 - SPatient'
		END AS ICNSource
	,ISNULL(s.SSNVerificationStatus,m.SSNVerificationStatus) AS SSNVerificationStatus
	,AssuranceLevelStatusCode
	,m.Veteran
	,m.AddressPopulated
	,m.PersonModifiedDateTime
	,p.Sta3n
	,i.NearestFacilitySiteCode
FROM #Identifiers i
LEFT JOIN #ICNMatch_SSN s 
	ON i.Id=s.Id
LEFT JOIN #SVeteran m 
	ON i.LastName = m.LastName AND i.Last4 = m.LastFour AND (i.PatientSSN IS NULL OR i.PatientSSN='') --only join on lastfour if there is no full SSN
LEFT JOIN #SPatient p
	ON i.LastName = p.PatientLastName AND i.Last4 = p.LastFour AND i.PatientSSN IS NULL --only join on lastfour if there is no full SSN
	) a
ORDER BY ROW_NUMBER() OVER (PARTITION BY ID ORDER BY CASE WHEN PatientICN IS NOT NULL THEN 0 ELSE 1 END
	,AssuranceLevelStatusCode DESC, SSNVerificationStatus, Veteran DESC, AddressPopulated DESC, PersonModifiedDateTime DESC, CASE WHEN Sta3n=NearestFacilitySiteCode THEN 0 ELSE 1 END)



DROP TABLE IF EXISTS #VCLHotlineCalls
SELECT mvi.MVIPersonSID
	  ,i.PatientICN
	  ,ICNSource = CASE WHEN i.ICNSource LIKE '%1' THEN 'Exact SSN'
						WHEN i.ICNSource LIKE 'Exact SSN%FullName Phone' THEN 'Exact SSN Full Name Phone'
						WHEN i.ICNSource LIKE 'Exact SSN%LastName Phone' THEN 'Exact SSN Last Name Phone'
						WHEN i.ICNSource LIKE 'Exact SSN%Phone' THEN 'Exact SSN Phone'
						WHEN i.ICNSource LIKE 'Exact SSN%FullName' THEN 'Exact SSN Full Name'
						WHEN i.ICNSource LIKE 'Exact SSN%LastName' THEN 'Exact SSN Last Name'
						WHEN i.ICNSource LIKE 'Exact SSN%FirstName' THEN 'Exact SSN First Name'
						WHEN i.ICNSource LIKE 'Exact SSN%' THEN 'Exact SSN'
						WHEN i.ICNSource LIKE 'FNameLast4%' THEN 'Full Name Last 4 Phone'
						WHEN i.ICNSource LIKE '%2' OR i.ICNSource LIKE 'Full Name Last 4%' THEN 'Full Name Last 4'
						WHEN i.ICNSource LIKE '%3' OR i.ICNSource LIKE 'LNameLast4 Phone%' THEN 'Last Name Last 4 Phone'
					END
	  ,h.[ID] AS vcl_ID
	  ,h.[Name]
	  ,h.VeteranName
	  ,h.CallerName AS CallerName
	  ,h.CallStart AS VCL_Call_Date
      ,h.NearestFacilitySiteCode AS VCL_NearestFacilitySiteCode
      ,h.VCL_IsVet
      ,h.VCL_IsActiveDuty
	  ,h.VCL_VeteranStatus
      ,h.VCL_MilitaryBranch
	  ,h.CaringLetterEligible
INTO #VCLHotlineCalls
FROM #Identifiers h 
LEFT JOIN #ICNMatch_SSN_Last4 i
	ON h.ID=i.ID
LEFT JOIN [Common].[vwMVIPersonSIDPatientICN] mvi WITH (NOLOCK)
	ON i.PatientICN=mvi.PatientICN


--Stop code from running if missing data for new enrolled patients 
DECLARE @NewThreshold INT = 1000
DECLARE @NewCount BIGINT = (SELECT COUNT(*) FROM #VCLHotlineCalls a )
IF 	@NewCount  < @NewThreshold
BEGIN

DECLARE @msg1 varchar(500)= 'Row count insufficient to proceed with Code.CaringLetters_VCL_PatientMapping'
	PRINT @msg1
	
	EXEC [Log].[Message] 'Error','Row Counts',@msg1
	EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error

	PRINT @Msg1;
	THROW 51000,@Msg1,1

END

EXEC [Maintenance].[PublishTable] 'CaringLetters.VCL_PatientMapping','#VCLHotlineCalls'

EXEC [Log].[ExecutionEnd]

END