


/* =============================================
-- Author: Liam Mina		 
-- Create date: 2023-03-23
-- Description:	
-- Modifications:

   ============================================= */
CREATE PROCEDURE [App].[PRF_HRS_CaringLettersDetails]
	@User varchar(50),
	@MVIPersonSID int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @MVIPersonSID int; SET @User = 'vha21\vhapalminal'; SET @MVIPersonSID = 39038601


DROP TABLE IF EXISTS #DefaultParam
SELECT * 
INTO #DefaultParam
FROM [CaringLetters].[HRF_Mailings] a WITH (NOLOCK)
WHERE ActiveRecord=1
AND a.MVIPersonSID=@MVIPersonSID

SELECT a.MVIPersonSID
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
FROM [CaringLetters].[HRF_Mailings] a  WITH (NOLOCK)
INNER JOIN [CaringLetters].[HRF_Cohort] b  WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID AND b.FirstLetterDate IS NOT NULL
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) AS Access 
	ON LEFT(b.OwnerChecklistID,3) = Access.sta3n
INNER JOIN #DefaultParam d
	ON a.MVIPersonSID=d.MVIPersonSID
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit]  WITH (NOLOCK) WHERE UserName LIKE 'vha21\vhapal%') AS e 
	ON @User=e.UserName
WHERE @MVIPersonSID = a.MVIPersonSID
 AND (e.UserName IS NOT NULL OR @User IN 
  (select NetworkId from [Config].[ReportUsers]  WITH (NOLOCK) where project = 'HRF Caring Letters'))

  ;

END