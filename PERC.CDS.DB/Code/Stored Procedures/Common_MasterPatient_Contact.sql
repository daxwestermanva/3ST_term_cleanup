/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient contact information
TEST:

	EXEC [Code].[Stage_MasterPatientVistA_Contact]
	EXEC [Code].[Stage_MasterPatientMill_Contact]
	EXEC [Code].[Common_MasterPatient_Contact]
UPDATE:
	2020-08-07	RAS	Created SP, incorporating CDS rules for patient information using
					Present_StationAssignments, and views in development for demographics, etc.
					Definitions differ from PDW_DWS_MasterPatient (e.g., VeteranFlag, TestPatientFlag)
					and includes additional fields (e.g., marital status, race, service connectedness)
	2020-10-21	RAS	V02 - Making code modular to implement overlaying of Cerner data in a more coherent way
	2021-01-22	RAS	Added code to determine if staging tables have too low of a row count to continue running the SP.
	2021-05-18	JEB	Enclave work - updated NDim Synonym use. No logic changes made.
	2021-05-18  JEB Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
	2021-05-18  JEB Enclave work - updated [SVeteran].[SMVIPerson] Synonym use. No logic changes made.	
	2021-08-18  JEB Enclave work - Enclave Refactoring - Counts confirmed based on Non Deleted CDW records; Some additional formatting; Added WITH (NOLOCK); Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	2022-02-23	LM	Included patients where PossibleTestPatient IS NULL - there is no PossibleTestPatient (i.e., CDWPossibleTestPatientFlag) value in the Cerner data and Test Patients are already excluded in MillCDS code
	2022-03-17	RAS	Added GISURH and County (note this is only from VistA, no Cerner and does not necessarily match MVIPerson address)
	2022-05-19	LM	Added EDIPI
	2022-08-30	RAS	Added 1 additional PatientICN to test patients for STORM display.
	2023-07-05  CMH Reworked code to only retain valid state-county pairs 
	2024-04-29	LM	Set streetaddress to NULL if address is invalid but retain city/state/zip/county when available
	2024-08-22  AER Added CountyFIPS
	2024-08-29	RAS	Removed FieldID 44 from address component list because it is not an address component.
	2024-10-09	LM	Broke contact info and patient data into separate procedures
*******************************************************************/

CREATE PROCEDURE [Code].[Common_MasterPatient_Contact]
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Common_MasterPatient_Contact','Execution of Code.Common_MasterPatient_Contact SP'

	-----------------------------------------------
	-- CHECK PREREQUISITES
	-----------------------------------------------
	/**Make sure staging tables are populated correctly**/
	DECLARE @VistaThreshold INT = 100000000
	DECLARE @MillThreshold INT = 1000000
	
	DECLARE @VistaCount BIGINT = (SELECT COUNT_BIG(*) FROM [Stage].[MasterPatientVistA_Contact] WITH (NOLOCK))
	DECLARE @MillCount BIGINT = (SELECT COUNT_BIG(*) FROM [Stage].[MasterPatientMill_Contact] WITH (NOLOCK))
	IF	(
		@VistaCount   < @VistaThreshold
		OR @MillCount < @MillThreshold
		)
	BEGIN 
		DECLARE @ErrorMsg varchar(500)=
			CASE WHEN @VistaCount < @VistaThreshold AND @MilLCount < @MillThreshold  THEN 'Staging tables MasterPatientVistA_Contact and MasterPatientMill_Contact: '
				WHEN @VistaCount < @VistaThreshold THEN 'Stage.MasterPatientVistA_Contact: '
				WHEN @MilLCount < @MillThreshold THEN 'Stage.MasterPatientMill_Contact: '
				END
			+ 'Row count insufficient to proceed with MasterPatient code'
		EXEC [Log].[Message] 'Error','Missing dependency',@ErrorMsg
		EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error
		PRINT @ErrorMsg;
		THROW 51000,@ErrorMsg,1
	END


