-- ==========================================================================================
-- Authors:		Claire Hannemann and Amy Robinson
-- Create date: 6/22/2022
-- Description: BHIP Panel Management Tool
--				Main stored proc to create tables BHIP.PatientDetails and BHIP.RiskFactors
-- Modifications:
--
-- 8/16/2023  CW  Adding generalized clinical reminder/screen logic into dataset
-- 9/14/2023  CMH Changing CSRE logic to pull directly from OMHSP_Standard.CSRE
-- 1/8/2024   CW  Updating criteria for 'BHIP' team (2/2 changes made to Present.Providers)
-- 1/25/2024  CW  Fixing most recent suicide screen output
-- 3/12/2024  CW  Adding SP 2.0 Clin Consult info for PowerBI quick view
-- 3/18/2024  CW  Fixing lookback time frame for MST screens
--				  Data source change, now using SBOSR SDV label for the following RiskFactor:
--				  'Most recent suicide attempt or overdose' 
-- 4/16/2024  CNB Replacing non-required I9 (stand alone) Depression screens with PHQ-2/PHQ-9 depression screens
-- 7/8/2024   CW  Adjusting rules for Last BHIP Contact. Instead of looking for last MHTC contact, will now look for
--				  contact with anyone on BHIP team. Note: only TeamType='BHIP' will be included (not TeamType='MH')
--					Update PTSD screen to remove Skipped (-99) cases
-- 7/10/2024  CNB Update depression screen to clarify which was completed. 
-- 10/16/2024 CW  Incorporating Overdue Screen data. 
--				  Changing 'Overdue Screen' label to 'Potential Screening Need'.
-- 10/22/2024 CW  Changing data source for tobacco screens
-- 10/25/2024 CNB Updates datasource for SPED data and updates code relevant to data source columns and design
-- 11/8/2024  CW  Changing method for pulling Unassigned Veterans. Now based on past/future appointment location instead of HomeStation.
-- 12/17/2024 CW  Adding patients to denominator cohort: no BHIP team, but has an admission to MH unit in prior year.
-- 12/18/2021 CW  Adding BHIP assessment information to the risk factors.
-- 12/19/2024 CW  Updating OverdueFlag criteria to include overdue flags or upcoming due flags.
-- 3/19/2025  CW  Adding to BHIP_RiskFactors table: TobaccoPositiveScreen.
--				  Adding to BHIP_PatientDetails table: Homeless.
--				  Removed #PROMS as it's no longer needed for the report. Instead, set up feed into MissedAppointments table for Power BI report.
-- 6/11/2025  CW  Bug fix with last BHIP contact
-- 7/15/2025  CW  Adding MPR and Overdue Injection; Will become part of new aggregate in action bar (PBI report) - Rx Adherence Concerns
-- 7/29/2025  CW  Ensuring no TestPatients make their way into the denominator cohort
-- ==========================================================================================
CREATE PROCEDURE [Code].[BHIP_PatientDetails]
	
AS
BEGIN

-- =================================================================================================
--  Create cohort  - currently assigned BHIP -or- MH appointment in last year and unassigned BHIP
-- =================================================================================================
	--Currently assigned to BHIP team 
	DROP TABLE IF EXISTS #BHIP 
	SELECT PatientSID
		,MVIPersonSID
		,PatientICN
		,TeamSID
		,Team 
		,Sta6a
		,ChecklistID
		,RelationshipStartDate
		,DivisionName
	INTO #BHIP
	FROM (
			SELECT PatientSID
				  ,MVIPersonSID
				  ,PatientICN
				  ,TeamSID
				  ,Team 
				  ,Sta6a
				  ,ChecklistID
				  ,RelationshipStartDateTime AS RelationshipStartDate
				  ,DivisionName
				  ,ROW_NUMBER() OVER(PARTITION BY PatientSID,ActiveAny ORDER BY CASE WHEN ProvType='MHTC' then 1 else 0 end DESC, RelationshipStartDateTime DESC) TeamRank_SID
			FROM [Common].[Providers] WITH (NOLOCK)
			WHERE TeamType IN ('BHIP','MH') 
			) a
	WHERE TeamRank_SID=1;
	-- about 38k patients are assigned to more than one BHIP team, one person has 6 teams

	--Not assigned to BHIP but had a MH encounter in prior year - assign encounter location as ChecklistID for report
	DROP TABLE IF EXISTS #Unassigned_Past
	SELECT DISTINCT
		a.MVIPersonSID
		,d.PatientICN
		,TeamSID=NULL
		,'Not Assigned to MH Team' as Team
		,a.ChecklistID
		,CAST(a.VisitDateTime as date) as VisitDateTime
	INTO #Unassigned_Past
	FROM Present.AppointmentsPast a WITH (NOLOCK)
	LEFT JOIN #BHIP b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID 
	LEFT JOIN Common.vwMVIPersonSIDPatientICN d WITH (NOLOCK) on a.MVIPersonSID=d.MVIPersonSID
	WHERE a.ApptCategory='MHRecent' and b.MVIPersonSID is NULL and MostRecent_SID=1;

	--Not assigned to BHIP but has a MH encounter in future year - assign encounter location as ChecklistID for report
	DROP TABLE IF EXISTS #Unassigned_Future
	SELECT DISTINCT
		f.MVIPersonSID
		,d.PatientICN
		,TeamSID=NULL
		,'Not Assigned to MH Team' as Team
		,f.ChecklistID
		,VisitDateTime=CAST(NULL as DATE)
	INTO #Unassigned_Future
	FROM Present.AppointmentsFuture f WITH (NOLOCK) 
	LEFT JOIN #BHIP b WITH (NOLOCK) on f.MVIPersonSID=b.MVIPersonSID 
	LEFT JOIN Common.vwMVIPersonSIDPatientICN d WITH (NOLOCK) on f.MVIPersonSID=d.MVIPersonSID
	WHERE f.ApptCategory='MHFuture' and b.MVIPersonSID is NULL and NextAppt_SID=1;

	--Not assigned to BHIP but had MH inpatient admission in prior year, or who are current admitted
	DROP TABLE IF EXISTS #Unassigned_Inpatient
	SELECT DISTINCT i.MVIPersonSID
		,m.PatientICN
		,TeamSID=NULL
		,'Not Assigned to MH Team' as Team
		,i.ChecklistID
		,VisitDateTime=cast(i.AdmitDateTime as date)
	INTO #Unassigned_Inpatient
	FROM Inpatient.BedSection i WITH (NOLOCK)
	LEFT JOIN #BHIP b WITH (NOLOCK) on i.MVIPersonSID=b.MVIPersonSID 
	LEFT JOIN Common.vwMVIPersonSIDPatientICN m WITH (NOLOCK) on i.MVIPersonSID=m.MVIPersonSID
	WHERE MentalHealth_TreatingSpecialty=1
	AND b.MVIPersonSID is NULL
	AND (AdmitDateTime >= dateadd(year, -1, getdate()) OR Census=1)

	--Combine Unassigned - past and future locations
	--Only accounting for past VisitDateTimes to keep dashboard display consistent with its labels (Last MH Visit)
	DROP TABLE IF EXISTS #Unassigned
	SELECT MVIPersonSID, PatientICN, TeamSID, Team, ChecklistID, MAX(VisitDateTime) as VisitDateTime
	INTO #Unassigned
	FROM (	SELECT *
			FROM #Unassigned_Past
			UNION
			SELECT *
			FROM #Unassigned_Future
			UNION
			SELECT *
			FROM #Unassigned_Inpatient
			) Src
	GROUP BY MVIPersonSID, PatientICN, TeamSID, Team, ChecklistID
	
	--Combine
	DROP TABLE IF EXISTS #StageCohort
	SELECT MVIPersonSID
			,PatientICN
			,TeamSID
			,Team 
			,ChecklistID
			,RelationshipStartDate
	INTO #StageCohort
	FROM #BHIP 
	UNION 
	SELECT  MVIPersonSID
			,PatientICN
			,TeamSID
			,Team 
			,ChecklistID
			,NULL
	FROM #Unassigned;

	DROP TABLE IF EXISTS #Cohort 
	SELECT a.[MVIPersonSID]
		  ,a.[PatientICN]
		  ,a.[TeamSID]
		  ,a.[Team]
		  ,a.[ChecklistID]
		  ,a.[RelationshipStartDate]
	INTO #Cohort
	FROM #StageCohort a
	left join Common.MasterPatient as p WITH (NOLOCK) on a.MVIPersonSID=p.MVIPersonSID
	where p.DateOfDeath_Combined is null 
		and p.MVIPersonSID > 0
		and TestPatient=0;

---------------------------------------------------------------
--Find date of last BHIP contact in past two years
---------------------------------------------------------------
	DROP TABLE IF EXISTS #LastBHIPContact
	SELECT MVIPersonSID, max(VisitDateTime) as LastBHIPContact
	INTO #LastBHIPContact
	FROM  (
			SELECT co.MVIPersonSID, a.VisitDateTime
			FROM #Cohort as co 
			inner join Common.MVIPersonSIDPatientPersonSID m WITH (NOLOCK) on co.MVIPersonSID=m.MVIPersonSID
			inner join Outpat.VProvider as a WITH (NOLOCK) on a.PatientSID = m.PatientPersonSID
			inner join Present.Provider_Active as b WITH (NOLOCK) on co.MVIPersonSID=b.MVIPersonSID and a.ProviderSID = b.PrimaryProviderSID and co.TeamSID = b.TeamSID AND b.TeamType IN ('BHIP')
			WHERE a.VisitDateTime > DATEADD(day,-730,getdate()) and a.WorkloadLogicFlag='Y'
			UNION
			SELECT co.MVIPersonSID, a.TZDerivedVisitDateTime as VisitDateTime 
			FROM #Cohort as co 
			inner join Common.MVIPersonSIDPatientPersonSID m WITH (NOLOCK) on co.MVIPersonSID=m.MVIPersonSID
			inner join Cerner.FactUtilizationOutpatient as a WITH (NOLOCK) on a.PersonSID = m.PatientPersonSID
			inner join [Cerner].[FactStaffDemographic] as d WITH (NOLOCK) on a.DerivedPersonStaffSID=d.PersonStaffSID
			inner join Present.Provider_Active as b WITH (NOLOCK) on co.MVIPersonSID=b.MVIPersonSID and d.EDIPI = convert(varchar,b.ProviderEDIPI) and co.TeamSID = b.TeamSID AND b.TeamType IN ('BHIP')
			WHERE a.TZDerivedVisitDateTime > DATEADD(day,-730,getdate())
		) a
	GROUP BY MVIPersonSID;

---------------------------------------------------------------
--Create temp table for risk factors
---------------------------------------------------------------
	DROP TABLE IF EXISTS #BHIP_RiskFactors
	CREATE TABLE #BHIP_RiskFactors (
		 MVIPersonSID INT NOT NULL
		,RiskFactor varchar(100)
		,ChecklistID varchar(5)
		,Facility varchar(100)
		,EventValue varchar(200)
		,EventDate date
		,LastBHIPContact date 
		,Actionable int
		,OverdueFlag int
		,ActionExpected varchar(50) 
		,ActionLabel varchar(50)
		,Code nvarchar(255) 
		)

-- =================================================================================================
--  Unassigned BHIP
-- =================================================================================================
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT co.MVIPersonSID
			,'Assign to BHIP' as RiskFactor
			,co.ChecklistID
			,c.Facility
			,'Last MH Visit'
			,co.VisitDateTime
			,NULL
			,1 as Actionable
			,-1 as OverdueFlag
			,'Assign to BHIP team'
			,'Action Required'
			,b.Code
	FROM #Unassigned co
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on co.ChecklistID=b.CheckListID
	LEFT JOIN Lookup.ChecklistID c WITH (NOLOCK) on co.ChecklistID=c.ChecklistID
	LEFT JOIN Common.MasterPatient as p WITH (NOLOCK) on co.MVIPersonSID=p.MVIPersonSID
	WHERE p.DateOfDeath_Combined is null;

-- =================================================================================================
--  Most recent BHIP assessment
-- =================================================================================================
	DROP TABLE IF EXISTS #BHIPAssessment
	SELECT *
	INTO #BHIPAssessment
	FROM Present.BHIP_Assessments WITH (NOLOCK)
	WHERE AssessmentRN=1

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT co.MVIPersonSID
			,RiskFactor='Most Recent BHIP Assessment'
			,a.ChecklistID
			,b.Facility
			,EventValue=CASE WHEN a.MVIPersonSID IS NULL THEN 'No BHIP Assessment in past year' ELSE 'BHIP Assessment' END
			,cast(VisitDateTime as date) as EventDate
			,LastBHIPContact
			,Actionable=CASE WHEN a.MVIPersonSID IS NULL THEN 1 ELSE 0 END
			,-1 as OverdueFlag
			,ActionExpected=CASE WHEN a.MVIPersonSID IS NULL THEN 'Case Review' ELSE 'Informational' END
			,ActionLabel=CASE WHEN a.MVIPersonSID IS NULL THEN 'Case Review' ELSE 'No Action Required' END
			,b.Code
	FROM #Cohort co
	LEFT JOIN #BHIPAssessment a  on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  REACH VET indicators
