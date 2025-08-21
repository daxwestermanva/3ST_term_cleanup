-- =============================================
-- Author:		Liam Mina
-- Create date: 10/16/2024
-- Description:	Contact information for patient lookup report; formerly included in App.MBC_Patient_LSV
-- Modifications:

-- Sample execution:
--		EXEC [App].[MBC_Patient_LSV_v02] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009044641'
--		EXEC [App].[MBC_Patient_LSV_v02] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009044641'
-- =============================================
CREATE PROCEDURE [App].[MBC_PatientContact_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
) 
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = '1002058830'
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = '1010769033'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	
	SELECT 
		  ad.PatientICN
		  ,ad.MVIPersonSID
		  ,ad.StreetAddress1
		  ,ad.StreetAddress2
		  ,ad.StreetAddress3
		  ,ad.City
		  ,ad.State as StateAbbrev
		  ,ad.Zip AS PostalCode
		  ,ad.Country
		  ,ad.AddressModifiedDateTime
		  ,ad.TempStreetAddress1
		  ,ad.TempStreetAddress2
		  ,ad.TempStreetAddress3
		  ,ad.TempCity
		  ,ad.TempStateAbbrev
		  ,ad.TempPostalCode
		  ,ad.TempCountry
		  ,ad.TempAddressModifiedDateTime
		  ,ad.MailStreetAddress1
		  ,ad.MailStreetAddress2
		  ,ad.MailStreetAddress3
		  ,ad.MailCity
		  ,ad.MailState AS MailStateAbbrev
		  ,ad.MailZip AS MailPostalCode
		  ,ad.MailCountry
		  ,ad.MailAddressModifiedDateTime
		  ,ad.PhoneNumber
		  ,ad.WorkPhoneNumber
		  ,ad.CellPhoneNumber
		  ,ad.TempPhoneNumber
		  ,ad.NextOfKinPhone
		  ,ad.NextOfKinPhone_Name
		  ,ad.EmergencyPhone
		  ,ad.EmergencyPhone_Name
	FROM [Common].[MasterPatient_Contact] ad WITH(NOLOCK)
	WHERE ad.PatientICN = @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		 
END