----------------------------------------------------------------------------
	-- HARMONIZE THE 2 SOURCES OF DATA
	----------------------------------------------------------------------------
	--Combine staging tables for address-related fields that require most recently entered or changed data (do this separately so that all pieces of address are pulled together)
	DROP TABLE IF EXISTS #AddressComponents
    SELECT MVIPersonSID
        ,MasterPatientFieldID
        ,FieldValue
        ,FieldModifiedDateTime
        ,CASE WHEN MasterPatientFieldID IN (31,32,33,34,35,36,51,52,56) THEN 1 --Home
			WHEN MasterPatientFieldID IN (37,38,39,40,41,42) THEN 2 --Temporary
			WHEN MasterPatientFieldID IN (58,59,60,61,62,63,64) THEN 3 --Mailing
			END AS AddressType 
    INTO #AddressComponents
    FROM [Stage].[MasterPatientVistA_Contact] WITH (NOLOCK) 
    WHERE MasterPatientFieldID IN (31,32,33,34,35,36,37,38,39,40,41,42,51,52,56,58,59,60,61,62,63,64) 
    UNION ALL
    SELECT MVIPersonSID
        ,MasterPatientFieldID
        ,FieldValue
        ,FieldModifiedDateTime
        ,CASE WHEN MasterPatientFieldID IN (31,32,33,34,35,36,51,52,56) THEN 1 --Home
			WHEN MasterPatientFieldID IN (37,38,39,40,41,42) THEN 2 --Temporary
			WHEN MasterPatientFieldID IN (58,59,60,61,62,63,64) THEN 3 --Mailing
			END AS AddressType 
    FROM [Stage].[MasterPatientMill_Contact] WITH (NOLOCK) 
    WHERE MasterPatientFieldID IN (31,32,33,34,35,36,37,38,39,40,41,42,51,52,56,58,59,60,61,62,63,64) 

    DROP TABLE IF EXISTS #MaxAddress
    SELECT MVIPersonSID
        ,AddressType
        ,MAX(FieldModifiedDateTime) AS FieldModifiedDateTime
    INTO #MaxAddress
    FROM #AddressComponents WHERE MasterPatientFieldID NOT IN (51,52,56) --GISURH, CountyFIPS
    GROUP BY MVIPersonSID, AddressType

	--In cases where patient doesn't have residential address, get GISURH, County, and FIPS from mail or temp addresses
	DROP TABLE IF EXISTS #FIPS_GISURH
    SELECT TOP 1 WITH TIES a.MVIPersonSID
        ,a.MasterPatientFieldID
		,i.MasterPatientFieldName
		,a.FieldValue
		,a.FieldModifiedDateTime
    INTO #FIPS_GISURH
    FROM #AddressComponents a
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = a.MasterPatientFieldID
		AND i.Category = 'Contact'
	LEFT JOIN #MaxAddress b 
		ON a.MVIPersonSID=b.MVIPersonSID AND a.FieldModifiedDateTime=b.FieldModifiedDateTime AND b.AddressType=1
	WHERE a.MasterPatientFieldID IN (51,52,56) --GISURH, CountyFIPS
    ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, a.MasterPatientFieldID ORDER BY CASE WHEN b.MVIPersonSID IS NOT NULL THEN 1 ELSE 2 END, a.AddressType, a.FieldModifiedDateTime DESC)
	
    DROP TABLE IF EXISTS #RecentAddress
    SELECT a.MVIPersonSID
        ,a.MasterPatientFieldID
		,i.MasterPatientFieldName
        ,a.FieldValue
        ,a.FieldModifiedDateTime
	INTO #RecentAddress
    FROM #AddressComponents a
    INNER JOIN #MaxAddress b ON a.MVIPersonSID=b.MVIPersonSID
        AND (a.FieldModifiedDateTime=b.FieldModifiedDateTime OR (a.FieldModifiedDateTime IS NULL AND b.FieldModifiedDateTime IS NULL))
        AND a.AddressType=b.AddressType
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = a.MasterPatientFieldID
		AND i.Category = 'Contact'
	WHERE a.MasterPatientFieldID NOT IN (51,52,56) --GISURH, CountyFIPS
	UNION ALL
	SELECT a.* FROM #FIPS_GISURH a

	DROP TABLE IF EXISTS #AddressComponents
	DROP TABLE IF EXISTS #FIPS_GISURH

		--Combine staging tables for non-address fields that require most recently entered or changed data  
	DROP TABLE IF EXISTS #recent;
	SELECT TOP 1 WITH TIES
		 s.MVIPersonSID
		,i.MasterPatientFieldName
		,s.FieldValue
		,s.FieldModifiedDateTime
	INTO #recent
	FROM (
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientVistA_Contact] WITH (NOLOCK) 
		WHERE MasterPatientFieldID IN (23,24,25,26,27,28,29,30) --Phone, NoK, and emergency contact
		UNION ALL
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientMill_Contact] WITH (NOLOCK) 
		WHERE MasterPatientFieldID IN (23,24,25,26,27,28,29,30) --Phone, NoK, and emergency contact
		) s
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = s.MasterPatientFieldID
		AND i.VistAMillMethod = 'DATE'
		AND i.Category = 'Contact'
	ORDER BY ROW_NUMBER() OVER(PARTITION BY s.MVIPersonSID, i.MasterPatientFieldID ORDER BY s.FieldModifiedDateTime DESC)

	--Combine all data and pivot fields to prepare for staging
	DROP TABLE IF EXISTS  #PivotMP
	SELECT 
		 MVIPersonSID
		,PhoneNumber
		,WorkPhoneNumber
		,CellPhoneNumber
		,TempPhoneNumber
		,NextOfKinPhone
		,NextOfKinPhone_Name
		,EmergencyPhone
		,EmergencyPhone_Name
		,StreetAddress1
		,StreetAddress2
		,StreetAddress3
		,City
		,State
		,Zip
		,Country
		,County
		,CountyFIPS
		,GISURH	
		,TempStreetAddress1
		,TempStreetAddress2
		,TempStreetAddress3
		,TempCity
		,TempState
		,TempZip
		,MailStreetAddress1
		,MailStreetAddress2
		,MailStreetAddress3
		,MailCity
		,MailState
		,MailZip
		,MailCountry
		,TestPatient
		,PossibleTestPatient
		,POBox = 0
		,InvalidAddress = 0
	INTO #PivotMP
	FROM (
		SELECT MVIPersonSID
			,MasterPatientFieldName
			,FieldValue
		FROM #RecentAddress	
		UNION ALL 
		SELECT MVIPersonSID
			,MasterPatientFieldName
			,FieldValue
		FROM #recent
		) a
	PIVOT (MAX(FieldValue) FOR MasterPatientFieldName IN (
		PhoneNumber
		,WorkPhoneNumber
		,CellPhoneNumber
		,TempPhoneNumber
		,NextOfKinPhone
		,NextOfKinPhone_Name
		,EmergencyPhone
		,EmergencyPhone_Name
		,StreetAddress1
		,StreetAddress2
		,StreetAddress3
		,City
		,State
		,Zip
		,Country
		,County
		,CountyFIPS
		,GISURH
		,TempStreetAddress1
		,TempStreetAddress2
		,TempStreetAddress3
		,TempCity
		,TempState
		,TempZip
		,MailStreetAddress1
		,MailStreetAddress2
		,MailStreetAddress3
		,MailCity
		,MailState
		,MailZip
		,MailCountry
		,TestPatient
		,PossibleTestPatient
		)	) p

	DROP TABLE IF EXISTS #RecentAddress

	--Add POBox Flag
	UPDATE #PivotMP
	SET POBox = 1 WHERE StreetAddress1 LIKE '%BOX %'

	--Add InvalidAddress Flag
	UPDATE #PivotMP
	SET InvalidAddress = 1 WHERE (StreetAddress1 IS NULL
			OR StreetAddress1 LIKE '%HOMELESS%'  
			OR StreetAddress1 LIKE '%ADDRESS%'  OR StreetAddress1 LIKE '%BAD AD%'
			OR StreetAddress1 LIKE '%WILL UPDATE%'  
			OR StreetAddress1 LIKE '%UNKNOWN%'  OR StreetAddress1 LIKE 'UNK%'
			OR StreetAddress1 LIKE '%NONE' OR StreetAddress1 LIKE '%NONE*%' OR StreetAddress1 LIKE '%NONE %' OR StreetAddress1 LIKE '%NONE,%' 
			OR StreetAddress1 LIKE '%VAMC%'
			OR StreetAddress1 LIKE '%UNDELIVERABLE%' OR StreetAddress1 LIKE '%DO NOT%'
			OR StreetAddress1 LIKE '%DECEASED%' OR StreetAddress1 LIKE '%DIED%'
			OR StreetAddress1 LIKE '000%'
			OR StreetAddress1 IN ('NO','DELETED','BLANK','','UNK','DO NOT MAIL','...')
			OR Zip IS NULL
			OR City IS NULL 
			OR City ='' )

	  --Lookup to fill in missing address parts
	  DROP TABLE IF EXISTS #AddressParts
	  SELECT TOP 1 WITH TIES a.City, c.StateAbbrev, a.Zip, a.FIPSCode, b.County
	  INTO #AddressParts
	  FROM [SPatient].[SPatientGISAddress] a WITH (NOLOCK)
	  INNER JOIN Dim.StateCounty b WITH (NOLOCK)
		ON a.StateCountySID=b.StateCountySID
	  INNER JOIN Dim.State c WITH (NOLOCK)
		ON a.StateSID = c.StateSID 
	  WHERE a.Zip IS NOT NULL AND a.Zip <> '00000' AND c.StateAbbrev <>'*' AND County <> '*Missing*'
	  AND a.GISMatchScore=100 AND a.City NOT LIKE 'Unk%' AND a.City IS NOT NULL
	  ORDER BY ROW_NUMBER() OVER (PARTITION BY a.City, c.StateAbbrev, a.Zip ORDER BY a.FIPSCode)

	  --Counties cannot cross state lines. Infer state if state is null and countyFIPS is not null
	  UPDATE #PivotMP
	  SET CountyFIPS = b.FIPSCode
		,County = b.County
	  FROM #PivotMP a
	  INNER JOIN #AddressParts b ON a.State=b.StateAbbrev AND a.Zip=b.Zip AND a.City=b.City
	  WHERE a.CountyFIPS IS NULL AND a.County IS NULL

	---------------------------------------------------
	-- CREATE FLAGS FOR MVI ADDRESS
	---------------------------------------------------
	DROP TABLE IF EXISTS #MVIAddress
	SELECT sv.MVIPersonSID
		  ,sv.StreetAddress1 as MVI_StreetAddress1 
		  ,sv.StreetAddress2 as MVI_StreetAddress2
		  ,sv.StreetAddress3 as MVI_StreetAddress3
		  ,sv.City as MVI_City
		  ,MVI_State = CASE WHEN st.StateAbbrev IN ('*','*Missing*') THEN z.StateCode ELSE ISNULL(st.StateAbbrev,z.StateCode) END
		  ,LEFT(sv.Zip4,5) as MVI_Zip
		  ,CASE WHEN c.PostalName='<NULL>' THEN c.CountryDescription
			WHEN c.PostalName IS NOT NULL AND c.PostalName NOT IN ('*Missing*','Unknown') THEN c.PostalName
			END AS MVI_Country
		  ,InvalidFlag=CASE 
			WHEN (sv.StreetAddress1 IS NULL
				OR sv.StreetAddress1 LIKE '%HOMELESS%'  
				OR sv.StreetAddress1 LIKE '%ADDRESS%'  OR sv.StreetAddress1 LIKE '%BAD AD%'
				OR sv.StreetAddress1 LIKE '%WILL UPDATE%'  
				OR sv.StreetAddress1 LIKE '%UNKNOWN%'  OR sv.StreetAddress1 LIKE 'UNK%'
				OR sv.StreetAddress1 LIKE '%NONE' OR sv.StreetAddress1 LIKE '%NONE*%' OR sv.StreetAddress1 LIKE '%NONE %' OR sv.StreetAddress1 LIKE '%NONE,%' 
				OR sv.StreetAddress1 LIKE '%VAMC%'
				OR sv.StreetAddress1 LIKE '%UNDELIVERABLE%' OR sv.StreetAddress1 LIKE '%DO NOT%'
				OR sv.StreetAddress1 LIKE '%DECEASED%' OR sv.StreetAddress1 LIKE '%DIED%'
				OR sv.StreetAddress1 LIKE '000%'
				OR sv.StreetAddress1 IN ('NO','DELETED','BLANK','','UNK','DO NOT MAIL','...')
				OR sv.Zip4 IS NULL
				OR sv.City IS NULL 
				OR sv.City ='' )		
			THEN 1 ELSE 0 END
		  ,POBox=CASE
			WHEN sv.StreetAddress1 LIKE '%BOX %' 
			THEN 1 ELSE 0 END
	INTO #MVIAddress
	FROM [SVeteran].[SMVIPerson] sv WITH (NOLOCK) 
	LEFT JOIN [NDim].[MVIState] st WITH (NOLOCK) 
		ON st.MVIStateSID = sv.MVIStateSID
	LEFT JOIN [NDim].[MVICountryCode] c WITH (NOLOCK)
		ON sv.MVICountrySID = c.MVICountryCodeSID
	LEFT JOIN [LookUp].[ZipState] z WITH (NOLOCK)
		ON LEFT(sv.Zip4,5)=z.ZipCode
	--WHERE sv.MVIPersonSID IN (SELECT MVIPersonSID FROM #PivotMP)

	DROP TABLE IF EXISTS #MVIAddress2
	SELECT DISTINCT sv.*
		,MVI_County=ad.County
		,MVI_FIPSCode=ad.FIPSCode
	INTO #MVIAddress2
	FROM #MVIAddress sv
	LEFT JOIN #AddressParts ad
		ON sv.MVI_City = ad.City AND sv.MVI_State = ad.StateAbbrev AND MVI_Zip = ad.Zip

	DROP TABLE IF EXISTS #MVIAddress


	---------------------------------------------------------------------------------
	-- COMBINE EHR AND MVI DATA, STAGE AND PUBLISH
	---------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #StageMasterPatientVM
	SELECT mv.MVIPersonSID
		,PatientICN				= mv.MVIPersonICN
		
		
		,p.PhoneNumber
		,p.WorkPhoneNumber
		,p.CellPhoneNumber
		,p.TempPhoneNumber
		,p.NextOfKinPhone
		,p.NextOfKinPhone_Name
		,p.EmergencyPhone
		,p.EmergencyPhone_Name
		--For addresses, retain city/state/zip data when available but set street address to null when data does not appear to be a real address
		,StreetAddress1			= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN NULL
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.StreetAddress1 
									ELSE ma.MVI_StreetAddress1 END
		,StreetAddress2			= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN NULL
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.StreetAddress2 
									ELSE ma.MVI_StreetAddress2 END
		,StreetAddress3			= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN NULL
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.StreetAddress3 
									ELSE ma.MVI_StreetAddress3 END
		,City					= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN ma.MVI_City
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.City 
									ELSE ma.MVI_City END
		,State					= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 AND ma.MVI_State IS NOT NULL THEN ma.MVI_State
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.State 
									ELSE ma.MVI_State END
		,Zip					= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN ma.MVI_Zip
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.Zip 
									ELSE ma.MVI_Zip END
		,Country				= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN ma.MVI_Country
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.Country
									ELSE ma.MVI_Country END
		,AddressModifiedDateTime= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 THEN mv.PersonModifiedDateTime
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN mh.FieldModifiedDateTime
									ELSE mv.PersonModifiedDateTime END
		,County					= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 AND ma.MVI_County IS NOT NULL THEN ma.MVI_County
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.County
									ELSE ISNULL(ma.MVI_County,p.County) END
		,CountyFIPS				= CASE WHEN ma.InvalidFlag=1 AND p.InvalidAddress=1 AND ma.MVI_FIPSCode IS NOT NULL THEN ma.MVI_FIPSCode
									WHEN ma.InvalidFlag=1 OR (p.POBox=0 AND ma.POBox=1 AND p.InvalidAddress=0) THEN p.CountyFIPS
									ELSE ISNULL(ma.MVI_FIPSCode,p.CountyFIPS) END
		,HomeAddress = NULL
		,p.GISURH
		,p.TempStreetAddress1
		,p.TempStreetAddress2
		,p.TempStreetAddress3
		,p.TempCity
		,p.TempState AS TempStateAbbrev
		,p.TempZip AS TempPostalCode 
		,mt.FieldModifiedDateTime AS TempAddressModifiedDateTime
		,p.MailStreetAddress1
		,p.MailStreetAddress2
		,p.MailStreetAddress3
		,p.MailCity
		,p.MailState
		,p.MailZip
		,p.MailCountry
		,MailAddress = NULL
		,mm.FieldModifiedDateTime AS MailAddressModifiedDateTime
	INTO #StageMasterPatientVM
	FROM [SVeteran].[SMVIPerson] mv WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient_Patient] e
		ON mv.MVIPersonSID = e.MVIPersonSID
	LEFT JOIN #PivotMP p 
		ON p.MVIPersonSID = mv.MVIPersonSID
	LEFT JOIN #MVIAddress2 ma 
		ON ma.MVIPersonSID = mv.MVIPersonSID 
	LEFT JOIN #MaxAddress mh
		ON mv.MVIPersonSID = mh.MVIPersonSID AND mh.AddressType=1 --Home address
	LEFT JOIN #MaxAddress mt
		ON mv.MVIPersonSID = mt.MVIPersonSID AND mt.AddressType=2 --Temporary address
	LEFT JOIN #MaxAddress mm
		ON mv.MVIPersonSID = mm.MVIPersonSID AND mm.AddressType=3 --Mailing address
		
