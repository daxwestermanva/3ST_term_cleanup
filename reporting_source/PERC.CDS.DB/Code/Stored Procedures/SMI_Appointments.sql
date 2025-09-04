



CREATE PROCEDURE [Code].[SMI_Appointments]
AS
/* ========================================================================
Author:		Claire Hannemann
Create date: 11/4/2021
Description: Creates tables SMI.AppointmentsPast and SMI.AppointmentsFuture
			 to pull into Code.SMI_PatientReport
Modifications:
	03172022: CMH Added Clinic location (appts and past enc) and Provider (past enc only)
	04082022: CMH Create table SMI.MHProviders to pull into Provider/Team parameter
	06172022: LM  Pointed to Lookup.StopCode; Cerner overlay for primary care visits
	08152022: SAA_JJR Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data	
	06262023: CMH Removed all encounters with secondary stop code 697 (chart review)
	12202024: CMH Added secondary stop codes '322','323','350' to PC definition
	01162025: CMH Added new CPT code 98016 (5-10 minute telephone) to exclusion criteria 
	03212025: CMH Added NOLOCKs
	04112025: CMH Corrected join between Cerner.FactUtilizationOutpatient and Cerner.FactUtilizationStopCode
	04142025: CMH Reworked code to account for encounters that fall into multiple categories 
  ======================================================================== */
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.SMI_Appointments', @Description = 'Execution of Code.SMI_PatientReport SP'


--SMI cohort
DROP TABLE IF EXISTS #cohort
SELECT MVIPersonSID, ChecklistID
INTO #cohort
FROM [Present].[ActivePatient] WITH (NOLOCK)
WHERE RequirementID = 50

------------------------------------
-- Vista PAST YEAR OUTPATIENT VISITS
------------------------------------
DROP TABLE IF EXISTS #op_vista
SELECT DISTINCT a.MVIPersonSID
	,c.VisitDateTime
	,d.StopCode as PrimaryStopCode
	,d.StopCodeName as PrimaryStopCodeName
	,e.StopCode as SecondaryStopCode
	,e.StopCodeName as SecondaryStopCodeName
	,g.CPTCode
	,c.VisitSID
	,CASE WHEN d.PC_Stop=1 OR e.StopCode IN ('322','323','350') THEN 1 else 0 end as PCRecent
	,CASE WHEN d.MHOC_MentalHealth_Stop=1 OR d.MHOC_Homeless_Stop=1 OR e.MHOC_MentalHealth_Stop=1 OR e.MHOC_Homeless_Stop=1 THEN 1 else 0 end as MHRecent
	,CASE WHEN d.EmergencyRoom_Stop=1 THEN 1 else 0 end as EDRecent
	,CASE WHEN d.StopCode IN ('546','552','567') OR e.StopCode IN ('546','552','567') THEN 1 ELSE 0 END AS ICMHR
	,j.ChecklistID
	,j.Facility
	,k.LocationName as ClinicName
	,l.ProviderSID
	,m.StaffName as Provider
INTO #op_vista
FROM #cohort a 
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] b WITH (NOLOCK) ON a.MVIPersonSID=b.MVIPersonSID
INNER JOIN [Outpat].[Visit] c WITH (NOLOCK) ON b.PatientPersonSID=c.PatientSID
INNER JOIN [LookUp].[StopCode] d WITH (NOLOCK) ON c.PrimaryStopCodeSID=d.StopCodeSID
LEFT JOIN [LookUp].[StopCode] e WITH (NOLOCK) ON c.SecondaryStopCodeSID=e.StopCodeSID
LEFT JOIN [Outpat].[VProcedure] f WITH (NOLOCK) ON c.VisitSID=f.VisitSID
LEFT JOIN [Dim].[CPT] g WITH (NOLOCK) ON f.CPTSID=g.CPTSID
LEFT JOIN [Dim].[Division] h WITH (NOLOCK) ON c.DivisionSID=h.DivisionSID
LEFT JOIN [LookUp].[Sta6a] i WITH (NOLOCK) ON h.Sta6a=i.Sta6a
LEFT JOIN [LookUp].[ChecklistID] j WITH (NOLOCK) ON i.ChecklistID=j.ChecklistID
LEFT JOIN [Dim].[Location] k WITH (NOLOCK) ON c.LocationSID=k.LocationSID
LEFT JOIN [Outpat].[VProvider] l WITH (NOLOCK) ON c.VisitSID=l.VisitSID
LEFT JOIN [SStaff].[SStaff] m WITH (NOLOCK) ON l.ProviderSID=m.StaffSID
WHERE c.VisitDateTime > DATEADD(DAY, -366, GETDATE()) 
	AND c.WorkloadLogicFlag='Y'
	AND l.PrimarySecondary='P' --primary provider

	
