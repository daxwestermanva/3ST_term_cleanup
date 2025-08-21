



/********************************************************************************************************************
DESCRIPTION: Create past and future appt table to use for all projects. Most recent visit in past year 
			 and next appointment (for each category).
AUTHOR:		 Sara Tavakoli
CREATED:	 04/24/2014
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	10/01/2018		SG		Removed DROP/Create for permanent tables 
	20181024		RAS		Refactored for MVIPersonSID.  Changed to pull all visits/appointments into temp table at 
							beginning of sections instead of multiple subqueries. Also added grouping for GID level 
							throughout code instead of calculating at end.
	20181218		RAS		Removed distincts from individual appointment type queries because row_number() was
							being used to select 1 appt per ICN and per SID.
	20200512		RAS		Replaced hard-coding of stop codes with lookup table. Pivoted lookup to improve efficiency code.	
	20200812		RAS		Removed final section that publishes data to Present.Appointments -- testing change in run time
							and pointing dependencies to the vertical tables.
	20200914		LM		Added a day to @EndDate, since this code runs in the evening and won't be viewable on reports 
							for most users until the next day.  Removed the exclusion for future group appointments after 
							discussion at all-hands 9.14.20
	20201201		MCP		Added Cerner data: For visits, use combo of activity types and ED/UC flags; for appts, use appointmenttype 
	20210518		LM		Changes to pull VistA SID values first and then add details for faster performance
	20210810		AI		Changed App.OutpatWorkload_StatusShowed reference to App.vwOutpatWorkload_StatusShowed
	20210915        AW      Changed DerivedAppointmentLocalDateTime to TZBeginDateTime
	20210917		AI		Enclave Refactoring - Counts confirmed
	20210923		JEB		Enclave Refactoring - Removed use of Partition ID
	20211104		LM		Added VisitSID
	20220329		LM		Removed e-consults with secondary stop code 697
	20220418		LM		Added peer support visits
	20220506		LM		Changed MH visits to use MHOC_MentalHealth_Stop, added Homeless (MHOC_Homeless_Stop)
	20220614		LM		Overlay to bring in Cerner StopCodes for non-MH visits
	20220815		SAA_JJR Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data
	20250402		CW		Adding additional constraint for VistaSID cancellations
	20250808		LM		Run time optimization

						
********************************************************************************************************************/
CREATE PROCEDURE [Code].[Present_Appointments] 
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Present_Appointments','Execution of Code.Present_Appointments SP'

PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' BEGIN PROCEDURE'	

	EXEC [Log].[ExecutionBegin] 'Code.Present_Appointments - Past','Execution of section to get past visit data'
---------------------------------
-- Create vertical lookup table for stop codes
---------------------------------
DROP TABLE IF EXISTS #LookUp_StopCode
CREATE TABLE #LookUp_StopCode (
	StopCodeSID bigint
	,StopCode varchar(100)
	,StopCodeName varchar(100)
	,ApptCategory varchar(25)
	,Flag BIT
	,Sta3n smallint
	,RestrictionTypeCode varchar(25)
	)
INSERT INTO #LookUP_StopCode
SELECT StopCodeSID
	  ,StopCode
	  ,StopCodeName
	  ,ApptCategory
	  ,Flag
	  ,Sta3n
	  ,RestrictionTypeCode
FROM (
	SELECT a.StopCodeSID
		  ,a.StopCode
		  ,a.StopCodeName
		  ,a.Sta3n
		  ,sc.RestrictionTypeCode
		  ,AnyRecentED			= CAST(1 as smallint) --Any Past Appt including urgent care and ED
		  ,AnyRecent			= a.Any_Stop --PastAppt (ANY) --Excludes Emergency Dept and Urgent Care
		  ,EDRecent				= a.EmergencyRoom_Stop --Emergency Dept and Urgent Care --ED and UC -- EmergencyRoom_Stop = 1 also includes 102	ADMITTING/SCREENING
		  ,ClinRelevantRecent	= a.ClinRelevant_Stop --PAST APPT Clinically Relevant (includes hand picked relevant appts)
		  ,PCRecent				= a.PC_Stop --PAST APPT Primary Care
		  ,PainRecent			= a.Pain_Stop --PAST APPT Pain Clinic
		  ,MHRecent				= a.MHOC_MentalHealth_Stop --PAST APPT MH Specialty
		  ,HomelessRecent		= a.MHOC_Homeless_Stop
		  ,PeerRecent			= a.PeerSupport_Stop
		  ,OtherRecent			= a.Other_Stop --PAST APPT Other (non-MH, PC, or Pain) /*these match, but might not match intention*/
	FROM [LookUp].[StopCode] a WITH(NOLOCK)
	LEFT JOIN [Dim].[StopCode] sc WITH (NOLOCK)
		ON a.StopCodeSID=sc.StopCodeSID
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (AnyRecentED		
								   ,AnyRecent			
								   ,EDRecent				
								   ,ClinRelevantRecent	
								   ,PCRecent				
								   ,PainRecent			
								   ,MHRecent
								   ,HomelessRecent
								   ,PeerRecent
								   ,OtherRecent	)
	) upvt