DROP TABLE IF EXISTS #PivotMP
DROP TABLE IF EXISTS #TempAddress
DROP TABLE IF EXISTS #MVIAddress2
DROP TABLE IF EXISTS #MaxAddress

UPDATE #StageMasterPatientVM
SET HomeAddress= CASE WHEN StreetAddress1 IS NOT NULL THEN 1
					WHEN City IS NOT NULL THEN 2
					ELSE 3 END
,MailAddress = CASE WHEN MailStreetAddress1 LIKE 'UNK%' OR MailStreetAddress1 LIKE '%UNKNOWN%' OR MailStreetAddress1 LIKE '%Incorrect%' 
						OR MailStreetAddress1 LIKE '%ADDRESS%'
						OR MailStreetAddress1 IN ('','0000','...','DECEASED','NONE')
						THEN 3
					WHEN MailStreetAddress1 IS NOT NULL THEN 1
					WHEN MailCity IS NOT NULL THEN 2
					ELSE 3 END
		
--If home address is missing, replace with mail address
UPDATE #StageMasterPatientVM
SET StreetAddress1=MailStreetAddress1
	,StreetAddress2=MailStreetAddress2
	,StreetAddress3=MailStreetAddress3
	,City=MailCity
	,State=MailState
	,Zip=MailZip
	,Country=MailCountry