-- =================================================================================================
	DROP TABLE IF EXISTS #REACH
	SELECT h.MVIPersonSID
		  ,CASE WHEN h.Top01Percent=1 THEN 'Top Risk Tier' 
			ELSE 'Top Risk Tier Within Past Year' END AS RV_Status
		  ,h.ChecklistID as RV_ChecklistID
		  ,b.Facility as RV_Facility
		  ,h.MostRecentRVDate
	INTO #REACH
	FROM [REACH].[History] h WITH (NOLOCK)
	LEFT JOIN [Lookup].[ChecklistID] b WITH (NOLOCK) on h.ChecklistID=b.ChecklistID
	WHERE h.Top01Percent = 1 OR h.MonthsIdentified12 IS NOT NULL;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'REACH VET' as RiskFactor
			,RV_ChecklistID
			,RV_Facility
			,RV_Status
			,cast(MostRecentRVDate as date)
			,LastBHIPContact
			,-1 as Actionable
			,-1 as OverdueFlag
			,'Informational'
			,'No Action Required'
			,b.Code
	FROM #REACH a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.RV_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  STORM indicators
-- =================================================================================================
	DROP TABLE IF EXISTS #STORM 
	SELECT a.MVIPersonSID		  
			 ,STORM_RiskCategory
			 ,STORM_RiskCategoryLabel
			 ,STORM_ChecklistID
			 ,STORM_Facility
	INTO #STORM
	FROM (
		SELECT MVIPersonSID		  
			  ,RiskCategory as STORM_RiskCategory
			  ,RiskCategoryLabel as STORM_RiskCategoryLabel
			  ,ChecklistID as STORM_ChecklistID
			  ,Facility as STORM_Facility
			  ,row_number() over (PARTITION BY MVIPersonSID ORDER BY RiskCategory desc) AS RN
		FROM [ORM].[PatientReport] WITH (NOLOCK) 
		) a
	WHERE RN=1;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'STORM' as RiskFactor
			,STORM_ChecklistID
			,STORM_Facility
			,STORM_RiskCategoryLabel
			,NULL as EventDate
			,LastBHIPContact
			,-1 as Actionable
			,-1 as OverdueFlag
			,'Informational'
			,'No Action Required'
			,b.Code
	FROM #STORM a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.STORM_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  COMPACT Act
-- =================================================================================================
	DROP TABLE IF EXISTS #CompactAct
	SELECT MVIPersonSID
		,EpisodeBeginDate as COMPACT_EpisodeBeginDate
		,EpisodeBeginSetting as COMPACT_EpisodeBeginSetting 
	INTO #CompactAct
	FROM COMPACT.Episodes WITH (NOLOCK)
	WHERE ActiveEpisode=1;
		
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Active COMPACT Act Episode' as RiskFactor
			,NULL as ChecklistID
			,NULL as Facility
			,COMPACT_EpisodeBeginSetting 
			,COMPACT_EpisodeBeginDate as EventDate
			,LastBHIPContact
			,-1 as Actionable
			,-1 as OverdueFlag
			,'Informational'
			,'No Action Required'
			,NULL as Code
	FROM #CompactAct a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  Clinical HRF 
-- =================================================================================================
   DROP TABLE IF EXISTS #hrf
   SELECT MVIPersonSID 
		 ,OwnerChecklistID as HRF_ChecklistID
		 ,Facility as HRF_Facility
		 ,LastActionDateTime as HRF_Date
		 ,LastActionDescription as HRF_Status
		 ,case when LastActionType in ('1','2','4') then 1 else 0 end as HRF_CurrentlyActive
   INTO #hrf 
   FROM [PRF_HRS].[PatientReport_v02] a WITH (NOLOCK) --this table contains most recent HRF status for patients in past year
   INNER JOIN [LookUp].[ChecklistID] b WITH (NOLOCK) on a.OwnerChecklistID=b.ChecklistID;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'High Risk Flag in past year' as RiskFactor
			,HRF_ChecklistID
			,HRF_Facility
			,HRF_Status
			,cast(HRF_Date as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(HRF_Date as date) or LastBHIPContact is NULL) and HRF_CurrentlyActive=1 then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(HRF_Date as date) or LastBHIPContact is NULL) and HRF_CurrentlyActive=1 then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(HRF_Date as date) or LastBHIPContact is NULL) and HRF_CurrentlyActive=1 then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #hrf a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.HRF_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  Active behavioral risk flag in last year
-- =================================================================================================
	-- Pull in most recent behavioral flag 
	DROP TABLE IF EXISTS #behavior
	SELECT r.MVIPersonSID		  
		 , b.ActionDateTime AS Behavioral_ActionDateTime
		 , b.ActionTypeDescription AS Behavioral_ActionName
		 ,b.OwnerChecklistID AS Behavioral_ChecklistID
		 ,b.OwnerFacility AS Behavioral_Facility
	INTO #behavior
	FROM #Cohort r 
	INNER JOIN [PRF].[BehavioralMissingPatient] b WITH (NOLOCK) 
		ON r.MVIPersonSID = b.MVIPersonSID
	WHERE b.NationalPatientRecordFlag = 'BEHAVIORAL'
	AND b.EntryCountDesc = 1
	AND b.ActiveFlag='Y'
	AND b.ActionDateTime >= dateadd(year, -1, getdate());

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Behavioral Risk Flag in past year' as RiskFactor
			,Behavioral_ChecklistID
			,Behavioral_Facility
			,Behavioral_ActionName
			,cast(Behavioral_ActionDateTime as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(Behavioral_ActionDateTime as date) or LastBHIPContact is NULL) then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(Behavioral_ActionDateTime as date) or LastBHIPContact is NULL) then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(Behavioral_ActionDateTime as date) or LastBHIPContact is NULL) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #behavior a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.Behavioral_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  SBOR - preparatory behavior, attempts and overdoses - most recent
-- =================================================================================================
------------------------------------------
-- Preparatory behavior
------------------------------------------
	DROP TABLE IF EXISTS #SBOR_Prep
	SELECT *
	INTO #SBOR_Prep
	FROM (
		SELECT a.MVIPersonSID
			  ,a.SDVClassification as SBOR_Detail_Prep
			  ,concat(a.MethodType1, ': ', a.Method1) as SBOR_Method_Prep
			  ,a.EventDate as SBOR_Date_Prep
			  ,SBOR_DateFormatted_Prep = ISNULL(a.EventDateFormatted, a.EntryDateTime)
			  ,c.Facility as SBOR_Facility_Prep
			  ,a.ChecklistID as SBOR_Checklistid_Prep
			  ,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.EventDateFormatted DESC, a.EntryDateTime DESC) AS SBOR_EventOrderDesc_Prep
		FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
		INNER JOIN #Cohort co on co.MVIPersonSID=a.MVIPersonSID
		INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) on c.ChecklistID=a.ChecklistID
		WHERE a.PreparatoryBehavior=1 and a.SDVClassification not like '%Undetermined%' --remove the 'undetermined' preparatory behavior; should not be included
			AND (a.EventType NOT IN ('Ideation','Non-Suicidal SDV') or a.EventType is null)
			AND a.Fatal = 0
		) a
	WHERE SBOR_EventOrderDesc_Prep=1;
	
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Most recent preparatory suicide event' as RiskFactor
			,SBOR_Checklistid_Prep
			,SBOR_Facility_Prep
			,concat(SBOR_Detail_Prep, ', ',SBOR_Method_Prep)
			,cast(SBOR_DateFormatted_Prep as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Prep as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Prep > dateadd(year,-1,getdate()))) then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Prep as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Prep > dateadd(year,-1,getdate()))) then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Prep as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Prep > dateadd(year,-1,getdate()))) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #SBOR_Prep a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.SBOR_Checklistid_Prep=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

---------------------------------------------------------
-- Attempts and Overdoses - combine into one risk factor
---------------------------------------------------------
	DROP TABLE IF EXISTS #SBOR_Attempt_OD
	SELECT DISTINCT *
	INTO #SBOR_Attempt_OD
	FROM (
		SELECT a.MVIPersonSID
			  ,b.SDVClassification as SBOR_Detail_Att_OD
			  ,concat(a.MethodType1, ': ', a.Method1) as SBOR_Method_Att_OD
			  ,a.EventDate as SBOR_Date_Att_OD
			  ,SBOR_DateFormatted_Att_OD = ISNULL(a.EventDateFormatted, a.EntryDateTime)
			  ,c.Facility as SBOR_Facility_Att_OD
			  ,a.ChecklistID as SBOR_Checklistid_Att_OD
			  ,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.eventdateformatted DESC, a.EntryDateTime DESC) AS SBOR_EventOrderDesc_Att_OD
		FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
		INNER JOIN #Cohort co 
			ON co.MVIPersonSID=a.MVIPersonSID
		INNER JOIN SBOSR.SDVDetails_PBI b WITH (NOLOCK)
			ON a.MVIPersonSID=b.MVIPersonSID
			AND cast(ISNULL(a.EventDateFormatted, a.EntryDateTime) as date)=b.[date]
		INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) on c.ChecklistID=a.ChecklistID
		WHERE ((a.SuicidalSDV=1 AND a.SDVClassification like '%Attempt%') OR a.Overdose = 1)
			AND (a.EventType NOT IN ('Ideation','Non-Suicidal SDV') or a.EventType is null)
			AND a.PreparatoryBehavior <> 1
			AND a.Fatal = 0
		) a
	WHERE SBOR_EventOrderDesc_Att_OD=1;
	
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Most recent suicide attempt or overdose' as RiskFactor
			,SBOR_Checklistid_Att_OD
			,SBOR_Facility_Att_OD
			,concat(SBOR_Detail_Att_OD, ', ',SBOR_Method_Att_OD)
			,cast(SBOR_DateFormatted_Att_OD as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Att_OD as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Att_OD > dateadd(year,-1,getdate())))  then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Att_OD as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Att_OD > dateadd(year,-1,getdate()))) then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(SBOR_DateFormatted_Att_OD as date) or (LastBHIPContact is NULL and SBOR_DateFormatted_Att_OD > dateadd(year,-1,getdate()))) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #SBOR_Attempt_OD a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b on a.SBOR_Checklistid_Att_OD=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID

-- =================================================================================================
--  SP2.0 Clin Consult
-- =================================================================================================
	--Get list of patients with SP 2.0 consults
	DROP TABLE IF EXISTS #SP2_Prep
	SELECT DISTINCT
		 c.MVIPersonSID
		,MAX(CAST(con.RequestDate AS DATE)) RequestDate
	INTO #SP2_Prep
	FROM [PDW].[NEPEC_MHICM_DOEx_TH_Consult_AllFacilities] con WITH(NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID m WITH(NOLOCK)
		ON con.PatientSID=m.PatientPersonSID
	INNER JOIN #Cohort c
		ON c.MVIPersonSID=m.MVIPersonSID
	WHERE C_Sent=1 OR C_Received=1
	GROUP BY c.MVIPersonSID;

	--Get most recent SP 2.0 consult and identify when consult was plaed within the year
	DROP TABLE IF EXISTS #SP2
	SELECT *, RequestDatePastYr=CASE WHEN RequestDate > dateadd(day,-366,getdate()) THEN 1 ELSE 0 END
	INTO #SP2
	FROM #SP2_Prep;

	--Suicial behaviors, including preparatory behaviors
	DROP TABLE IF EXISTS #SDV_Prep
	SELECT c.ChecklistID
		,MVIPersonSID
		,c.Facility
		,MAX(ISNULL(EventDateFormatted,EntryDateTime)) SDVDate
	INTO #SDV_Prep
	FROM OMHSP_Standard.SuicideOverdoseEvent s WITH (NOLOCK)
	INNER JOIN LookUp.ChecklistID c WITH (NOLOCK)
		ON s.ChecklistID=c.ChecklistID
	WHERE EventType='Suicide Event' 
		AND Fatal=0 
		AND Intent='Yes'
		AND ISNULL(EventDateFormatted,EntryDateTime) > dateadd(year,-5,cast(getdate() as date))
	GROUP BY MVIPersonSID, c.ChecklistID, c.Facility

	--Get most recent suicide behavior and identify when SDV occurred within the year
	DROP TABLE IF EXISTS #SDV
	SELECT *, SDVPastYr=CASE WHEN SDVDate > dateadd(day,-366,getdate()) THEN 1 ELSE 0 END
	INTO #SDV
	FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SDVDate DESC) RN
			FROM #SDV_Prep ) Src
	WHERE RN=1;
	
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT sdv.MVIPersonSID
			,'Most Recent SP 2.0 Clinical Telehealth Consult' as RiskFactor
			,sdv.ChecklistID
			,sdv.Facility
			,EventValue=	CASE WHEN con.RequestDate IS NOT NULL THEN 'SP 2.0 Consult' ELSE 'No SP 2.0 Clinical Telehealth Consult Recorded' END
			,EventDate=		RequestDate
			,LastBHIPContact
			,Actionable=	CASE WHEN (cast(LastBHIPContact as date) < cast(SDVDate as date) OR LastBHIPContact IS NULL) 
								   OR (SDVPastYr=1 AND (con.RequestDate IS NULL OR con.RequestDatePastYr=0)) 
								   OR (SDVPastYr=1 AND (con.RequestDate < SDVDate)) THEN 1 ELSE 0 END
			,OverdueFlag=	-1
			,ActionExpected=CASE WHEN (cast(LastBHIPContact as date) < cast(SDVDate as date) OR LastBHIPContact IS NULL) 
								   OR (SDVPastYr=1 AND (con.RequestDate IS NULL OR con.RequestDatePastYr=0)) 
								   OR (SDVPastYr=1 AND (con.RequestDate < SDVDate)) THEN 'Case Review' ELSE 'Informational' END
			,ActionLabel=CASE WHEN (cast(LastBHIPContact as date) < cast(SDVDate as date) OR LastBHIPContact IS NULL) 
								   OR (SDVPastYr=1 AND (con.RequestDate IS NULL OR con.RequestDatePastYr=0)) 
								   OR (SDVPastYr=1 AND (con.RequestDate < SDVDate)) THEN 'Action Required' ELSE 'No Action Required' END
			,b.Code
	FROM #SDV sdv
	INNER JOIN #Cohort co on sdv.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN #SP2 con on con.MVIPersonSID=sdv.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on sdv.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on sdv.MVIPersonSID=c.MVIPersonSID;

