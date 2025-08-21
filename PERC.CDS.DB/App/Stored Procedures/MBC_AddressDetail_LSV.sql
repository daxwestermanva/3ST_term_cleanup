
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <10/06/2021>
-- Description:	List of all patient addresses - used in CRISTAL subreport 
-- Updates
--	2022/06/07	- JEB	- Hotfix to address Enclave sources using App signing module notworking 
 
-- EXEC [App].[MBC_AddressDetail_LSV] @User = 'vha21\vhapalminal'	, @Patient = '1001092794'
-- EXEC [App].[MBC_AddressDetail_LSV] @User = 'vha21\vhapalminal'	, @Patient = '1011018504'
-- =============================================
CREATE PROCEDURE [App].[MBC_AddressDetail_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;
 
	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'	; SET @Patient = '1017875666'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'	; SET @Patient = '1019348032'
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	SELECT DISTINCT a.PatientICN
		,Source='V'
		,s.NameOfContact
		,s.RelationshipToPatient
		,s.AddressType
		,s.StreetAddress1
		,s.StreetAddress2
		,s.StreetAddress3
		,s.City
		,s.State
		,LEFT(s.Zip4,5) AS Zip
		,s.Country
		,s.BadAddressIndicator
		,CASE WHEN OrdinalNumber IN (1,4,9,13,14) THEN CAST(s.AddressChangeDateTime AS date) 
			ELSE CAST(max(s.AddressChangeDateTime) OVER (Partition by s.NameOfContact, s.AddressType, s.StreetAddress1) as date) 
			END AS AddressChangeDateTime
		,CONVERT(varchar,s.AddressStartDateTime,101) AS AddressStartDateTime
		,CONVERT(varchar,s.AddressEndDateTime,101) AS AddressEndDateTime
		,CASE WHEN OrdinalNumber IN (1,4,9,13,14) THEN 1 ELSE 0 END AS Patient
		,MPI = 0
	FROM  [SPatient].[SPatientAddress] AS s WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] AS a WITH (NOLOCK)
		ON a.PatientPersonSID=s.PatientSID
	WHERE a.PatientICN = @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		AND (s.StreetAddress1 IS NOT NULL OR s.City IS NOT NULL)
		--AND OrdinalNumber IN (1,4,9,13,14) --Legal Residence, Temporary, Employer, Patient, Residence
		AND (s.AddressEndDateTime IS NULL OR s.AddressEndDateTime>=getdate())
	UNION ALL
		SELECT DISTINCT a.PatientICN
		,Source='C'
		,s.ContactName
		,RelationshipToPatient='Self'
		,s.AddressType
		,s.StreetAddress
		,s.StreetAddress2
		,s.StreetAddress3
		,s.CityName
		,s.State
		,LEFT(s.ZipCode,5) AS ZipCode
		,s.Country
		,BadAddressIndicator=NULL
		,CAST(s.ModifiedDateTime AS date)
		,CONVERT(varchar,s.BeginEffectiveDateTime,101)
		,CONVERT(varchar,s.EndEffectiveDateTime,101)
		,Patient = 1 --currently no related persons in this query
		,MPI = 0
	FROM  [SVeteranMill].[SPersonAddress]  AS s WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] AS a WITH (NOLOCK)
		ON a.PatientPersonSID=s.PersonSID
	WHERE a.PatientICN = @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		AND (s.StreetAddress IS NOT NULL OR s.City IS NOT NULL)
		AND s.AddressType NOT IN ('E-mail','Birth')
		AND (s.EndEffectiveDateTime IS NULL OR s.EndEffectiveDateTime>=getdate())
		AND s.ActiveIndicator = 1
	UNION ALL
		SELECT DISTINCT s.MVIPersonICN
		,Source=NULL
		,NameOfContact=NULL
		,RelationshipToPatient='Self'
		,AddressType = NULL
		,s.StreetAddress1
		,s.StreetAddress2
		,s.StreetAddress3
		,s.City
		,st.StateAbbrev
		,s.Zip4
		,c.CountryDescription
		,BadAddressIndicator=NULL
		,CAST(s.PersonModifiedDateTime AS date)
		,NULL
		,NULL
		,Patient = 1 --currently no related persons in this query
		,MPI = 1
	FROM  [SVeteran].[SMVIPerson]  AS s WITH (NOLOCK)
	LEFT JOIN [NDim].[MVIState] st WITH (NOLOCK) 
		ON st.MVIStateSID = s.MVIStateSID
	LEFT JOIN [NDim].[MVICountryCode] c WITH (NOLOCK)
		ON s.MVICountrySID = c.MVICountryCodeSID
	WHERE s.MVIPersonICN = @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)

 
END