


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2024-07-06
-- Description:	
-- Modifications:

   ============================================= */
CREATE PROCEDURE [App].[VCL_CaringLettersDetails]
	@User varchar(50),
	@MVIPersonSID int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @MVIPersonSID int; SET @User = 'vha21\vhapalminal'; SET @MVIPersonSID = 54098552

--Users who can access report - check for national access
--Traditional row-level security does not work because not all patients have an associated station that we can check permissions against
DROP TABLE IF EXISTS #ReportUsers
SELECT UserName 
INTO #ReportUsers
FROM [Config].[WritebackUsersToOmit] WITH (NOLOCK) WHERE UserName LIKE 'vha21\vhapal%'
UNION
SELECT NetworkId 
FROM [Config].[ReportUsers] WITH (NOLOCK) WHERE Project = 'VCL Caring Letters'

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
FROM [CaringLetters].[VCL_Mailings] a WITH (NOLOCK)
WHERE ActiveRecord=1
AND a.MVIPersonSID=@MVIPersonSID

SELECT DISTINCT 
	a.VCL_ID
	,a.MVIPersonSID
	,PreferredNameParam = d.PreferredName 
	,OptOutParam = d.DoNotSend 
	,OptOutParamReason = CASE WHEN d.DoNotSendReason IS NULL THEN 'N/A' ELSE d.DoNotSendReason END
	,Address1Param = d.StreetAddress1
	,Address2Param = ISNULL(d.StreetAddress2,'')
	,Address3Param = ISNULL(d.StreetAddress3,'')
	,CityParam = d.City
	,StateParam = d.State
	,ZipParam = d.Zip
	,CountryParam = d.Country
	,FullNameParam = CASE WHEN d.PreferredName=1 THEN d.FullNamePreferred ELSE d.FullNameLegal END
	,FirstNameParam = CASE WHEN d.PreferredName=1 THEN d.FirstNamePreferred ELSE d.FirstNameLegal END
	,b.DoNotSend AS CurrentDoNotSend
	,b.DoNotSendReason AS CurrentDoNotSendReason
	,b.DoNotSendDate AS CurrentDoNotSendDate
FROM [CaringLetters].[VCL_Mailings] a  WITH (NOLOCK)
INNER JOIN [CaringLetters].[VCL_Cohort] b  WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID AND b.FirstLetterDate IS NOT NULL 
	AND a.VCL_ID = b.VCL_ID
INNER JOIN #CheckPermissions c
	ON c.UserName=@User
INNER JOIN #DefaultParam d
	ON a.MVIPersonSID=d.MVIPersonSID
	AND a.VCL_ID = d.VCL_ID
WHERE a.MVIPersonSID=@MVIPersonSID


  ;

END