-- =======================================================================================================
--  Screening Indicators: C-SSRS, CSRE, AUDIT-C, Depression, Homeless/Food Insecurity, MST, PTSD, Tobacco
-- =======================================================================================================
------------------------------------------
-- Potential Screening Needs
------------------------------------------
	DROP TABLE IF EXISTS #OverdueScreen
	SELECT o.MVIPersonSID
		,o.ChecklistID
		,s.Facility
		,OverdueFlag= 
			--When OverdueFlag=1 (is overdue) or Next30DaysOverdueFlag=1 
			--(about to be overdue) this identifies a Potential Screening Need
			CASE WHEN o.OverdueFlag=1 OR o.Next30DaysOverdueFlag=1 THEN 1 ELSE 0 END 
		,o.MostRecentScreenDate
		,o.Screen
	INTO #OverdueScreen
	FROM Present.OverdueScreens o WITH(NOLOCK)
	LEFT JOIN LookUp.StationColors s WITH (NOLOCK) on o.ChecklistID=s.CheckListID

	--select MVIPersonSID from #Cohort --(BHIP driven cohort above)
	--except
	--select MVIPersonSID from #OverdueScreen --(cohort driven by Common.MasterPatient)
	--0 rows and should continue to be 0 rows

------------------------------------------
-- CSRE
------------------------------------------
	--Get CSRE information
	DROP TABLE IF EXISTS #CSRE 
	SELECT a.MVIPersonSID
		,a.ChecklistID
		,CSRE_Date=CAST(ISNULL(a.EntryDateTime,a.VisitDateTime) as DATE)
		,c.Facility
		,a.AcuteRisk as CSRE_Acute
		,a.ChronicRisk as CSRE_Chronic
		,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EntryDateTime,a.VisitDateTime) DESC) AS RN
	INTO #CSRE
	FROM [OMHSP_Standard].[CSRE] a WITH (NOLOCK)
	LEFT JOIN [Lookup].[ChecklistID] c WITH(NOLOCK) on a.ChecklistID=c.ChecklistID
	WHERE (EvaluationType='New CSRE' or EvaluationType='Updated CSRE')
			and ISNULL(EntryDateTime,VisitDateTime) > dateadd(year,-5,cast(getdate() as date))

	--Details of most recent CSRE
	DROP TABLE IF EXISTS #CSRERecentResult;
	SELECT MVIPersonSID
	  ,CSRE_Date
	  ,ChecklistID
	  ,Facility
	  ,CSRE_Acute
	  ,CSRE_Chronic
	INTO #CSRERecentResult
	FROM #CSRE
	WHERE RN=1

	--CSRE Risk ID - for high or intermediate CSREs
	DROP TABLE IF EXISTS #CSRE_RiskID;
	SELECT TOP (1) WITH TIES
		MVIPersonSID,CSRE_Date,ChecklistID,Facility,CSRE_Acute,CSRE_Chronic	
	INTO #CSRE_RiskID
	FROM #CSRE
	WHERE CSRE_Acute LIKE '%High%'
		OR CSRE_Acute LIKE '%Interm%'
		OR CSRE_Chronic LIKE '%High%'
		OR CSRE_Chronic LIKE '%Interm%'
	ORDER BY row_number() OVER (Partition By MVIPersonSID order by CSRE_Date DESC);

	--Prioritize a high or intermediate CSRE - if none, select most recent Low risk CSRE
	DROP TABLE IF EXISTS #CSRE2
	SELECT MVIPersonSID,CSRE_Date,ChecklistID,Facility,CSRE_Acute,CSRE_Chronic	 
	INTO #CSRE2
	FROM #CSRE_RiskID
	UNION 
	SELECT MVIPersonSID,CSRE_Date,ChecklistID,Facility,CSRE_Acute,CSRE_Chronic	 
	FROM #CSRERecentResult 
	WHERE MVIPersonSID NOT IN (SELECT MVIPersonSID FROM #CSRE_RiskID);

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'CSRE - Acute Risk' as RiskFactor
			,a.ChecklistID
			,a.Facility
			,case when CSRE_Acute like '%Low%' then 'Low'
				  when CSRE_Acute like '%Intermed%' then 'Intermediate'
				  when CSRE_Acute like '%High%' then 'High' end as EventValue
			,cast(CSRE_Date as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Acute not like '%Low%' then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Acute not like '%Low%' then 'Case Review'			 else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Acute not like '%Low%' then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #CSRE2 a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID
	
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'CSRE - Chronic Risk' as RiskFactor
			,a.ChecklistID
			,a.Facility
			,case when CSRE_Chronic like '%Low%' then 'Low'
				  when CSRE_Chronic like '%Intermed%' then 'Intermediate'
				  when CSRE_Chronic like '%High%' then 'High' end as EventValue
			,cast(CSRE_Date as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Chronic not like '%Low%' then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Chronic not like '%Low%' then 'Case Review'
				   else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(CSRE_Date as date) or LastBHIPContact is NULL) and CSRE_Chronic not like '%Low%' then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #CSRE2 a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

------------------------------------------
-- C-SSRS
------------------------------------------
	--Most recent C-SSRS
	--for display_cssrs column, 1 is positive, 0 is negative, -99 is missing/unknown/skipped
	DROP TABLE IF EXISTS #cssrs 
	SELECT TOP (1) WITH TIES
		 m.MVIPersonSID
		,m.ChecklistID
		,c.Facility
		,CSSRS_Date=m.SurveyGivenDateTime
		,m.SurveyName
		,m.display_CSSRS
	INTO #cssrs
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] m WITH (NOLOCK)
	LEFT JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) on c.ChecklistID=m.ChecklistID
	WHERE display_CSSRS > -1 
		AND Surveyname<>'PHQ9'
		AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date))
	ORDER BY ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID ORDER BY SurveyGivenDateTime DESC, display_CSSRS DESC); 

------------------------------------------
-- Suicide Screen
------------------------------------------
	--Most Recent Suicide Screen (due annually)
	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent Suicide Screen' as RiskFactor
			,case when cast(CSSRS_Date as date) > cast(cr.CSRE_Date as date) 
				    or cast(CSSRS_Date as date) IS NOT NULL AND cast(cr.CSRE_Date as date) IS NULL then a.ChecklistID
				  when cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date) 
				    or cast(cr.CSRE_Date as date) IS NOT NULL AND cast(a.CSSRS_Date as date) IS NULL then cr.ChecklistID
				  when cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date) then cr.ChecklistID
			 end as ChecklistID	
			,case when cast(CSSRS_Date as date) > cast(cr.CSRE_Date as date) 
				    or cast(CSSRS_Date as date) IS NOT NULL AND cast(cr.CSRE_Date as date) IS NULL then a.Facility
				  when cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date) 
				    or cast(cr.CSRE_Date as date) IS NOT NULL AND cast(a.CSSRS_Date as date) IS NULL then cr.Facility
				  when cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date) then cr.Facility
			 end as Facility
			,case when o.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis' 
				  when (cast(CSSRS_Date as date) < DATEADD(d,-366,GETDATE()) or CSSRS_Date is NULL) and 
					   (cast(cr.CSRE_Date as date) < DATEADD(d,-366,GETDATE()) or cr.CSRE_Date is NULL) then 'No Suicide Screen in past year'
				 
				 --'CSRE - Chronic Risk (High)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute IS NULL and cr.CSRE_Chronic like '%High%')
			      then 'CSRE - Chronic Risk (High)'
				 
				 --'CSRE - Chronic Risk (Intermediate)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute IS NULL and cr.CSRE_Chronic like '%Intermed%')
				  then 'CSRE - Chronic Risk (Intermediate)'
				 
				 --'CSRE - Chronic Risk (Low)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute IS NULL and cr.CSRE_Chronic like '%Low%')
				  then 'CSRE - Chronic Risk (Low)'
				  
				 --'CSRE - Acute Risk (High)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%High%' and cr.CSRE_Chronic IS NULL)
			      then 'CSRE - Acute Risk (High)'

				 --'CSRE - Acute Risk (Intermediate)'  
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Intermed%' and cr.CSRE_Chronic IS NULL)
			      then 'CSRE - Acute Risk (Intermediate)'	
				  
				 --'CSRE - Acute Risk (Low)'				  
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Low%' and cr.CSRE_Chronic IS NULL)
			      then 'CSRE - Acute Risk (Low)'

				 --'CSRE - Acute Risk (High), Chronic Risk (High)'				  				  
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%High%' and cr.CSRE_Chronic like '%High%')
				  then 'CSRE - Acute Risk (High), Chronic Risk (High)'

				 --'CSRE - Acute Risk (Intermediate), Chronic Risk (High)'			  				  				  
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Intermed%' and cr.CSRE_Chronic like '%High%')
			      then 'CSRE - Acute Risk (Intermediate), Chronic Risk (High)'

				 --'CSRE - Acute Risk (Low), Chronic Risk (High)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Low%' and cr.CSRE_Chronic like '%High%')
				  then 'CSRE - Acute Risk (Low), Chronic Risk (High)'
				  
				 --'CSRE - Acute Risk (High), Chronic Risk (Intermediate)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%High%' and cr.CSRE_Chronic like '%Intermed%')
				  then 'CSRE - Acute Risk (High), Chronic Risk (Intermediate)'

				 --'CSRE - Acute Risk (Intermediate), Chronic Risk (Intermediate)'		  
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Intermed%' and cr.CSRE_Chronic like '%Intermed%')
			      then 'CSRE - Acute Risk (Intermediate), Chronic Risk (Intermediate)'
				  
				 --'CSRE - Acute Risk (Low), Chronic Risk (Intermediate)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Low%' and cr.CSRE_Chronic like '%Intermed%')
				  then 'CSRE - Acute Risk (Low), Chronic Risk (Intermediate)'
				  
				 --'CSRE - Acute Risk (High), Chronic Risk (Low)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%High%' and cr.CSRE_Chronic like '%Low%')
				  then 'CSRE - Acute Risk (High), Chronic Risk (Low)'

				 --'CSRE - Acute Risk (Intermediate), Chronic Risk (Low)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				  and (cr.CSRE_Acute like '%Intermed%' and cr.CSRE_Chronic like '%Low%')
			      then 'CSRE - Acute Risk (Intermediate), Chronic Risk (Low)'
				 
				 --'CSRE - Acute Risk (Low), Chronic Risk (Low)'
				  when ((cast(cr.CSRE_Date as date) > cast(CSSRS_Date as date))
				    or (cast(cr.CSRE_Date as date) IS NOT NULL AND cast(CSSRS_Date as date) IS NULL)
				    or cast(cr.CSRE_Date as date) = cast(a.CSSRS_Date as date))
				    and (cr.CSRE_Acute like '%Low%' and cr.CSRE_Chronic like '%Low%')
				  then 'CSRE - Acute Risk (Low), Chronic Risk (Low)'

				 --'C-SSRS - Positive' 			 
				  when (cast(CSSRS_Date as date) > cast(cr.CSRE_Date as date) and display_CSSRS=1) 
				    or (cast(CSSRS_Date as date) IS NOT NULL and cast(cr.CSRE_Date as date) IS NULL and display_CSSRS=1) 
			      then 'C-SSRS - Positive'

				 --'C-SSRS - Negative' 			 
				  when (cast(CSSRS_Date as date) > cast(cr.CSRE_Date as date) and display_CSSRS=0)
				    or (cast(CSSRS_Date as date) IS NOT NULL and cast(cr.CSRE_Date as date) IS NULL and display_CSSRS=0) 
				  then 'C-SSRS - Negative'

				 --'C-SSRS - Not Scored Due to Incomplete Information' 
				  when (cast(CSSRS_Date as date) > cast(cr.CSRE_Date as date) and display_CSSRS=-99)
				    or (cast(CSSRS_Date as date) IS NOT NULL and cast(cr.CSRE_Date as date) IS NULL and display_CSSRS=-99) 
				  then 'C-SSRS - Not Scored Due to Incomplete Information' end as EventValue
			,EventDate=o.MostRecentScreenDate
			,LastBHIPContact
			,case when o.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(CSSRS_Date as date) or LastBHIPContact is NULL) and display_CSSRS=1 then 1 
				  when (cast(CSSRS_Date as date) < DATEADD(d,-366,GETDATE()) or CSSRS_Date is NULL) and 
					   (cast(cr.CSRE_Date as date) < DATEADD(d,-366,GETDATE()) or cr.CSRE_Date is NULL) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(o.OverdueFlag,1) --if NULL, the screen is overdue
			,case when o.OverdueFlag = -1 then 'Informational'
				  when (cast(CSSRS_Date as date) < DATEADD(d,-366,GETDATE()) or CSSRS_Date is NULL) and 
					   (cast(cr.CSRE_Date as date) < DATEADD(d,-366,GETDATE()) or cr.CSRE_Date is NULL) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(cr.CSRE_Date as date) or LastBHIPContact is NULL) and 
					    CSRE_Chronic not like '%Low%' then 'Case Review' 
				  else 'Informational' end ActionExpected
			,case when o.OverdueFlag = -1 then 'No Action Required'
				  when (cast(CSSRS_Date as date) < DATEADD(d,-366,GETDATE()) or CSSRS_Date is NULL) and 
					   (cast(cr.CSRE_Date as date) < DATEADD(d,-366,GETDATE()) or cr.CSRE_Date is NULL) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(CSSRS_Date as date) or LastBHIPContact is NULL) and display_CSSRS=1 then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co 
	LEFT JOIN #cssrs a on a.MVIPersonSID=co.MVIPersonSID 
	LEFT JOIN #CSRERecentResult cr on co.MVIPersonSID=cr.MVIPersonSID
	LEFT JOIN #LastBHIPContact c on co.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #OverdueScreen o on co.MVIPersonSID=o.MVIPersonSID AND Screen='Suicide'
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(o.ChecklistID,co.ChecklistID)=b.CheckListID;