WHERE (HomeAddress=3 AND MailAddress<=2)
	OR (HomeAddress=2 AND MailAddress=1)
			
UPDATE #StageMasterPatientVM
SET  City=MailCity
	,State=MailState
	,Zip=MailZip
	,Country=MailCountry
WHERE StreetAddress1 IS NULL AND City IS NULL AND State IS NULL AND Zip IS NULL

UPDATE #StageMasterPatientVM
SET State = b.StateCode
FROM #StageMasterPatientVM a
INNER JOIN Lookup.ZipState b ON a.Zip=b.ZipCode
WHERE a.State IS NULL

UPDATE #StageMasterPatientVM
SET State = c.StateAbbrev
FROM #StageMasterPatientVM a
INNER JOIN Config.FIPS_County b ON a.CountyFIPS=b.FIPS
INNER JOIN Dim.State c ON b.state_name=c.State
WHERE a.State IS NULL



 --Only retain legit state-county combos, otherwise mark county as null
DROP TABLE IF EXISTS #counties
SELECT DISTINCT st.StateAbbrev, ad.County,min(f.fips) as CountyFIPS
INTO #counties
FROM [Dim].[StateCounty] ad WITH (NOLOCK) 
INNER JOIN [Dim].[State] st WITH (NOLOCK) 
             ON st.StateSID = ad.StateSID
