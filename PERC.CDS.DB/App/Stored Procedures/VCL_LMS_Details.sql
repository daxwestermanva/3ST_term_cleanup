


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2025-07-06
-- Description:	
-- Modifications:

   ============================================= */
CREATE PROCEDURE [App].[VCL_LMS_Details]
	@User varchar(50),
	@VCL_ID int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @VCL_ID int; SET @User = 'vha21\vhapalminal'; SET @VCL_ID=1

--Users who can access report - check for national access
--Traditional row-level security does not work because not all patients have an associated station that we can check permissions against
DROP TABLE IF EXISTS #ReportUsers
SELECT UserName 
INTO #ReportUsers
FROM [Config].[WritebackUsersToOmit] WITH (NOLOCK) WHERE UserName LIKE 'vha21\vhapal%'
UNION
SELECT NetworkId 
FROM [Config].[ReportUsers] WITH (NOLOCK) WHERE Project = 'VCL LMS'

DROP TABLE IF EXISTS #CheckPermissions
SELECT UserName, CASE WHEN COUNT(b.Sta3n)=130 THEN 1 ELSE 0 END AS NationalPermission 
INTO #CheckPermissions
FROM #ReportUsers a
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) AS b
	ON a.UserName = @User
GROUP BY UserName

DELETE FROM #CheckPermissions WHERE NationalPermission=0

DROP TABLE IF EXISTS #DefaultParam
SELECT * 
INTO #DefaultParam
FROM [CaringLetters].[VCL_LMS_Cohort] a WITH (NOLOCK)
WHERE a.VCL_ID=@VCL_ID

SELECT DISTINCT 
	a.VCL_ID
	,a.MVIPersonSID
	,OptOutParam = d.DoNotSend 
	,AddressParam = UPPER(d.StreetAddress)
	,CityParam = UPPER(d.City)
	,StateParam = UPPER(d.State)
	,ZipParam = d.Zip
	,CountryParam = UPPER(d.Country)
	,FullNameParam = UPPER(d.FullName)
	,FirstNameParam = d.FirstName
	,a.DoNotSend AS CurrentDoNotSend
	,a.GunlockQuantity
FROM [CaringLetters].[VCL_LMS_Cohort] a  WITH (NOLOCK)
INNER JOIN #CheckPermissions c
	ON c.UserName=@User
INNER JOIN #DefaultParam d
	ON a.VCL_ID = d.VCL_ID
WHERE a.VCL_ID=@VCL_ID


  ;

END