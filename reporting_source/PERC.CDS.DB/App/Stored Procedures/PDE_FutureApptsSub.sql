/* =============================================
-- Author: Elena Cherkasova		 
-- Create date: 2024-10-25
-- Description:	Future appointments dataset for post discharge engagement dashboard subreport

 EXEC [App].[PDE_FutureApptsSub] 
    @MVIPersonSID=''
   ,@DisDay=''
   ============================================= */
CREATE PROCEDURE [App].[PDE_FutureApptsSub]

  @MVIPersonSID INT
 ,@DisDay date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT ra.*
		,mp.PatientName
		,mp.LastFour
		,mp.EDIPI
		,CAST(mp.DateOfBirth AS DATE) as DateOfBirth
FROM [PDE_Daily].[FutureAppts] as ra WITH (NOLOCK)
LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
	ON mp.MVIPersonSID=ra.MVIPersonSID
WHERE ra.MVIPersonSID=@MVIPersonSID
	AND ra.DisDay=@DisDay
ORDER BY ra.MVIPersonSID,ra.AppointmentDateTime desc
;

END