LEFT OUTER JOIN Config.FIPS_County as f on ad.County Collate SQL_Latin1_General_CP1253_CI_AI = f.county_name Collate SQL_Latin1_General_CP1253_CI_AI and f.state_name=State
WHERE County NOT LIKE '%ZZ%' AND StateAbbrev NOT LIKE 'ZZ%'
GROUP BY st.StateAbbrev, ad.County

UPDATE #StageMasterPatientVM
SET County=b.County
FROM #StageMasterPatientVM a
INNER JOIN #counties b ON a.CountyFIPS=b.CountyFIPS
WHERE a.CountyFIPS IS NOT NULL

UPDATE #StageMasterPatientVM
SET CountyFIPS=b.CountyFIPS
FROM #StageMasterPatientVM a
INNER JOIN #counties b ON a.County=b.County AND a.State=b.StateAbbrev
WHERE a.CountyFIPS IS NULL AND a.County IS NOT NULL

DROP TABLE IF EXISTS #StageMasterPatientVM2
SELECT DISTINCT a.MVIPersonSID
		,a.PatientICN			
		,a.PhoneNumber
		,a.WorkPhoneNumber
		,a.CellPhoneNumber
		,a.TempPhoneNumber
		,a.NextOfKinPhone
		,a.NextOfKinPhone_Name
		,a.EmergencyPhone
		,a.EmergencyPhone_Name
		,a.StreetAddress1		
		,a.StreetAddress2		
		,a.StreetAddress3		
		,a.City				
		,a.State			
		,Zip				
		,CASE WHEN a.Country IS NOT NULL AND a.Country NOT IN ('*Missing*','Unknown') THEN a.Country
			WHEN c.StateCode IS NOT NULL THEN 'UNITED STATES'
			ELSE d.Country END AS Country
		,b.County --only retain legit counties
		,ISNULL(b.CountyFIPS,a.CountyFIPS) AS CountyFIPS_All
		,b.CountyFIPS
		,a.GISURH
		,a.AddressModifiedDateTime
		,a.TempStreetAddress1
		,a.TempStreetAddress2
		,a.TempStreetAddress3
		,a.TempCity
		,a.TempStateAbbrev
		,a.TempPostalCode
		,CASE WHEN c2.StateCode IS NOT NULL THEN 'UNITED STATES'
			ELSE d2.Country END AS TempCountry
		,a.TempAddressModifiedDateTime
		,a.MailStreetAddress1
		,a.MailStreetAddress2
		,a.MailStreetAddress3
		,a.MailCity
		,a.MailState
		,a.MailZip
		,CASE WHEN c3.StateCode IS NOT NULL THEN 'UNITED STATES'
			ELSE d3.Country END AS MailCountry
		,a.MailAddressModifiedDateTime
	INTO #StageMasterPatientVM2
	FROM #StageMasterPatientVM a

	LEFT JOIN #counties b 
		on a.State=b.StateAbbrev and a.County=b.County
	LEFT JOIN Lookup.StateCountry c WITH (NOLOCK)
		ON a.State = c.StateCode AND c.Country = 'United States'
	LEFT JOIN Lookup.StateCountry d WITH (NOLOCK)
		ON a.State = d.CountryCode AND d.Country <> 'United States'
	LEFT JOIN Lookup.StateCountry c2 WITH (NOLOCK)
		ON a.TempStateAbbrev = c2.StateCode AND c2.Country = 'United States'
	LEFT JOIN Lookup.StateCountry d2 WITH (NOLOCK)
		ON a.TempStateAbbrev = d2.CountryCode AND d2.Country <> 'United States'
	LEFT JOIN Lookup.StateCountry c3 WITH (NOLOCK)
		ON a.MailState = c3.StateCode AND c3.Country = 'United States'
	LEFT JOIN Lookup.StateCountry d3 WITH (NOLOCK)
		ON a.MailState = d3.CountryCode AND d3.Country <> 'United States'	
		