------------------------------------------
-- AUDIT-C for alcohol use
------------------------------------------
	DROP TABLE IF EXISTS #AUDIT_C
	SELECT TOP (1) WITH TIES
		 mh.MVIPersonSID
		,AUDITC_ChecklistID=mh.ChecklistID
		,AUDITC_Facility=c.Facility
		,CASE WHEN mh.Display_AUDC = 1 THEN 'Positive-Mild'
			  WHEN mh.Display_AUDC = 2 THEN 'Positive-Moderate'
			  WHEN mh.Display_AUDC = 3 THEN 'Positive-Severe'
			  WHEN mh.Display_CSSRS = 0 or mh.Display_AUDC = 0 THEN 'Negative'
		 END AS AUDITC_SurveyResult
		,CAST(SurveyGivenDatetime AS DATE) AS AUDITC_SurveyDate
	INTO #AUDIT_C
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] mh WITH (NOLOCK)
	LEFT JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on mh.ChecklistID=c.ChecklistID
	WHERE mh.display_AUDC > -1
	AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date)) 
	ORDER BY ROW_NUMBER() OVER (PARTITION BY mh.MVIPersonSID 
									ORDER BY mh.SurveyGivenDatetime DESC);

	--Most recent AUDIT-C (due annually)
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent AUDIT-C' as RiskFactor
			,AUDITC_ChecklistID
			,AUDITC_Facility
			,case when o.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis'
				  when (cast(AUDITC_SurveyDate as date) < DATEADD(d,-366,GETDATE())) or (cast(AUDITC_SurveyDate as date) is null) then 'No AUDIT-C in past year'
				  --when AUDITC_SurveyResult is null then 'No AUDIT-C in past year' 
				  else AUDITC_SurveyResult end as EventValue
			,cast(AUDITC_SurveyDate as date) d
			,LastBHIPContact
			,case when o.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(AUDITC_SurveyDate as date) or LastBHIPContact is NULL) and AUDITC_SurveyResult like '%Positive%' then 1 
				  when (cast(AUDITC_SurveyDate as date) < DATEADD(d,-366,GETDATE())) or (cast(AUDITC_SurveyDate as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(o.OverdueFlag,1) --if NULL, the screen is overdue
			,case when o.OverdueFlag = -1 then 'Informational'
				  when (cast(AUDITC_SurveyDate as date) < DATEADD(d,-366,GETDATE())) or (cast(AUDITC_SurveyDate as date) is null) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(AUDITC_SurveyDate as date) or LastBHIPContact is NULL) and AUDITC_SurveyResult like '%Positive%' then 'Case Review' 
				  else 'Informational' end ActionExpected
			,case when o.OverdueFlag = -1 then 'No Action Required'
				  when (cast(AUDITC_SurveyDate as date) < DATEADD(d,-366,GETDATE())) or (cast(AUDITC_SurveyDate as date) is null) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(AUDITC_SurveyDate as date) or LastBHIPContact is NULL) and AUDITC_SurveyResult like '%Positive%' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co
	LEFT JOIN #AUDIT_C a on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.AUDITC_ChecklistID,co.ChecklistID)=b.CheckListID
	LEFT JOIN #LastBHIPContact c on co.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #OverdueScreen o on co.MVIPersonSID=o.MVIPersonSID AND Screen='AUDIT-C'

---------------------------------------------------------------
--PHQ-2 or PHQ-9 for Depression
---------------------------------------------------------------
	DROP TABLE IF EXISTS #Dep
	SELECT TOP (1) WITH TIES
		   m.MVIPersonSID
		  ,m.SurveyName
		  ,DepScr_Facility=c.Facility
		  ,DepScr_ChecklistID=m.ChecklistID
		  ,cast(surveygivendatetime as date) as DepScr_date
		  ,m.display_PHQ2
		  ,m.display_PHQ9
		  ,DepScr_Result=m.DisplayScore
		  ,case when m.display_PHQ2 in ('1','0') and surveyname not like '%Q%2%' then 'PHQ-2' 
				when m.display_PHQ9>=0 and surveyname not like '%Q%9%' then 'PHQ-9' else '' 
				end as DepScrType
	INTO #Dep
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] m WITH (NOLOCK)
	INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) on c.ChecklistID=m.ChecklistID
	WHERE (display_phq2 in ('1','0') or display_PHQ9>=0)
		AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date))
	ORDER BY ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID 
					ORDER BY m.SurveyGivenDateTime DESC, 
							 CASE WHEN m.display_PHQ9 >= 0 THEN 1 ELSE 0 END DESC);

	--Most recent Dep screen(due annually)
	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent Depression Screen' as RiskFactor
			,DepScr_ChecklistID
			,DepScr_Facility
			,case when o.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis'
				  when (cast(DepScr_date as date) < DATEADD(d,-366,GETDATE())) or (cast(DepScr_Date as date) is null) then 'No Depression Screen in past year'
					when DepScrType='' then CONCAT(SurveyName, ': ', DepScr_Result)
					else CONCAT(SurveyName,'; ',DepScrType, ': ',DepScr_Result)  end as EventValue
			,DepScr_date 
			,LastBHIPContact
			,case when o.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(DepScr_date as date) or LastBHIPContact is NULL) and DepScr_Result like '%Positive%' then 1 
				  when (cast(DepScr_date as date) < DATEADD(d,-366,GETDATE())) or (cast(DepScr_date as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(o.OverdueFlag,1) --if NULL, the screen is overdue
			,case when o.OverdueFlag = -1 then 'Informational'
				  when (cast(DepScr_date as date) < DATEADD(d,-366,GETDATE())) or (cast(DepScr_date as date) is null) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(DepScr_date as date) or LastBHIPContact is NULL) 
				  and DepScr_Result like '%Positive%' then 'Case Review' --need BAM?
				  else 'Informational' end ActionExpected
			,case when o.OverdueFlag = -1 then 'No Action Required'
				  when (cast(DepScr_date as date) < DATEADD(d,-366,GETDATE())) or (cast(DepScr_date as date) is null) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(DepScr_date as date) or LastBHIPContact is NULL) and DepScr_Result like '%Positive%' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co
	LEFT JOIN #Dep a on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.DepScr_ChecklistID,co.ChecklistID)=b.CheckListID
	LEFT JOIN #LastBHIPContact c on co.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #OverdueScreen o on co.MVIPersonSID=o.MVIPersonSID and Screen='Depression';
	
