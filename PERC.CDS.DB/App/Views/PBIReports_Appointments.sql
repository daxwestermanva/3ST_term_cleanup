


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Appointments]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Appointments] AS

	WITH Cohort AS (
		SELECT DISTINCT MVIPersonSID, PatientICN 
		FROM [Common].[PBIReportsCohort] WITH (NOLOCK)
	)
	SELECT DISTINCT
		 p.MVIPersonSID
		,c.Facility
		,c.Code
		,PrintName = 
			CASE WHEN ApptCategory IN ('PCFuture','PCRecent')					THEN 'Primary Care Appointment'
					WHEN ApptCategory IN ('MHFuture','MHRecent')				THEN 'MH Appointment'
					WHEN ApptCategory IN ('HomelessFuture','HomelessRecent')	THEN 'Homeless Appointment'
					WHEN ApptCategory IN ('PainFuture','PainRecent')			THEN 'Specialty Pain'
					WHEN ApptCategory IN ('PeerFuture','PeerRecent')			THEN 'Peer Support'
					WHEN ApptCategory IN ('OtherFuture','OtherRecent')			THEN 'Other Appointment'
					WHEN ApptCategory = 'ClinRelevantRecent'					THEN 'Any Clinical Appointment'
					WHEN ApptCategory = 'EDRecent'								THEN 'Emergency Room'
					END
		,StopCodeName = PrimaryStopCodeName
		,AppointmentDate
		,ApptLabel=CASE WHEN PastFuture='2' THEN 'Future Appointments'
						WHEN PastFuture='1' THEN 'Last VA Contact'
						END
	FROM Cohort p
	INNER JOIN (
			SELECT MVIPersonSID, ISNULL(PrimaryStopCodeName,AppointmentType) AS PrimaryStopCodeName, PrimaryStopCode, cast(AppointmentDatetime as date) AppointmentDate, Sta3n, ChecklistID ,ApptCategory, SecondaryStopCode, PastFuture = 2
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN=1
				AND (ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PeerFuture','OtherFuture')
					)
			UNION ALL
			SELECT MVIPersonSID, PrimaryStopCodeName, PrimaryStopCode, cast(VisitDatetime as date) AppointmentDate, Sta3n, ChecklistID ,ApptCategory, SecondaryStopCode, PastFuture = 1
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_ICN=1
				AND (ApptCategory IN ('ClinRelevantRecent','PCRecent','EDRecent','MHRecent','HomelessRecent','PeerRecent','PainRecent','OtherRecent')
					)
			)
		AS a ON a.MVIPersonSID = p.MVIPersonSID
	INNER JOIN [Lookup].[StationColors] AS c WITH (NOLOCK)
		ON a.ChecklistID = c.ChecklistID

	UNION

	SELECT MVIPersonSID
		,Facility
		,Code
		,AppointmentPrintName
		,AppointmentStopCodeName
		,AppointmentDate
		,AppointmentLabel
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)