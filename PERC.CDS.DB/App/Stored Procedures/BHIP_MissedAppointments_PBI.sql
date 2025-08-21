-- ==============================================================================
-- Author:		Amy Robinson/Claire Hannemann
-- Create date: <4/28/2022>
-- Description:	All missed MH appointments for BHIP report cohort
--				For use in PowerBI report
--
-- 3/26/2025  CW  Updating method to mirror that of new view. Will be deleting 
--				  this procedure in an upcoming sprint, once new OMHSP_PERC App 
--				  is ready for production/deployment
-- ==============================================================================

CREATE PROCEDURE [App].[BHIP_MissedAppointments_PBI]

AS
BEGIN
	SET NOCOUNT ON;

	SELECT *, AppointmentNumber=ROW_NUMBER () OVER (Partition By MVIPersonSID ORDER BY AppointmentSID, AppointmentDate)
	FROM BHIP.MissedAppointments_PBI WITH (NOLOCK);

END