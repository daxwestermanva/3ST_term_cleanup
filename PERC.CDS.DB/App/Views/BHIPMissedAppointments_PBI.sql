



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/18/2025
-- Description:	To be used as Fact source in BHIP Care Coordination Power BI report.
--				Data sourced in 'BHIPCareCoordination__PROD.Dataset'.pbix (semantic model).
--				Data reported in 'BHIP Care Coordination'.pbix (production facing report).
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 3/26/2025 - CW - Adding AppointmentNumber so the report has a UniqueKey for the visual in 'Cancelled Appt Reason' page
-- 7/9/2025  - CW - Adding TestPatients from central table
--
-- =======================================================================================================


CREATE VIEW [App].[BHIPMissedAppointments_PBI] AS

	SELECT MVIPersonSID
		,AppointmentSID
		,AppointmentDate
		,CancellationReason
		,CancellationReasonType
		,CancellationRemarks
		,LocationName
		,ChecklistID
		,AppointmentNumber=ROW_NUMBER () OVER (Partition By MVIPersonSID ORDER BY AppointmentSID, AppointmentDate)
	FROM BHIP.MissedAppointments_PBI WITH (NOLOCK)
	UNION
	SELECT MVIPersonSID
		,AppointmentSID=1
		,AppointmentDate
		,BHIPCancellationReason
		,BHIPCancellationReasonType
		,BHIPCancellationRemarks
		,Clinic
		,ChecklistID
		,AppointmentNumber=1
	FROM App.PBIReports_TestPatients