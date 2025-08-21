/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient information
TEST:
	EXEC [Code].[Stage_MasterPatientMill_Contact]
UPDATE:
	2020-08-21	RAS	Created code for Cerner Millenium data, modeled off previous version
	2020-10-26	RAS	Changed ActualVisitDateTime to DerivedVisitDateTime per source column change
	2020-11-30  CMH Added code to remove test patients from all fact tables
	2020-12-08	RAS	Added comments per validation feedback.
	2021-01-13  For Hospice, Accommodation = Null from [MillCDS].[FactUtilizationOutpatient] and changes related to [MillCDS].[FactPatientContactInfo]
	2022-01-06	RAS	Updated MaritalStatus logic to return "*Implied NULL*" as null value
	2024-05-21	LM	Added County from Millenium data; updated address logic to avoid combining columns from different addresses and reduce unmailable addresses
	2024-19-08  AER Adding FIPS
	2024-09-26  CMH Adding GISURH data
	2024-10-09	LM	Break contact info into separate procedure
DEPENDENCIES:
	-- [Config].[MasterPatientFields]
	-- [Cerner].[FactPatientDemographic] 
	-- [Cerner].[FactPatientContactInfo]
*******************************************************************/

CREATE PROCEDURE [Code].[Stage_MasterPatientMill_Contact]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Stage_MasterPatientMill_Contact','Execution of Code.Stage_MasterPatientMill_Contact SP'

DROP TABLE IF EXISTS #StageMasterPatient_Contact_Mill
CREATE TABLE #StageMasterPatient_Contact_Mill (
	MVIPersonSID INT NULL
	,FieldName VARCHAR(25) NOT NULL
	,FieldValue VARCHAR(200) NULL
	,FieldModifiedDateTime DATETIME2(0) NULL
	)
-----------------------------------------------------------------------------
-- Basic Demographics
-----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Demog_Mill_Contact;
SELECT MVIPersonSID
		,TestPatient=0 --setting to 0 because we are only retaining Cerner non-test patients
		,VeteranFlag=NULL
		,ModifiedDateTime
INTO #Demog_Mill_Contact
FROM [Cerner].[FactPatientDemographic] WITH(NOLOCK)

INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,FieldName
	,FieldValue 
	,ModifiedDateTime
FROM (
	SELECT MVIPersonSID 
		,CAST(TestPatient AS VARCHAR(100)) AS TestPatient
		,ModifiedDateTime	
	FROM #Demog_Mill_Contact
	) ph
UNPIVOT (FieldValue FOR FieldName IN (	
		TestPatient
		)
	) u

DROP TABLE #Demog_Mill_Contact

-----------------------------------------------------------------------------
-- Phone Numbers
-----------------------------------------------------------------------------
INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,FieldName = 'PhoneNumber'
	,PhoneNumber = Home_PhoneNumber
	,PhoneUpdateDateTime = Home_PhoneUpdateDateTime
FROM [Cerner].[FactPatientContactInfo]
WHERE Home_PhoneNumber IS NOT NULL
UNION ALL
SELECT MVIPersonSID
	,FieldName = 'CellPhoneNumber'
	,PhoneNumber = Mobile_PhoneNumber
	,PhoneUpdateDateTime = Mobile_PhoneUpdateDateTime
FROM [Cerner].[FactPatientContactInfo]
WHERE Mobile_PhoneNumber  IS NOT NULL

