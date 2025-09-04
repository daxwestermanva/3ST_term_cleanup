

/*=============================================
-- Author:		Liam Mina
-- Create date: 2021-08-12
-- Description:	Local address for HRF patients
-- Modifications:
-- 20210914 BTW: Enclave Refactoring - Counts Confirmed.
-- 20210917 JEB: Enclave Refactoring - Refactored comment
-- 20220607	LM:  For patients who don't have an address at the station where their flag is owned - use address from Common.MasterPatient
-- 20220815 SAA_JJR: Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data
-- 20230215	LM:	 Update to get address for living patients with any history of HRF, not just those with flags that are currently active or inactivated in past year

Testing Execution - EXECUTE [Code].[PRF_HRS_PatientAddress]
  =============================================*/
CREATE   PROCEDURE [Code].[PRF_HRS_PatientAddress]
AS
BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_HRS_PatientAddress', @Description = 'Execution of Code.PRF_HRS_PatientAddress SP'

DROP TABLE IF EXISTS #Cohort
SELECT a.MVIPersonSID, OwnerChecklistID
INTO #Cohort
FROM [OMHSP_Standard].[PRF_HRS_CompleteHistory] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) ON a.MVIPersonSID = b.MVIPersonSID
WHERE b.DateOfDeath_Combined IS NULL
UNION 
SELECT a.MVIPersonSID, a.OwnerChecklistID --to get addresses for patients with VistA/Cerner flag discrepancies where there is no VistA flag record
FROM [PRF_HRS].[PatientReport_v02] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) ON a.MVIPersonSID = b.MVIPersonSID

DROP TABLE IF EXISTS #AddressVistA
SELECT TOP 1 WITH TIES
	c.MVIPersonSID
	,ad.StreetAddress1
	,ad.StreetAddress2
	,ad.StreetAddress3
	,ad.City
	,st.StateAbbrev AS State
	,ad.Zip
	,CASE WHEN co.PostalName='<NULL>' THEN co.PostalDescription ELSE co.PostalName END AS Country
	,CASE WHEN ad.StreetAddress1 IS NOT NULL AND ad.City IS NOT NULL AND (ad.Zip IS NOT NULL OR ad.Country IS NOT NULL) THEN 1 ELSE 0 END AS FullAddress
INTO #AddressVistA
FROM #Cohort c
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON c.MVIPersonSID = mvi.MVIPersonSID
INNER JOIN [SPatient].[SPatientAddress] ad WITH(NOLOCK) ON mvi.PatientPersonSID =ad.PatientSID AND LEFT(c.OwnerChecklistID,3)=ad.Sta3n
INNER JOIN [Dim].[State] st WITH(NOLOCK) ON st.StateSID=ad.StateSID
LEFT JOIN [Dim].[Country] co WITH (NOLOCK) ON ad.CountrySID=co.CountrySID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) ON c.OwnerChecklistID = ch.ChecklistID
LEFT JOIN [Lookup].[ChecklistID] cer WITH(NOLOCK) ON ch.StaPa=cer.StaPa AND cer.IOCDate<getdate()
WHERE OrdinalNumber=13 
	AND StreetAddress1 NOT LIKE '%HOMELESS%'  
	AND StreetAddress1 NOT LIKE '%ADDRESS%'  
	AND StreetAddress1 NOT LIKE '%WILL UPDATE%'  
	AND StreetAddress1 NOT LIKE '%UNKNOWN%'  
	AND StreetAddress1 NOT LIKE '%NONE' AND StreetAddress1 NOT LIKE '%NONE*%' AND StreetAddress1 NOT LIKE '%NONE %' AND StreetAddress1 NOT LIKE '%NONE,%' 
AND cer.StaPa IS NULL
ORDER BY ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY ad.AddressChangeDateTime DESC)