UPDATE #StageMasterPatientVM2
SET CountyFIPS = c.CountyFIPS
	,County = c.County
FROM #StageMasterPatientVM2 a
INNER JOIN #AddressParts b ON a.State=b.StateAbbrev AND a.Zip=b.Zip AND a.City=b.City
INNER JOIN #counties c ON REPLACE(b.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI =REPLACE(c.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI AND b.StateAbbrev=c.StateAbbrev
WHERE a.CountyFIPS IS NULL AND a.County IS NULL

UPDATE #StageMasterPatientVM2
SET CountyFIPS = c.CountyFIPS
	,County = c.County
FROM #StageMasterPatientVM2 a
INNER JOIN #AddressParts b ON a.TempStateAbbrev=b.StateAbbrev AND a.TempPostalCode=b.Zip AND a.TempCity=b.City
INNER JOIN #counties c ON REPLACE(b.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI =REPLACE(c.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI AND b.StateAbbrev=c.StateAbbrev
WHERE a.CountyFIPS IS NULL AND a.County IS NULL and a.StreetAddress1 IS NULL

UPDATE #StageMasterPatientVM2
SET CountyFIPS = c.CountyFIPS
	,County = c.County
FROM #StageMasterPatientVM2 a
INNER JOIN #AddressParts b ON a.MailState=b.StateAbbrev AND a.MailZip=b.Zip AND a.MailCity=b.City
INNER JOIN #counties c ON REPLACE(b.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI =REPLACE(c.County,' ','') Collate SQL_Latin1_General_CP1253_CI_AI AND b.StateAbbrev=c.StateAbbrev
WHERE a.CountyFIPS IS NULL AND a.County IS NULL and a.StreetAddress1 IS NULL

