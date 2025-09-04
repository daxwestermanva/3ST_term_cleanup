
-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/26/2021
-- Description:	Updated writeback SP for Patient Table
-- =============================================
CREATE PROCEDURE [App].[PDSI_Writeback_PatientData]
	-- Add the parameters for the stored procedure here

	@MVIPersonSID INT
	,@Sta3n SMALLINT


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT a.*
	  ,@Sta3n as Sta3n
	  ,mp.PatientName
	  ,mp.LastFour
	  ,mp.Age
	  ,mp.Gender
FROM PDSI.PatientDetails a
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID=a.MVIPersonSID
WHERE a.MVIPersonSID = @MVIPersonSID


END