------------------------------------------
-- Homeless/Food Insecurity/MST 
------------------------------------------
	DROP TABLE IF EXISTS #Homeless_FoodInsecurity_MST
	SELECT TOP (1) WITH TIES
		 r.MVIPersonSID
		,r.ChecklistID as Survey_ChecklistID
		,r.Category
		,cast(r.ScreenDateTime as date) as Survey_Date
		,r.Score
		,case when r.Score=1 then 'Positive' else 'Negative' end as Survey_Result
	INTO #Homeless_FoodInsecurity_MST
	FROM SDH.ScreenResults r WITH(NOLOCK)
	WHERE r.Category IN ('Food Insecurity Screen', 'Homeless Screen', 'MST Screen')
	ORDER BY ROW_NUMBER() OVER(PARTITION BY r.MVIPersonSID, r.Category 
									ORDER BY r.ScreenDateTime DESC)

	--Most recent Homeless Screen (due annually)
	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent Homeless Screen' as RiskFactor
			,Survey_ChecklistID
			,Survey_Facility
			,case when a.OverdueFlag = -1  then 'Excluded from screening requirement due to diagnosis'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'No Homeless Screen in past year' 
				  else Survey_Result end as EventValue
			,Survey_Date 
			,LastBHIPContact
			,case when a.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 1 
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(a.OverdueFlag,1) --if NULL, the screen is overdue
			,case when a.OverdueFlag = -1 then 'Informational'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when a.OverdueFlag = -1 then 'No Action Required'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co
	LEFT JOIN ( SELECT a.MVIPersonSID
					,Survey_ChecklistID=a.Survey_ChecklistID
					,a.Survey_Date
					,a.Survey_Result
					,Survey_Facility=c.Facility
					,o.OverdueFlag
				FROM #Homeless_FoodInsecurity_MST a
				LEFT JOIN #OverdueScreen o
					ON o.MVIPersonSID=a.MVIPersonSID
					AND o.Screen='Homeless'
				LEFT JOIN LookUp.ChecklistID c
					ON a.Survey_ChecklistID=c.ChecklistID
				WHERE Category='Homeless Screen'
					AND Survey_Date >= DATEADD(YEAR,-5,CAST(GETDATE() as date))) a 
		ON a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.Survey_ChecklistID,co.ChecklistID)=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

	--Most recent Food Insecurity Screen (due annually)
	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent Food Insecurity Screen' as RiskFactor
			,Survey_ChecklistID
			,Survey_Facility
			,case when a.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'No Food Insecurity Screen in past year' 
				  else Survey_Result end as EventValue
			,Survey_Date  
			,LastBHIPContact
			,case when a.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 1 
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(a.OverdueFlag,1) --if NULL, the screen is overdue
			,case when a.OverdueFlag = -1 then 'Informational'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when a.OverdueFlag = -1 then 'No Action Required'
				  when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co
	LEFT JOIN ( SELECT a.MVIPersonSID
					,Survey_ChecklistID=a.Survey_ChecklistID
					,a.Survey_Date
					,a.Survey_Result
					,Survey_Facility=c.Facility
					,o.OverdueFlag
				FROM #Homeless_FoodInsecurity_MST a
				LEFT JOIN #OverdueScreen o
					ON o.MVIPersonSID=a.MVIPersonSID
					AND o.Screen='Food Insecurity'
				LEFT JOIN LookUp.ChecklistID c WITH (NOLOCK)
					ON a.Survey_ChecklistID=c.ChecklistID
				WHERE Category='Food Insecurity Screen'
					AND Survey_Date >= DATEADD(YEAR,-5,CAST(GETDATE() as date))) a 
		ON a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.Survey_ChecklistID,co.ChecklistID)=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

	--Most recent MST Screen (due every 99 years)
	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent MST Screen' as RiskFactor
			,Survey_ChecklistID
			,Survey_Facility
			,case when a.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis'
				  when (cast(Survey_Date as date) < DATEADD(year,-99,GETDATE())) or (cast(Survey_Date as date) is null) then 'No MST Screen Recorded' 
				  else Survey_Result end as EventValue
			,Survey_Date 
			,LastBHIPContact
			,case when a.OverdueFlag = -1 then -5
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 1 
				  when (cast(Survey_Date as date) < DATEADD(year,-99,GETDATE())) or (cast(Survey_Date as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(a.OverdueFlag,1) --if NULL, the screen is overdue
			,case when a.OverdueFlag = -1 then 'Informational'
				  when (cast(Survey_Date as date) < DATEADD(year,-99,GETDATE())) or (cast(Survey_Date as date) is null) then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when a.OverdueFlag = -1 then 'No Action Required'
				  when (cast(Survey_Date as date) < DATEADD(year,-99,GETDATE())) or (cast(Survey_Date as date) is null) then 'Action Required'
				  when (cast(LastBHIPContact as date) < cast(Survey_Date as date) or LastBHIPContact is NULL) and Survey_Result like '%Positive%' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Cohort co
	LEFT JOIN ( SELECT a.MVIPersonSID
					,Survey_ChecklistID=a.Survey_ChecklistID
					,a.Survey_Date
					,a.Survey_Result
					,Survey_Facility=c.Facility
					,o.OverdueFlag
				FROM #Homeless_FoodInsecurity_MST a
				LEFT JOIN #OverdueScreen o
					ON o.MVIPersonSID=a.MVIPersonSID
					AND o.Screen='MST'
				LEFT JOIN LookUp.ChecklistID c WITH (NOLOCK)
					ON a.Survey_ChecklistID=c.ChecklistID
				WHERE Category='MST Screen'
					AND Survey_Date >= DATEADD(YEAR,-99,CAST(GETDATE() as date))) a 
		ON a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.Survey_ChecklistID,co.ChecklistID)=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

------------------------------------------
-- Tobacco use screening
------------------------------------------
	--Grab all tobacco screens in last 5 years
	DROP TABLE IF EXISTS #TUDScreen_recent
	SELECT a.MVIPersonSID
		,a.ChecklistID
		,c.Facility
		,a.HealthFactorDateTime
		,a.HealthFactorType
		,a.PositiveScreen
	INTO #TUDScreen_recent
	FROM [SUD].[TobaccoScreens] a WITH (NOLOCK)
	LEFT JOIN LookUp.ChecklistID c WITH (NOLOCK) on a.ChecklistID=c.ChecklistID
	WHERE OrderDesc=1

	--Most recent Tobacco Screen (due every year)
	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent Tobacco Screen' as RiskFactor
			,a.ChecklistID
			,a.Facility
			,case when o.OverdueFlag = -1 then  'Excluded from screening requirement due to diagnosis'
				  when (cast(HealthFactorDateTime as date) < DATEADD(d,-366,GETDATE())) or (cast(HealthFactorDateTime as date) is null) then 'No Tobacco Screen in past year' 
				  else HealthFactorType end as EventValue
			,HealthFactorDateTime
			,LastBHIPContact
			,case when o.OverdueFlag = -1 then -5
				  when cast(LastBHIPContact as date) < cast(HealthFactorDateTime as date) or LastBHIPContact is NULL then 1 
				  when (cast(HealthFactorDateTime as date) < DATEADD(d,-366,GETDATE())) or (cast(HealthFactorDateTime as date) is null) then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(o.OverdueFlag,1) --if NULL, the screen is overdue
			,case when o.OverdueFlag = -1 then 'Informational'
				  when (cast(HealthFactorDateTime as date) < DATEADD(d,-366,GETDATE())) or (cast(HealthFactorDateTime as date) is null) then 'Potential Screening Need'
				  else 'Informational' end ActionExpected
			,case when o.OverdueFlag = -1 then 'No Action Required'
				  when (cast(HealthFactorDateTime as date) < DATEADD(d,-366,GETDATE())) or (cast(HealthFactorDateTime as date) is null) then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,Code=NULL
	FROM #Cohort co
	LEFT JOIN #OverdueScreen o on co.MVIPersonSID=o.MVIPersonSID and o.Screen='Tobacco'
	LEFT JOIN #TUDScreen_recent a on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

------------------------------------------
-- PTSD screening
------------------------------------------
--Retain most recent PTSD screen. For the first 5 years after military separation (based on service separation date), PTSD screens are due year; after that they are due every 5 years
	DROP TABLE IF EXISTS #PTSD_screen
	SELECT a.MVIPersonSID
		,a.ChecklistID
		,c.Facility
		,cast(a.SurveyGivenDatetime as date) as SurveyGivenDate
		,a.SurveyName
		,a.DisplayScore
		,b.ServiceSeparationDate
	INTO #PTSD_screen
	FROM (
			SELECT *
				,RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SurveyGivenDateTime DESC)
			FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (NOLOCK)
			WHERE display_PTSD NOT IN (-1, -99) and SurveyGivenDatetime >= DATEADD(year,-5,CAST(GETDATE() as date))
		 ) a
	LEFT JOIN Common.MasterPatient b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN Lookup.ChecklistID c WITH (NOLOCK) on a.ChecklistID=c.ChecklistID
	WHERE RN=1

	INSERT INTO #BHIP_RiskFactors 
	SELECT DISTINCT co.MVIPersonSID
			,'Most Recent PTSD Screen' as RiskFactor
			,a.ChecklistID
			,a.Facility
			,case when o.OverdueFlag = -1 then 'Excluded from screening requirement due to diagnosis'
				  when SurveyGivenDate is null then 'No PTSD Screen in past 5 years' 
				  else CONCAT(SurveyName,': ',DisplayScore) end as EventValue
			,SurveyGivenDate
			,LastBHIPContact
			,case when o.OverdueFlag = -1 then -5
				  when cast(LastBHIPContact as date) < SurveyGivenDate or LastBHIPContact is NULL then 1 
				  when (ServiceSeparationDate > DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(d,-366,GETDATE()))
					or (ServiceSeparationDate < DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(year,-5,GETDATE()))
					or SurveyGivenDate is null then 1
				  else 0 end Actionable
			,OverdueFlag=ISNULL(o.OverdueFlag,1) --if NULL, the screen is overdue
			,case when o.OverdueFlag = -1 then 'Informational'
				  when (ServiceSeparationDate > DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(d,-366,GETDATE()))
					or (ServiceSeparationDate < DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(year,-5,GETDATE()))
					or SurveyGivenDate is null and o.OverdueFlag<> -1 then 'Potential Screening Need'
				  when (cast(LastBHIPContact as date) < SurveyGivenDate or LastBHIPContact is NULL) and DisplayScore='Positive' then 'Case Review' 
				  else 'Informational' end ActionExpected
			,case when o.OverdueFlag = -1 then 'No Action Required'
				  when (ServiceSeparationDate > DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(d,-366,GETDATE()))
					or (ServiceSeparationDate < DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(year,-5,GETDATE()))
					or SurveyGivenDate is null then 'Action Required'
					when (cast(LastBHIPContact as date) < SurveyGivenDate or LastBHIPContact is NULL) and DisplayScore='Positive' then 'Action Required'
				  else 'No Action Required' end as ActionLabel
			,Code
	FROM #Cohort co
	LEFT JOIN #PTSD_screen a on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on ISNULL(a.ChecklistID,co.ChecklistID)=b.ChecklistID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #OverdueScreen o on co.MVIPersonSID=o.MVIPersonSID and o.Screen='PTSD';

------------------------------------------
-- Relationship & health safety screening
------------------------------------------

------------------------------------------
-- Sexual orientation screening	
------------------------------------------

-- =================================================================================================
--  CAN score
-- =================================================================================================

	----Find most recent CAN hospitalization risk score
	--DROP TABLE IF EXISTS #CAN_hosp;
	--SELECT TOP (1) WITH TIES
	--	 co.MVIPersonSID
	--	,CAST(HospRiskDate AS DATE) AS CAN_HospRiskDate
	--	,can.cHosp_90d AS CAN_cHosp_90d
	--INTO #CAN_hosp
	--FROM [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] can WITH (NOLOCK) 
	--INNER JOIN #Cohort co 
	--	ON co.MVIPersonSID=can.MVIPersonSID
	--ORDER BY ROW_NUMBER() OVER (PARTITION BY can.MVIPersonSID ORDER BY can.HospRiskDate DESC)

	----Find most recent CAN mortality risk score
	--DROP TABLE IF EXISTS #CAN_mort;
	--SELECT TOP (1) WITH TIES
	--	 co.MVIPersonSID
	--	,CAST(MortRiskDate AS DATE) AS CAN_MortRiskDate
	--	,can.cMort_90d AS CAN_cMort_90d
	--INTO #CAN_mort
	--FROM [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] can WITH (NOLOCK) 
	--INNER JOIN #Cohort co 
	--	ON co.MVIPersonSID=can.MVIPersonSID
	--ORDER BY ROW_NUMBER() OVER (PARTITION BY can.MVIPersonSID ORDER BY can.MortRiskDate DESC)

-- =================================================================================================
--  OFR care
-- =================================================================================================

-- =================================================================================================
--  Veterans Crisis Line (VCL) call consult - we don't have this data yet
-- =================================================================================================

-- =================================================================================================
--  MH Inpatient stay in last 6 months or PDE discharge
-- =================================================================================================
	DROP TABLE IF EXISTS #MH_Inpatient
	SELECT DISTINCT i.MVIPersonSID
		  ,i.AdmitDateTime
		  ,i.DischargeDateTime
		  ,i.ChecklistID as InpatChecklistID
		  ,i.BedSectionName as Disch_BedSecName
		  ,c.Facility as InpatFacility
		  ,i.Census as Inpat_current
		  ,0 as PDE
	INTO #MH_Inpatient
	FROM [Inpatient].[BedSection] i WITH(NOLOCK)
	INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=i.ChecklistID
	LEFT JOIN [LookUp].[ICD10] icd WITH(NOLOCK) on i.PrincipalDiagnosisICD10SID=icd.ICD10SID
	WHERE (Census=1 OR DischargeDateTime >= DATEADD(MONTH,-12,CAST(GETDATE() AS DATE)))
			AND 1 in (MentalHealth_TreatingSpecialty,RRTP_TreatingSpecialty)

	UNION
	--PDE cohort
	SELECT p.MVIPersonSID
			,p.Admitdatetime
			,p.DischargeDateTime
			,p.ChecklistID_Discharge
			,p.Disch_BedSecName
			,c.Facility
			,p.Census as Inpat_current
			,1 as PDE
		FROM [PDE_Daily].[PDE_PatientLevel] p WITH(NOLOCK)
		LEFT JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=p.ChecklistID_Discharge
		WHERE Exclusion30=0
		
	--Most recent MH inpatient discharge 
	DROP TABLE IF EXISTS #MH_Inpatient_MostRecent
	SELECT MVIPersonSID
		,AdmitDateTime as MHInpat_AdmitDate
		,DischargeDateTime as MHInpat_DischargeDate
		,InpatChecklistID as MHInpat_ChecklistID
		,InpatFacility as MHInpat_Facility
		,Disch_BedSecName
		,PDE
		,Inpat_current as MHInpat_current
	INTO #MH_Inpatient_MostRecent
	FROM (
		SELECT *
			,row_number() over (PARTITION BY MVIPersonSID ORDER BY ISNULL(DischargeDateTime,AdmitDateTime) desc, PDE desc) AS RN
		FROM #MH_Inpatient
		) a
	WHERE RN=1;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Inpat MH Stay in past year' as RiskFactor
			,MHInpat_ChecklistID
			,MHInpat_Facility
			,Disch_BedSecName
			,cast(MHInpat_DischargeDate as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(MHInpat_DischargeDate as date) or LastBHIPContact is NULL)  then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(MHInpat_DischargeDate as date) or LastBHIPContact is NULL) then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(MHInpat_DischargeDate as date) or LastBHIPContact is NULL) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #MH_Inpatient_MostRecent a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.MHInpat_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;
	