------------------------------------
-- Cerner PAST YEAR OUTPATIENT VISITS
------------------------------------
DROP TABLE IF EXISTS #LookUp_ActivityTypesMill
SELECT ItemID
	  ,AttributeValue
	  ,List
	  ,ApptCategory
	  ,Flag
INTO #LookUp_ActivityTypesMill
FROM (
	SELECT ItemID
		  ,AttributeValue
		  ,List
		--  ,AnyRecentED	= 1--CAST(1 as smallint) --Any Past Appt including urgent care and ED
	    --,EDRecent			= EmergencyRoom_Stop --Emergency Dept and Urgent Care --ED and UC -- EmergencyRoom_Stop = 1 also includes 102	ADMITTING/SCREENING
	    --,PCRecent			= PCRecent_Stop --PAST APPT Primary Care --still need defined
	      ,MHRecent			= CASE WHEN List IN  ('MHOC_MH','MHOC_Homeless') THEN 1 ELSE 0 END--PAST APPT MH Specialty --s
	FROM [LookUp].[ListMember] WITH(NOLOCK)
	WHERE Domain = 'ActivityType' 
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (MHRecent	)			
	) upvt
WHERE Flag=1

DROP TABLE IF EXISTS #op_mill
CREATE TABLE #op_mill (
	 MVIPersonSID bigint
	,VisitDateTime datetime
	,PrimaryStopCode varchar(5)
	,PrimaryStopCodeName varchar(100)
	,SecondaryStopCode varchar(5)
	,SecondaryStopCodeName varchar(100)
	,CPTCode varchar(10)
	,VisitSID bigint
	,PCRecent bit
	,MHRecent bit
	,EDRecent bit
	,ICMHR bit
	,ChecklistID varchar(10)
	,Facility varchar(100)
	,ClinicName varchar(100)
	,ProviderSID varchar(100)
	,Provider varchar(200)
	)

INSERT INTO #op_mill
SELECT DISTINCT
	 b.MVIPersonSID
	,c.TZDerivedVisitDateTime as VisitDateTime
	,sc.GenLedgerCompanyUnitAliasNumber as PrimaryStopCode
	,CASE WHEN c.UrgentCareFlag = 1 or c.EmergencyCareFlag = 1 then c.MedicalService
		ELSE ISNULL(c.ActivityType,ISNULL(lsc.StopCodeName,c.MedicalService)) end as PrimaryStopCodeName
	,NULL as SecondaryStopCode
	,NULL as SecondaryStopCodeName
	,p.SourceIdentifier as CPTCode 
	,c.EncounterSID as VisitSID 
	,CASE WHEN lsc.PC_Stop = 1 THEN 1 else 0 end as PCRecent
	,CASE WHEN c.UrgentCareFlag <> 1 and c.EmergencyCareFlag <> 1 and a.ApptCategory = 'MHRecent' then 1 else 0 end as MHRecent
	,CASE WHEN c.UrgentCareFlag = 1 or c.EmergencyCareFlag = 1 then 1 else 0 end as EDRecent
	,CASE WHEN sc.GenLedgerCompanyUnitAliasNumber in ('546','552','567') or ISNULL(c.ActivityType,lsc.StopCodeName) like '%ICMHR%' THEN 1 ELSE 0 END AS ICMHR
	,ch.ChecklistID
	,ch.Facility
	,c.LocationNurseUnit as ClinicName
	,d.PersonStaffSID as ProviderSID
	,d.NameFullFormatted as Provider
