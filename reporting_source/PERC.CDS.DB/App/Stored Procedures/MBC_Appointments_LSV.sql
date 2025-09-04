
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report; Used by CRISTAL SSRS reports
-- Updates
--	2019-01-09 - Jason Bacani - Refactored to use MVIPersonSID; Performance tuning; formatting; NOLOCKs
--  2019-04-05 - Liam Mina - Added MVIPersonSID to initial select statement
--  2019-08-08 - Liam Mina - Added most recent ED visit for CRISTAL
--  2020-05-27 - RAS - Changed CancelNoShowCode to AppointmentStatus per CDW column change
--	2020-09-15 - LM - Getting appointments from Present.AppointmentsPast and Present.AppointmentsFuture
--  2020-09-21 - RAS - Changed initial query to use MasterPatient instead of StationAssignments.
					-- Updated appointments query to simplify
--	2022-04-13 - LM - Added Peer Support visits to CRISTAL
--	2022-05-06 - LM - Added Homeless visits; previously were included in MHRecent but now are broken out separately
--	2025-04-09 - LM - Added past year community care ED visit for CRISTAL
--	2025-07-11 - LM - Removed ClinicalRelevant visits from CRISTAL because it is duplicative of the other appointment types that display
--  2025-07-16 - TG - Included Community Care emergency department visists in STORM
-- EXEC [App].[MBC_Appointments_LSV]  @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001092794, @Report = 'STORM'  
-- EXEC [App].[MBC_Appointments_LSV]  @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1012614757, @Report = 'CRISTAL'
-- =============================================
CREATE PROCEDURE [App].[MBC_Appointments_LSV]
(
  @User varchar(max),
  @Patient varchar(1000),
  @Report varchar(100)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inlne testing only
	--DECLARE @User varchar(max), @Patient varchar(1000), @Report varchar(100); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1000880368; SET @Report = 'STORM'  
	--DECLARE @User varchar(max), @Patient varchar(1000), @Report varchar(100); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = 1012708080; SET @Report = 'CRISTAL'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT a.MVIPersonSID,a.PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT
		PrintName = 
			CASE WHEN ApptCategory IN ('PCFuture','PCRecent')				THEN 'Primary Care Appointment'
				 WHEN ApptCategory IN ('MHFuture','MHRecent')				THEN 'MH Appointment'
				 WHEN ApptCategory IN ('HomelessFuture','HomelessRecent')	THEN 'Homeless Appointment'
				 WHEN ApptCategory IN ('PainFuture','PainRecent')			THEN 'Specialty Pain'
				 WHEN ApptCategory IN ('PeerFuture','PeerRecent')			THEN 'Peer Support'
				 WHEN ApptCategory IN ('OtherFuture','OtherRecent')			THEN 'Other Appointment'
				 WHEN ApptCategory = 'EDRecent' AND DirectCare=0			THEN 'Emergency Room - Community Care'
				 WHEN ApptCategory = 'EDRecent'								THEN 'Emergency Room'
				 END
		,StopCodeName = PrimaryStopCodeName
		,AppointmentDatetime
		,Facility
		,PastFuture
		,DirectCare
	FROM #Patient AS p 
	INNER JOIN (
			SELECT MVIPersonSID, ISNULL(PrimaryStopCodeName,AppointmentType) AS PrimaryStopCodeName, PrimaryStopCode, AppointmentDatetime, Sta3n, ChecklistID ,ApptCategory, SecondaryStopCode, PastFuture = 2, DirectCare=1
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN=1
				AND (  (@Report = 'CRISTAL' AND ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PeerFuture','OtherFuture'))
					OR (@Report = 'STORM'   AND ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PainFuture','OtherFuture') )
					)
			UNION ALL
			SELECT MVIPersonSID, PrimaryStopCodeName, PrimaryStopCode, VisitDatetime, Sta3n, ChecklistID ,ApptCategory, SecondaryStopCode, PastFuture = 1, DirectCare=1
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_ICN=1
				AND (  (@Report = 'CRISTAL' AND ApptCategory IN ('PCRecent','EDRecent','MHRecent','HomelessRecent','PeerRecent','OtherRecent'))
					OR (@Report = 'STORM'   AND ApptCategory IN ('PCRecent','MHRecent','HomelessRecent','PainRecent','OtherRecent') )
					)
			UNION ALL
			SELECT TOP 1 WITH TIES e.MVIPersonSID, e.Hospital, NULL, e.Service_Start_Date, NULL, e.ChecklistID, 'EDRecent', NULL, PastFuture=1, DirectCare=0
			FROM [CommunityCare].[EmergencyVisit] e WITH (NOLOCK) 
			INNER JOIN #Patient p ON e.MVIPersonSID=p.MVIPersonSID
			WHERE e.Service_Start_Date>dateadd(year,-1,getdate()) 
				AND (@Report='CRISTAL' OR @Report = 'STORM')
			ORDER BY ROW_NUMBER() OVER (PARTITION BY e.MVIPersonSID, e.CHecklistID ORDER BY e.Service_Start_Date DESC, e.Service_End_Date DESC)
			)
		AS a ON a.MVIPersonSID = p.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK)
		ON a.ChecklistID = c.ChecklistID
	ORDER BY AppointmentDateTime
	;

END