-- ==================================================
-- Inpatient MH admitted for suicidality
-- ==================================================
	DROP TABLE IF EXISTS #Inpatient
	SELECT DISTINCT i.MVIPersonSID
		  ,i.AdmitDateTime
		  ,i.DischargeDateTime
		  ,i.ChecklistID as InpatChecklistID
		  ,i.BedSectionName as Disch_BedSecName
		  ,c.Facility as InpatFacility
		  ,case when Census=1 then 1 else 0 end as Inpat_current
		  ,case when 1 in (MentalHealth_TreatingSpecialty,RRTP_TreatingSpecialty) then 1 else 0 end as Inpat_MH
		  ,i.ICD10Code as Inpat_ICD10Code
		  ,icd.ICD10Description as Inpat_ICD10Description
		  ,ISNULL(icd.SuicideAttempt,0) as Inpat_SuicideAttempt
	INTO #Inpatient
	FROM [Inpatient].[BedSection] i WITH(NOLOCK)
	INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=i.ChecklistID
	LEFT JOIN [LookUp].[ICD10] icd WITH(NOLOCK) on i.PrincipalDiagnosisICD10SID=icd.ICD10SID
	WHERE (Census=1 OR DischargeDateTime >= DATEADD(MONTH,-12,CAST(GETDATE() AS DATE)));
		--	AND 1 in (MentalHealth_TreatingSpecialty,RRTP_TreatingSpecialty)

	DROP TABLE IF EXISTS #Inpat_SuicideAttempt
	SELECT MVIPersonSID
		,AdmitDateTime as InpatSuicideAttempt_AdmitDate
		,DischargeDateTime as InpatSuicideAttempt_DischargeDate
		,InpatChecklistID as InpatSuicideAttempt_ChecklistID
		,InpatFacility as InpatSuicideAttempt_Facility
		,Inpat_ICD10Code as InpatSuicideAttempt_ICD10Code
		,Inpat_ICD10Description as InpatSuicideAttempt_ICD10Description
		,Disch_BedSecName
		,Inpat_current as SuicInpat_current
	INTO #Inpat_SuicideAttempt
	FROM (
		SELECT *
			,row_number() over (PARTITION BY MVIPersonSID ORDER BY ISNULL(DischargeDateTime,AdmitDateTime) desc) AS RN
		FROM #Inpatient
		WHERE Inpat_SuicideAttempt=1
		) a
	WHERE RN=1;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Inpat for Suicide Attempt in past year' as RiskFactor
			,InpatSuicideAttempt_ChecklistID
			,InpatSuicideAttempt_Facility
			,Disch_BedSecName
			,cast(InpatSuicideAttempt_DischargeDate as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(InpatSuicideAttempt_DischargeDate as date) or LastBHIPContact is NULL) then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(InpatSuicideAttempt_DischargeDate as date) or LastBHIPContact is NULL) then 'Case Review'
				  else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(InpatSuicideAttempt_DischargeDate as date) or LastBHIPContact is NULL) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #Inpat_SuicideAttempt a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.InpatSuicideAttempt_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
-- ED or Urgent Care visit with mental-health related diagnosis
-- =================================================================================================
--Acute MH crisis - ED/UC visit due to MH crisis in last 6 months
	drop table if exists #ED
	select MVIPersonSID
		,VisitDateTime as ED_VisitDate
		,case when PrimaryStop not in ('EMERGENCY DEPT','URGENT CARE CLINIC') then SecondaryStop else PrimaryStop end as ED_StopCodeName
		,ICD10Code as ED_ICD10Code
		,ICD10Description as ED_ICD10Description
		,ChecklistID as ED_ChecklistID
		,Facility as ED_Facility
	into #ED
	from (
		select co.MVIPersonSID
			,a.VisitDateTime
			,c.StopCodeName as PrimaryStop
			,d.StopCodeName as SecondaryStop
			,e.ICD10Code
			,e.ICD10Description
			,i.ChecklistID
			,i.Facility
			,row_number() over (PARTITION BY co.MVIPersonSID ORDER BY a.VisitDateTime desc) AS RN
		from #cohort co
		inner join Common.MVIPersonSIDPatientPersonSID m WITH (NOLOCK) on co.MVIPersonSID=m.MVIPersonSID
		inner join Outpat.Visit a WITH (NOLOCK) on m.PatientPersonSID=a.PatientSID
		left join Outpat.VDiagnosis b WITH (NOLOCK) on a.visitsid=b.VisitSID
		left join Lookup.StopCode c WITH (NOLOCK) on a.PrimaryStopCodeSID=c.StopCodeSID
		left join Lookup.StopCode d WITH (NOLOCK) on a.SecondaryStopCodeSID=d.StopCodeSID
		left join LookUp.ICD10 e WITH (NOLOCK) on b.ICD10SID=e.ICD10SID
		left join Dim.Location f WITH (NOLOCK) on a.LocationSID=f.LocationSID
		left join Dim.Division g WITH (NOLOCK) on f.DivisionSID=g.DivisionSID
		left join Lookup.Sta6a h WITH (NOLOCK) on g.Sta6a=h.Sta6a
		left join Lookup.ChecklistID i WITH (NOLOCK) on h.ChecklistID=i.ChecklistID
		where a.VisitDateTime > DATEADD(month,-12,getdate())
			and (c.EmergencyRoom_Stop=1 or d.EmergencyRoom_Stop=1)
			and 1 in (e.MHSUDdx_poss,e.SuicideAttempt)
		) a
	where RN=1;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'MH-related ED/Urgent Care visit' as RiskFactor
			,ED_ChecklistID
			,ED_Facility
			,ED_ICD10Description
			,cast(ED_VisitDate as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(ED_VisitDate as date) or LastBHIPContact is NULL) then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(ED_VisitDate as date) or LastBHIPContact is NULL) then 'Case Review'
				   else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(ED_VisitDate as date) or LastBHIPContact is NULL) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,NULL
	FROM #ED a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	--LEFT JOIN Lookup.StationColors b on a.PDE_Disch_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
-- SPED (Suicide Prevention in ED)
-- =================================================================================================
	DROP TABLE IF EXISTS #SPED
	SELECT mp.MVIPersonSID
		  ,l.ChecklistID as SPED_ChecklistID
		  ,v.timein as SPED_DateTime
		  ,c.Facility as SPED_Facility
		  ,SPED_6mo=1
	INTO #SPED
	FROM (
			SELECT PatientICN
			 ,timein
			 ,station = d.checklistid
			 ,RN=ROW_NUMBER() OVER(Partition By PatientICN ORDER BY timein DESC) --grab most recent SPED date
			FROM [PDW].[OMHSP_MIRECC_DOEx_SPEDCohort]  v WITH(NOLOCK)
			inner join Lookup.DivisionFacility as d --use this because RM MIRECC's file contains sta6a e.g. 659BY, 568A4, 573A4, 659BZ and others that need to be rolled up to main HCS
			on d.sta6a=v.sta6a
			WHERE ineligibledatetime is null --removes the cases that are identified as SPED ineligible per an SRM F/U entry
		) v
	INNER JOIN [Common].[vwMVIPersonSIDPatientICN] mp WITH(NOLOCK) on mp.PatientICN=v.PatientICN
	INNER JOIN [LookUp].[Sta6a] l WITH(NOLOCK) on l.Sta6a=v.Station
	INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=l.ChecklistID
	WHERE v.timein >= DATEADD(MONTH,-12,CAST(GETDATE() as date))
		and v.RN=1;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'SPED: Suicide Prevention in ED in last year' as RiskFactor --overlap between this and previous ED risk factor?
			,SPED_ChecklistID
			,SPED_Facility
			,NULL
			,cast(SPED_DateTime as date)
			,LastBHIPContact
			,case when (cast(LastBHIPContact as date) < cast(SPED_DateTime as date) or LastBHIPContact is NULL) then 1 
				  else 0 end Actionable
			,-1 as OverdueFlag
			,case when (cast(LastBHIPContact as date) < cast(SPED_DateTime as date) or LastBHIPContact is NULL) then 'Case Review'
				   else 'Informational' end ActionExpected
			,case when (cast(LastBHIPContact as date) < cast(SPED_DateTime as date) or LastBHIPContact is NULL) then 'Action Required'
				   else 'No Action Required' end as ActionLabel
			,b.Code
	FROM #SPED a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.SPED_ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  No pills on hand (overdue for fill)
-- =================================================================================================
	DROP TABLE IF EXISTS #NoPillsOnHand
	SELECT *
	INTO #NoPillsOnHand
	FROM (
		SELECT a.MVIPersonSID
				,a.RxOutpatSID
				,b.ChecklistID
				,a.PrescribingFacility
				,a.DrugNameWithoutDose
				,a.ReleaseDate
				,a.DaysWithNoPoH
				,c.DosageForm
				,RN=ROW_NUMBER() OVER(Partition By a.MVIPersonSID ORDER BY a.ReleaseDate DESC)
		FROM Present.RxTransitionsMH a WITH (NOLOCK)
		LEFT JOIN Lookup.ChecklistID b WITH (NOLOCK) on a.PrescribingFacility=b.Facility
		LEFT JOIN Present.Medications c WITH (NOLOCK) on a.MVIPersonSID=c.MVIPersonSID and a.RxOutpatSID=c.RxOutpatSID
		WHERE NoPoH_RxActive = 1 and DaysWithNoPoH >=0 and RxCategory <> 'OpioidForPain_Rx' 

		) a
	WHERE RN=1;


--removed PRN (as needed) prescription since we cannot predict no pills on hand for these medications 
delete from #NoPillsonHand
where RxOutpatSID in (select a.RxOutpatSID from #NoPillsonHand as a 
inner join  RxOut.RxOutpatMedInstructions as b WITH (NOLOCK) on a.RxOutpatSID = b.RxOutpatSID where Schedule like '%PRN%')

	DROP TABLE IF EXISTS #Injection
	SELECT a.MVIPersonSID
		,a.ChecklistID
		,a.PrescribingFacility
		,a.DrugNameWithoutDose
		,a.DaysWithNoPoH
		,a.ReleaseDate
		,m.DosageForm
		,m.RxOutpatSID
	INTO #Injection
	FROM #NoPillsOnHand a
	INNER JOIN Present.Medications m WITH (NOLOCK) on a.MVIPersonSID=m.MVIPersonSID and a.RxOutpatSID=m.RxOutpatSID
	WHERE m.DosageForm like '%inj%'


--remove Inj medications from No Pills On Hand to remove duplication in QuickView
delete from #NoPillsOnHand
where MVIPersonSID in 
	(select a.MVIPersonSID
 	 from #NoPillsOnHand a
	 inner join #Injection b on a.MVIPersonSID=b.MVIPersonSID and a.RxOutpatSID=b.RxOutpatSID
	)
;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'No Pills on Hand' as RiskFactor
			,a.ChecklistID
			,a.PrescribingFacility
			,CONCAT(a.DrugNameWithoutDose, ', ', a.DaysWithNoPoH, ' days without pills')
			,cast(a.ReleaseDate as date)
			,LastBHIPContact
			,1 as Actionable
			,-1 as OverdueFlag
			,'Assess/counsel on medication adherence' as ActionExpected
			,'Action Required' as ActionLabel
			,b.Code
	FROM #NoPillsOnHand a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;


	INSERT INTO #BHIP_RiskFactors
	SELECT a.MVIPersonSID
		,'Overdue Injection' as RiskFactor
		,a.ChecklistID
		,a.PrescribingFacility
		,CONCAT(a.DrugNameWithoutDose, ', ', a.DaysWithNoPoH, ' days without injection')
		,cast(a.ReleaseDate as date)
		,LastBHIPContact
		,1 as Actionable
		,-1 as OverdueFlag
		,'Assess/counsel on medication adherence' as ActionExpected
		,'Action Required' as ActionLabel
		,b.Code
	FROM #Injection a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  Rx Adherence Concerns
-- =================================================================================================
	--Logic adapted from SP: [App].[MBC_Medications_LSV]
	--Focused specifically on Psychotropic_Rx medications
	DROP TABLE IF EXISTS #MPR
	SELECT * 
	INTO #MPR
	FROM (
	SELECT DISTINCT co.MVIPersonSID
		,a.DrugNameWithoutDose
		,ISNULL(o.MPRToday,m.MPRToday) AS MPRToday 
		,CASE WHEN RxStatus IN ('Active','Suspended') 
			THEN CAST(DATEDIFF(M,ISNULL(o.TrialEndDateTime,m.TrialEndDateTime) ,GETDATE()) + ISNULL(o.MonthsInTreatment, m.MonthsInTreatment ) AS numeric(18,1))
			ELSE CAST(ISNULL(o.MonthsInTreatment, m.MonthsInTreatment ) AS numeric(18,1)) 
			END AS MonthsInTreatment
		,d.ChecklistID
		,d.Facility 
		,a.Psychotropic_Rx
		,CASE WHEN ISNULL(o.MPRToday,m.MPRToday) IS NULL THEN 0 ELSE 1 END AS MPRCalculated_Rx 
	FROM #Cohort AS co
	INNER JOIN [Present].[Medications] AS a WITH (NOLOCK)
		ON co.MVIPersonSID = a.MVIPersonSID
		AND (a.NationalDrugSID > 0 OR a.VUID > 0)
	LEFT JOIN [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] AS m WITH (NOLOCK)
		ON a.DrugNameWithoutDose = m.DrugNameWithoutDose 
		AND m.MVIPersonSID = a.MVIPersonSID
		AND m.MostRecentTrialFlag = 'True' and m.ActiveMedicationFlag='True'
		AND a.Sta3n <> 200
	LEFT JOIN [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] AS o WITH (NOLOCK)
		ON a.DrugNameWithDose = o.DrugNameWithDose 
		AND o.MVIPersonSID = a.MVIPersonSID
		AND o.MostRecentTrialFlag = 'True' and o.ActiveMedicationFlag='True'
		AND a.Sta3n <> 200
	LEFT JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	LEFT JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
		ON c.ChecklistID = d.ChecklistID
		) Src
	WHERE MPRToday < 0.80 AND Psychotropic_Rx=1

	INSERT INTO #BHIP_RiskFactors
	SELECT a.MVIPersonSID
			,'MPR < 80%' as RiskFactor
			,a.ChecklistID
			,b.Facility
			,CONCAT(a.DrugNameWithoutDose, ' ', ROUND(a.MPRToday * 100, 0), '%  over ', CAST(ROUND(a.MonthsInTreatment, 0) AS INT), ' months') as EventValue --rounding to nearest whole numbers
			,NULL as EventDate
			,LastBHIPContact
			,1 as Actionable
			,-1 as OverdueFlag
			,'Assess/counsel on medication adherence' as ActionExpected
			,'Action Required' as ActionLabel
			,b.Code
	FROM #MPR a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;


