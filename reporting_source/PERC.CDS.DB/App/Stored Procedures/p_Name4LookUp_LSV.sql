
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	Create a patient parameter using SSN,ICN,or NameLast4 and based on User's permissions
--				Used in CRISTAL and STORM lookups (2018-05-11)
--	2019-01-02:	Jason Bacani - Ensured both parts of the IF-THEN-ELSE clause return the same number of attributes; cleaned up code
--  2019-02-15: Liam Mina - Updated domain name @User logic to allow for domain names longer than 7 characters (e.g., VHAMASTER)
--  2019-06-12: Liam Mina - Updated to reflect practice of allowing users with permissions at any station to be able to look up any patient. Removed INNER JOIN to App.Access and replaced with 'and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)' in final where clause. 
--	2020-09-16:	Liam Mina - Pointed to _VM tables
--  2020-09-21: RAS - Changed StationAssignments to SPatient table
--	2020-12-30:	LM - Added patients who are not in SPatient (this has been requested multiple times and does not appear to affect performance.  I've made changes on the CRISTAL report to prioritize display of patients who are in SPatient when using NameFour lookup)
--	2021-02-02: LM - Added patients deceased in past 31 days to CRISTAL to facilitate chart review
--  2021-05-18: JEB - Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
--	2021-10-08:	LM - Changed reference from SStaff.SStaff to CRISTAL.SStaff (CDS table) for better performance
--	2022-05-20:	LM - Added EDIPI
--	2024-01-11:	LM - Allow CRISTAL lookups for deceased patients on full SSN
--	2024-04-04:	LM - Allow CRISTAL lookups by full name
--
-- Sample execution calls
-- EXEC [App].[p_Name4LookUp_LSV] @User='vha21\vhapalstephr6',@PatientType='PatientSSN',@PatientName='Enter SSN Here' 
-- EXEC [App].[p_Name4LookUp_LSV] @User='vha21\vhapalstephr6',@PatientType='PatientSSN',@PatientName='Enter SSN Here' 
-- EXEC [App].[p_Name4LookUp_LSV] @User='VHAMASTER\VHAISBBACANJ',@PatientType='PatientSSN',@PatientName='Enter SSN Here'
-- =============================================
CREATE PROCEDURE [App].[p_Name4LookUp_LSV]
(
  @User VARCHAR(MAX),
  @PatientName VARCHAR(100),
  @PatientType VARCHAR(100),
  @Report varchar(100)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @PatientName VARCHAR(100), @PatientType VARCHAR(100), @Report VARCHAR(100); SET @User='vha21\vhapalminal'; SET @PatientType='NameFour'; SET @PatientName='B6294' ; SET @Report='CRISTAL'
	--DECLARE @User VARCHAR(MAX), @PatientName VARCHAR(100), @PatientType VARCHAR(100), @Report VARCHAR(100); SET @User='vha21\vhapalstephr6'; SET @PatientType='PatientSSN'; SET @PatientName='' ; SET @Report='STORM'
	--DECLARE @User VARCHAR(MAX), @PatientName VARCHAR(100), @PatientType VARCHAR(100), @Report VARCHAR(100); SET @User='VHAMASTER\VHAISBBACANJ'; SET @PatientType='FullName'; SET @PatientName=''; SET @Report='CRISTAL';

	--Get correct permissions using INNER JOIN [App].[Access]. The below use-case is an exception.
	--For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
SELECT DISTINCT PatientSSN
		,PatientName
		,PatientICN
		,NameFour
		,DateOfBirth
		,PhoneNumber
		,CellPhoneNumber
		,StreetAddress
		,City
		,State
		,Zip
		,EDIPI
		,SensitiveFlag
		,RecentPatient
		,Deceased
		,CASE --don't allow users to view own data or view sensitive records without proper user name
			WHEN c.PatientSSN = UserSSN  THEN ' -- Security regulations prohibit computer access to your own medical record.'
			WHEN b.NetworkUsername IS NULL AND c.SensitiveFlag = 1 THEN ' -- Your NetworkUserName is missing from the NEW PERSON file. A valid user name is required to view sensitive patient records.  Contact your ADP Coordinator, or follow instructions <a href="https://dvagov.sharepoint.com/sites/VHAPERC/PEC_Portal/SitePages/NetworkName.aspx">Here</a>'
			WHEN c.EHR=0 THEN 'Person does not have a VA EHR record. Drill-through to CRISTAL is unavailable'
			ELSE NULL
			END AS Error
		,CASE --variable used in report for visibility of error messages
			WHEN c.PatientSSN = b.UserSSN THEN 1
			WHEN b.NetworkUsername IS NULL AND c.SensitiveFlag = 1 THEN 1
			WHEN c.EHR=0 THEN 1
			ELSE 0
			END AS ThrowError
	FROM (
	SELECT 
		c.PatientSSN
		,c.PatientName
		,c.PatientICN
		,c.NameFour
		,c.DateOfBirth
		,c.PhoneNumber
		,c.CellPhoneNumber
		,CASE WHEN c.StreetAddress3 IS NOT NULL THEN CONCAT(c.StreetAddress1,', ',c.StreetAddress2,', ',c.StreetAddress3)
			WHEN c.StreetAddress2 IS NOT NULL THEN CONCAT(c.StreetAddress1,', ',c.StreetAddress2)
			ELSE c.StreetAddress1 END AS StreetAddress
		,c.City
		,c.State
		,c.Zip
		,c.EDIPI
		,CASE WHEN c.SensitiveFlag=1 THEN 'Y' ELSE 'N' END AS SensitiveFlag
		,EHR=1
		,CASE WHEN a.MVIPersonSID IS NULL THEN 0 ELSE 1 END AS RecentPatient
		,CASE WHEN c.DateOfDeath_Combined IS NOT NULL THEN 1 ELSE 0 END AS Deceased
	FROM [Common].[MasterPatient] AS c WITH (NOLOCK)
	LEFT JOIN [Present].[SPatient] AS a WITH(NOLOCK) ON c.MVIPersonSID=a.MVIPersonSID
	WHERE (
			(@PatientType = 'PatientSSN' AND c.PatientSSN = CAST(REPLACE(@PatientName, '-', '') AS VARCHAR(100))			)
			OR (@PatientType = 'PatientICN'	AND CONVERT(VARCHAR(100), c.PatientICN) = @PatientName)
			OR (@PatientType = 'NameFour'	AND c.NameFour = @PatientName)
			OR (@PatientType = 'EDIPI' AND c.EDIPI = @PatientName)
			OR (@PatientType = 'FullName' AND @PatientName = CONCAT(c.LastName,',',c.FirstName))
			OR (@PatientType = 'FullName' AND @PatientName = CONCAT(c.LastName,', ',c.FirstName))
		)
		AND ((@Report='STORM' AND c.DateOfDeath_Combined IS NULL)
			OR (@Report='CRISTAL' AND (c.DateOfDeath_Combined IS NULL OR c.DateOfDeath_Combined>=DateAdd(day,-31,getdate()) OR @PatientType NOT IN ('NameFour','FullName'))))
	UNION ALL
	SELECT 
		c.PatientSSN
		,c.PatientName
		,c.PatientICN
		,c.NameFour
		,c.DateOfBirth
		,c.PhoneNumber
		,c.CellPhoneNumber
		,c.StreetAddress
		,c.City
		,c.State
		,c.Zip
		,c.EDIPI
		,SensitiveFlag='N'
		,EHR=0
		,RecentPatient=0
		,Deceased=0
	FROM [Common].[MVIPerson_NoEHR] AS c WITH (NOLOCK) 
	WHERE (
			(@PatientType = 'PatientSSN' AND c.PatientSSN = CAST(REPLACE(@PatientName, '-', '') AS VARCHAR(100)))
		)
		AND @Report='CRISTAL' 
	) c
	
	LEFT JOIN 
		(
			SELECT 
				s.StaffSSN AS UserSSN  
				,s.NetworkUsername
			FROM [Present].[SStaff] AS s WITH (NOLOCK)
			WHERE s.NetworkUsername = SUBSTRING(@User, CHARINDEX('\', @User) + 1, 100)
		) AS b 
		ON 1 = 1
	WHERE EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		
	OPTION (Recompile) 

END
GO