-----------------------------------------------------------------------------
-- Patient Address
-----------------------------------------------------------------------------
	-- Most recently modified address data from Cerner Mill
	DROP TABLE IF EXISTS #HomeAddress_Mill
	SELECT MVIPersonSID
			,StreetAddress1
			,StreetAddress2
			,City 
			,State 
			,Zip
			,County
			,POBox
			,ModifiedDateTime
			,Home_CountyFIPS AS CountyFIPS
			,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY IncompleteAddress, ModifiedDateTime DESC)
	INTO #HomeAddress_Mill
	FROM
	(
		SELECT MVIPersonSID
				,Home_StreetAddress as StreetAddress1
				,CASE WHEN Home_StreetAddress=Home_StreetAddress2 THEN NULL ELSE Home_StreetAddress2 END AS StreetAddress2
				,DerivedHome_City  as City
				,ISNULL(DerivedHome_State,z.StateCode) as State 
				,LEFT(Home_Zipcode, 5) as Zip
				,DerivedHome_County AS County
				,POBox=CASE WHEN Home_StreetAddress LIKE '%BOX %' THEN 1 ELSE 0 END
				,Home_ModifiedDateTime as ModifiedDateTime
				,CASE WHEN (Home_StreetAddress IS NULL
					OR Home_StreetAddress LIKE '%HOMELESS%'  
					OR Home_StreetAddress LIKE '%ADDRESS%'  OR Home_StreetAddress LIKE 'BAD AD%'
					OR Home_StreetAddress LIKE '%WILL UPDATE%'  
					OR Home_StreetAddress LIKE '%UNKNOWN%'   OR Home_StreetAddress LIKE 'UNK%'
					OR Home_StreetAddress LIKE '%NONE' OR Home_StreetAddress LIKE '%NONE*%' OR Home_StreetAddress LIKE '%NONE %' OR Home_StreetAddress LIKE '%NONE,%'
					OR Home_StreetAddress LIKE '%VAMC%' 
					OR Home_StreetAddress LIKE '%UNDELIVERABLE%' OR Home_StreetAddress LIKE '%DO NOT%'
					OR Home_StreetAddress LIKE '%DECEASED%' OR Home_StreetAddress LIKE '%DIED%'
					OR Home_StreetAddress LIKE '000%'
					OR Home_StreetAddress IN ('NO','DELETED','BLANK','','UNK','DO NOT MAIL','...')
					OR Home_Zipcode IS NULL 
					OR DerivedHome_City IS NULL 
					OR DerivedHome_City ='' 
					) THEN 1 ELSE 0 END AS IncompleteAddress
				,NULL as Home_CountyFIPS
		FROM [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
		LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
			ON LEFT(i.Home_Zipcode,5)=z.ZipCode
		WHERE MVIPersonSID>0 
		) ad1

	DELETE FROM #HomeAddress_Mill WHERE RN>1

	INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,FieldName
		,FieldValue 
		,ModifiedDateTime
	FROM (
		SELECT MVIPersonSID 
			,CAST(StreetAddress1 AS VARCHAR(100)) AS StreetAddress1
			,CAST(StreetAddress2 AS VARCHAR(100)) AS StreetAddress2
			,CAST(City AS VARCHAR(100)) AS City
			,CAST(State AS VARCHAR(100)) AS State
			,CAST(Zip AS VARCHAR(100)) AS Zip
			,CAST(County AS VARCHAR(100)) AS County
			,CAST(ISNULL(CountyFIPS,-1) AS VARCHAR(100)) AS CountyFIPS
		,ModifiedDateTime
		FROM #HomeAddress_Mill
		) ph
	UNPIVOT (FieldValue FOR FieldName IN (
			StreetAddress1
			,StreetAddress2
			,City
			,State
			,Zip
			,County
		,CountyFIPS
			)
		) u

	--Temporary Address
	DROP TABLE IF EXISTS #TempAddress_Mill
	SELECT MVIPersonSID
			,TempStreetAddress1
			,TempStreetAddress2
			,TempCity 
			,TempState 
			,TempZip
			,TempCounty
			,POBox
			,ModifiedDateTime
			,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY IncompleteAddress, ModifiedDateTime DESC)
	INTO #TempAddress_Mill
	FROM
	(
	SELECT MVIPersonSID
			,Temp_StreetAddress as TempStreetAddress1
			,CASE WHEN Temp_StreetAddress=Temp_StreetAddress2 THEN NULL ELSE Temp_StreetAddress2 END AS TempStreetAddress2
			,DerivedTemp_City as TempCity
			,ISNULL(DerivedTemp_State,z.StateCode) as TempState
			,LEFT(Temp_Zipcode, 5) as TempZip
			,DerivedTemp_County AS TempCounty
			,POBox=CASE WHEN Temp_StreetAddress LIKE '%BOX %' THEN 1 ELSE 0 END
			,Temp_ModifiedDateTime as ModifiedDateTime
			,CASE WHEN (Temp_StreetAddress LIKE '%HOMELESS%'  
				OR Temp_StreetAddress LIKE '%ADDRESS%'  OR Temp_StreetAddress LIKE '%BAD AD%'
				OR Temp_StreetAddress LIKE '%WILL UPDATE%'  
				OR Temp_StreetAddress LIKE '%UNKNOWN%'  OR Temp_StreetAddress LIKE 'UNK%'
				OR Temp_StreetAddress LIKE '%NONE' OR Temp_StreetAddress LIKE '%NONE*%' OR Temp_StreetAddress LIKE '%NONE %' OR Temp_StreetAddress LIKE '%NONE,%' 
				OR Temp_StreetAddress LIKE '%VAMC%' 
				OR Temp_StreetAddress LIKE '%UNDELIVERABLE%' OR Temp_StreetAddress LIKE '%DO NOT%'
				OR Temp_StreetAddress LIKE '%DECEASED%' OR Temp_StreetAddress LIKE '%DIED%'
				OR Temp_StreetAddress LIKE '000%'
				OR Temp_StreetAddress IN ('NO','DELETED','BLANK','','UNK','DO NOT MAIL','...','SAME','TBA','NA')
				OR Temp_Zipcode IS NULL 
				OR DerivedTemp_City IS NULL 
				OR DerivedTemp_City ='' 
				) THEN 1 ELSE 0 END AS IncompleteAddress
	FROM [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
	LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
			ON LEFT(i.Temp_Zipcode,5)=z.ZipCode
	WHERE  MVIPersonSID>0 AND Temp_StreetAddress IS NOT NULL 
	) ad1 WHERE IncompleteAddress=0

	DELETE FROM #TempAddress_Mill WHERE RN>1

	INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,FieldName
		,FieldValue 
		,ModifiedDateTime
	FROM (
		SELECT MVIPersonSID 
			,CAST(TempStreetAddress1 AS VARCHAR(100)) AS TempStreetAddress1
			,CAST(TempStreetAddress2 AS VARCHAR(100)) AS TempStreetAddress2
			,CAST(TempCity AS VARCHAR(100)) AS TempCity
			,CAST(TempState AS VARCHAR(100)) AS TempState
			,CAST(TempZip AS VARCHAR(100)) AS TempZip
		,ModifiedDateTime
		FROM #TempAddress_Mill
		) ph
	UNPIVOT (FieldValue FOR FieldName IN (
			TempStreetAddress1
			,TempStreetAddress2
			,TempCity
			,TempState
			,TempZip
			)
		) u

	--Mailing Address
	DROP TABLE IF EXISTS #MailAddress_Mill
	SELECT MVIPersonSID
			,MailStreetAddress1
			,MailStreetAddress2
			,MailCity 
			,MailState 
			,MailZip
			,POBox
			,ModifiedDateTime
			,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY IncompleteAddress, ModifiedDateTime DESC)
	INTO #MailAddress_Mill
	FROM
	(
	SELECT MVIPersonSID
			,Mail_StreetAddress as MailStreetAddress1
			,CASE WHEN Mail_StreetAddress=Mail_StreetAddress2 THEN NULL ELSE Mail_StreetAddress2 END AS MailStreetAddress2
			,DerivedMail_City as MailCity
			,ISNULL(DerivedMail_State,z.StateCode) as MailState
			,LEFT(Mail_Zipcode, 5) as MailZip
			,DerivedMail_County AS MailCounty
			,POBox=CASE WHEN Mail_StreetAddress LIKE '%BOX %' THEN 1 ELSE 0 END
			,Mail_ModifiedDateTime as ModifiedDateTime
			,CASE WHEN (Mail_StreetAddress LIKE '%HOMELESS%'  
				OR Mail_StreetAddress LIKE '%ADDRESS%'  OR Mail_StreetAddress LIKE '%BAD AD%'
				OR Mail_StreetAddress LIKE '%WILL UPDATE%'  
				OR Mail_StreetAddress LIKE '%UNKNOWN%'  OR Mail_StreetAddress LIKE 'UNK%'
				OR Mail_StreetAddress LIKE '%NONE' OR Mail_StreetAddress LIKE '%NONE*%' OR Mail_StreetAddress LIKE '%NONE %' OR Mail_StreetAddress LIKE '%NONE,%' 
				OR Mail_StreetAddress LIKE '%VAMC%' 
				OR Mail_StreetAddress LIKE '%UNDELIVERABLE%' OR Mail_StreetAddress LIKE '%DO NOT%'
				OR Mail_StreetAddress LIKE '%DECEASED%' OR Mail_StreetAddress LIKE '%DIED%'
				OR Mail_StreetAddress LIKE '000%'
				OR Mail_StreetAddress IN ('NO','DELETED','BLANK','','UNK','DO NOT MAIL','...','SAME','TBA','NA')
				OR Mail_Zipcode IS NULL 
				OR DerivedMail_City IS NULL 
				OR DerivedMail_City ='' 
				) THEN 1 ELSE 0 END AS IncompleteAddress
	FROM [Cerner].[FactPatientContactInfo] i WITH (NOLOCK)
	LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
			ON LEFT(i.Mail_Zipcode,5)=z.ZipCode
	WHERE  MVIPersonSID>0 AND Mail_StreetAddress IS NOT NULL 
	) ad1 WHERE IncompleteAddress=0

	DELETE FROM #MailAddress_Mill WHERE RN>1

	INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,FieldName
		,FieldValue 
		,ModifiedDateTime
	FROM (
		SELECT MVIPersonSID 
			,CAST(MailStreetAddress1 AS VARCHAR(100)) AS MailStreetAddress1
			,CAST(MailStreetAddress2 AS VARCHAR(100)) AS MailStreetAddress2
			,CAST(MailCity AS VARCHAR(100)) AS MailCity
			,CAST(MailState AS VARCHAR(100)) AS MailState
			,CAST(MailZip AS VARCHAR(100)) AS MailZip
		,ModifiedDateTime
		FROM #MailAddress_Mill
		) ph
	UNPIVOT (FieldValue FOR FieldName IN (
			MailStreetAddress1
			,MailStreetAddress2
			,MailCity
			,MailState
			,MailZip
			)
		) u