FROM #cohort b
INNER JOIN [Cerner].[FactUtilizationOutpatient] c WITH (NOLOCK) on b.MVIPersonSID=c.MVIPersonSID
LEFT JOIN [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK) ON c.EncounterSID = sc.EncounterSID and c.TZDerivedVisitDateTime=sc.TZDerivedVisitDateTime
LEFT JOIN #LookUp_ActivityTypesMill as a on a.ItemID = c.ActivityTypeCodeValueSID
LEFT JOIN [Lookup].[StopCode] lsc WITH (NOLOCK) ON sc.CompanyUnitBillTransactionAliasSID = lsc.StopCodeSID
LEFT JOIN [Cerner].[FactProcedure] as p WITH (NOLOCK) ON c.EncounterSID=p.EncounterSID and c.TZDerivedVisitDateTime=p.TZDerivedProcedureDateTime
	AND p.SourceVocabulary = 'CPT4'
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK) on c.Sta6a=s.Sta6a
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) on s.ChecklistID=ch.ChecklistID
LEFT JOIN [Cerner].[FactStaffDemographic] d WITH (NOLOCK) on c.DerivedPersonStaffSID=d.PersonStaffSID
WHERE c.TZDerivedVisitDateTime > DATEADD(DAY, -366, GETDATE()) 


------------------------------------------
-- Combine the two and account for CPT codes
------------------------------------------
DROP TABLE IF EXISTS #past_encounters
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,PCRecent
	,MHRecent
	,EDRecent
	,CASE WHEN PCRecent=0 and MHRecent=0 and EDRecent=0 then 1 else 0 end as OtherRecent
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
INTO #past_encounters
FROM #op_vista
UNION
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,PCRecent
	,MHRecent
	,EDRecent
	,CASE WHEN PCRecent=0 and MHRecent=0 and EDRecent=0 then 1 else 0 end as OtherRecent
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
FROM #op_mill

DROP TABLE IF EXISTS #past_encounters2
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,ApptCategory='PCRecent'
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
INTO #past_encounters2
FROM #past_encounters
WHERE PCRecent=1
UNION
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,ApptCategory='MHRecent'
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
FROM #past_encounters
WHERE MHRecent=1
UNION
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,ApptCategory='EDRecent'
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
FROM #past_encounters
WHERE EDRecent=1
UNION
SELECT MVIPersonSID
	,VisitDateTime
	,PrimaryStopCode
	,PrimaryStopCodeName
	,SecondaryStopCode
	,SecondaryStopCodeName
	,CPTCode 
	,VisitSID 
	,ApptCategory='OtherRecent'
	,ICMHR
	,ChecklistID
	,Facility
	,ClinicName
	,ProviderSID
	,Provider
FROM #past_encounters
WHERE OtherRecent=1


--Any MH visits with CPT codes '98966','99441','98016' (less than 10 mins) won't count as MH. Flag these as 'OtherRecent' and include an indicator to put on dashboard
DROP TABLE IF EXISTS #MH_visit
SELECT VisitSID, 
		VisitDateTime,
		max(MH_under10min) as MH_under10min
INTO #MH_visit
FROM (
	SELECT *,
	CASE WHEN CPTCode in ('98966','99441','98016') THEN 1 ELSE 0 END AS MH_under10min
	FROM #past_encounters2
	WHERE ApptCategory='MHRecent'
	) a
GROUP BY VisitSID, VisitDateTime

DROP TABLE IF EXISTS #MH_under10min
SELECT * 
INTO #MH_under10min
FROM #MH_visit
WHERE MH_under10min=1