WHERE Flag=1

--Align ED definition with original code
DELETE #LookUp_StopCode WHERE ApptCategory='EDRecent' AND StopCode=102
--Don't use stop codes for Cerner MH visits
DELETE #Lookup_StopCode WHERE Sta3n = 200 AND ApptCategory IN ('MHRecent','HomelessRecent')

CREATE CLUSTERED INDEX CIX_LookUpStop ON #LookUp_StopCode (StopCodeSID)

-----------------------------------
--Cerner Activity types - use for visits
--------------------------------
/*MHOC MH, MHOC Homeless, MHOC GMH, MHOC HBPC, MHOC PTSD, MHOC PCT, MHOC SUD, MHOC TSES, MHOC PRRC, MHOC MHICM, MHOC PCMHI, MHOC RRTP, Reach_Homeless, 
Reach_MH, MHRecent (STORM), WHole Health
*/
DROP TABLE IF EXISTS #LookUp_ActivityTypesMill
CREATE TABLE #LookUp_ActivityTypesMill (
	 ItemID bigint
	,AttributeValue varchar(100)
	,List varchar(100)
	,ApptCategory varchar(25)
	,Flag BIT
	)
INSERT INTO #LookUp_ActivityTypesMill
SELECT ItemID
	  ,AttributeValue
	  ,List
	  ,ApptCategory
	  ,Flag
FROM (
	SELECT ItemID
		  ,AttributeValue
		  ,List
		  ,AnyRecentED			= 1--CAST(1 as smallint) --Any Past Appt including urgent care and ED
	    --,AnyRecent			= AnyRecent_Stop --PastAppt (ANY) --Excludes Emergency Dept and Urgent Care --ED and urgent care from utulization table
	    --,EDRecent			= EmergencyRoom_Stop --Emergency Dept and Urgent Care --ED and UC -- EmergencyRoom_Stop = 1 also includes 102	ADMITTING/SCREENING
	    --,ClinRelevantRecent	= ClinRelevantRecent_Stop --PAST APPT Clinically Relevant (includes hand picked relevant appts) -- still need these defined
	    --,PCRecent			= PCRecent_Stop --PAST APPT Primary Care --still need defined
	    --,PainRecent			= PainRecent_Stop --PAST APPT Pain Clinic --still need defined
	      ,MHRecent				= CASE WHEN List = 'MHOC_MH' THEN 1 ELSE 0 END--PAST APPT MH Specialty --s
		  ,HomelessRecent		= CASE WHEN List = 'MHOC_Homeless' THEN 1 ELSE 0 END
	    --,OtherRecent		= OtherRecent_Stop --still need defined
	FROM [LookUp].[ListMember] WITH(NOLOCK)
	WHERE Domain = 'ActivityType' 
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (AnyRecentED		
								   --,AnyRecent			
								   --,EDRecent				
								   --,ClinRelevantRecent	
								   --,PCRecent				
								   --,PainRecent			
								   ,MHRecent	
								   ,HomelessRecent)			
								   --,OtherRecent	)
	) upvt
WHERE Flag=1