DROP TABLE IF EXISTS #AddressMill
SELECT TOP 1 WITH TIES  
	c.MVIPersonSID
	,CASE WHEN ad.Mail_StreetAddress IS NULL AND ad.DerivedMail_City IS NULL THEN ad.Home_StreetAddress ELSE ad.Mail_StreetAddress END AS StreetAddress1
	,CASE WHEN ad.Mail_StreetAddress IS NULL AND ad.DerivedMail_City IS NULL THEN ad.Home_StreetAddress2 ELSE ad.Mail_StreetAddress2 END AS StreetAddress2
	,StreetAddress3=CAST(NULL as varchar)
	,CASE WHEN ad.Mail_StreetAddress IS NULL AND ad.DerivedMail_City IS NULL THEN ad.DerivedHome_City ELSE ad.DerivedMail_City END AS City
	,CASE WHEN ad.Mail_StreetAddress IS NULL AND ad.DerivedMail_City IS NULL THEN ad.DerivedHome_State ELSE ad.DerivedMail_State END AS State
	,CASE WHEN ad.Mail_StreetAddress IS NULL AND ad.DerivedMail_City IS NULL THEN LEFT(ad.Home_ZipCode,5) ELSE LEFT(ad.Mail_ZipCode,5) END AS Zip
	,Country=CAST(NULL as varchar)
	,CASE WHEN (ad.Mail_StreetAddress IS NOT NULL AND ad.DerivedMail_City IS NOT NULL AND ad.Mail_ZipCode IS NOT NULL)
		OR (ad.Home_StreetAddress IS NOT NULL AND ad.DerivedHome_City IS NOT NULL AND ad.Home_ZipCode IS NOT NULL) THEN 1 ELSE 0 END AS FullAddress
INTO #AddressMill
FROM #Cohort c
INNER JOIN [Cerner].[FactPatientContactInfo] ad WITH(NOLOCK) ON c.MVIPersonSID=ad.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) ON c.OwnerChecklistID = ch.ChecklistID
INNER JOIN [Lookup].[ChecklistID] cer WITH(NOLOCK) ON ch.StaPa=cer.STAPA AND cer.IOCDate<getdate()
ORDER BY ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY ISNULL(ad.Mail_ModifiedDateTime, ad.Home_ModifiedDateTime) DESC)

DROP TABLE IF EXISTS #Address
SELECT * 
INTO #Address
FROM #AddressVistA
UNION ALL
SELECT * FROM #AddressMill

UPDATE #Address
SET Country = 'United States'
FROM #Address a
INNER JOIN [Dim].[State] b ON a.State=b.StateAbbrev
WHERE TRY_CAST(b.VAStateCode as int) BETWEEN 01 AND 56 

DROP TABLE IF EXISTS #TempAddress
SELECT c.MVIPersonSID
	,ad.StreetAddress1
	,ad.StreetAddress2
	,ad.StreetAddress3
	,ad.City
	,st.StateAbbrev AS State
	,ad.Zip
	,CASE WHEN co.PostalName='<NULL>' THEN co.PostalDescription ELSE co.PostalName END AS Country
	,CASE WHEN ad.StreetAddress1 IS NOT NULL AND ad.City IS NOT NULL AND (ad.Zip IS NOT NULL OR ad.Country IS NOT NULL) THEN 1 ELSE 0 END AS FullAddress
INTO #TempAddress
FROM #Cohort c
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON c.MVIPersonSID = mvi.MVIPersonSID
INNER JOIN [SPatient].[SPatientAddress] ad WITH(NOLOCK) ON mvi.PatientPersonSID =ad.PatientSID AND LEFT(c.OwnerChecklistID,3)=ad.Sta3n
INNER JOIN [Dim].[State] st WITH(NOLOCK) ON st.StateSID=ad.StateSID
LEFT JOIN [Dim].[Country] co WITH (NOLOCK) ON ad.CountrySID = co.CountrySID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) ON c.OwnerChecklistID = ch.ChecklistID AND ch.IOCDate>getdate()
WHERE OrdinalNumber=4 
AND (ad.AddressStartDateTime BETWEEN CAST(CAST(GETDATE() AS DATE) AS DATETIME2) AND CAST(CAST(GETDATE() AS DATE) AS DATETIME2)
	OR (ad.AddressStartDateTime <= CAST(CAST(GETDATE() AS DATE) AS DATETIME2) AND ad.AddressEndDateTime IS NULL))