DROP TABLE #HomeAddress_Mill,#MailAddress_Mill,#TempAddress_Mill

-----------------------------------------------------
--GISRUH urban/rural indicator
-----------------------------------------------------
INSERT INTO #StageMasterPatient_Contact_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,'GISURH'
	,URH_CODE
	,Home_ModifiedDateTime
FROM (
	SELECT MVIPersonSID
		,URH_CODE
		,Home_ModifiedDateTime
	FROM [Cerner].[FactPatientContactInfo] WITH (NOLOCK)
	WHERE URH_CODE IS NOT NULL
	) a

-----------------------------------------------------------------------------
-- Stage and Publish
-----------------------------------------------------------------------------
	--Create table with all MVIPersonSIDs that will be included in final table
	----Get IDs for the patients who are defined in first section with test patient logic.
	----This TestPatiet FieldName is used to get the list of final patients because only this 
	----criteria will return EVERY patient because every patient has either a value 0 or 1.  
	----And it has already been filtered for the patients we want to keep in the table 
	----(mostly non-test patients)
	DROP TABLE IF EXISTS #ExcludeTest_Mill
	SELECT DISTINCT MVIPersonSID
	INTO #ExcludeTest_Mill
	FROM #StageMasterPatient_Contact_Mill
	WHERE FieldName = 'TestPatient' 
	
	--Join the above patient list with all of the patient data in #StageMasterPatient
	----This will filter out data for patients who are not real (e.g., an address for a test patient)
	DROP TABLE IF EXISTS #StageMPMill;
	SELECT st.MVIPersonSID
		,i.MasterPatientFieldID
		,st.FieldName AS MasterPatientFieldName
		,st.FieldValue
		,st.FieldModifiedDateTime
	INTO #StageMPMill
	FROM #StageMasterPatient_Contact_Mill st
	INNER JOIN  [Config].[MasterPatientFields] i WITH (NOLOCK) ON i.MasterPatientFieldName=st.FieldName
	INNER JOIN #ExcludeTest_Mill nt ON nt.MVIPersonSID=st.MVIPersonSID
	WHERE st.MVIPersonSID>0

--------------------------------------------
-- PUBLISH 
--------------------------------------------
EXEC [Maintenance].[PublishTable] 'Stage.MasterPatientMill_Contact','#StageMPMill'

EXEC [Log].[ExecutionEnd]
END