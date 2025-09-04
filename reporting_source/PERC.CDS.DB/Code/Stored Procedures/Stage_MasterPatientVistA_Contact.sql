/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient information
TEST:
	EXEC [Code].[Stage_MasterPatientVistA_Contact]
UPDATE:
	2020-08-07	RAS	Created SP, incorporating CDS rules for patient information using
					Present_StationAssignments, and views in development for demographics, etc.
					Definitions differ from PDW_DWS_MasterPatient (e.g., VeteranFlag, TestPatientFlag)
					and includes additional fields (e.g., marital status, race, service connectedness)
	2020-08-18	RAS	Changed BirthDateTime limitation to <= '1900-01-01' instead of '1914-01-01' to align 
					with RealPatients code that this is replacing. This was decided in a meeting with JT
					a while back, but I am not sure why.
	2020-08-21	RAS	Added ISNULL for PatientSSN to pull from SPatient if MVIPerson table contains null value.
	2020-10-20	RAS	Branched MasterPatient to VistA-specific code to implement modular approach for Cerner Overlay.
	2020-12-08	RAS	Added comments per validation feedback. Corrected WorkPhoneNumber to use the entry from OrdinalNumber = 13
	2021-05-05	LM	Removed CDWPossibleTestPatient as an indicator for test patients to be removed; 
					added PossibleTestPatient to flag these patients
	2021-05-14  JEB Change Synonym DWS_ reference to proper PDW_ reference
	2021-08-17	JEB Enclave Refactoring - Counts confirmed; Some additional formatting; Added WITH (NOLOCK)
	2021-09-23	JEB Enclave Refactoring - Removed use of Partition ID
	2021-11-18	LM	Adjusted address where clause from NOT LIKE '%NONE%' to NOT LIKE '%NONE' to avoid excluding addresses where 
					'none' is part of a valid address (e.g., Cannoneer)
	2022-01-06	RAS	Added MaritalStatus from SPatient
	2022-03-11	RAS	Added County and GISURH to address information
	2022-04-05	LM	Changed address query to get most recently updated address rather than address from most recently updated VistA record
	2022-06-23	LM	Pointed to Lookup.StopCode_VM
	2022-08-24	RAS	Added additional test patients used in STORM.
	2022-08-30	RAS	Removed 3 ICNs for test patient display that appear to be real records and NOT actual test.
	2024-04-04	LM	Refined address query
	2024-08-19  AER Adding FIPS
	2024-09-18	LM	Added preferred name from SPatient table
	2024-10-08	LM	Move temp address query from MasterPatient code to this stage code
	2024-10-09	LM	Break contact info into separate procedure
CDS DEPENDENCIES:
	-- [Config].[MasterPatientFields]

*******************************************************************/