UPDATE #TempAddress
SET Country = 'United States'
FROM #TempAddress a
INNER JOIN [Dim].[State] b ON a.State=b.StateAbbrev
WHERE TRY_CAST(b.VAStateCode as int) BETWEEN 01 AND 56 


--need to look into temp addresses from Cerner; currently in CCLPatientAddress but I think those tables are being phased out soon?

DROP TABLE IF EXISTS #Final
SELECT DISTINCT c.MVIPersonSID
	,c.OwnerChecklistID
	,CASE WHEN t.FullAddress=1 THEN t.StreetAddress1 ELSE ad.StreetAddress1 END AS StreetAddress1
	,CASE WHEN t.FullAddress=1 THEN t.StreetAddress2 ELSE ad.StreetAddress2 END AS StreetAddress2
	,CASE WHEN t.FullAddress=1 THEN t.StreetAddress3 ELSE ad.StreetAddress3 END AS StreetAddress3
	,CASE WHEN t.FullAddress=1 THEN t.City ELSE ad.City END AS City
	,CASE WHEN t.FullAddress=1 THEN t.State ELSE ad.State END AS State
	,CASE WHEN t.FullAddress=1 THEN LEFT(t.Zip,5) ELSE LEFT(ad.Zip,5) END AS Zip
	,CASE WHEN t.FullAddress=1 THEN t.Country ELSE ad.Country END AS Country
	,CASE WHEN t.FullAddress=1 THEN 1 ELSE 0 END AS TempAddress
INTO #Final
FROM #Cohort c
LEFT JOIN #Address ad ON c.MVIPersonSID=ad.MVIPersonSID
LEFT JOIN #TempAddress t ON c.MVIPersonSID=t.MVIPersonSID --AND t.FullAddress=1
WHERE ad.FullAddress=1 OR t.FullAddress=1

--For patients who don't have an address at the station where their flag is owned - use address from Common.MasterPatient
DROP TABLE IF EXISTS #CommonAddress
SELECT DISTINCT b.MVIPersonSID
	,b.OwnerChecklistID
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempStreetAddress1 ELSE a.StreetAddress1 END AS StreetAddress1
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempStreetAddress2 ELSE a.StreetAddress2 END AS StreetAddress2
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempStreetAddress3 ELSE a.StreetAddress3 END AS StreetAddress3
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempCity ELSE a.City END AS City
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempStateAbbrev ELSE a.State END AS State
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN LEFT(a.TempPostalCode,5) ELSE LEFT(a.Zip,5) END AS Zip
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN a.TempCountry ELSE a.Country END AS Country
	,CASE WHEN a.TempStreetAddress1 IS NOT NULL AND a.TempCity IS NOT NULL AND a.TempPostalCode IS NOT NULL 
		THEN 1 ELSE 0 END AS TempAddress
INTO #CommonAddress
FROM [Common].[MasterPatient] a WITH (NOLOCK)
INNER JOIN #Cohort b on a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN #Final c on a.MVIPersonSID=c.MVIPersonSID
WHERE c.MVIPersonSID IS NULL

UPDATE #CommonAddress
SET Country = 'United States'
FROM #CommonAddress a
INNER JOIN [Dim].[State] b ON a.State=b.StateAbbrev
WHERE a.Country IS NULL 
AND TRY_CAST(b.VAStateCode as int) BETWEEN 01 AND 56 --US States
	OR TRY_CAST(b.VAStateCode as int) IN (60,66,69,72,74,78) --US Territories

INSERT INTO #Final
SELECT * FROM #CommonAddress


EXEC [Maintenance].[PublishTable] 'PRF_HRS.PatientAddress', '#final'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'


END