DROP TABLE IF EXISTS #past_encounters3
SELECT DISTINCT 
	a.MVIPersonSID
	,a.VisitSID
	,a.VisitDateTime
	,a.PrimaryStopCode 
	,a.PrimaryStopCodeName
	,a.SecondaryStopCode
	,a.SecondaryStopCodeName
	,a.ChecklistID
	,a.Facility
	,a.ClinicName
	,a.Provider
	,a.ProviderSID
	,CASE WHEN a.ApptCategory='MHRecent' AND b.MH_under10min=1 THEN 'OtherRecent' ELSE a.ApptCategory END AS ApptCategory
	,b.MH_under10min
	,a.ICMHR
INTO #past_encounters3
FROM #past_encounters2 a
LEFT JOIN #MH_under10min b ON a.VisitSID=b.VisitSID and a.VisitDateTime=b.VisitDateTime

--get rid of chart reviews
DELETE FROM #past_encounters3 where SecondaryStopCode='697'

--Save table of all MH providers to combine with Present.GroupAssignments for Provider/Team parameter 
DROP TABLE IF EXISTS #mh_providers
SELECT DISTINCT 
	b.PatientICN
	,a.MVIPersonSID
	,GroupID=6
	,GroupType='MH Provider'
	,a.ProviderSID
	,a.Provider AS ProviderName
	,a.ChecklistID
	,c.STA3N
	,c.VISN
INTO #mh_providers
FROM #past_encounters3 a
LEFT JOIN [Common].[MasterPatient] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) on a.ChecklistID=c.ChecklistID
WHERE a.ApptCategory='MHRecent'

EXEC [Maintenance].[PublishTable] 'SMI.MHProviders','#mh_providers'


--Calculate number of unique ED visits in past year. Just retain ED stop codes, not urgent care
DROP TABLE IF EXISTS #ED_Count
SELECT MVIPersonSID, COUNT(MVIPersonSID) AS ED_counts_pastyear
INTO #ED_Count
FROM (
	SELECT DISTINCT MVIPersonSID, CAST(VisitDateTime AS DATE) AS VisitDate
	FROM #past_encounters3
	WHERE PrimaryStopCode ='130' or PrimaryStopCodeName like '%Emergency%'
	) a
GROUP BY MVIPersonSID

--Calculate number of MH visits in past year
DROP TABLE IF EXISTS #MH_Count
SELECT MVIPersonSID, COUNT(MVIPersonSID) AS MH_counts_pastyear
INTO #MH_Count
FROM (
	SELECT DISTINCT MVIPersonSID, CAST(VisitDateTime AS DATE) AS VisitDate
	FROM #past_encounters3
	WHERE ApptCategory='MHRecent'
	) a
GROUP BY MVIPersonSID

--Calculate number of ICMHR visits in past 90 days - for HIAS metric
DROP TABLE IF EXISTS #ICMHR_Count
SELECT MVIPersonSID, COUNT(MVIPersonSID) AS ICMHR_counts_90day
INTO #ICMHR_Count
FROM (
	SELECT DISTINCT MVIPersonSID, CAST(VisitDateTime AS DATE) AS VisitDate
	FROM #past_encounters3
	WHERE ICMHR=1 
		AND ApptCategory='MHRecent' 
		AND CAST(VisitDateTime AS DATE) >= DATEADD(day,-91,CAST(getdate() AS DATE))
	) a
GROUP BY MVIPersonSID

--Finally, save most recent encounter for each ApptCategory and merge in counts
DROP TABLE IF EXISTS #past_encounters_final
SELECT a.MVIPersonSID
	,a.VisitSID
	,a.VisitDateTime
	,a.PrimaryStopCode
	,a.PrimaryStopCodeName
	,a.SecondaryStopCode
	,a.SecondaryStopCodeName
	,a.ChecklistID
	,a.Facility
	,a.ClinicName
	,a.Provider
	,a.ApptCategory
	,a.MH_under10min
	,b.ED_counts_pastyear
	,c.MH_counts_pastyear
	,d.ICMHR_counts_90day