-- =================================================================================================
--  Overdue for labs
-- =================================================================================================
	DROP TABLE IF EXISTS #OverdueforLab
	SELECT DISTINCT a.MVIPersonSID
		,ISNULL(cm.DrugNameWithoutDose,lm.drug) as Drug
		,MAX(ISNULL(cm.ChecklistID,lm.ChecklistID)) as ChecklistID
		,OverdueForLab=1
	INTO #OverdueforLab
	FROM #Cohort a
	LEFT JOIN Pharm.ClozapineMonitoring cm WITH (NOLOCK) on a.MVIPersonSID= cm.MVIPersonSID
	LEFT JOIN Pharm.LithiumPatientReport lm WITH (NOLOCK) on  a.MVIPersonSID=lm.MVIPersonSID
	WHERE ([MostRecentClozapine_D&T] is null and max_releasedatetime <= getdate() - 14) --never had a lab and started more then 2 weeks ago
			OR lm.FollowUpKey in (2,3)
	GROUP BY a.MVIPersonSID, ISNULL(cm.DrugNameWithoutDose,lm.drug)

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Overdue for Lab' as RiskFactor
			,a.ChecklistID
			,ch.Facility
			,Drug
			,NULL
			,LastBHIPContact
			,1 as Actionable
			,-1 as OverdueFlag
			,'Order lab' as ActionExpected
			,'Action Required' as ActionLabel
			,b.Code
	FROM #OverdueforLab a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	LEFT JOIN Lookup.ChecklistID ch WITH (NOLOCK) on a.ChecklistID= ch.ChecklistID
	LEFT JOIN Lookup.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID;

-- =================================================================================================
--  Missed appointments, upcoming and past year appts
-- =================================================================================================
	drop table if exists #MissedAppointments_Vista
	select distinct a.MVIPersonSID
		,a.AppointmentSID
		,a.AppointmentDate
		,a.CancellationReason
		,a.CancellationReasonType
		,a.CancellationRemarks
		,a.LocationName
		,ChecklistID=ISNULL(cl.ChecklistID,a.Sta3n)
	into #MissedAppointments_Vista
	from (
			SELECT  
				mvi.MVIPersonSID
				,a.Sta3n
				,a.PatientSID
				,a.VisitSID
				,AppointmentSID
				,AppointmentDate=cast(AppointmentDateTime as date)
				,LocationName
				,Max(AppointmentDateTime) over (partition by mvi.MVIPersonSID) as MostRecentMissedAppointment
				,CancellationReasonType
				,CancellationReason
				,l.InstitutionSID
				,s.StopCode
				,StopCodeName
				,a.CancellationRemarks
			FROM #Cohort as co
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] as mvi	WITH (NOLOCK) ON co.MVIPersonSID=mvi.MVIPersonSID
			inner join [Appt].[Appointment] as a WITH (NOLOCK) on mvi.[PatientPersonSID] = a.[PatientSID] 
			inner join dim.CancellationReason as c WITH (NOLOCK) on a.[CancellationReasonSID] = c.[CancellationReasonSID] 
			inner join dim.Location as l WITH (NOLOCK) on a.LocationSID = l.LocationSID
			inner join Lookup.StopCode as s WITH (NOLOCK) on l.PrimaryStopCodeSID = s.StopCodeSID 
			WHERE a.AppointmentDateTime between getdate()-370 and getdate()
				AND a.[CancellationReasonSID] > 0 --cancelled
				AND mvi.MVIPersonSID > 0 
				AND s.MHOC_MentalHealth_Stop=1  
		) as a 
	left outer join [Present].[AppointmentsPast] as p WITH (NOLOCK) on a.MVIPersonSID = p.MVIPersonSID and p.VisitDateTime > a.MostRecentMissedAppointment and a.stopcode = PrimaryStopCode
	left join (	select cl.ChecklistID, i.InstitutionSID
				from dim.institution i WITH (NOLOCK)
				inner join LookUp.ChecklistID cl on i.StaPa=cl.StaPa
			  ) cl
		on a.InstitutionSID=cl.InstitutionSID
	where p.MVIPersonSID is null

	DROP TABLE IF EXISTS #MissedAppointments_Cerner;
	SELECT 
	   co.MVIPersonSID
	  ,AppointmentSID=AppointmentScheduleSID 
	  ,AppointmentDate=cast(TZBeginDateTime as date)
	  ,CancellationReason=DerivedCancelReason
	  ,CancellationReasonType=''
	  ,CancellationRemarks=''
	  ,LocationName=AppointmentLocation
	  ,ChecklistID=c.ChecklistID
	INTO #MissedAppointments_Cerner
	FROM #Cohort co
	inner join Cerner.FactAppointment f WITH (NOLOCK) on f.MVIPersonSID=co.MVIPersonSID
	INNER JOIN LookUp.ChecklistID c WITH (NOLOCK) on f.STAPA=c.StaPa
	WHERE 1=1
	  AND ScheduleState = 'Canceled'
	  AND (AppointmentLocation LIKE '%MH%' OR AppointmentLocation LIKE '%BH%')
	  AND TZBeginDateTime between getdate()-370 and getdate()

	DROP TABLE IF EXISTS #MissedAppointments
	SELECT MVIPersonSID, AppointmentSID, AppointmentDate, CancellationReason, CancellationReasonType, CancellationRemarks, LocationName, ChecklistID
	INTO #MissedAppointments
	FROM #MissedAppointments_Vista
	UNION
	SELECT MVIPersonSID, AppointmentSID, AppointmentDate, CancellationReason, CancellationReasonType, CancellationRemarks, LocationName, ChecklistID
	FROM #MissedAppointments_Cerner;

	--Total Missed Appts in past year
	drop table if exists #TotalMissedAppt
	select MVIPersonSID,sum(MissedAppointments) as TotalMissedAppointments
	into #TotalMissedAppt
	from (select distinct MVIPersonSID, count(AppointmentDate) as MissedAppointments, AppointmentSID
		  from #MissedAppointments
		  group by MVIPersonSID, AppointmentSID
		 ) a
	group by MVIPersonSID;

	--Pull in most recent MH encounter and next MH appt
	drop table if exists #pastMHappt
	select distinct b.MVIPersonSID
		,cast(b.visitdatetime as date) as MostRecentMHEnc_Date
		,PrimaryStopCodeName as MostRecentMHEnc_StopCode
		,c.ChecklistID as MostRecentMHEnc_ChecklistID
		,c.Facility as MostRecentMHEnc_Facility
	into #pastMHappt
	from #cohort a
	inner join Present.AppointmentsPast b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	inner join Lookup.ChecklistID c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	where MostRecent_ICN=1 and ApptCategory in ('MHRecent');

	drop table if exists #nextMHappt
	select distinct b.MVIPersonSID
		,b.AppointmentDateTime as NextMHAppt_Date
		,PrimaryStopCodeName as NextMHAppt_StopCode
		,c.ChecklistID as NextMHAppt_ChecklistID
		,c.Facility as NextMHAppt_Facility
	into #nextMHappt
	from #cohort a
	inner join Present.AppointmentsFuture b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	inner join Lookup.ChecklistID c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	where NextAppt_ICN=1 and ApptCategory in ('MHFuture');

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT a.MVIPersonSID
			,'Multiple missed MH appts past year' as RiskFactor
			,NULL
			,NULL
			,concat(TotalMissedAppointments, ' appts missed') 
			,NULL
			,LastBHIPContact
			,-1 as Actionable
			,-1 as OverdueFlag
			,'Informational' 
			,'No Action Required' 
			,NULL
	FROM #TotalMissedAppt a
	INNER JOIN #Cohort co on a.MVIPersonSID=co.MVIPersonSID
	--LEFT JOIN Lookup.StationColors b on a.ChecklistID=b.CheckListID
	LEFT JOIN #LastBHIPContact c on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #nextMHappt n on a.MVIPersonSID=n.MVIPersonSID
	WHERE TotalMissedAppointments > 1 and n.MVIPersonSID is null;

	INSERT INTO #BHIP_RiskFactors
	SELECT DISTINCT co.MVIPersonSID
			,'No MH encounter in last 6 mos & no upcoming appt' as RiskFactor
			,NULL
			,NULL
			,'Last MH Visit'
			,MostRecentMHEnc_Date
			,LastBHIPContact
			,1 as Actionable
			,-1 as OverdueFlag
			,'Consider scheduling MH appointment'
			,'Action Required' 
			,NULL
	FROM #Cohort co 
	LEFT JOIN #pastMHappt a on co.MVIPersonSID=a.MVIPersonSID
	LEFT JOIN #LastBHIPContact c on co.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #nextMHappt n on co.MVIPersonSID=n.MVIPersonSID
	WHERE (a.MostRecentMHEnc_Date < DATEADD(month,-6,getdate()) or a.MVIPersonSID is null) and n.MVIPersonSID is null;

