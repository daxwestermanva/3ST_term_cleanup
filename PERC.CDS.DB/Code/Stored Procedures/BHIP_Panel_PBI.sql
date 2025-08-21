-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/18/2025
-- Description:	To be used as Dim source in BHIP Care Coordination Power BI report.
--				Adapted from [App].[BHIP_Panel_PBI]

--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/7/2025  CW  Hotfix: Fixing bug related to AppointmentDateTime (removing date cast)
--
--
-- =======================================================================================================
CREATE PROCEDURE [Code].[BHIP_Panel_PBI]
AS
BEGIN

	---------------------------------
	-- STARTING COHORT
	---------------------------------
	DROP TABLE IF EXISTS #Panel
	SELECT DISTINCT a.MVIPersonSID
		,a.PatientICN
		,a.PatientName
		,c.LastFour
		,c.DateOfBirth
		,a.Team
		,a.MHTC_Provider
		,RelationshipStartDate=CAST(a.BHIP_StartDate as date)
		,ChecklistID=a.BHIP_ChecklistID
		,a.OverdueforFill
		,a.NoMHAppointment6mo
		,a.TotalMissedAppointments
		,a.OverdueForLab
		,a.AcuteEventScore
		,a.ChronicCareScore
		,e.ActiveEpisode
		,MAX(cast(b.Eventdate as date)) over (partition by a.MVIPersonSID) as LastEvent
		,MAX(b.OverdueFlag) over(partition by a.MVIPersonSID) as Overdue_Any
		,LastBHIPContact=cast(a.LastBHIPContact as date)
		,'All Data'  as ReportMode
		,CurrentlyAdmitted=case when iv.MVIPersonSID is not null then 'Yes'  else 'No' end
		,FLOWEligible
		,a.Homeless
	INTO #Panel
	FROM  [BHIP].[PatientDetails] as a WITH (NOLOCK)
	left outer join [BHIP].[RiskFactors] as b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID 
	inner join Common.MasterPatient as c WITH (NOLOCK) on a.MVIPersonSID = c.MVIPersonSID
	left outer join (   select MVIPersonSID, MAX(ISNULL(EntryDateTime,VisitDateTime)) as CSREDate
						from OMHSP_Standard.CSRE WITH (NOLOCK)
						group by MVIPersonSID   ) d on a.MVIPersonSID=d.MVIPersonSID
	left outer join Common.InpatientRecords iv WITH (NOLOCK) on a.MVIPersonSID = iv.MVIPersonSID and iv.DischargeDateTime is null
	left outer join COMPACT.Episodes e WITH (NOLOCK) on a.MVIPersonSID=e.MVIPersonSID and e.ActiveEpisode=1

	UNION 

	SELECT DISTINCT MVIPersonSID
		,PatientICN=NULL
		,PatientName
		,LastFour
		,DateOfBirth=NULL
		,Team=NULL
		,MHTC_Provider=NULL
		,BHIP_StartDate=NULL
		,ChecklistID=NULL
		,OverdueforFill=NULL
		,NoMHAppointment6mo=NULL
		,TotalMissedAppointments=NULL
		,OverdueForLab=NULL
		,AcuteEventScore=NULL
		,ChronicCareScore=NULL
		,ActiveEpisode=NULL
		,LastEvent=NULL
		,Overdue_Any=1
		,'8/22/1864'
		,'Demo Mode' 
		,CurrentlyAdmitted='Yes'
		,FLOWEligible='Yes'
		,Homeless='Homeless Svcs or Dx'
		from Common.MasterPatient mv WITH (NOLOCK) 
		inner join LookUp.ChecklistID c1 WITH (NOLOCK) on 1=1 and len(c1.ChecklistID) >=3
		where mvipersonsid = 13066049


	---------------------------------
	-- APPOINTMENT INFO
	---------------------------------
	--Vista stop codes
	DROP TABLE IF EXISTS #LookUp_StopCode
	CREATE TABLE #LookUp_StopCode (
		StopCodeSID bigint
		,StopCode varchar(100)
		,StopCodeName varchar(100)
		,ApptCategory varchar(25)
		,Flag BIT
		,Sta3n smallint
		)	
	INSERT INTO #LookUp_StopCode
	SELECT StopCodeSID
		  ,StopCode
		  ,StopCodeName
		  ,ApptCategory
		  ,Flag
		  ,Sta3n
	FROM (
		SELECT StopCodeSID
			  ,StopCode
			  ,StopCodeName
			  ,Sta3n
			  ,MHFuture			= MHOC_MentalHealth_Stop --Future Appt MH specialty
			  ,HomelessFuture	= MHOC_Homeless_Stop
		FROM [LookUp].[StopCode] WITH(NOLOCK)
		) lkup
	UNPIVOT (Flag FOR ApptCategory IN (
									   MHFuture
									   ,HomelessFuture
									   )
		) upvt
	WHERE Flag=1

	--Mill Appointment Types - not set yet
	--create temporary AppointmentType lookup until we can get concrete categories from SMEs
	DROP TABLE IF EXISTS #Lookup_ApptType
	SELECT DISTINCT 
		 AppointmentType 
		,AppointmentTypeCodeValueSID
		,CASE WHEN AppointmentType like '%MH%' THEN 1 ELSE 0 END MHFuture
	INTO #Lookup_ApptType
	FROM [Cerner].[FactAppointment] WITH(NOLOCK)

	DROP TABLE IF EXISTS #LookUp_ApptTypesMill
	CREATE TABLE #LookUp_ApptTypesMill (
		 AppointmentType varchar(100)
		,AppointmentTypeCodeValueSID int
		,ApptCategory varchar(25)
		,Flag BIT
		)
	INSERT INTO #LookUp_ApptTypesMill
	SELECT AppointmentType 
		  ,AppointmentTypeCodeValueSID
		  ,ApptCategory
		  ,Flag
	FROM (
		SELECT AppointmentType 
			  ,AppointmentTypeCodeValueSID
			  ,MHFuture		--= MHRecent_Stop --Future Appt MH specialty
		FROM #Lookup_ApptType
		) lkup
	UNPIVOT (Flag FOR ApptCategory IN (
									   MHFuture
									   )
		) upvt
	WHERE Flag=1


	---------------------------------
	-- FUTURE APPOINTMENTS --Vista
	---------------------------------
		DROP TABLE IF EXISTS #VistaFutureSIDs;
		SELECT
			mvi.MVIPersonSID
			,a.Sta3n
			,a.PatientSID
			,a.VisitSID
			,AppointmentDateTime
			,a.LocationSID
		INTO #VistaFutureSIDs
		FROM [BHIP].[PatientDetails] b WITH (NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
			ON b.MVIPersonSID=mvi.MVIPersonSID
		INNER JOIN [Appt].[Appointment] a WITH (NOLOCK)
			ON a.PatientSID = mvi.PatientPersonSID
		WHERE a.AppointmentDateTime > DATEADD(day,-1,cast(getdate() as date)) 
			AND a.AppointmentDateTime <= DATEADD(year,1,cast(getdate() as date))  
			AND a.[CancellationReasonSID] = -1 -- not cancelled
			AND a.CancelDateTime IS NULL -- not cancelled
			AND mvi.MVIPersonSID > 0
	
		DROP TABLE IF EXISTS #FutureAppointmentVista;
		SELECT DISTINCT A.MVIPersonSID
			  ,A.Sta3n
			  ,A.PatientSID
			  ,A.VisitSID
			  ,A.AppointmentDateTime
			  ,C.StopCode AS PrimaryStopCode
			  ,C.StopCodeName AS PrimaryStopCodeName
			  ,F.StopCode AS SecondaryStopCode
			  ,F.StopCodeName AS SecondaryStopCodeName
			  ,CASE WHEN F.ApptCategory IN ('MHFuture','HomelessFuture')
				THEN F.ApptCategory ELSE C.ApptCategory END AS ApptCategory
			  ,B.MedicalService
			  ,B.AppointmentLength
			  ,D.DivisionName AS AppointmentDivisionName
			  ,E.InstitutionName AS AppointmentInstitutionName
			  ,B.LocationName AS AppointmentLocationName
			  ,B.LocationSID
			  ,D.Sta6a
			  ,ISNULL(D.ChecklistID,A.Sta3n) as ChecklistID
			  ,s.Code
		INTO #FutureAppointmentVista
		FROM #VistaFutureSIDs AS A WITH(NOLOCK)
		LEFT JOIN [Dim].[Location] AS B WITH(NOLOCK) ON A.LocationSID=B.LocationSID
		LEFT JOIN #LookUp_StopCode AS C ON B.PrimaryStopCodeSID=C.StopCodeSID
		LEFT JOIN #LookUp_StopCode AS F ON B.SecondaryStopCodeSID=F.StopCodeSID
		--LEFT JOIN [Dim].[Division] AS D ON B.DivisionSID=D.DivisionSID
		LEFT JOIN [Dim].[Institution] AS E WITH(NOLOCK) ON B.InstitutionSID=E.InstitutionSID
		LEFT JOIN [LookUp].[DivisionFacility] as D WITH(NOLOCK) ON B.DivisionSID=D.DivisionSID
		LEFT JOIN LookUp.StationColors as s on ISNULL(D.ChecklistID,A.Sta3n) = s.ChecklistID
		WHERE c.ApptCategory IN ('MHFuture','HomelessFuture') or f.ApptCategory IN ('MHFuture','HomelessFuture')


	---------------------------------
	-- FUTURE APPOINTMENTS --Mill
	---------------------------------
		DROP TABLE IF EXISTS #FutureAppointmentMill;
		SELECT DISTINCT a.MVIPersonSID
			  ,a.PersonSID
			  ,a.EncounterSID
			  ,a.TZBeginDateTime AS AppointmentDateTime
			  ,a.AppointmentType
			  ,a.DerivedActivityType
			  ,a.OrganizationNameSID
			  ,a.STA6A
			  ,ch.ChecklistID
			  ,a.TimeDuration
			  ,a.EncounterType --is this or EncounterTypeClass equivalent to MedicalService?
			  ,a.EncounterTypeClass
			  ,c.ApptCategory
			  ,a.AppointmentLocation
			  ,l.Divison AS AppointmentDivisionName
			  ,l.OrganizationName AS InstitutionName --is this right?
			  ,s.Code
		INTO #FutureAppointmentMill
		FROM [Cerner].[FactAppointment] AS a WITH (NOLOCK)
		INNER JOIN [Lookup].[ChecklistID] AS ch WITH (NOLOCK)
			ON a.StaPa = ch.StaPa
		INNER JOIN #LookUp_ApptTypesMill AS c 
			ON a.AppointmentTypeCodeValueSID = c.AppointmentTypeCodeValueSID
		LEFT JOIN [Cerner].[DimLocations] AS l WITH (NOLOCK) 
			ON a.OrganizationNameSID = l.OrganizationNameSID
		LEFT JOIN LookUp.StationColors as s on ch.ChecklistID = s.ChecklistID
		WHERE a.ScheduleState <> 'Canceled' 
			AND a.TZBeginDateTime >  cast(getdate() as date)
			AND a.TZBeginDateTime <= DATEADD(year,1,cast(getdate() as date))  
			AND a.MVIPersonSID > 0

	---------------------------------
	--Combine Vista and Mill future MH appts
	---------------------------------
	drop table if exists #appt
	SELECT DISTINCT f.*
	into #appt
	FROM 
	  (
			SELECT MVIPersonSID
			  ,PatientSID
			  ,VisitSID
			  ,AppointmentDateTime
			  ,Sta3n
			  ,STA6A
			  ,ChecklistID
			  ,PrimaryStopCode
			  ,PrimaryStopCodeName
			  ,SecondaryStopCode
			  ,SecondaryStopCodeName
			  ,MedicalService
			  ,AppointmentLength
			  ,AppointmentDivisionName
			  ,AppointmentInstitutionName
			  ,AppointmentLocationName
			  ,LocationSID
			  ,AppointmentType=CAST(NULL as varchar)
			  ,OrganizationNameSID=CAST(NULL as int)
			  ,ApptCategory
			  ,NextAppt_SID=Row_Number() OVER(Partition By PatientSID,ApptCategory Order By AppointmentDateTime ASC)
			  ,Code
			FROM #FutureAppointmentVista 
				UNION ALL
			SELECT MVIPersonSID
				,PersonSID
				,EncounterSID
				,AppointmentDateTime
				,Sta3n = 200
				,STA6A
				,ChecklistID
				,PrimaryStopCode=CAST(NULL as varchar)
				,PrimaryStopCodeName=CAST(NULL as varchar)
				,SecondaryStopCode=CAST(NULL as varchar)
				,SecondaryStopCodeName=CAST(NULL as varchar)
				,MedicalService=CAST(NULL as varchar)
				,TimeDuration AS AppointmentLength
				,AppointmentDivisionName
				,AppointmentInstitutionName=CAST(NULL as varchar)
				,AppointmentLocationName=AppointmentLocation
				,LocationSID=CAST(NULL as int)
				,AppointmentType
				,OrganizationNameSID
				,ApptCategory
				,NextAppt_SID=Row_Number() OVER(Partition By PersonSID,ChecklistID,ApptCategory Order By AppointmentDateTime ASC)
				,Code
			FROM #FutureAppointmentMill c
			) as f;


	--Prepping appointment information for final table
	DROP TABLE IF EXISTS #Appointments
	SELECT
		 p.MVIPersonSID
		,a.ChecklistID
		,AppointmentDateTime
		,AppointmentLocationName
		,RedactedName='Redacted Name'
		,RedactedDate='08/22/1864'
	INTO #Appointments
	FROM #Panel p
	LEFT JOIN #appt a
		ON p.MVIPersonSID=a.MVIPersonSID

	UNION 

	Select distinct 
		 MVIPersonSID
		,c1.ChecklistID
		,'08/22/1864' as AppointmentDateTime
		,'Test Location' AppointmentLocationName
		,'Redacted Name' as RedactedName
		,'08/22/1864' as RedactedDate
	from Common.MasterPatient mv WITH (NOLOCK) 
	inner join LookUp.ChecklistID c1 WITH (NOLOCK) on 1=1 and len(c1.ChecklistID) >=3
	where mvipersonsid = 13066049;


	---------------------------------
	-- FINAL TABLE
	---------------------------------
	DROP TABLE IF EXISTS #Final
	SELECT DISTINCT p.MVIPersonSID
		,p.PatientICN
		,p.PatientName
		,p.LastFour
		,p.DateOfBirth
		,p.Team
		,p.MHTC_Provider
		,p.RelationshipStartDate
		,p.ChecklistID
		,p.OverdueforFill
		,p.NoMHAppointment6mo
		,p.TotalMissedAppointments
		,p.OverdueForLab
		,p.AcuteEventScore
		,p.ChronicCareScore
		,p.ActiveEpisode
		,p.LastEvent
		,p.Overdue_Any
		,p.LastBHIPContact
		,p.ReportMode
		,p.CurrentlyAdmitted
		,p.FLOWEligible
		,s.Facility
		,s.Code
		,VisitNumber=ROW_NUMBER() OVER (PARTITION BY p.MVIPersonSID ORDER BY a.AppointmentDateTime)
		,a.AppointmentDateTime
		,a.AppointmentLocationName
		,a.RedactedName
		,a.RedactedDate
		,AppointmentDayFormatted=CAST(FORMAT(a.AppointmentDateTime, ('ddd')) as varchar)
		,AppointmentDate_Slicer=
			CASE WHEN CAST(a.AppointmentDateTime AS DATE) = CAST(GETDATE() AS DATE) THEN CAST(FORMAT(GETDATE(),'M/d/yyyy') as DATE)
				 WHEN CAST(a.AppointmentDateTime AS DATE) > CAST(GETDATE() AS DATE) THEN CAST(FORMAT(a.AppointmentDateTime,'M/d/yyyy') as DATE)
				 END
		,p.Homeless
	INTO #Final
	FROM #Panel p
	LEFT JOIN #Appointments a
		ON a.MVIPersonSID=p.MVIPersonSID AND p.ChecklistID=a.ChecklistID
	LEFT JOIN LookUp.StationColors s WITH (NOLOCK)
		ON p.ChecklistID=s.CheckListID
	LEFT JOIN Common.MasterPatient m WITH (NOLOCK) on p.MVIPersonSID=m.MVIPersonSID;

EXEC [Maintenance].[PublishTable] 'BHIP.Panel_PBI', '#Final';


END