--Add countyFIPS from CDW data if no matching FIPS in config file exists
UPDATE #StageMasterPatientVM2
SET CountyFIPS=CountyFIPS_All
WHERE CountyFIPS IS NULL AND CountyFIPS_All IS NOT NULL

UPDATE #StageMasterPatientVM2
SET Country='PHILIPPINES'
	,State=NULL
WHERE State='PH'

DROP TABLE IF EXISTS #StageMasterPatientVM
DROP TABLE IF EXISTS #counties
/*********************************************************************************************************************
Prevent table from updating if the patient count is lower than it was the last time it was published.
Row counts generally increase by a few hundred to a few thousand each run due to new enrollees, etc.
Patient population (combined current and historic) should not shrink. Decreases likely mean incomplete data at run time.
**********************************************************************************************************************/

DECLARE @LastRunCount BIGINT = (SELECT COUNT_BIG(*) FROM [Common].[MasterPatient_Contact] WITH (NOLOCK))
DECLARE @CurrentCount BIGINT = (SELECT COUNT_BIG(*) FROM #StageMasterPatientVM2)

IF	@CurrentCount < @LastRunCount
	
BEGIN 
	DECLARE @ErrorMsg2 varchar(500)= 'Row count insufficient to proceed with Code.Common_MasterPatient_Contact'
	EXEC [Log].[Message] 'Error','Row Counts',@ErrorMsg2
	EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error
	PRINT @ErrorMsg2;
	THROW 51000,@ErrorMsg2,1
END


	EXEC [Maintenance].[PublishTable] 'Common.MasterPatient_Contact','#StageMasterPatientVM2'


	
	DROP TABLE IF EXISTS #StageMasterPatientVM2

	EXEC [Log].[ExecutionEnd]

END