

---- =======================================================================================================
---- Author:		Christina Wade
---- Create date:	3/18/2025
---- Description:	To be used as Dim source in BHIP Care Coordination Power BI report.
----
----				Row duplication is expected in this dataset.
----
---- Modifications:
---- 7/9/2025  - CW - Adding TestPatients from central table
---- 8/11/2025 - CW - Hotfix: Adding components of the actionbar for intra-report filtering
----
---- =======================================================================================================


CREATE VIEW [App].[BHIPPanel_PBI] AS

	WITH Cohort AS (
	SELECT MVIPersonSID
		,PatientICN
		,PatientName
		,LastFour
		,DateOfBirth
		,Team
		,MHTC_Provider
		,RelationshipStartDate
		,ChecklistID
		,OverdueforFill
		,NoMHAppointment6mo
		,TotalMissedAppointments
		,OverdueForLab
		,AcuteEventScore
		,ChronicCareScore
		,ActiveEpisode
		,LastEvent
		,Overdue_Any
		,LastBHIPContact
		,ReportMode
		,CurrentlyAdmitted
		,FLOWEligible
		,Facility
		,Code
		,VisitNUmber
		,AppointmentDateTime
		,AppointmentLocationName
		,AppointmentDayFormatted
		,AppointmentDate_Slicer
		,Homeless
	FROM BHIP.Panel_PBI WITH(NOLOCK)

	UNION

	SELECT MVIPersonSID
		,PatientICN
		,PatientName
		,LastFour
		,DateOfBirth
		,Team
		,ProviderName
		,BHIP_StartDate
		,ChecklistID
		,BHIPOverdueforFill
		,BHIPNoMHAppointment6mo
		,BHIPTotalMissedAppointments
		,BHIPOverdueForLab
		,BHIPAcuteEventScore
		,BHIPChronicCareScore
		,ActiveEpisode=0
		,LastEvent
		,BHIPOverdueFlag
		,LastBHIPContact
		,ReportMode
		,CurrentlyAdmitted
		,FLOWEligible
		,Facility
		,Code
		,VisitNUmber=1
		,AppointmentDateTime
		,Clinic
		,BHIPAppointmentDayFormatted
		,BHIPAppointmentDate_Slicer
		,Homeless
	FROM App.PBIReports_TestPatients WITH(NOLOCK)
	),
	SuiOD AS (
	SELECT DISTINCT MVIPersonSID FROM BHIP.RiskFactors WHERE RiskFactor='Most recent suicide attempt or overdose' AND EventDate >= DATEADD(MONTH, -6, GETDATE())
	),
	MHInpat AS (
	SELECT DISTINCT MVIPersonSID FROM BHIP.RiskFactors WHERE RiskFactor='Inpat MH Stay in past year' AND EventDate >= DATEADD(MONTH, -6, GETDATE())
	), 
	MHEDVisits AS (
	SELECT DISTINCT MVIPersonSID FROM BHIP.RiskFactors WHERE RiskFactor='MH-related ED/Urgent Care visit' AND EventDate >= DATEADD(MONTH, -6, GETDATE())
	), 
	CSRERisk AS (
	SELECT DISTINCT MVIPersonSID FROM BHIP.RiskFactors WHERE (RiskFactor IN ('CSRE - Acute Risk', 'CSRE - Chronic Risk') AND EventValue IN ('Intermediate', 'High')) AND EventDate >= DATEADD(MONTH, -6, GETDATE())
	),
	HRF AS (
	SELECT DISTINCT MVIPersonSID FROM BHIP.RiskFactors WHERE (RiskFactor IN ('High Risk Flag in past year') AND EventValue NOT IN ('Inactivated')) AND EventDate >= DATEADD(MONTH, -6, GETDATE())
	)
	--Final query
	SELECT DISTINCT a.*
		,SuiOD_ActionBar=CASE WHEN b.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
		,MHInpat_ActionBar=CASE WHEN c.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
		,MHEDVisits_ActionBar=CASE WHEN d.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
		,CSRERisk_ActionBar=CASE WHEN e.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
		,HRF_ActionBar=CASE WHEN f.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
	FROM Cohort a
	LEFT JOIN SuiOD b on a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN MHInpat c on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN MHEDVisits d on a.MVIPersonSID=d.MVIPersonSID
	LEFT JOIN CSRERisk e on a.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN HRF f on a.MVIPersonSID=f.MVIPersonSID