-- =================================================================================================
--  Combine all into patient-level table 
-- =================================================================================================
	DROP TABLE IF EXISTS #PatientDetails
	SELECT DISTINCT a.*
		
		,bh.LastBHIPContact

		--REACH
		,rv.RV_Status
		,rv.RV_ChecklistID
		,rv.RV_Facility

		--STORM
		,strm.STORM_RiskCategory
		,strm.STORM_RiskCategoryLabel
		,strm.STORM_ChecklistID
		,strm.STORM_Facility

		--HRF
		,hrf.HRF_ChecklistID
		,hrf.HRF_Facility
		,hrf.HRF_CurrentlyActive
		,hrf.HRF_Status
		,HRF_Date=cast(hrf.HRF_Date as date) 

		--Behavioral flag
		,beh.Behavioral_ActionName
		,beh.Behavioral_ActionDateTime
		,beh.Behavioral_ChecklistID
		,beh.Behavioral_Facility

		--Most recent high/intermed CSRE (or most recent CSRE if never high/intermed)
		 ,CSRE_Date=cast(c.CSRE_Date as date)
		 ,CSRE_ClinImpressAcute=c.CSRE_Acute
		 ,CSRE_ClinImpressChronic=c.CSRE_Chronic
		 ,CSRE_ChecklistID=c.ChecklistID
		 ,CSRE_Facility=c.Facility

		 --Most recent C-SSRS
		 ,CSSRS_Date=cast(cssrs.CSSRS_Date as date)
		 ,CSSRS_Facility=cssrs.Facility
		 ,CSSRS_ChecklistID=cssrs.ChecklistID
		 ,display_CSSRS=cssrs.display_CSSRS

		 ----C-SSRS Risk ID
		 --,CSSRS_MostRecentPos_Date=cast(ci.CSSRS_MostRecentPos_Date as date)
		 --,ci.CSSRS_MostRecentPos_ChecklistID
		 --,ci.CSSRS_MostRecentPos_Facility

		 --Most recent CSSRS follow up CSRE
		 --,CSSRS_CSREDateTime=cast(c3.SurveyGivenDateTime as date)

		 -- Most recent AUDIT C
		 ,aud.AUDITC_ChecklistID
		 ,aud.AUDITC_Facility
		 ,AUDITC_SurveyDate=cast(aud.AUDITC_SurveyDate as date)
		 ,aud.AUDITC_SurveyResult
	
		--Inpat 
		,MHInpat_AdmitDate=cast(ip.MHInpat_AdmitDate as date)
		,MHInpat_DischargeDate=cast(ip.MHInpat_DischargeDate as date)
		,ip.MHInpat_ChecklistID
		,ip.MHInpat_Facility
		,ip.MHInpat_current
		,InpatSuicideAttempt_AdmitDate=cast(ip2.InpatSuicideAttempt_AdmitDate as date)
		,InpatSuicideAttempt_DischargeDate=cast(ip2.InpatSuicideAttempt_DischargeDate as date)
		,ip2.InpatSuicideAttempt_ChecklistID
		,ip2.InpatSuicideAttempt_Facility
		,ip2.SuicInpat_current

		--ED 
		,ED_VisitDate=cast(ed.ED_VisitDate as date)
		,ed.ED_StopCodeName
		,ed.ED_ICD10Code
		,ed.ED_ICD10Description

		--SPED
		,sp.SPED_6mo
		,SPED_DateTime=cast(sp.SPED_DateTime as date)
		,sp.SPED_ChecklistID
		,sp.SPED_Facility

		--SBOR
		,prep.SBOR_DateFormatted_Prep
		,prep.SBOR_Detail_Prep
		,att.SBOR_DateFormatted_Att_OD
		,att.SBOR_Detail_Att_OD

		--Appts  
		,tm.TotalMissedAppointments
		,case when tm.TotalMissedAppointments >1 and n.MVIPersonSID is null then 1 else 0 end MultipleMissedAppointments
		,case when (p.MostRecentMHEnc_Date < dateadd(month,-6,getdate()) or p.MostRecentMHEnc_Date is null) and n.MVIPersonSID is null then 1 else 0 end NoMHAppointment6mo
		,MostRecentMHEnc_Date=cast(p.MostRecentMHEnc_Date as date)
		,p.MostRecentMHEnc_StopCode
		,p.MostRecentMHEnc_ChecklistID
		,p.MostRecentMHEnc_Facility
		,n.NextMHAppt_Date
		,n.NextMHAppt_StopCode
		,n.NextMHAppt_ChecklistID
		,n.NextMHAppt_Facility

		--Meds
		--,psy.TotalPsychtropics

		--Overdue for meds or labs
		,case when poh.MVIPersonSID is not null or mpr.MVIPersonSID is not null or inj.MVIPersonSID is not null then 1 else 0 end OverdueforFill
		,ISNULL(ol.OverdueForLab,0) as OverdueForLab

	INTO #PatientDetails
	FROM #cohort a
	LEFT JOIN #LastBHIPContact bh on a.MVIPersonSID=bh.MVIPersonSID
	LEFT JOIN #REACH rv on a.MVIPersonSID=rv.MVIPersonSID
	--LEFT JOIN #ORM_RMS orm on a.MVIPersonSID=orm.MVIPersonSID
	LEFT JOIN #STORM strm on a.MVIPersonSID=strm.MVIPersonSID
	--LEFT JOIN #STORM90 strm90 on a.MVIPersonSID=strm90.MVIPersonSID
	LEFT JOIN #hrf hrf on a.MVIPersonSID=hrf.MVIPersonSID
	LEFT JOIN #behavior beh on a.MVIPersonSID=beh.MVIPersonSID
	LEFT JOIN #CSRE2 c on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #cssrs cssrs on a.MVIPersonSID=cssrs.MVIPersonSID
	--LEFT JOIN #cssrs_id ci on a.MVIPersonSID=ci.MVIPersonSID
	--LEFT JOIN (SELECT * FROM #CSRE_SurveyDates WHERE SurveyWithCSRE ='CSSRS') c3 on 
				--a.MVIPersonSID=c3.MVIPersonSID AND cssrs.CSSRS_Date=c3.SurveyCSRE_Date
	LEFT JOIN #AUDIT_C aud on a.MVIPersonSID=aud.MVIPersonSID
	LEFT JOIN #SPED sp on a.MVIPersonSID=sp.MVIPersonSID
	LEFT JOIN #TotalMissedAppt tm on a.MVIPersonSID=tm.MVIPersonSID
	LEFT JOIN #pastMHappt p on a.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #nextMHappt n on a.MVIPersonSID=n.MVIPersonSID
	--LEFT JOIN #psychotropics psy on a.MVIPersonSID=psy.MVIPersonSID
	LEFT JOIN #NoPillsOnHand poh on a.MVIPersonSID=poh.MVIPersonSID
	LEFT JOIN #Injection inj on a.MVIPersonSID=inj.MVIPersonSID
	LEFT JOIN #MPR mpr on a.MVIPersonSID=mpr.MVIPersonSID
	LEFT JOIN #OverdueforLab ol on a.MVIPersonSID=ol.MVIPersonSID
	LEFT JOIN #MH_Inpatient_MostRecent ip on a.MVIPersonSID=ip.MVIPersonSID
	LEFT JOIN #Inpat_SuicideAttempt ip2 on a.MVIPersonSID=ip2.MVIPersonSID
	LEFT JOIN #ED ed on a.MVIPersonSID=ed.MVIPersonSID
	LEFT JOIN #SBOR_Prep prep on a.MVIPersonSID=prep.MVIPersonSID
	LEFT JOIN #SBOR_Attempt_OD att on a.MVIPersonSID=att.MVIPersonSID;

-- =================================================================================================
--  Create risk scores for sorting on report - assign higher number to greater risk factor
-- =================================================================================================
	drop table if exists #riskscore
	select distinct a.MVIPersonSID 
		,CSRE_Score
		,HRF_Score
		,Behavioral_Score
		,SBOR_Score
		,MHInpat_Score
		,ED_Score
		,OverdueforFill
		,NoMHAppointment6mo
		,TotalMissedAppointments
		,OverdueForLab
		,case when CSRE_Score >0 then 1 end + case when HRF_Score > 0 then 1 else 0 end 
        + case when Behavioral_Score > 0  then 1 else 0 end + case when SBOR_Score > 0 then 1 else 0 end 
        + case when MHInpat_Score>0 then 1 else 0 end + case when ED_Score > 0 then 1 else 0 end as AcuteEventScore
		,OverdueforFill+NoMHAppointment6mo+OverdueForLab as ChronicCareScore
	into #riskscore
	from (
			select *
			,case 
				--when ( CSRE_ClinImpressAcute like '%high%' or CSRE_ClinImpressChronic like '%high%') and  CSRE_Date > dateadd(day,-7,getdate()) then 8
				when ( CSRE_ClinImpressAcute like '%high%' or CSRE_ClinImpressChronic like '%high%') and  (CSRE_Date > LastBHIPContact or LastBHIPContact is null) then 6
				--when ( CSRE_ClinImpressAcute like '%int%' or CSRE_ClinImpressChronic like '%int%') and  CSRE_Date > dateadd(day,-7,getdate()) then 7
				when ( CSRE_ClinImpressAcute like '%int%' or CSRE_ClinImpressChronic like '%int%') and  (CSRE_Date > LastBHIPContact or LastBHIPContact is null) then 5
				when ( CSRE_ClinImpressAcute like '%high%' or CSRE_ClinImpressChronic like '%high%')  then 2
				when ( CSRE_ClinImpressAcute like '%int%' or CSRE_ClinImpressChronic like '%int%') then 1
				else 0 
				end CSRE_Score
			,case 
				when HRF_Status like '%New%' and (HRF_Date > LastBHIPContact or LastBHIPContact is null) then 6
				when HRF_Status like '%React%' and (HRF_Date > LastBHIPContact or LastBHIPContact is null) then 3
				when HRF_Status like '%New%' or HRF_Status like '%React%' or HRF_Status like '%Cont%' then 1
				else 0
				end HRF_Score
			,case 
				when (Behavioral_ActionName='New' or Behavioral_ActionName='Reactivated') and (Behavioral_ActionDateTime > LastBHIPContact or LastBHIPContact is null) then 2
				when Behavioral_ActionDateTime is not null then 1
				else 0
				end Behavioral_Score
			,case 
				when SBOR_DateFormatted_Att_OD > dateadd(day,-7,getdate()) then 8
				when SBOR_DateFormatted_Att_OD is not null and (SBOR_DateFormatted_Att_OD > LastBHIPContact or LastBHIPContact is null) then 7
				when SBOR_DateFormatted_Prep > dateadd(day,-7,getdate()) then 6
				when SBOR_DateFormatted_Prep is not null and (SBOR_DateFormatted_Prep > LastBHIPContact or LastBHIPContact is null) then 5
				when SBOR_Detail_Att_OD is not null then 3
				when SBOR_Detail_Prep is not null then 2
				else 0
				end SBOR_Score
			,case 
				when MHInpat_DischargeDate > dateadd(day,-7,getdate()) or MHInpat_current=1 then 6
				when InpatSuicideAttempt_DischargeDate > dateadd(day,-7,getdate()) or SuicInpat_current=1 then 6
				when MHInpat_DischargeDate is not null and (MHInpat_DischargeDate > LastBHIPContact or LastBHIPContact is null) then 5
				when InpatSuicideAttempt_DischargeDate is not null and (InpatSuicideAttempt_DischargeDate > LastBHIPContact or LastBHIPContact is null) then 5
				when MHInpat_DischargeDate <= dateadd(day,-7,getdate()) and (MHInpat_DischargeDate <= LastBHIPContact or LastBHIPContact is null) then 1
				when InpatSuicideAttempt_DischargeDate <= dateadd(day,-7,getdate()) and (InpatSuicideAttempt_DischargeDate <= LastBHIPContact or LastBHIPContact is null) then 1
				else 0
				end as MHInpat_Score
			,case	
				when ED_VisitDate > dateadd(day,-7,getdate()) then 6
				when ED_VisitDate is not null and (ED_VisitDate > LastBHIPContact or LastBHIPContact is null) then 5
				when ED_VisitDate is not null then 1
				else 0 
				end as ED_Score
			from #PatientDetails 
			) as a;

	--Pull together BHIP team info and risk scores 
	drop table if exists #PatientDetails2
	select distinct a.MVIPersonSID
		,a.PatientICN
		,c.PatientName
		,a.TeamSID
		,a.Team
		,m.StaffName as MHTC_Provider
		,a.ChecklistID as BHIP_ChecklistID
		,s.Facility as BHIP_Facility
		,a.RelationshipStartDate as BHIP_StartDate
		,s.Code --color coding
		,b.CSRE_Score
		,b.HRF_Score
		,b.Behavioral_Score
		,b.SBOR_Score
		,b.MHInpat_Score
		,b.ED_Score
		,b.OverdueforFill
		,b.NoMHAppointment6mo
		,b.TotalMissedAppointments
		,b.OverdueForLab
		,b.AcuteEventScore
		,b.ChronicCareScore
		,lc.LastBHIPContact
		,Homeless=CASE WHEN c.Homeless=1 THEN 'Homeless Svcs or Dx' ELSE '' END
    ,case when vf.MVIPersonSID is not null then 'Yes' else 'No' end FLOWEligible
	into #PatientDetails2 
	from #cohort a
	left join #riskscore b on a.MVIPersonSID=b.MVIPersonSID
	left join Lookup.StationColors s WITH (NOLOCK) on a.ChecklistID=s.CheckListID
	left join Present.Provider_MHTC m WITH (NOLOCK) on a.MVIPersonSID=m.MVIPersonSID and a.ChecklistID=m.ChecklistID
	left join Common.MasterPatient c WITH (NOLOCK) on a.MVIPersonSID=c.MVIPersonSID 
	left join #LastBHIPContact lc on a.MVIPersonSID=lc.MVIPersonSID
    left outer join DOEx.vwFLOWPatientCohort vf on a.mvipersonsid = vf.mvipersonsid

-- =================================================================================================
--  Complete Risk Factor table with additional components needed for Power BI report
-- =================================================================================================
	DROP TABLE IF EXISTS #BHIP_RiskFactors_Final
	SELECT DISTINCT r.[MVIPersonSID]
		,r.[RiskFactor]
		,r.[ChecklistID]
		,r.[Facility] 
		,EventValue=CASE WHEN r.RiskFactor like '%Tobacco%' and t.PositiveScreen<>1 THEN NULL ELSE r.[EventValue] END
		,EventDate=
			CASE WHEN p.MHInpat_Score>0 and r.EventDate is null and r.RiskFactor= 'Inpat MH Stay in past year'
				 THEN CAST(DATEADD(DAY, -2, GETDATE()) AS DATE) ELSE r.EventDate END 
		,r.[LastBHIPContact]
		,r.[Actionable] 
		,r.[OverdueFlag]
		,r.[ActionExpected] 
		,r.[ActionLabel]
		,r.[Code] 
		,TobaccoPositiveScreen = t.PositiveScreen
	INTO #BHIP_RiskFactors_Final 
	FROM #BHIP_RiskFactors r
	LEFT JOIN #PatientDetails2 p on r.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #TUDScreen_recent t WITH (NOLOCK)
		ON r.MVIPersonSID=t.MVIPersonSID
		AND r.RiskFactor like '%Tobacco%'
		AND CAST(r.EventDate as DATE)=CAST(t.HealthFactorDateTime as DATE)

-- --=================================================================================================
-- -- Save patient-level table and risk factors table as permanent
-- --=================================================================================================
	EXEC [Maintenance].[PublishTable] 'BHIP.PatientDetails','#PatientDetails2'

	EXEC [Maintenance].[PublishTable] 'BHIP.RiskFactors','#BHIP_RiskFactors_Final'

	EXEC [Maintenance].[PublishTable] 'BHIP.MissedAppointments_PBI','#MissedAppointments'


END