CREATE PROCEDURE [Code].[Stage_MasterPatientVistA_Contact]
AS
BEGIN

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Stage_MasterPatientVistA_Contact','Execution of Code.Stage_MasterPatientVistA_Contact SP'

	DROP TABLE IF EXISTS #StageMasterPatient_Contact
	CREATE TABLE #StageMasterPatient_Contact (
		MVIPersonSID INT NOT NULL
		,FieldName VARCHAR(25) NOT NULL
		,FieldValue VARCHAR(200) NULL
		,FieldModifiedDateTime DATETIME2(0) NULL
		)
	-----------------------------------------------------------------------------
	-- Basic Demographics
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #SPatientDemog_Contact;
	SELECT MVIPersonSID
		,PatientICN
		,TestPatient
		,PossibleTestPatient
	INTO #SPatientDemog_Contact
	FROM [Common].[MasterPatient_Patient] WITH (NOLOCK)
	CREATE UNIQUE CLUSTERED INDEX CIX_SPatient_MVI ON #SPatientDemog_Contact(MVIPersonSID)
	

	-----------------------------------------------------------------------------
	-- Phone Numbers
	-----------------------------------------------------------------------------
	/*
		/*
		SELECT DISTINCT OrdinalNumber,PatientContactType
		FROM [SPatient].[SPatientPhone]
		WHERE PatientCOntactType NOT LIKE '*Unknown at this time*'
		ORDER BY 1
		*/
		OrdinalNumber	PatientContactType
		2				Next Of Kin
		3				Secondary Next Of Kin
		4				Temporary
		5				Confidential
		6				Spouse Employer
		7				VA Guardian
		8				Civil Guardian
		9				Patient Employer
		10				Emergency Contact
		11				Secondary Emergency Contact
		12				Designee
		13				Patient Residence
		14				Patient Cell Phone
		15				Patient Pager
		16				Patient Email
	*/
	
	DROP TABLE IF EXISTS #SPatientPhone;
	SELECT TOP 1 WITH TIES 
		pp.* 
	INTO #SPatientPhone
	FROM 
		(
			SELECT mvi.MVIPersonSID
				  ,p.OrdinalNumber
				  ,CASE WHEN p.OrdinalNumber IN (2,10) AND p.RelationshipToPatient IS NOT NULL THEN p.NameOfContact + ' (' + p.RelationshipToPatient + ')'
						WHEN p.OrdinalNumber IN (2,10) THEN p.NameOfContact
						ELSE p.NameOfContact
						END AS NameOfContact
				  ,p.RelationshipToPatient
				  ,CASE WHEN p.OrdinalNumber=9 THEN p.WorkPhoneNumber ELSE p.PhoneNumber END AS PhoneNumber
				  ,CASE WHEN p.OrdinalNumber = 13	THEN 'PhoneNumber'
						WHEN p.OrdinalNumber = 2	THEN 'NextOfKinPhone'
						WHEN p.OrdinalNumber = 4	THEN 'TempPhoneNumber'
						WHEN p.OrdinalNumber = 10	THEN 'EmergencyPhone'
						WHEN p.OrdinalNumber = 14	THEN 'CellPhoneNumber'
						WHEN p.OrdinalNumber = 9	THEN 'WorkPhoneNumber'
						END AS PhoneFieldName
				  ,p.ChangeDateTime
				  ,p.ChangeSource
				  ,s.PatientEnteredDateTime
			FROM [SPatient].[SPatientPhone] p WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON p.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [SPatient].[SPatient] s WITH (NOLOCK)
				ON p.PatientSID = s.PatientSID
			WHERE p.OrdinalNumber IN (2,4,10,13,14,9)
				AND mvi.MVIPersonSID >0 AND (p.PhoneNumber IS NOT NULL OR (p.OrdinalNumber=9 AND p.WorkPhoneNumber IS NOT NULL AND p.WorkPhoneNumber <>'NONE'))
			UNION ALL
			SELECT mvi.MVIPersonSID
				  ,OrdinalNumber=9
				  ,p.NameOfContact
				  ,p.RelationshipToPatient
				  ,p.WorkPhoneNumber
				  ,PhoneFieldName='WorkPhoneNumber'
				  ,p.ChangeDateTime
				  ,p.ChangeSource
				  ,s.PatientEnteredDateTime
			FROM [SPatient].[SPatientPhone] p WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON p.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [SPatient].[SPatient] s WITH (NOLOCK)
				ON p.PatientSID = s.PatientSID
			WHERE p.OrdinalNumber IN (4,13,14,9) AND p.RelationshipToPatient='Self'
				AND mvi.MVIPersonSID >0
				AND WorkPhoneNumber IS NOT NULL AND WorkPhoneNumber <>'NONE'
		) pp
	ORDER BY ROW_NUMBER() OVER(PARTITION BY pp.MVIPersonSID, pp.OrdinalNumber ORDER BY pp.ChangeDateTime DESC, pp.ChangeSource DESC, pp.PatientEnteredDateTime DESC, pp.RelationshipToPatient DESC)

	INSERT INTO #StageMasterPatient_Contact (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID,FieldName,FieldValue,ModifiedDateTime 
	FROM (
		SELECT MVIPersonSID
			,FieldName = PhoneFieldName 
			,FieldValue = PhoneNumber
			,ModifiedDateTime = ChangeDateTime
		FROM #SPatientPhone
		UNION ALL
		SELECT MVIPersonSID
			,FieldName = 'NextOfKinPhone_Name'
			,FieldValue = NameOfContact
			,ModifiedDateTime = ChangeDateTime
		FROM #SPatientPhone
		WHERE OrdinalNumber = 2
		UNION ALL
		SELECT MVIPersonSID
			,FieldName = 'EmergencyPhone_Name'
			,FieldValue = NameOfContact
			,ModifiedDateTime = ChangeDateTime
		FROM #SPatientPhone
		WHERE OrdinalNumber = 10
		) phone
	WHERE FieldValue IS NOT NULL

	DROP TABLE #SPatientPhone

	-----------------------------------------------------------------------------
	-- Patient Address
	-----------------------------------------------------------------------------
	--Get the most recently updated address

	DROP TABLE IF EXISTS #SPatientAddress
	SELECT TOP 1 WITH TIES *
	INTO #SPatientAddress
	FROM (SELECT DISTINCT
		 mvi.MVIPersonSID
		,ad.AddressType
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
		,ad.County
		,ad.GISURH
		,ad.AddressChangeDateTime
		,CASE WHEN (ad.StreetAddress1 IS NULL
			OR ad.StreetAddress1 LIKE '%HOMELESS%'  
			OR ad.StreetAddress1 LIKE '%ADDRESS%'  OR ad.StreetAddress1 LIKE '%BAD AD%'
			OR ad.StreetAddress1 LIKE '%WILL UPDATE%'  
			OR ad.StreetAddress1 LIKE '%UNKNOWN%' OR ad.StreetAddress1 LIKE 'UNK%' 
			OR ad.StreetAddress1 LIKE '%NONE' OR ad.StreetAddress1 LIKE '%NONE*%' OR ad.StreetAddress1 LIKE '%NONE %' OR ad.StreetAddress1 LIKE '%NONE,%' 
			OR ad.StreetAddress1 LIKE '%VAMC%'
			OR ad.StreetAddress1 LIKE '%UNDELIVERABLE%' OR ad.StreetAddress1 LIKE '%DO NOT%'
			OR ad.StreetAddress1 LIKE '%DECEASED%' OR ad.StreetAddress1 LIKE '%DIED%'
			OR ad.StreetAddress1 LIKE '000%'
			OR TRIM(ad.StreetAddress1) IN ('NO','DELETE','DELETED','BLANK','','UNK','DO NOT MAIL','...')
			OR (ad.Zip IS NULL AND ad.PostalCode IS NULL)
			OR ad.City IS NULL 
			OR ad.City ='')
			THEN 1 ELSE 0 END AS IncompleteAddress
		,CASE WHEN ad.BadAddressIndicator IN ('HOMELESS','ADDRESS NOT FOUND','UNDELIVERABLE') THEN 1 ELSE 0 END AS BadAddress
		,ad.GISFIPSCode as CountyFIPS
		,ad.OrdinalNumber
	FROM [SPatient].[SPatientAddress] ad WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
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
	) a 
	WHERE a.MVIPersonSID>0
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, OrdinalNumber ORDER BY IncompleteAddress, BadAddress, AddressChangeDateTime DESC) --pull in partial data if it's the only thing available

	INSERT INTO #StageMasterPatient_Contact (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,CASE WHEN FieldName IN ('GISURH','CountyFIPS','County') THEN FieldName
			WHEN OrdinalNumber=4 THEN CONCAT('Temp',FieldName) 
			WHEN OrdinalNumber=13 THEN CONCAT('Mail',FieldName)
			ELSE FieldName END AS FieldName
		,FieldValue 
		,AddressChangeDateTime
	FROM (
		SELECT MVIPersonSID 
			,CAST(StreetAddress1 AS VARCHAR(100)) AS StreetAddress1
			,CAST(StreetAddress2 AS VARCHAR(100)) AS StreetAddress2
			,CAST(StreetAddress3 AS VARCHAR(100)) AS StreetAddress3
			,CAST(City AS VARCHAR(100)) AS City
			,CAST(State AS VARCHAR(100)) AS State
			,CAST(Zip AS VARCHAR(100)) AS Zip
			,CAST(Country AS VARCHAR(100)) AS Country
			,CAST(County AS VARCHAR(100)) AS County
			,CAST(GISURH AS VARCHAR(100)) AS GISURH
			,CAST(CountyFIPS as varchar(100)) AS CountyFIPS
			,AddressChangeDateTime
			,OrdinalNumber
		FROM #SPatientAddress
		) ph
	UNPIVOT (FieldValue FOR FieldName IN (
			StreetAddress1
			,StreetAddress2
			,StreetAddress3
			,City
			,State
			,Zip
			,County
			,GISURH
			,CountyFIPS
			)
		) u
		
	DROP TABLE #SPatientAddress
	-----------------------------------------------------------------------------
	-- Stage and Publish
	-----------------------------------------------------------------------------

	DROP TABLE IF EXISTS #StageMPVistA_Contact;
	SELECT st.MVIPersonSID
		,i.MasterPatientFieldID
		,st.FieldName AS MasterPatientFieldName
		,st.FieldValue
		,st.FieldModifiedDateTime
	INTO #StageMPVistA_Contact
	FROM #StageMasterPatient_Contact st
	INNER JOIN #SPatientDemog_Contact sp 
		ON st.MVIPersonSID = sp.MVIPersonSID
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldName = st.FieldName
	
		
	EXEC [Maintenance].[PublishTable] 'Stage.MasterPatientVistA_Contact','#StageMPVistA_Contact'

	EXEC [Log].[ExecutionEnd]
END