INTO #past_encounters_final
FROM (
	SELECT *,RN=row_number() OVER(Partition By MVIPersonSID,ApptCategory Order By VisitDateTime DESC)
	FROM #past_encounters3
	 ) a
LEFT JOIN #ED_Count b ON a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN #MH_Count c ON a.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #ICMHR_Count d ON a.MVIPersonSID=d.MVIPersonSID
WHERE a.RN=1


EXEC [Maintenance].[PublishTable] 'SMI.AppointmentsPast','#past_encounters_final'



------------------------------------------
-- Vista Future Appointments 
------------------------------------------
DROP TABLE IF EXISTS #VistaFutureSIDs;
SELECT
	mvi.MVIPersonSID
	,a.Sta3n
	,a.PatientSID
	,a.AppointmentDateTime
	,a.LocationSID
INTO #VistaFutureSIDs
FROM #cohort c 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON c.MVIPersonSID=mvi.MVIPersonSID
INNER JOIN [Appt].[Appointment] a WITH (NOLOCK) 
	ON a.PatientSID = mvi.PatientPersonSID
WHERE a.AppointmentDateTime > getdate()
	AND a.[CancellationReasonSID] = -1 -- not cancelled

DROP TABLE IF EXISTS #FutureAppointmentVista;
SELECT DISTINCT A.MVIPersonSID
	  ,A.Sta3n
	  ,A.PatientSID
	  ,A.AppointmentDateTime
	  ,C.StopCode AS PrimaryStopCode
	  ,C.StopCodeName AS PrimaryStopCodeName
	  ,F.StopCode AS SecondaryStopCode
	  ,F.StopCodeName AS SecondaryStopCodeName
	  ,CASE WHEN c.PC_Stop=1 or f.StopCode IN ('322','323','350') THEN 'PCFuture'
		 WHEN (c.MHOC_MentalHealth_Stop=1 or c.MHOC_Homeless_Stop=1 or f.MHOC_MentalHealth_Stop=1 or f.MHOC_Homeless_Stop=1) and b.AppointmentLength > 10 THEN 'MHFuture'
		 ELSE 'OtherFuture'
		 END AS ApptCategory
	  ,CASE WHEN (c.MHOC_MentalHealth_Stop=1 or c.MHOC_Homeless_Stop=1 or f.MHOC_MentalHealth_Stop=1 or f.MHOC_Homeless_Stop=1) and b.AppointmentLength <= 10 
		 THEN 1 
		 END AS MH_under10min
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
LEFT JOIN [Dim].[Location] AS B WITH(NOLOCK) ON A.LocationSID=B.LocationSID
LEFT JOIN [LookUp].[StopCode] AS C WITH (NOLOCK) ON B.PrimaryStopCodeSID=C.StopCodeSID
LEFT JOIN [LookUp].[StopCode] AS F WITH (NOLOCK) ON B.SecondaryStopCodeSID=F.StopCodeSID
LEFT JOIN [Dim].[Institution] AS E WITH(NOLOCK) ON B.InstitutionSID=E.InstitutionSID
LEFT JOIN [LookUp].[DivisionFacility] as D WITH(NOLOCK) ON B.DivisionSID=D.DivisionSID

---------------------------------
-- Mill Future Appointments 
---------------------------------
DROP TABLE IF EXISTS #FutureAppointmentMill;
SELECT A.MVIPersonSID
	  ,A.PersonSID
	  ,A.TZBeginDateTime as AppointmentDateTime
	  ,A.AppointmentType
	  ,A.DerivedActivityType
	  ,A.OrganizationNameSID
	  ,A.STA6A
	  ,A.STAPA
	  ,A.TimeDuration
	  ,A.EncounterType --is this or EncounterTypeClass equivalent to MedicalService?
	  ,A.EncounterTypeClass
	  ,CASE WHEN AppointmentType like '%MH%' and a.TimeDuration > 10 THEN 'MHFuture'
		    WHEN AppointmentType like '%PC%' then 'PCFuture'
			ELSE 'OtherFuture'
			END AS ApptCategory
	  ,CASE WHEN a.TimeDuration <= 10 and a.AppointmentType like '%MH%' THEN 1 END AS MH_under10min
	  ,L.Divison as AppointmentDivisionName
	  ,L.OrganizationName as InstitutionName --is this right?