--Get all possible combinations of primary and secondary stop codes
DROP TABLE IF EXISTS #PrimarySecondaryStop
SELECT DISTINCT a.StopCode AS PrimaryStopCode
	,a.StopCodeSID AS PrimaryStopCodeSID
	,a.StopCodeName AS PrimaryStopCodeName
	,b.StopCode AS SecondaryStopCode
	,b.StopCodeSID AS SecondaryStopCodeSID
	,b.StopCodeName AS SecondaryStopCodeName
	,CASE WHEN b.ApptCategory IN ('MHRecent','HomelessRecent','PainRecent','PCRecent','PeerRecent','EDRecent') 
			THEN b.ApptCategory ELSE a.ApptCategory END AS ApptCategory
	,a.Sta3n
	,FutureStop= CASE WHEN b.ApptCategory IN ('MHRecent','HomelessRecent','PainRecent','PCRecent','PeerRecent')
		OR a.ApptCategory IN ('AnyRecent','PCRecent','PainRecent','MHRecent','HomelessRecent','PeerRecent','OtherRecent')
		THEN 1 ELSE	0 END
INTO #PrimarySecondaryStop
FROM (SELECT * FROM #LookUp_StopCode WHERE RestrictionTypeCode <>'S') AS a --Primary, Either
INNER JOIN (SELECT * FROM #LookUp_StopCode WHERE RestrictionTypeCode <>'P') AS b --Secondary, Either
	ON a.Sta3n=b.Sta3n AND a.StopCodeSID<>b.StopCodeSID
UNION ALL
--Primary stop codes without a secondary stop code 
SELECT DISTINCT a.StopCode AS PrimaryStopCode
	,a.StopCodeSID AS PrimaryStopCodeSID
	,a.StopCodeName AS PrimaryStopCodeName
	,SecondaryStopCode=NULL
	,SecondaryStopCodeSID=NULL
	,SecondaryStopCodeName=NULL
	,a.ApptCategory
	,a.Sta3n
	,FutureStop= CASE WHEN a.ApptCategory IN ('AnyRecent','PCRecent','PainRecent','MHRecent','HomelessRecent','PeerRecent','OtherRecent')
		THEN 1 ELSE	0 END
FROM #LookUp_StopCode AS a
WHERE a.RestrictionTypeCode <>'S' --Primary, Either

UPDATE #PrimarySecondaryStop
SET FutureStop=0
WHERE ApptCategory='EDRecent'

DELETE FROM #PrimarySecondaryStop
WHERE SecondaryStopCode='697'

---------------------------------
-- PAST OUTPATIENT VISITS
---------------------------------
	DECLARE @BeginDate Date
	DECLARE @EndDate Date
	SET @BeginDate=DateAdd(d,-366,getdate())
	SET @EndDate=DateAdd(d,1,getdate())

	DROP TABLE IF EXISTS #dates
	SELECT BeginDate=@BeginDate
		,EndDate=@EndDate
	INTO #dates


PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' Declared variables, begin visit computation'

	DROP TABLE IF EXISTS #PastAppointmentVista;
	SELECT TOP 1 WITH TIES
		 v.MVIPersonSID
		,v.PatientSID
		,v.VisitSID
		,v.VisitDateTime
		,v.Sta3n
		,d.ChecklistID
		,a.PrimaryStopCode
		,a.PrimaryStopCodeName
		,a.SecondaryStopCode
		,a.SecondaryStopCodeName
		,a.ApptCategory
		,MostRecent_SID=1
	INTO #PastAppointmentVista
	FROM [App].[vwOutpatWorkload_StatusShowed_PastYear] v WITH(NOLOCK)
	INNER JOIN #PrimarySecondaryStop AS a on a.PrimaryStopCodeSID=v.PrimaryStopCodeSID AND ISNULL(a.SecondaryStopCodeSID,0)=ISNULL(v.SecondaryStopCodeSID,0)
	LEFT JOIN [LookUp].[DivisionFacility] d WITH(NOLOCK) on v.DivisionSID=d.DivisionSID
	ORDER BY ROW_NUMBER() OVER (PARTITION BY v.PatientSID,a.ApptCategory ORDER BY VisitDateTime DESC)

---------------------------------
-- Cerner PAST OUTPATIENT VISITS
---------------------------------

	DROP TABLE IF EXISTS #MillStopCode
	SELECT usc.EncounterSID, lsc.StopCode, lsc.StopCodeName, lsc.ApptCategory 
	INTO #MillStopCode
	FROM [Cerner].[FactUtilizationStopCode] usc WITH (NOLOCK)
	INNER JOIN #LookUp_StopCode lsc
		ON lsc.StopCodeSID = usc.CompanyUnitBillTransactionAliasSID
		AND lsc.Sta3n=200
	INNER JOIN #dates d ON TZDerivedVisitDateTime BETWEEN d.BeginDate AND d.EndDate

	DROP TABLE IF EXISTS #PastAppointmentMill
	SELECT TOP 1 WITH TIES
		MVIPersonSID
		  ,PersonSID
		  ,EncounterSID
		  ,TZDerivedVisitDateTime
		  ,ChecklistID 
		  ,PrimaryStopCode=StopCode
		  ,PrimaryStopCodeName=StopCodeName
		  ,ActivityType
		  ,ActivityTypeCodeValueSID
		  ,VisitCategory as ApptCategory
	INTO #PastAppointmentMill
	FROM (
		SELECT DISTINCT
			 c.MVIPersonSID
			,c.PersonSID
			,c.EncounterSID
			,c.TZDerivedVisitDateTime
			,ch.ChecklistID
			--,c.Location
			,ActivityType=a.AttributeValue
			,ActivityTypeCodeValueSID=a.ItemID
			,sc.StopCode
			,sc.StopCodeName
			--,c.EncounterType
			--,c.MedicalService
			--,c.UrgentCareFlag as UrgentCare
			--,c.EmergencyCareFlag as EmergencyCare
			,CASE WHEN c.UrgentCareFlag = 1 or c.EmergencyCareFlag = 1 then 'EDRecent'
			 WHEN c.UrgentCareFlag <> 1 and c.EmergencyCareFlag <> 1 and a.ApptCategory IN ('MHRecent','HomelessRecent') then a.ApptCategory
				  ELSE sc.ApptCategory END VisitCategory
			--,ISNULL(a.ApptCategory,sc.ApptCategory) AS ApptCategory --for validation
		FROM [Cerner].[FactUtilizationOutpatient] c WITH(NOLOCK)
		INNER JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
			ON c.StaPa = ch.StaPa
		INNER JOIN #dates d 
			ON c.TZDerivedVisitDateTime BETWEEN d.BeginDate AND d.EndDate
		LEFT JOIN #LookUp_ActivityTypesMill as a 
			ON a.ItemID = c.ActivityTypeCodeValueSID
		LEFT JOIN #MillStopCode sc
			ON c.EncounterSID = sc.EncounterSID
		WHERE c.MVIPersonSID>0
		AND (sc.StopCode IS NOT NULL OR c.ActivityType IS NOT NULL)
		) a
	ORDER BY ROW_NUMBER() OVER(PARTITION BY PersonSID,ChecklistID,VisitCategory ORDER BY TZDerivedVisitDateTime DESC)

	--Combine Vista and Mill
	DROP TABLE IF EXISTS #PastAppointment
	SELECT MVIPersonSID
		  ,PatientSID
		  ,VisitSID
		  ,VisitDateTime
		  ,Sta3n
		  ,ChecklistID
		  ,PrimaryStopCode
		  ,PrimaryStopCodeName
		  ,SecondaryStopCode
		  ,SecondaryStopCodeName
		  ,ActivityType=CAST(NULL as varchar)
		  ,ActivityTypeCodeValueSID=CAST(NULL as int)
		  ,ApptCategory
		  ,MostRecent_SID=1
	INTO #PastAppointment
	FROM #PastAppointmentVista v
	UNION ALL 
	SELECT c.MVIPersonSID
		,c.PersonSID
		,c.EncounterSID
		,c.TZDerivedVisitDateTime
		,Sta3n = 200
		,c.ChecklistID 
		,PrimaryStopCode
		,PrimaryStopCodeName
		,SecondaryStopCode=CAST(NULL as varchar)
		,SecondaryStopCodeName=CAST(NULL as varchar)
		,c.ActivityType
		,c.ActivityTypeCodeValueSID
		,c.ApptCategory
		,MostRecent_SID=1
	FROM #PastAppointmentMill c

	DROP TABLE IF EXISTS #PastAppointmentMill
	DROP TABLE IF EXISTS #PastAppointmentVista;

	/**********************************************Flag Most Recent*************************************************/		
	DROP TABLE IF EXISTS #MostRecentVisits;
	SELECT MVIPersonSID
		,PatientSID
		,VisitSID
		,VisitDateTime
		,PrimaryStopCode
		,PrimaryStopCodeName
		,SecondaryStopCode
		,SecondaryStopCodeName
		,Sta3n
		,ApptCategory
		,MostRecent_SID
		,MostRecent_ICN
		,ChecklistID
		,ActivityType
		,ActivityTypeCodeValueSID 
	INTO #MostRecentVisits
	FROM (
		SELECT MVIPersonSID
			  ,PatientSID
			  ,VisitSID
			  ,VisitDateTime
			  ,PrimaryStopCode
			  ,PrimaryStopCodeName
			  ,SecondaryStopCode
			  ,SecondaryStopCodeName
			  ,Sta3n
			  ,ApptCategory
			  ,MostRecent_SID
			  ,MostRecent_ICN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,ApptCategory ORDER BY VisitDateTime DESC)
			  ,ChecklistID
			  ,ActivityType
			  ,ActivityTypeCodeValueSID
		FROM #PastAppointment
		) a
	WHERE  MostRecent_SID=1 
		OR MostRecent_ICN=1
		
    PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' Created #MostRecentVisits'	

EXEC [Maintenance].[PublishTable] 'Present.AppointmentsPast','#MostRecentVisits'

DROP TABLE IF EXISTS #PastAppointment;

EXEC [Log].[ExecutionEnd] --Past appointments

---------------------------------
-- FUTURE APPOINTMENTS --13346005 
---------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.Present_Appointments - Future','Execution of section to get future appointment data'

PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' BEGIN FUTURE APPOINTMENTS SECTION'


--Mill Appointment Types - not set yet

--create temporary AppointmentType lookup until we can get concrete categories from SMEs
DROP TABLE IF EXISTS #Lookup_ApptType

SELECT DISTINCT 
	 AppointmentType 
	,AppointmentTypeCodeValueSID
	,CASE WHEN AppointmentType like '%MH%'		THEN 1 ELSE 0 END MHFuture
	,CASE WHEN AppointmentType like '%pain%'	THEN 1 ELSE 0 END PainFuture
	,CASE WHEN AppointmentType like '%PC%'		THEN 1 ELSE 0 END PCFuture
	,CASE WHEN AppointmentType NOT LIKE '%MH%' AND AppointmentType NOT LIKE '%pain%' AND AppointmentType NOT LIKE '%PC%' THEN 1 ELSE 0 END AS OtherFuture
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
		  ,AnyFuture	= 1 --FUTURE APPT (ANY) 
		  ,PCFuture		--= PCRecent_Stop --Future Appt Primary Care
		  ,PainFuture	--= PainRecent_Stop
		  ,MHFuture		--= MHRecent_Stop --Future Appt MH specialty
		  ,OtherFuture	--= OtherRecent_Stop --Future Appt Other (non-MH, PC, or Pain)
	FROM #Lookup_ApptType
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (AnyFuture	
								   ,PCFuture				
								   ,PainFuture
								   ,MHFuture
								   ,OtherFuture
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
		,a.AppointmentDateTime
		,a.LocationSID
	INTO #VistaFutureSIDs
	FROM [Appt].[Appointment] a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.PatientSID = mvi.PatientPersonSID
	INNER JOIN #dates d
		ON  a.AppointmentDateTime > d.EndDate
	WHERE a.CancellationReasonSID = -1 -- not cancelled
		AND a.CancelDateTime IS NULL -- not cancelled
		AND mvi.MVIPersonSID > 0
	
	DROP TABLE IF EXISTS #FutureAppointmentVista;
	SELECT A.MVIPersonSID
		  ,A.Sta3n
		  ,A.PatientSID
		  ,A.VisitSID
		  ,A.AppointmentDateTime
		  ,C.PrimaryStopCode
		  ,C.PrimaryStopCodeName
		  ,C.SecondaryStopCode
		  ,C.SecondaryStopCodeName
		  ,REPLACE(C.ApptCategory,'Recent','Future') AS ApptCategory
		  ,B.MedicalService
		  ,B.AppointmentLength
		  ,D.DivisionName AS AppointmentDivisionName
		  ,E.InstitutionName AS AppointmentInstitutionName
		  ,B.LocationName AS AppointmentLocationName
		  ,B.LocationSID
		  ,D.Sta6a
		  ,ISNULL(D.ChecklistID,A.Sta3n) as ChecklistID
	INTO #FutureAppointmentVista
	FROM #VistaFutureSIDs AS A WITH(NOLOCK)
	INNER JOIN [Dim].[Location] AS B WITH(NOLOCK) ON A.LocationSID=B.LocationSID
	INNER JOIN #PrimarySecondaryStop AS C ON B.PrimaryStopCodeSID=C.PrimaryStopCodeSID AND b.SecondaryStopCodeSID=ISNULL(c.SecondaryStopCodeSID,-1) AND FutureStop=1
	LEFT JOIN [Dim].[Institution] AS E WITH(NOLOCK) ON B.InstitutionSID=E.InstitutionSID
	LEFT JOIN [LookUp].[DivisionFacility] as D WITH(NOLOCK) ON B.DivisionSID=D.DivisionSID

	DROP TABLE IF EXISTS #PrimarySecondaryStop
	DROP TABLE IF EXISTS #VistaFutureSIDs;

---------------------------------
-- FUTURE APPOINTMENTS --Mill
---------------------------------
	DROP TABLE IF EXISTS #FutureAppointmentMill;
	SELECT a.MVIPersonSID
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
		  ,l.Divison AS AppointmentDivisionName
		  ,l.OrganizationName AS InstitutionName --is this right?
	INTO #FutureAppointmentMill
	FROM [Cerner].[FactAppointment] AS a WITH (NOLOCK)
	INNER JOIN [Lookup].[ChecklistID] AS ch WITH (NOLOCK)
		ON a.StaPa = ch.StaPa
	INNER JOIN #dates d
		ON a.TZBeginDateTime> d.EndDate
	LEFT JOIN #LookUp_ApptTypesMill AS c 
		ON a.AppointmentTypeCodeValueSID = c.AppointmentTypeCodeValueSID
	LEFT JOIN [Cerner].[DimLocations] AS l WITH (NOLOCK) 
		ON a.OrganizationNameSID = l.OrganizationNameSID
	WHERE a.ScheduleState <> 'Canceled'
		AND a.MVIPersonSID > 0

--Combine Vista and Mill
DROP TABLE IF EXISTS #FutureAppointment

	SELECT DISTINCT f.*
	INTO #FutureAppointment 
	FROM (
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
		    ,AppointmentLocationName=CAST(NULL as varchar)
		    ,LocationSID=CAST(NULL as int)
			,AppointmentType
			,OrganizationNameSID
			,ApptCategory
			,NextAppt_SID=Row_Number() OVER(Partition By PersonSID,ChecklistID,ApptCategory Order By AppointmentDateTime ASC)
		FROM #FutureAppointmentMill c
		) as f

    PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' Created temp table for upcoming appointments (#FutureAppointmentAll)'

	DROP TABLE IF EXISTS #FutureAppointmentVista
	DROP TABLE IF EXISTS #FutureAppointmentMill
	/**********************************************Flag Next Appointments*************************************************/	
	DROP TABLE IF EXISTS #NextAppointments;
	SELECT * INTO #NextAppointments
	FROM (
		SELECT MVIPersonSID
			  ,PatientSID
			  ,Sta3n
			  ,VisitSID
			  ,AppointmentDateTime
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
			  ,STA6A           
			  ,ApptCategory
			  ,NextAppt_SID
			  ,NextAppt_ICN=Row_Number() OVER(Partition By MVIPersonSID,ApptCategory Order By AppointmentDateTime ASC)
			  ,ChecklistID
			  ,AppointmentType
			  ,OrganizationNameSID
		FROM #FutureAppointment
		) a
	WHERE NextAppt_SID=1 or NextAppt_ICN=1

	PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' Created #NextAppointments'

EXEC [Maintenance].[PublishTable] 'Present.AppointmentsFuture','#NextAppointments';
	
DROP TABLE IF EXISTS #FutureAppointment;

EXEC [Log].[ExecutionEnd] --Future appointments

EXEC [Log].[ExecutionEnd]

PRINT CAST(cast(GETDATE() as datetime2(0)) as varchar)+' END PROCEDURE'

END

GO
