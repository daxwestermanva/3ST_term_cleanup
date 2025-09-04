



/* =============================================
-- Author:		Rebecca Stephens
-- Create date: 2018-01-19
-- Description:	Code to get outpatient appointments for patients on HRF dashboard. 
	  Appointments beginning 90 days before the most recent flag action 
	  (activation, continuation, or reactivation) through the present.
	  Visits include MH 500 series (includes phone > 10 min) and PC appt
	  Pulled in to separate code from original HighRisk_Tracking code.
-- Modifications:
	2018-11-08	RAS	- Changed date granularity of HRF_ApptCategory to include appts on same day of flag activation in category 1
--	2019-02-16	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--	2020-06-04	LM - Added new CPT codes for telephone visits based on temporary guidance post-COVID
--	2020-11-04	LM - New metric definition allowing any CPT code for telephone visits except 98966 and 99441 effective 10/1
--	2020-11-04	LM - Cerner overlay (including changes from EC and MP)
--	2020-02-04	SM - Replaced ResponsiblePhysicianPersonStaffSID with DerivedPersonStaffSID for consistency with naming convention of computed fields
--  2020-02-16	SG - Replaced  DerivedPersonStaffSID with ResponsiblePhysicianPersonStaffSID for HotFix
--	2021-02-17	LM - Updated CPT codes for telephone visits based on new metric definition
--  2021-02-18	SA - Replaced ResponsiblePhysicianPersonStaffSID with DerivedPersonStaffSID for consistency with naming convention of computed fields, after hotfix
--	2021-03-08	LM - Fix to correctly include visits that occurred on Day 90 in HRF_ApptCategory=90
--  2021-03-23	SA - Updated reference to field name DerivedVisitDateTimeTZ (from [MillCDS].[FactUtilizationOutpatient]); Changed to TZDerivedVisitDateTime
--  2021-05-18  Jason Bacani - Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
--  2021-08-24	JEB - Enclave Refactoring - Counts confirmed; Some major additional formatting; Added WITH (NOLOCK); Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--	2021-08-24	LM - Updated telephone CPT exclusion for Cerner visits
--  2021-09-15  AW - Changed DerivedAppointmentLocalDateTime and TZDerivedAppointmentLocalDateTime to TZBeginDateTime
--	2022-03-29	LM - Removed e-consults with secondary stop code 697
--  2022-05-02	RAS: Switched reference to LookUp.CPT_VM to Dim.CPT -- changing CPT lookup to List structure, this was a hard-coded definition
--	2022-05-10	LM - Updated stop code and activity type references
--	2022-06-15	LM - Fixed CPT code exclusions for Recurring encounters in Cerner
--	2022-06-22	LM - Pointed to Lookup.StopCode_VM
--	2022-07-06	LM - Limit to visits in past 1 year
--  2022-08-15  SAA_JJR: Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data
--	2022-10-25	LM - Updated to use MHOC_MentalHealth and MHOC_Homeless stop codes to reflect change in metric definition
--	2023-03-07	LM - Added encounters from Cerner.FactUtilizationInpatientVisit to capture MH contacts that occur while the patient is admitted
--	2023-04-05	LM - Added column for location of visit/appointment
--	2024-11-06	LM - Add visits that do not count for HRF, for display on report.  Add visits for patients whose flags were inactivated in past year
--	2025-01-10	LM - Add 98016 to list of CPT exclusions - new 2025 code for 5-10 minute discussion
--
-- Testing execution:
--		EXEC [Code].[PRF_HRS_OutpatDetail]
--
-- Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'Code.PRF_HRS_OutpatDetail'
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 2 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'OutpatDetail' ORDER BY 1 DESC
-- ============================================*/
CREATE PROCEDURE [Code].[PRF_HRS_OutpatDetail] --VisitsAppointments
AS
BEGIN

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_HRS_OutpatDetail', @Description = 'Execution of Code.PRF_HRS_OutpatDetail SP'

	-------------------------------------------------------
	-- CREATE COHORT FOR PatientSID and DATE JOINS
	-------------------------------------------------------
	--Active flags and flags inactivated in the past year
	DROP TABLE IF EXISTS #cohortflags
	SELECT a.MVIPersonSID
		,a.InitialActivation
		,a.EpisodeBeginDateTime
		,a.EpisodeEndDateTime
		,h.MostRecentActivation
		,ISNULL(h.ActionDateTime,a.EpisodeEndDateTime) AS LastActionDateTime
	INTO #cohortflags
	FROM [PRF_HRS].[EpisodeDates] a WITH (NOLOCK)
	LEFT JOIN [PRF_HRS].[ActivePRF] h WITH (NOLOCK)
		ON a.MVIPersonSID=h.MVIPersonSID
	WHERE FlagEpisode=TotalEpisodes --active or most recent record
	AND (a.CurrentActiveFlag=1 OR a.EpisodeEndDateTime >= DateAdd(day,-366,getdate()))
	;
	CREATE INDEX idx_cohortInitial ON #cohortflags (MVIPersonSID,InitialActivation)
	CREATE INDEX idx_cohortCurrent ON #cohortflags (MVIPersonSID,EpisodeBeginDateTime)

	/*****************************************************************
	 GET ALL MH VISITS FOR COHORT 
	******************************************************************/
	--VISTA: Get relevant visits since 90 days before the most recent flag action
	DROP TABLE IF EXISTS #visits
	SELECT DISTINCT 
		 c.MVIPersonSID
		,v.Sta3n
		,c.MostRecentActivation
		,c.EpisodeBeginDateTime
		,c.EpisodeEndDateTime
		,c.LastActionDateTime
		,v.VisitSID
		,v.VisitDateTime 
		,v.PrimaryStopCodeSID   
		,v.SecondaryStopCodeSID 
		,v.DivisionSID	
		,l.LocationName
		,v.WorkloadLogicFlag
		,CASE WHEN v.WorkloadLogicFlag='Y' AND (sc1.MHOC_MentalHealth_Stop = 1 OR sc1.MHOC_Homeless_Stop = 1 OR sc2.MHOC_MentalHealth_Stop=1 OR sc2.MHOC_Homeless_Stop = 1)
			THEN 1 ELSE 0 END AS HRF_Elig
		,CASE WHEN v.WorkloadLogicFlag = 'N' THEN 1 ELSE 0 END AS Inelig_Workload
		,CASE WHEN (sc1.MHOC_MentalHealth_Stop = 1 OR sc1.MHOC_Homeless_Stop = 1 OR sc2.MHOC_MentalHealth_Stop=1 OR sc2.MHOC_Homeless_Stop = 1) THEN 0 ELSE 1 END AS Inelig_Clinic
		,Inelig_CPT=0
	INTO #visits
	FROM [Outpat].[Visit_Recent] v WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON V.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #Cohortflags c
		on  c.MVIPersonSID = mvi.MVIPersonSID 
		--and v.VisitDateTime >= DATEADD(D,-90,CAST(c.LastActionDateTime AS DATE))
    INNER JOIN [Lookup].[StopCode] sc1 WITH (NOLOCK)
	    ON v.primarystopcodesid = sc1.stopcodesid
	LEFT JOIN [Lookup].[StopCode] sc2 WITH (NOLOCK)
		ON v.SecondaryStopCodeSID = sc2.stopcodesid
	LEFT JOIN [Dim].[Location] l WITH (NOLOCK)
		ON v.LocationSID = l.LocationSID
	WHERE CAST(v.VisitDateTime AS date) BETWEEN CAST(c.EpisodeBeginDateTime AS date) AND CAST(ISNULL(c.EpisodeEndDateTime,getdate()) AS date)
	AND v.PrimaryStopCodeSID>0

	;	

	--VISTA: Get stop codes and names for relevant visits
	DROP TABLE IF EXISTS #visitsSC
	SELECT 
		 v.MVIPersonSID
		,v.Sta3n
		,v.MostRecentActivation
		,v.EpisodeBeginDateTime
		,v.EpisodeEndDateTime
		,v.LastActionDateTime
		,v.VisitSID
		,v.VisitDateTime 
		,v.DivisionSID	
		,v.PrimaryStopCodeSID
		,v.LocationName AS Location
		,psc.StopCode AS PrimaryStopCode
		,psc.StopCodeName AS PrimaryStopCodeName
		,ssc.StopCode AS SecondaryStopCode
		,ssc.StopCodeName AS SecondaryStopCodeName
		,CAST(NULL AS VARCHAR) AS ActivityType
		,v.WorkloadLogicFlag
		,v.HRF_Elig
		,v.Inelig_Workload
		,v.Inelig_Clinic
		,v.Inelig_CPT
	INTO #visitsSC
	FROM #visits v
	INNER JOIN [LookUp].[StopCode] psc WITH (NOLOCK) ON v.PrimaryStopCodeSID = psc.StopCodeSID
	LEFT JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) ON v.SecondaryStopCodeSID = ssc.StopCodeSID

	UPDATE #visitsSC
	SET HRF_Elig=0
		,Inelig_Clinic=1
	WHERE SecondaryStopCode = '697'

	EXEC [Tool].[CIX_CompressTemp] '#visitssc','visitsid'

	--get cpt code sids for < 10 minute cpt code to exclude (effective as of 10/1)
	DROP TABLE IF EXISTS #cptexclude
	SELECT CPTSID,CPTCode
	INTO #cptexclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('98966', '99441', '99211', '99212','98016')

	EXEC [Tool].[CIX_CompressTemp] '#cptexclude','cptsid'

	--get cpt code sids for add-on codes that can be used with excluded CPT codes (effective as of 10/1)
	DROP TABLE IF EXISTS #cptinclude;
	SELECT CPTSID,CPTCode
	INTO #cptinclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('90833','90836','90838')

	EXEC [Tool].[CIX_CompressTemp] '#cptinclude','cptsid'

	----get cpt codes for any visit from initial visit query that have phone stop code
	DROP TABLE IF EXISTS #cptoutpat;
	SELECT 
		v.*
		--,ce.CPTCode AS ExcludeCPT --for validation
		--,ci.CPTCode AS IncludeCPT --for validation
		,CASE 
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTCode='98016' THEN NULL --exclude all phone encounters with this CPT code regardless of any add-on codes
			WHEN sc.Telephone_MH_Stop=1 AND ci.CPTSID IS NOT NULL 
				THEN ci.CPTCode -- if one of these CPT codes is used, the visit counts even if an excluded code is also used
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTSID IS NOT NULL 
				THEN NULL --exclude visits with these CPT codes (unless they have one of the included codes accounted for above)
			ELSE 999999 
		END AS CPTCode --999999 => that there is no procedure code requirement
		,p.CPTSID
	INTO #cptoutpat
	FROM #visitssc AS v
	INNER JOIN [Lookup].[StopCode] sc WITH (NOLOCK)
		ON v.PrimaryStopCodeSID = sc.StopCodeSID
	LEFT JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
		ON v.VisitSID = p.VisitSID 
	LEFT JOIN 
		(
			SELECT p.VisitSID, e.CPTSID, e.CPTCode 
			FROM #cptexclude e
			INNER JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
				ON e.CPTSID = p.CPTSID
		) ce 
		ON p.VisitSID = ce.VisitSID
	LEFT JOIN #cptinclude ci 
		ON ci.CPTSID = p.CPTSID
	; 
	--String CPT codes in each encounter for display on report
	DROP TABLE IF EXISTS #CPTDisplay
	SELECT b.VisitSID, LEFT(STRING_AGG(b.CPTCode,','),47) AS CPTCode_Display
	INTO #CPTDisplay
	FROM (SELECT DISTINCT a.VisitSID, c.CPTCode FROM #cptoutpat a
		INNER JOIN [Lookup].[CPT] c WITH (NOLOCK) ON a.CPTSID=c.CPTSID) b
	GROUP BY b.VisitSID

	UPDATE #cptoutpat
	SET HRF_Elig=0
		,Inelig_CPT=1
	WHERE CPTcode is null; 

	--CERNER: Get relevant visits since 90 days before the most recent flag action (including CPT codes)
	--Note: For VistA data we are excluding telephone visits that are incorrectly coded using 99211 and 99212 unless they are used in combination
	--with #cptinclude codes. In Cerner we cannot identify telephone visits using 99211 and 99212 so we leaving this exclusion out 
	DROP TABLE IF EXISTS #VisitsCerner;
	SELECT DISTINCT 
		 co.MVIPersonSID
		,200 AS Sta3n
		,co.MostRecentActivation
		,co.EpisodeBeginDateTime
		,co.EpisodeEndDateTime
		,co.LastActionDateTime
		,v.EncounterSID AS VisitSID
		,v.TZDerivedVisitDateTime AS VisitDateTime
		,p.OrganizationNameSID AS DivisionSID
		,v.Location
		,CAST(NULL AS VARCHAR) AS PrimaryStopCode
		,CAST(NULL AS VARCHAR) AS PrimaryStopCodeName
		,CAST(NULL AS VARCHAR) AS SecondaryStopCode
		,CAST(NULL AS VARCHAR) AS SecondaryStopCodeName
		,v.ActivityType
		--,v.EncounterType --for validation
		--,ce.CPTCode AS CPTExclude --for validation
		--,ci.CPTCode AS CPTInclude --for validation
		,CASE WHEN v.EncounterType='Telephone' AND ce.CPTCode='98016' THEN NULL --exclude all phone encounters with this CPT code regardless of any add-on codes
			WHEN v.EncounterType='Telephone' AND ci.CPTSID IS NOT NULL THEN ci.CPTCode
			WHEN v.EncounterType='Telephone' AND ce.CPTSID IS NOT NULL THEN NULL
			WHEN ce.CPTCode IN ('98966','99441') AND ci.CPTCode IS NULL THEN NULL --telephone CPT codes, may have been used in non-telephone encounter types before Telephone encounter type existed
			ELSE 999999 
			END AS CPTCode --999999 => that there is no procedure code requirement
		,p.SourceIdentifier
		,WorkloadLogicFlag='Y'
		,HRF_Elig=MAX(CASE WHEN lm.list IN ('MHOC_MH','MHOC_Homeless') THEN 1 ELSE 0 END) OVER (PARTITION BY v.EncounterSID,TZDerivedVisitDateTime)
		,Inelig_Workload=0
		,Inelig_Clinic=MIN(CASE WHEN lm.list IN ('MHOC_MH','MHOC_Homeless') THEN 0 ELSE 1 END) OVER (PARTITION BY v.EncounterSID,TZDerivedVisitDateTime)
		,Inelig_CPT=0
	INTO #VisitsCerner
	FROM [Cerner].[FactUtilizationOutpatient] AS v WITH(NOLOCK)
	INNER JOIN #Cohortflags AS co
		ON co.MVIPersonSID=v.MVIPersonSID 
	LEFT JOIN [Cerner].[FactProcedure] as p WITH(NOLOCK) 
		ON v.EncounterSID=p.EncounterSID
	INNER JOIN [Lookup].[ChecklistID] as cg WITH(NOLOCK) 
		ON v.StaPa=cg.StaPa AND v.TZDerivedVisitDateTime>=cg.IOCDate
	LEFT JOIN [LookUp].[ListMember] AS lm WITH(NOLOCK)
		ON v.ActivityTypeCodeValueSID=lm.ItemID AND lm.domain='ActivityType' 
	LEFT JOIN (SELECT p.EncounterType
				,p.EncounterSID
				,CASE WHEN EncounterTypeClass = 'Recurring' OR EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
				,e.CPTCode
				,e.CPTSID FROM #cptexclude AS e
			INNER JOIN [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
			ON e.CPTCode=p.SourceIdentifier)
		AS ce ON p.EncounterSID=ce.EncounterSID AND (ce.TZDerivedProcedureDateTime IS NULL OR ce.TZDerivedProcedureDateTime = v.TZServiceDateTime)
	LEFT JOIN #cptinclude AS ci ON p.SourceIdentifier=ci.CPTCode
	WHERE CAST(v.TZDerivedVisitDateTime AS date) BETWEEN CAST(co.EpisodeBeginDateTime AS date) AND CAST(ISNULL(co.EpisodeEndDateTime,getdate()) AS date)

	UNION ALL

	SELECT DISTINCT 
		 co.MVIPersonSID
		,200 AS Sta3n
		,co.MostRecentActivation
		,co.EpisodeBeginDateTime
		,co.EpisodeEndDateTime
		,co.LastActionDateTime
		,v.EncounterSID AS VisitSID
		,v.TZServiceDateTime AS VisitDateTime
		,ip.OrganizationNameSID AS DivisionSID
		,ip.Location
		,CAST(NULL AS VARCHAR) AS PrimaryStopCode
		,CAST(NULL AS VARCHAR) AS PrimaryStopCodeName
		,CAST(NULL AS VARCHAR) AS SecondaryStopCode
		,CAST(NULL AS VARCHAR) AS SecondaryStopCodeName
		,v.ActivityType
		--,v.EncounterType --for validation
		--,ce.CPTCode AS CPTExclude --for validation
		--,ci.CPTCode AS CPTInclude --for validation
		,CPTCode = 99999 --no CPT code exclusion for inpatient encounters
		,SourceIdentifier=NULL
		,WorkloadLogicFlag='Y'
		,HRF_Elig=MAX(CASE WHEN lm.list IN ('MHOC_MH','MHOC_Homeless') THEN 1 ELSE 0 END) OVER (PARTITION BY v.EncounterSID,TZServiceDateTime)
		,Inelig_Workload=0
		,Inelig_Clinic=MIN(CASE WHEN lm.list IN ('MHOC_MH','MHOC_Homeless') THEN 0 ELSE 1 END) OVER (PARTITION BY v.EncounterSID,TZServiceDateTime)
		,Inelig_CPT=0
	FROM [Cerner].[FactUtilizationInpatientVisit] AS v WITH(NOLOCK)
	INNER JOIN #Cohortflags AS co
		ON co.MVIPersonSID=v.MVIPersonSID 
	INNER JOIN [Cerner].[FactInpatient] ip WITH (NOLOCK) ON v.EncounterSID = ip.EncounterSID
	INNER JOIN [Lookup].[ChecklistID] as cg WITH(NOLOCK) 
		ON ip.StaPa=cg.StaPa AND v.TZServiceDateTime>=cg.IOCDate
	LEFT JOIN [LookUp].[ListMember] AS lm WITH(NOLOCK)
		ON v.ActivityType=lm.AttributeValue AND lm.domain='ActivityType'
	WHERE CAST(v.TZServiceDateTime AS date) BETWEEN CAST(co.EpisodeBeginDateTime AS date) AND CAST(ISNULL(co.EpisodeEndDateTime,getdate()) AS date)

	--In cases where there are multiple charges in an encounter, and one counts for the metric but others do not, remove the ones that didn't count
	DELETE FROM #VisitsCerner
	WHERE HRF_Elig=1 AND ActivityType NOT IN (SELECT AttributeValue FROM Lookup.ListMember WHERE Domain='ActivityType' AND List IN  ('MHOC_MH','MHOC_Homeless') )

	;
	DROP TABLE IF EXISTS #CPTDisplay_Cerner
	SELECT DISTINCT a.VisitSID, LEFT(STRING_AGG(a.SourceIdentifier,','),47) AS CPTCode_Display
	INTO #CPTDisplay_Cerner
	FROM (SELECT DISTINCT VisitSID, SourceIdentifier FROM #VisitsCerner) a
	GROUP BY a.VisitSID

	UPDATE #VisitsCerner 
	SET HRF_Elig=0
		,Inelig_CPT=1
	WHERE CPTcode IS NULL


	DROP TABLE IF EXISTS #CombinedVisits
	SELECT DISTINCT a.MVIPersonSID,a.Sta3n
		,a.MostRecentActivation,a.EpisodeBeginDateTime,a.EpisodeEndDateTime,a.LastActionDateTime
		,a.VisitSID,a.VisitDateTime,a.DivisionSID,a.Location
		,a.PrimaryStopCode,a.PrimaryStopCodeName
		,a.SecondaryStopCode,a.SecondaryStopCodeName
		,a.ActivityType, a.WorkloadLogicFlag, b.CPTCode_Display
		,a.HRF_Elig,a.Inelig_Workload,a.Inelig_CPT,a.Inelig_Clinic
	INTO #CombinedVisits
	FROM #cptoutpat a
	LEFT JOIN #CPTDisplay b ON a.VisitSID=b.VisitSID
	UNION ALL
	SELECT DISTINCT a.MVIPersonSID,a.Sta3n
		,a.MostRecentActivation,a.EpisodeBeginDateTime,a.EpisodeEndDateTime,a.LastActionDateTime
		,a.VisitSID,a.VisitDateTime,a.DivisionSID,a.Location
		,a.PrimaryStopCode,a.PrimaryStopCodeName
		,a.SecondaryStopCode,a.SecondaryStopCodeName
		,a.ActivityType, a.WorkloadLogicFlag, b.CPTCode_Display
		,a.HRF_Elig,a.Inelig_Workload,a.Inelig_CPT,a.Inelig_Clinic
	FROM #VisitsCerner a
	LEFT JOIN #CPTDisplay_Cerner b ON a.VisitSID=b.VisitSID


	---------------------------------
	--APPOINTMENT INFORMATION (FUTURE & CANCELLED/NO SHOWS)
	---------------------------------

	--------------------------------------------------------------------------------------------------------------
	/****************************************VistA Appointment**********************************************/
	--------------------------------------------------------------------------------------------------------------
	DECLARE @StartAppt DATETIME2 = DATEADD(D,-90, DATEDIFF(D, 0, CAST(GETDATE() AS DATE)))
	DECLARE @EndAppt DATETIME2 = DATEADD(MS,-3,DATEADD(D,31, DATEDIFF(D, 0, CAST(GETDATE() AS DATE))))

	DROP TABLE IF EXISTS #appt;
	SELECT DISTINCT 
		 c.MVIPersonSID
		,appt.Sta3n
		,c.InitialActivation
		,c.MostRecentActivation
		,c.EpisodeBeginDateTime
		,c.EpisodeEndDateTime
		,c.LastActionDateTime
		,appt.AppointmentSID
		,appt.AppointmentDateTime
		,CASE WHEN appt.AppointmentStatus IS NULL and appt.AppointmentDateTime>=getdate() THEN 'FUT'
				WHEN appt.AppointmentStatus IS NULL THEN '*Missing*'
				ELSE appt.AppointmentStatus 
		END AS AppointmentStatusAbbrv
		--,appt.CancelNoShowCode
		,appt.CancellationReasonSID
		,appt.CancellationRemarks
		,appt.CancelDateTime
		,DATEDIFF(d,appt.AppointmentDateTime,appt.CancelDateTime) AS CancelTiming
		,loc.PrimaryStopCodeSID
		,loc.SecondaryStopCodeSID
		,psc.StopCode AS PriStopCode
		,psc.StopCodeName AS PriStopCodeName
		,ssc.StopCode AS SecStopCode
		,ssc.StopCodeName AS SecStopCodeName
		,loc.DivisionSID
		,loc.LocationName
		,appt.VisitSID
	INTO #appt
	FROM #cohortflags c
	INNER JOIN 
		(
			SELECT 
				mvi.MVIPersonSID
				,appt1.AppointmentSID
				,appt1.Sta3n
				,appt1.AppointmentStatus
				,appt1.CancellationReasonSID
				,appt1.CancellationRemarks
				,appt1.VisitSID
				,appt1.AppointmentDateTime
				,appt1.CancelDateTime
				,appt1.LocationSID
			FROM [Appt].[Appointment] appt1 WITH (NOLOCK) 
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON appt1.PatientSID = mvi.PatientPersonSID 
			WHERE appt1.AppointmentDateTime BETWEEN @StartAppt AND @EndAppt
		) appt	
		on c.MVIPersonSID = appt.MVIPersonSID 
	INNER JOIN [Dim].[Location] loc WITH (NOLOCK) 
		ON loc.LocationSID = appt.LocationSID
	INNER JOIN [LookUp].[StopCode] psc WITH (NOLOCK) 
		ON loc.PrimaryStopCodeSID = psc.StopCodeSID
	INNER JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) 
		ON loc.SecondaryStopCodeSID = ssc.StopCodeSID
	WHERE appt.AppointmentDateTime BETWEEN @StartAppt AND @EndAppt
	AND (psc.MHOC_MentalHealth_Stop = 1 OR psc.MHOC_Homeless_Stop = 1 OR ssc.MHOC_MentalHealth_Stop = 1 OR ssc.MHOC_Homeless_Stop = 1)
	;

	--------------------------------------------------------------------------------------------------------------
	/****************************************Cerner Appointment**********************************************/
	--------------------------------------------------------------------------------------------------------------

	DROP TABLE IF EXISTS #MillAppt
	SELECT DISTINCT 
		 c.MVIPersonSID
		,Sta3n=200
		,c.InitialActivation
		,c.MostRecentActivation
		,c.EpisodeBeginDateTime
		,c.EpisodeEndDateTime
		,c.LastActionDateTime
		,appt.PersonSID
		,appt.TZBeginDateTime
		,appt.ScheduleState
		,appt.STAPA -- checklistID
		,appt.STA6A -- sta6aid
		,CASE 
			WHEN ScheduleState <> 'Canceled' AND TZBeginDateTime >= GETDATE() THEN 'FUT'
			WHEN ScheduleState = 'No Show' THEN 'N'
			WHEN ScheduleState = 'Checked Out' THEN 'CO'
			WHEN ScheduleState = 'Checked In' THEN 'CI'
			WHEN ScheduleState = 'Canceled' THEN 'C'
		END AS AppointmentStatusAbbrv
		,CancelTiming=DateDiff(d,appt.TZBeginDateTime,appt.TZDerivedCancelDateTime)
		,CancelDateTime = appt.TZDerivedCancelDateTime
		,appt.DerivedCancelReason as CancelReason
		,appt.EncounterType
		,appt.EncounterTypeClass
		,appt.EncounterSID
		,appt.DerivedActivityType
		,appt.OrganizationNameSID AS DivisionSID
		,appt.AppointmentLocation
		,appt.AppointmentType
	INTO #MillAppt
	FROM #cohortflags as c
	INNER JOIN [Cerner].[FactAppointment] appt WITH (NOLOCK) 
		ON appt.MVIPersonSID = c.MVIPersonSID 
	LEFT JOIN [Lookup].[ListMember] lm WITH (NOLOCK) 
		ON appt.derivedactivitytype LIKE '%'+lm.attributevalue+'%' 
	INNER JOIN [Lookup].[ChecklistID] i WITH (NOLOCK) 
		ON appt.StaPa = i.StaPa 
		AND appt.TZBeginDateTime >= i.IOCDate
	WHERE appt.TZBeginDateTime BETWEEN @StartAppt AND @EndAppt 
		AND (
			(lm.list IN ('MHOC_MH','MHOC_Homeless') AND lm.Domain LIKE 'ActivityType') --For cancelled past visits -- should add equivalent stop code 156, 157 when it becomes available
			OR (appt.AppointmentType LIKE 'MH%') --use appointmenttype for future appts/no-shows since there is no activity type? Guessing on this for now.
			)
	/*
	Original code looks for:  Visits include MH 500 series (includes phone > 10 min) and PC appt
	--0 rows bc not enough test data, cohort is not that big?
	*/
	--------------------------------------------------------------------------------------------------------------
	/****************************************VistA CleanUp**********************************************/
	--------------------------------------------------------------------------------------------------------------
	--delete from previous table appointments in the past that are not cancels or no shows (appts happened)
	--OR appointments that were canceled more than 30 days before appt
	DELETE #appt
	WHERE (AppointmentDateTime < GETDATE()
		and AppointmentStatusAbbrv NOT IN ('C','CA','PC','PCA','N','NA'))
	  OR (AppointmentStatusAbbrv IN ('C','CA','PC','PCA','N','NA')
		  and CancelTiming < -30)
	;

	-------------------------------------------------------------------------------------------------------------
	/****************************************Cerner Cleanup**********************************************/
	--------------------------------------------------------------------------------------------------------------
	--delete from previous table appointments in the past that are not cancels or no shows (appts happened)
	--OR appointments that were canceled more than 30 days before appt
	--*Note: we're seeing cancel dates that are after the appointment date, so keep monitoring this
	DELETE #MillAppt
	WHERE (TZBeginDateTime<GetDate()
			AND ScheduleState not in ('No Show','Canceled'))
	   OR (ScheduleState in ('No Show','Canceled')
		  and CancelTiming<-30)
	;

	--------------------------------------------------------------------------------------------------------------
	/****************************************VistA Appt Descriptions**********************************************/
	--------------------------------------------------------------------------------------------------------------

	--LookUp Appointment Status descriptions
	DROP TABLE IF EXISTS #status;
	SELECT DISTINCT AppointmentStatus,AppointmentStatusAbbreviation 
	INTO #status 
	FROM [Dim].[AppointmentStatus] WITH (NOLOCK)
	WHERE AppointmentStatusAbbreviation NOT IN ('I','DEL') --inpatient or deleted
	; 
	INSERT INTO #status VALUES ('FUTURE','FUT'); -- add in a row for Future appointments

	--Add details
	DROP TABLE IF EXISTS #apptstatus;
	SELECT a.*
		  ,AppointmentStatus
		  ,CancellationReason
	INTO #apptstatus
	FROM #appt a 
	INNER JOIN #status s 
		ON s.AppointmentStatusAbbreviation = a.AppointmentStatusAbbrv
	LEFT JOIN [Dim].[CancellationReason] r WITH (NOLOCK) 
		ON r.CancellationReasonSID = a.CancellationReasonSID
	;

	--------------------------------------------------------------------------------------------------------------
	/****************************************Cerner Appt Descriptions**********************************************/
	--------------------------------------------------------------------------------------------------------------
	--LookUp Appointment Status descriptions
	DROP TABLE IF EXISTS #MillStatus;
	SELECT DISTINCT AppointmentStatus, AppointmentStatusAbbreviation
	INTO #MillStatus 
	FROM [Cerner].[DimAppointmentStatus] WITH (NOLOCK)--[CDW2].[CDS_DimAppointmentStatus]
	WHERE AppointmentStatus NOT IN ('Deleted') --inpatient or deleted (no inpatient in appointmentstatus)
	; 
	INSERT INTO #MillStatus VALUES ('FUTURE','FUT'); -- add in a row for Future appointments

	--Add details
	-- link between CDW2.CDS_DimAppointmentStatus and CDW2.CDS_Appointments has been added: AppointmentStatusIEN, but maybe don't need this doesn't add any new data
	DROP TABLE IF EXISTS #MillApptStatus;
	SELECT a.*
		  ,s.AppointmentStatus AS MillStatus
	INTO #MillApptStatus
	FROM #MillAppt a 
	INNER JOIN #MillStatus s 
		ON s.AppointmentStatusAbbreviation = a.AppointmentStatusAbbrv

	---------------------------------
	DROP TABLE IF EXISTS #all;
	SELECT 
		 MVIPersonSID
		,MostRecentActivation
		,EpisodeBeginDateTime
		,EpisodeEndDateTime
		,LastActionDateTime
		,OutpatDateTime=VisitDateTime
		,PrimaryStopCode
		,ISNULL(PrimaryStopCodeName,ActivityType) AS PrimaryStopCodeName
		,SecondaryStopCode
		,SecondaryStopCodeName
		,Sta3n
		,DivisionSID
		,Location
		,'CO' AS AppointmentStatusAbbrv
		,'COMPLETE' AS AppointmentStatus
		,NULL AS CancellationReason
		,NULL AS CancelDateTime
		,NULL AS CancellationRemarks
		,NULL AS CancelTiming
		,VisitSID
		,WorkloadLogicFlag
		,CPTCode_Display
		,HRF_Elig
		,Inelig_Workload
		,Inelig_CPT
		,Inelig_Clinic
	INTO #all
	FROM #CombinedVisits--#visitssc
	UNION ALL
	SELECT 
		 MVIPersonSID
		,MostRecentActivation
		,EpisodeBeginDateTime
		,EpisodeEndDateTime
		,LastActionDateTime
		,AppointmentDateTime AS OutpatDateTime
		,PriStopCode
		,PriStopCodeName
		,SecStopCode
		,SecStopCodeName
		,Sta3n
		,DivisionSID
		,LocationName
		,AppointmentStatusAbbrv
		,AppointmentStatus
		,CancellationReason
		,CancelDateTime
		,CancellationRemarks
		,CancelTiming
		,VisitSID
		,WorkloadLogicFlag=NULL
		,CPTCode_Display=NULL
		,HRF_Elig=NULL
		,Inelig_Workload=NULL
		,Inelig_CPT=NULL
		,Inelig_Clinic=NULL
	FROM #apptstatus
	UNION ALL
	SELECT MVIPersonSID
		  ,MostRecentActivation
		  ,EpisodeBeginDateTime
		  ,EpisodeEndDateTime
		  ,LastActionDateTime
		  ,TZBeginDateTime AS OutpatDateTime
		  ,CAST(NULL AS VARCHAR) AS PriStopCode
		  ,AppointmentType AS PriStopCodeName
		  ,CAST(NULL AS VARCHAR) AS SecStopCode
		  ,CAST(NULL AS varchar) AS SecStopCodeName
		  ,200 AS Sta3n
		  ,DivisionSID
		  ,AppointmentLocation
		  ,AppointmentStatusAbbrv
		  ,ScheduleState AS AppointmentStatus
		  ,CancelReason AS CancellationReason
		  ,CancelDateTime
		  ,CAST(NULL AS VARCHAR) AS CancellationRemarks
		  ,CancelTiming
		  ,EncounterSID AS VisitSID
		  ,WorkloadLogicFlag=NULL
		  ,CPTCode_Display=NULL
		  ,HRF_Elig=NULL
		  ,Inelig_Workload=NULL
		  ,Inelig_CPT=NULL
		  ,Inelig_Clinic=NULL
	FROM #MillApptStatus
	; 

	--Add Provider Info
	DROP TABLE IF EXISTS #VisitSID
	SELECT DISTINCT VisitSID 
	INTO #visitsid	
	FROM #all 
	WHERE VisitSID > -1
	EXEC [Tool].[CIX_CompressTemp] '#visitsid','visitsid'

	DROP TABLE IF EXISTS #Provider;
	SELECT 
		 p.ProviderSID
		,p.VisitSID 
		,s.StaffName
	INTO #Provider
	FROM [Outpat].[VProvider] p WITH (NOLOCK) 
	INNER JOIN #visitSID v 
		ON v.VisitSID = p.VisitSID
	LEFT JOIN [SStaff].[SStaff] s WITH (NOLOCK) 
		ON p.ProviderSID = s.StaffSID
	UNION
	SELECT 
		 p.PersonStaffSID
		,o.EncounterSID
		,p.NameFullFormatted
	FROM [Cerner].[FactUtilizationOutpatient] o WITH (NOLOCK)
	INNER JOIN [Cerner].[FactStaffDemographic] p WITH (NOLOCK) 
		ON o.DerivedPersonStaffSID = p.PersonStaffSID
	INNER JOIN #visitSID v 
		ON v.VisitSID = o.EncounterSID

	EXEC [Tool].[CIX_CompressTemp] '#provider','visitsid'

	DROP TABLE IF EXISTS #withProv;
	SELECT a.*, ProviderSID, StaffName
	INTO #withProv
	FROM #all a
	LEFT JOIN #provider p 
		ON p.VisitSID=a.VisitSID
	; 

	--Add Location Info
	DROP TABLE IF EXISTS #OutpatFinal;
	SELECT 
		 a.*
		,s.Sta6a
		,div.DivisionName
		,s.ChecklistID
	INTO #OutpatFinal
	FROM #withProv a 
	INNER JOIN [Dim].[Division] div WITH (NOLOCK) 
		ON div.DivisionSID = a.DivisionSID
	LEFT JOIN [LookUp].[Sta6a] s WITH (NOLOCK) 
		ON s.Sta6a = div.Sta6a
	UNION ALL
	SELECT 
		 a.*
		,loc.Sta6a
		,loc.Divison
		,loc.STAPA 
	FROM #withProv as a 
	INNER JOIN [Cerner].[DimLocations] loc WITH (NOLOCK) 
		ON a.DivisionSID = loc.OrganizationNameSID
	;

	/* Make a status column?
	0 - Appt completed, but not in relevant 90 day window
	1 - Appt complete, counted in 90 day follow up
	2 - Future appointment
	3 - Past appt date, canceled
	4 - Past appt date, no show
	5 - Future appt date, canceled
	6 - Past visits that do not count for HRF based on workload, stop code, or CPT code
	*/
	ALTER TABLE #OutpatFinal
	ADD HRF_ApptCategory tinyint;

	UPDATE #OutpatFinal	
	SET HRF_ApptCategory =
			CASE 
				WHEN HRF_Elig = 0 AND AppointmentStatusAbbrv = 'CO' THEN 6 
				WHEN AppointmentStatusAbbrv IN ('C','CA','PC','PCA','N','NA') AND OutpatDateTime >= GETDATE() THEN 5
				WHEN AppointmentStatusAbbrv IN ('N','NA') AND OutpatDateTime < GETDATE() THEN 4
				WHEN AppointmentStatusAbbrv IN ('C','CA','PC','PCA') AND OutpatDateTime < GETDATE() THEN 3
				WHEN AppointmentStatusAbbrv = 'FUT' THEN 2
				WHEN AppointmentStatusAbbrv = 'CO' AND CAST(OutpatDateTime AS DATE) BETWEEN CAST(ISNULL(MostRecentActivation,LastActionDateTime) AS DATE) AND DATEADD(d,90,CAST(LastActionDateTime AS DATE)) THEN 1 
				ELSE 0 
			END;

	DROP TABLE IF EXISTS #staging;
	SELECT DISTINCT
		 MVIPersonSID
		,EpisodeBeginDateTime
		,EpisodeEndDateTime
		,OutpatDateTime
		,PrimaryStopCode
		,PrimaryStopCodeName
		,SecondaryStopCode
		,SecondaryStopCodeName
		,AppointmentStatusAbbrv
		,AppointmentStatus
		,CancellationReason
		,CancelDateTime
		,CancellationRemarks
		,CancelTiming
		,VisitSID
		,ProviderSID
		,StaffName
		,Sta3n
		,Sta6a
		,DivisionName
		,Location
		,ChecklistID
		,WorkloadLogicFlag
		,CPTCode_Display
		,HRF_ApptCategory
		,Inelig_Category=CASE WHEN Inelig_Workload=1 AND Inelig_CPT=1 AND Inelig_Clinic=1 THEN 1 --Ineligible due to workload, CPT code, and stop code
			WHEN Inelig_Workload=1 AND Inelig_CPT=1 AND Inelig_Clinic=0 THEN 2 --Ineligible due to workload and CPT code
			WHEN Inelig_Workload=1 AND Inelig_CPT=0 AND Inelig_Clinic=1 THEN 3 --Ineligible due to workload and stop code
			WHEN Inelig_Workload=0 AND Inelig_CPT=1 AND Inelig_Clinic=1 THEN 4 --Ineligible due to CPT code and stop code
			WHEN Inelig_Workload=1 AND Inelig_CPT=0 AND Inelig_Clinic=0 THEN 5 --Ineligible due to workload only
			WHEN Inelig_Workload=0 AND Inelig_CPT=0 AND Inelig_Clinic=1 THEN 6 --Ineligible due to stop code only
			WHEN Inelig_Workload=0 AND Inelig_CPT=1 AND Inelig_Clinic=0 THEN 7 --Ineligible due to CPT code only
			END
	INTO #staging
	FROM #OutpatFinal a;

	--Only keep ineligible visits that occurred in past 90 days
	DELETE FROM #staging
	WHERE HRF_ApptCategory=6 AND OutpatDateTime < DateAdd(day,-90,ISNULL(EpisodeEndDateTime,getdate()))

	---------------------------------
	--CREATE FINAL TABLE
	---------------------------------
	EXEC [Maintenance].[PublishTable] 'PRF_HRS.OutpatDetail', '#staging'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END