INTO #FutureAppointmentMill
FROM [Cerner].[FactAppointment] AS A WITH(NOLOCK)
INNER JOIN #cohort c on a.MVIPersonSID=c.MVIPersonSID
LEFT JOIN [Cerner].[DimLocations] AS L WITH(NOLOCK) on A.OrganizationNameSID = L.OrganizationNameSID
WHERE ScheduleState <> 'Canceled' 
	AND TZBeginDateTime> getdate()


---------------------------------
-- Combine the two
---------------------------------
DROP TABLE IF EXISTS #FutureAppointment 
SELECT MVIPersonSID
  ,PatientSID
  ,AppointmentDateTime
  ,Sta3n
  ,STA6A
  ,ChecklistID
  ,PrimaryStopCode
  ,PrimaryStopCodeName
  ,SecondaryStopCode
  ,SecondaryStopCodeName
  ,MH_under10min
  ,MedicalService
  ,AppointmentLength
  ,AppointmentDivisionName
  ,AppointmentInstitutionName
  ,AppointmentLocationName
  ,LocationSID
  ,OrganizationNameSID=CAST(NULL as int)
  ,ApptCategory
INTO #FutureAppointment 
FROM #FutureAppointmentVista 
	UNION ALL 
SELECT MVIPersonSID
	,PersonSID
	,AppointmentDateTime
	,Sta3n = 200
	,STA6A
	,STAPA as ChecklistID --is this correct?
    ,PrimaryStopCode=CAST(NULL as varchar)
    ,PrimaryStopCodeName=AppointmentType -- forcing AppointmentType into this so it will show up properly on report
    ,SecondaryStopCode=CAST(NULL as varchar)
    ,SecondaryStopCodeName=CAST(NULL as varchar)
	,MH_under10min
	,MedicalService=CAST(NULL as varchar)
	,TimeDuration AS AppointmentLength
	,AppointmentDivisionName
    ,AppointmentInstitutionName=CAST(NULL as varchar)
    ,AppointmentLocationName=CAST(NULL as varchar)
    ,LocationSID=CAST(NULL as int)
	,OrganizationNameSID
	,ApptCategory
FROM #FutureAppointmentMill c

--get rid of chart reviews
DELETE FROM  #FutureAppointment where SecondaryStopCode='697'

-- Now retain earliest appointment for each ApptCategory
DROP TABLE IF EXISTS #FutureAppointment_final
SELECT MVIPersonSID,
		AppointmentDateTime, 
		PrimaryStopCode, 
		PrimaryStopCodeName,
		SecondaryStopCode, 
		SecondaryStopCodeName,
		ChecklistID,
		Facility,
		AppointmentLocationName as ClinicName,
		ApptCategory,
		MH_under10min --"This visit is less than 10 minutes, therefore does not count toward Mental Health workload"
INTO #FutureAppointment_final
FROM (
	SELECT a.*
		,b.Facility
		,RN=row_number() OVER(Partition By MVIPersonSID,ApptCategory Order By AppointmentDateTime)
	FROM #FutureAppointment a
	LEFT JOIN [LookUp].[ChecklistID] b WITH (NOLOCK) on a.ChecklistID=b.ChecklistID
	) a
WHERE a.RN=1

EXEC [Maintenance].[PublishTable] 'SMI.AppointmentsFuture','#FutureAppointment_final'

EXEC [Log].[ExecutionEnd]

END