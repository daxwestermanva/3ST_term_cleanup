-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	7/25/2024
-- Description:	Combined cohort of all Power BI source reports for cross report drill through. Includes
--				source report flag, which can be used to filter between cohorts in the target report
--				(Power BI file name: CaseFactors.pbix and Clinical_Insights.pbix).
--
--				Includes patient details, reporttypes, riskflags, and screening information as well as 
--				related to the Power BI combined cohort.
--
--				Row duplication is expected in all of these datasets.
--
-- Modifications:
-- 8/8/2024	  - CW	Adding SSP/IDU cohort 
-- 10/10/2024 - CW	Adding SUD Case Finder cohort
-- 10/21/2024 - CW  Adding HomeStation ChecklistID for instances where ChecklistID IS NULL
-- 2/11/2025  - CW  Adding FLOW eligibility status
-- 3/24/2025  - CW  Adding code to feed data/tables for the following Views: 
						--[App].[PBIReports_ReportType]
						--[App].[PBIReports_RiskFlags]
						--[App].[PBIReports_ComunityCare]
						--[App].[PBIReports_Screening]
-- 5/19/2025  - CW  Ensuring no test patients are in this dataset
-- =======================================================================================================
CREATE PROCEDURE [Code].[Common_PBIReportsCohort]
AS
BEGIN

-------------------------------------------------------------
-------------------------------------------------------------
/* 
TABLE 1: [Common].[PBIReportsCohort]

Get MVIPersonSID and ChecklistID for all PowerBI reports 
wanting to use cross report drill through features 
*/
-------------------------------------------------------------
-------------------------------------------------------------
	--Get combined Power BI cohort
	DROP TABLE IF EXISTS #Cohort_Prep
	SELECT a.*
	INTO #Cohort_Prep 
	FROM (
		--BHIP
		SELECT MVIPersonSID, ChecklistID=BHIP_ChecklistID, Report='BHIP'
		FROM BHIP.PatientDetails WITH (NOLOCK)
		UNION
		--IDU
		SELECT MVIPersonSID, CheckListID, Report='IDU'
		FROM SUD.IDUCohort WITH (NOLOCK)
		UNION
		--COMPACT
		SELECT MVIPersonSID, ChecklistID_EpisodeBegin, Report='COMPACT'
		FROM COMPACT.Episodes WITH (NOLOCK)
		UNION
		SELECT MVIPersonSID, ChecklistID, Report='COMPACT'
		FROM COMPACT.Template WITH (NOLOCK) 
		UNION
		--SUD CaseFinder
		SELECT a.MVIPersonSID, b.ChecklistID, Report='SUDCaseFinder'
		FROM SUD.CaseFinderCohort a WITH (NOLOCK)
		LEFT JOIN[Present].[Provider_Active] b WITH (NOLOCK)
			ON a.MVIPersonSID = b.MVIPersonSID
		) a
	INNER JOIN Common.MasterPatient b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE b.TestPatient=0

	--Get PatientICN to allow for easier drill option from SSRS
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT 
		 a.MVIPersonSID
		,b.PatientICN
		,Checklistid=ISNULL(a.ChecklistID,h.ChecklistiD)
		,a.Report
		,FlowEligible=CASE WHEN vw.MVIPersonSID IS NOT NULL THEN 'Yes' ELSE 'No' END
	INTO #Cohort
	FROM #Cohort_Prep a
	INNER JOIN Common.MasterPatient b
		ON a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN Present.HomestationMonthly h
		ON a.MVIPersonSID=h.MVIPersonSID
	LEFT JOIN DOEx.vwFLOWPatientCohort vw
		ON a.MVIPersonSID=vw.MVIPersonSID;

-------------------------------------------------------------
--Get details for CaseFactors.pbix and Clinical_Insights.pbix
-------------------------------------------------------------
	--Get demographics
	DROP TABLE IF EXISTS #FinalCohort_Prep
	SELECT 
		 MVIPersonSID
		,PatientICN
		,FlowEligible
		,Checklistid
		,Report
		,FullPatientName
		,MailAddress
		,StreetAddress
		,MailCityState
		,PhoneNumber
		,Zip
		,CASE 
			WHEN age <20 THEN 1
			WHEN age between 20 and 39 THEN 2
			WHEN age between 40 and 59 THEN 3
			WHEN age between 60 and 79 THEN 4
			WHEN age between 80 and 99 THEN 5
			WHEN age>=100 THEN 6
			End AgeSort
		,CASE 
			WHEN age <20 THEN '<20'
			WHEN age between 20 and 39 THEN '20-39'
			WHEN age between 40 and 59 THEN '40-59'
			WHEN age between 60 and 79 THEN '60-79'
			WHEN age between 80 and 99 THEN '80-99'
			WHEN age>=100 THEN '100+'
			End AgeCategory		
		,BranchOfService
		,DateOfBirth
		,CASE WHEN DisplayGender='Man' THEN 'Male'
			  WHEN DisplayGender='Woman' THEN 'Female'
			  WHEN DisplayGender='Transgender Man' THEN 'Transgender Male'
			  WHEN DisplayGender='Transgender Woman' THEN 'Transgender Female'
			  ELSE DisplayGender
		 END AS DisplayGender
		,Race
		,ServiceSeparationDate
		,DoDSeprationType=
			CASE WHEN ServiceSeparationDate <= GETDATE() AND ServiceSeparationDate >= DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN 'DoD Separation - Past Year' 
				 WHEN ServiceSeparationDate IS NULL THEN 'No DoD Separation Date on File'
				 ELSE 'DoD Separation - Over Year Ago' END
		,PeriodOfService
		,COMPACTEligible=CASE WHEN (PriorityGroup NOT IN (1,2,3,4,5,6,7,8) OR PrioritySubGroup IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible Only' 
			  WHEN (PriorityGroup IN (1,2,3,4,5,6,7,8) AND PrioritySubGroup NOT IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible'
			  ELSE 'Not Verified as COMPACT Eligible' END
		 ,HomelessSlicer=CASE WHEN Homeless=1 THEN 'Yes' ELSE 'No' END
	INTO #FinalCohort_Prep
	FROM ( SELECT DISTINCT c.*
				,ISNULL(mp.DateOfBirth,CASE WHEN sp.DateOfBirth>'1900-01-01' THEN sp.DateOfBirth ELSE NULL END) AS DateOfBirth
				,mp.Age
				,mp.BranchOfService
				,ISNULL(mp.DisplayGender,CASE WHEN sp.SexCode='M' THEN 'Male' WHEN sp.SexCode='F' THEN 'Female' ELSE NULL END) AS DisplayGender
				,mp.Race
				,mp.PeriodOfService
				,mp.COMPACTEligible
				,mp.PriorityGroup
				,mp.PrioritySubGroup
				,mp.ServiceSeparationDate
				,mp.Zip
				,MailCityState=CONCAT(ISNULL(mc.MailCity,'Unknown'), ', ', mc.MailState)
				,FullPatientName=CONCAT(PatientName,' (',LastFour,')')
				,MailAddress=CONCAT(COALESCE(mc.MailStreetAddress1, mc.MailStreetAddress2, mc.MailStreetAddress3),' ',mc.MailCity,', ',mc.MailState,' ', mc.MailZip)
				,StreetAddress=CONCAT(COALESCE(mp.StreetAddress1, mp.StreetAddress2, mp.StreetAddress3),' ',mp.[City],', ',mp.[State],' ',mp.[Zip])
				,mp.PhoneNumber
				,mp.Homeless
			FROM #Cohort c
			LEFT JOIN Common.MasterPatient mp WITH (NOLOCK)	
				ON c.MVIPersonSID=mp.MVIPersonSID
			LEFT JOIN Common.MVIPersonSIDPatientPersonSID psid WITH (NOLOCK)
				ON mp.MVIPersonSID=psid.MVIPersonSID
			LEFT JOIN Common.MasterPatient_Contact mc
				ON c.MVIPersonSID=mc.MVIPersonSID
			LEFT JOIN [PDW].[SpanExport_tbl_Patient] sp WITH (NOLOCK)
				ON psid.PatientPersonSID = sp.PatientID) Src;

	UPDATE #FinalCohort_Prep
	SET COMPACTEligible = 'Active COMPACT Episode' 
	FROM #FinalCohort_Prep f
	LEFT JOIN COMPACT.Episodes e WITH (NOLOCK)
		ON f.MVIPersonSID=e.MVIPersonSID
	WHERE ActiveEpisode=1;

	--Get prevalence of BHIP Assessment within past year
	DROP TABLE IF EXISTS #BHIPAssessment
	SELECT *, BHIPPastYear=CASE WHEN VisitDateTime > DATEADD(day, -366, GETDATE()) THEN 1 ELSE 0 END
	INTO #BHIPAssessment
	FROM Present.BHIP_Assessments
	WHERE AssessmentRN=1;

	--Final cohort - All together
	DROP TABLE IF EXISTS #FinalCohort
	SELECT DISTINCT f.MVIPersonSID
		,f.PatientICN
		,f.ChecklistID
		,FlowEligible
		,Report
		,HomelessSlicer
		,FullPatientName
		,MailAddress
		,StreetAddress
		,MailCityState
		,PhoneNumber
		,Zip
		,AgeSort
		,AgeCategory=ISNULL(AgeCategory,'Unknown')
		,BranchOfService=ISNULL(BranchOfService,'Unknown')
		,DateOfBirth
		,DisplayGender=ISNULL(DisplayGender,'Unknown')
		,Race=ISNULL(Race,'Unknown')
		,ServiceSeparationDate
		,DoDSeprationType=ISNULL(DoDSeprationType,'Unknown')
		,PeriodOfService=ISNULL(PeriodOfService,'Unknown')
		,COMPACTEligible=ISNULL(COMPACTEligible,'Not Verified as COMPACT Eligible')
		,BHIPAssessment=
			CASE WHEN BHIPPastYear = 1 THEN 'BHIP Assessment Past Year' ELSE 'No BHIP Assessment Past Year' END
	INTO #FinalCohort
	FROM #FinalCohort_Prep f
	LEFT JOIN #BHIPAssessment b
		ON f.MVIPersonSID=b.MVIPersonSID;	

-------------------------------------------------------------
-------------------------------------------------------------
/* 
TABLE 2: [PBIReports].[ReportType]

Get info needed for PBI drill slicers in Clinical_Insights.pbix
Adapted from [App].[PowerBIReports_ReportType] 
*/
-------------------------------------------------------------
-------------------------------------------------------------
	--Define Report for Power BI slicer
	DROP TABLE IF EXISTS #ReportType 
	SELECT DISTINCT a.MVIPersonSID
		,a.ChecklistID
		,Report=CASE WHEN Report='BHIP' THEN 'BHIP Care Coordination'
					 WHEN Report='CaseFinder' THEN 'SUD Case Finder'
					 WHEN Report='COMPACT' THEN 'COMPACT Act Care Coordination'
					 WHEN Report='IDU' THEN 'Syringe Services Program (Confirmed IDU)'
					 WHEN Report='SUDCaseFinder' THEN 'Substance Use Population Mgmt'
				END
		,b.Confirmed
	INTO #ReportType
	FROM #FinalCohort a WITH (NOLOCK)
	LEFT JOIN SUD.IDUCohort b WITH (NOLOCK) 
		ON a.MVIPersonSID=b.MVIPersonSID

	--Only interested in Confirmed IDU SSP cohort (when it comes to Clinical Insights for the SSP cohort)
	DELETE FROM #ReportType
	WHERE (Confirmed = 0 OR Confirmed = -1 OR Confirmed IS NULL) AND Report='Syringe Services Program (Confirmed IDU)'

	--Helps the report run faster to have all slicers coming from same procedure
	DROP TABLE IF EXISTS #ProviderSlicers
	SELECT  
		d.ChecklistID, b.MVIPersonSID, a.Team, a.TeamRole, a.StaffName AS ProviderName
	INTO #ProviderSlicers
	FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
	INNER JOIN #FinalCohort AS b 
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	INNER JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
		ON c.checklistID = d.ChecklistID
	UNION
	SELECT c.ChecklistID
		,a.MVIPersonSID
		,CASE WHEN b.Program = 'VJO' THEN 'Veterans Justice Outreach (VJO)' 
			  WHEN b.Program = 'HCRV' THEN 'Health Care for Re-Entry Veterans (HCRV)'
			  WHEN b.Program = 'HCHV Case Management' THEN 'Health Care for Homeless Veterans (HCHV) Case Management'
			  ELSE b.PROGRAM END AS Program
		,'Lead Case Manager' AS TeamRole
		,b.LeadCaseManager AS ProviderName
	FROM #FinalCohort a WITH (NOLOCK)
	INNER JOIN Common.MasterPatient m WITH (NOLOCK)
		ON a.MVIPersonSID=m.MVIPersonSID
	INNER JOIN [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] b WITH (NOLOCK)
		ON m.PatientICN = b.PatientICN
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
		ON b.Program_Entry_Sta3n = c.Sta3n

	DROP TABLE IF EXISTS #FutureAppointments
	SELECT MVIPersonSID
		,ChecklistID
		,PrimaryStopCodeName
		,AppointmentType
		,AppointmentDateTime
		,FormattedDate=FORMAT(CAST(AppointmentDateTime as date), 'M/d/yy')
	INTO #FutureAppointments
	FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
	WHERE AppointmentDateTime >= GETDATE() AND AppointmentDateTime <= DATEADD(day, 366, getdate())
	AND (ApptCategory IN ('AnyFuture'))
	AND NextAppt_ICN=1;

	--Combine for final output
	DROP TABLE IF EXISTS #PowerBISlicers
	SELECT 
		 a.MVIPersonSID
		,a.Report
		,ProviderName=ISNULL(p.ProviderName,'Unassigned')
		,Team=ISNULL(p.Team,'Unassigned')
		,p.TeamRole
		,c.ChecklistID
		,c.VISN
		,s.Facility
		,AppointmentInfo=
			CASE WHEN AppointmentDateTime IS NULL THEN 'No Appointment in Next 365 days'
				 ELSE CONCAT('(', f.ChecklistID, ') ', f.FormattedDate, ' | ', ISNULL(f.PrimaryStopCodeName,f.AppointmentType)) END
		,AppointmentSlicer=
			CASE WHEN AppointmentDateTime <= DATEADD(day, 7, GETDATE()) THEN 'Next 7 days'
					WHEN AppointmentDateTime <= DATEADD(day, 30, GETDATE()) THEN 'Next 8-30 days' 
					WHEN AppointmentDateTime <= DATEADD(day, 90, GETDATE()) THEN 'Next 31-90 days' 
					WHEN AppointmentDateTime <= DATEADD(day, 180, GETDATE()) THEN 'Next 91-180 days'
					WHEN AppointmentDateTime <= DATEADD(day, 366, GETDATE()) THEN 'Next 181-365 days' 
					ELSE 'No Appointment in Next 365 days' END
		,AppointmentSort=
			CASE WHEN AppointmentDateTime <= DATEADD(day, 7, GETDATE()) THEN 2
					WHEN AppointmentDateTime <= DATEADD(day, 30, GETDATE()) THEN 3 
					WHEN AppointmentDateTime <= DATEADD(day, 90, GETDATE()) THEN 4 
					WHEN AppointmentDateTime <= DATEADD(day, 180, GETDATE()) THEN 5
					WHEN AppointmentDateTime <= DATEADD(day, 366, GETDATE()) THEN 6
					ELSE 1 END
	INTO #PowerBISlicers
	FROM #ReportType a
	LEFT JOIN #ProviderSlicers p
		ON a.MVIPersonSID=p.MVIPersonSID AND a.ChecklistID=p.ChecklistID
	LEFT JOIN LookUp.ChecklistID c WITH (NOLOCK)
		ON ISNULL(a.ChecklistID,p.ChecklistID)=c.ChecklistID
	LEFT JOIN LookUp.StationColors s WITH (NOLOCK)
		ON s.CheckListID=c.ChecklistID
	LEFT JOIN #FutureAppointments f
		ON a.MVIPersonSID=f.MVIPersonSID;


-------------------------------------------------------------
-------------------------------------------------------------
/*
TABLE 3: [PBIReports].[RiskFlags]

Get info needed for PBI visuals re: risk flags in CaseFactors.pbix and Clinical_Insights/pbix
Adapted from [App].[PowerBIReports_RiskFlags] and includes:
	- High Risk for Suicide Flag	
	- Behavioral Flag
	- Missing Patient Flag
	- REACH Vet
	- Most Recent Suicide Event
	- Most Recent Overdose Event
	- Most Recent Community Care (ED, OD, OP: Mental Health and Chronic Pain)
	- Most Recent COMPACT Act Episode
*/
-------------------------------------------------------------
-------------------------------------------------------------
	--High Risk 
	DROP TABLE IF EXISTS #HRF
	SELECT DISTINCT
		s.MVIPersonSID
		,h.OwnerChecklistID
		,FlagType	=CASE WHEN ActiveFlag='Y' THEN 'Active PRF HRS'
						  WHEN ActiveFlag='N' THEN 'Inactive PRF HRS'
						  ELSE 'None' END
		,FlagInfo	=CASE WHEN ActiveFlag IN ('Y','N') THEN CONCAT('(',cast(h.OwnerChecklistID as varchar),') ',cl.Facility)
						  ELSE NULL END
		,FlagDate=cast(p.LastActionDateTime as date)
	INTO #HRF
	FROM [PRF_HRS].[EpisodeDates] h WITH (NOLOCK)
	INNER JOIN LookUp.ChecklistID cl WITH (NOLOCK)
		ON h.OwnerChecklistID=cl.ChecklistID
	INNER JOIN [PRF_HRS].[PatientReport_v02] p WITH (NOLOCK)
		ON h.MVIPersonSID=p.MVIPersonSID
	INNER JOIN #FinalCohort s 
		ON s.MVIPersonSID=h.MVIPersonSID
	WHERE p.LastActionDateTime > DATEADD(year,-5,cast(getdate() as date))

	--Behavioral 
	DROP TABLE IF EXISTS #Behavioral
	SELECT DISTINCT c.MVIPersonSID
		,h.OwnerChecklistID
		,FlagType	=CASE WHEN ActiveFlag='Y' THEN 'Active Behavioral'
						  WHEN ActiveFlag='N' THEN 'Inactive Behavioral'
						  ELSE 'None' END
		,FlagInfo	=CASE WHEN ActiveFlag IN ('Y','N') THEN CONCAT('(',cast(OwnerChecklistID as varchar),') ',OwnerFacility) --, ' | ', ActionTypeDescription)
						  ELSE NULL END
		,CAST(h.ActionDateTime AS Date) AS ActionDateTime
	INTO #Behavioral
	FROM #FinalCohort AS c
	LEFT JOIN [PRF].[BehavioralMissingPatient]  AS h WITH(NOLOCK)
		ON c.MVIPersonSID=h.MVIPersonSID AND h.NationalPatientRecordFlag = 'BEHAVIORAL'
	WHERE h.ActionDateTime > DATEADD(year,-5,cast(getdate() as date));

	--Missing
	DROP TABLE IF EXISTS #Missing
	SELECT DISTINCT c.MVIPersonSID
		,h.OwnerChecklistID
		,FlagType	=CASE WHEN ActiveFlag='Y' THEN 'Active Missing Patient'
						  WHEN ActiveFlag='N' THEN 'Inactive Missing Patient'
						  ELSE 'None' END
		,FlagInfo	=CASE WHEN ActiveFlag IN ('Y','N') THEN CONCAT('(',cast(OwnerChecklistID as varchar),') ',OwnerFacility) --, ' | ', ActionTypeDescription)
						  ELSE NULL END
		,CAST(h.ActionDateTime AS Date) AS ActionDateTime
	INTO #Missing
	FROM #FinalCohort AS c
	LEFT JOIN [PRF].[BehavioralMissingPatient]  AS h WITH(NOLOCK)
		ON c.MVIPersonSID=h.MVIPersonSID AND h.NationalPatientRecordFlag = 'MISSING PATIENT' 
	WHERE h.ActionDateTime > DATEADD(year,-5,cast(getdate() as date));

	--Reach Vet
	DROP TABLE IF EXISTS #REACH_Prep
	SELECT 
		 a.MVIPersonSID
		,h.ChecklistID
		,ck.Facility
		,CAST(h.Top01Percent AS tinyint) AS Top01Percent
		,c.ProviderType
		,c.UserName
		,ActionDateTime=cast(h.LastIdentifiedExcludingCurrentMonth as date)
	INTO #REACH_Prep
	FROM #FinalCohort AS a 
	LEFT JOIN [REACH].[History] AS h WITH (NOLOCK) ON a.MVIPersonSID = h.MVIPersonSID
	LEFT JOIN 
		(
			SELECT	
				h.MVIPersonSID
				,CASE WHEN h.CoordinatorName IS NOT NULL THEN 'REACH VET Coordinator' ELSE NULL END AS ProviderType
				,h.CoordinatorName AS UserName 
			FROM [REACH].[QuestionStatus] AS h WITH (NOLOCK)
			WHERE h.CoordinatorName IS NOT NULL
			UNION ALL
			SELECT	
				h.MVIPersonSID
				,CASE WHEN h.ProviderName IS NOT NULL THEN 'REACH VET Provider' ELSE NULL END AS ProviderType
				,h.ProviderName AS UserName 
			FROM [REACH].[QuestionStatus] AS h WITH (NOLOCK)
			WHERE h.ProviderName IS NOT NULL
		) AS c ON a.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN LookUp.ChecklistID ck WITH (NOLOCK)
		ON h.ChecklistID=ck.ChecklistID;

	DROP TABLE IF EXISTS #REACH
	SELECT MVIPersonSID
		,ChecklistID
		,FlagType	=CASE WHEN Top01Percent=1 THEN 'Currently Identified in REACH VET: Yes'
						  ELSE 'Currently Identified in REACH VET: No' END
		,FlagInfo	=CASE WHEN Top01Percent=0 THEN  CONCAT('(',cast(ChecklistID as varchar),') ',Facility, ' | ', ProviderType, ': ', UserName, ' | ', 'Most Recent Month Identified: ')
						  WHEN Top01Percent=1 THEN  CONCAT('(',cast(ChecklistID as varchar),') ',Facility, ' | ', ProviderType, ': ', UserName)
						  ELSE 'No History of REACH VET Identification' END
		,FlagDate=cast(ActionDateTime as date)
	INTO #REACH
	FROM #REACH_Prep
	WHERE ActionDateTime > DATEADD(year,-5,cast(getdate() as date))

	--Most recent SDV
	DROP TABLE IF EXISTS #SDV
	SELECT TOP (1) WITH TIES a.MVIPersonSID
		,a.ChecklistID
		,FlagType='Suicide Event'
		,FlagInfo=concat(b.SDVClassification, '  |  ',concat(a.MethodType1, ': ', a.Method1))
		,FlagDate = cast(ISNULL(a.EventDateFormatted, a.EntryDateTime) as date)
	INTO #SDV
	FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
	INNER JOIN #FinalCohort co 
		ON co.MVIPersonSID=a.MVIPersonSID
	INNER JOIN SBOSR.SDVDetails_PBI b WITH (NOLOCK)
		ON a.MVIPersonSID=b.MVIPersonSID
		AND cast(ISNULL(a.EventDateFormatted, a.EntryDateTime) as date)=b.[date]
	WHERE (a.EventType='Suicide Event')
		AND ISNULL(a.EventDateFormatted, a.EntryDateTime) > DATEADD(year,-5,cast(getdate() as date))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EventDateFormatted, a.EntryDateTime) DESC, EntryDateTime DESC);

	--Most recent OD (intentional or accidental)
	DROP TABLE IF EXISTS #OD
	SELECT TOP (1) WITH TIES a.MVIPersonSID
		,a.ChecklistID
		,FlagType='Overdose Event'
		,FlagInfo=concat(b.SDVClassification, '  |  ',concat(a.MethodType1, ': ', a.Method1))
		,FlagDate = cast(ISNULL(a.EventDateFormatted, a.EntryDateTime) as date)
	INTO #OD
	FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
	INNER JOIN #FinalCohort co 
		ON co.MVIPersonSID=a.MVIPersonSID
	INNER JOIN SBOSR.SDVDetails_PBI b WITH (NOLOCK)
		ON a.MVIPersonSID=b.MVIPersonSID
		AND cast(ISNULL(a.EventDateFormatted, a.EntryDateTime) as date)=b.[date]
	WHERE (a.Overdose=1)
		AND ISNULL(a.EventDateFormatted, a.EntryDateTime) > DATEADD(year,-5,cast(getdate() as date))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EventDateFormatted, a.EntryDateTime) DESC, EntryDateTime DESC);

	--Community Care
	--Possibe Overdose
	DROP TABLE IF EXISTS #CommunityCareOD
	SELECT TOP (1) WITH TIES c.MVIPersonSID
		,od.ChecklistID
		,FlagType='Community Care Treatment'
		,FlagInfo='Outpatient - Possible Overdose Event'
		,FlagInfo2='Outpatient - Possible Overdose Event'
		,FlagDate=cast(od.EpisodeEndDate as date)
	INTO #CommunityCareOD
	FROM #FinalCohort c
	LEFT JOIN CommunityCare.ODUniqueEpisode od WITH (NOLOCK)
		ON c.MVIPersonSID=od.MVIPersonSID
	--Criteria used in SUD.Cohort (re: STORM cohort and mitigation strategy)
	WHERE SBOR_CSRE_Any=0  --no SBOR was recorded after community care episode
		AND ExpectedSBOR=1 --SBOR was expected
		AND CAST(EpisodeStartDate as DATE) > DATEADD(YEAR, -5, CAST(GETDATE() AS DATE))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY od.EpisodeEndDate DESC);

	--Emergency Visit
	DROP TABLE IF EXISTS #CommunityCareED
	SELECT TOP (1) WITH TIES MVIPersonSID
		,ChecklistID
		,FlagType='Community Care Treatment'
		,FlagInfo='Emergency Visit'
		,FlagInfo2='Emergency Visit'
		,FlagDate=cast(Service_End_Date as date)
	INTO #CommunityCareED
	FROM CommunityCare.EmergencyVisit WITH (NOLOCK)
	WHERE CommunityEmergencyVisit=1
	AND Service_End_Date > DATEADD(YEAR, -5, CAST(GETDATE() AS DATE))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY Service_End_Date DESC)

	--COMPACT Act Episode
	DROP TABLE IF EXISTS #Compact
	SELECT TOP (1) WITH TIES a.MVIPersonSID
		,ChecklistID=ISNULL(s.ChecklistID,b.ChecklistID_EpisodeBegin)
		,FlagType='Community Care Treatment'
		,FlagInfo=CASE WHEN ActiveEpisode=1 THEN 'Active COMPACT Episode | Encounter Start Date' ELSE 'Inactive COMPACT Episode | Encounter Start Date' END
		,FlagInfo2=CASE WHEN ActiveEpisode=1 THEN 'Active COMPACT Episode' ELSE 'Inactive COMPACT Episode' END
		,FlagDate=cast(a.EncounterStartDate as date)
	INTO #Compact
	FROM COMPACT.ContactHistory a WITH (NOLOCK)
	INNER JOIN COMPACT.Episodes b WITH (NOLOCK)
		ON a.MVIPersonSID=b.MVIPersonSID AND a.EpisodeRankDesc=b.EpisodeRankDesc
	INNER JOIN Lookup.Sta6a s WITH (NOLOCK)
		ON a.Sta6a=s.Sta6a
	WHERE a.ContactType LIKE 'CC%'
	AND (b.EpisodeEndDate > DATEADD(YEAR, -5, CAST(GETDATE() AS date)) OR EpisodeEndDate IS NULL)
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY b.EpisodeBeginDate DESC)

	--Outpatient: Mental Health
	DROP TABLE IF EXISTS #MHICD10
	SELECT DISTINCT ICD10Code
	INTO #MHICD10
	FROM LookUp.ICD10
	WHERE MHSUDdx_poss=1;

	DROP TABLE IF EXISTS #CommunityOPMH_Prep
	SELECT DISTINCT a.Patient_ICN
		,a.Primary_ICD
		,i.ICD10Code
		,Sta6a=a.Station_Number
		,Service_End_Date=cast(a.Service_End_Date as date)
	INTO #CommunityOPMH_Prep
	FROM PDW.CDWWork_IVC_CDS_CDS_Claim_Header a
	INNER JOIN #MHICD10 i
		ON CONCAT(LEFT(a.Primary_ICD,3),'.',SUBSTRING(a.Primary_ICD,4,5))=i.ICD10Code
	WHERE Patient_ICN IS NOT NULL
	AND Service_End_Date > DATEADD(YEAR, -5, CAST(GETDATE() AS DATE));

	DROP TABLE IF EXISTS #CommunityOPMH
	SELECT TOP (1) WITH TIES m.MVIPersonSID
		,d.ChecklistID
		,FlagType='Community Care Treatment'
		,FlagInfo=CONCAT('Outpatient - Mental Health (',ICD10Code,')')
		,FlagInfo2='Outpatient - Mental Health'
		,FlagDate=cast(c.Service_End_Date as date)
	INTO #CommunityOPMH
	FROM #CommunityOPMH_Prep c
	INNER JOIN Common.MasterPatient m
		ON c.Patient_ICN=m.PatientICN
	INNER JOIN LookUp.DivisionFacility d 
		ON c.Sta6a=d.Sta6a
	ORDER BY ROW_NUMBER() OVER (PARTITION BY m.MVIPersonSID ORDER BY Service_End_Date DESC);

	--Outpatient: Chronic Pain
	DROP TABLE IF EXISTS #ChronicPainICD10
	SELECT DISTINCT v.ICD10Code, v.ICD10Description
	INTO #ChronicPainICD10
	FROM [LookUp].[ICD10_Display] dis
	INNER JOIN LookUp.ICD10_VerticalSID v WITH (NOLOCK)
		ON v.DxCategory=dis.DxCategory
	INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK)
		ON c.ColumnName=dis.DxCategory
	WHERE c.TableName = 'ICD10' AND c.PrintName='Chronic Pain'

	DROP TABLE IF EXISTS #CommunityOPChronicPain_Prep
	SELECT DISTINCT a.Patient_ICN
		,a.Primary_ICD
		,i.ICD10Code
		,Sta6a=a.Station_Number
		,Service_End_Date=cast(a.Service_End_Date as date)
	INTO #CommunityOPChronicPain_Prep
	FROM PDW.CDWWork_IVC_CDS_CDS_Claim_Header a
	INNER JOIN #ChronicPainICD10 i
		ON CONCAT(LEFT(a.Primary_ICD,3),'.',SUBSTRING(a.Primary_ICD,4,5))=i.ICD10Code
	WHERE Patient_ICN IS NOT NULL
	AND Service_End_Date > DATEADD(YEAR, -5, CAST(GETDATE() AS DATE));

	DROP TABLE IF EXISTS #CommunityOPChronicPain
	SELECT TOP (1) WITH TIES m.MVIPersonSID
		,d.ChecklistID
		,FlagType='Community Care Treatment'
		,FlagInfo=CONCAT('Outpatient - Chronic Pain (',ICD10Code,')')
		,FlagInfo2='Outpatient - Chronic Pain'
		,FlagDate=cast(c.Service_End_Date as date)
	INTO #CommunityOPChronicPain
	FROM #CommunityOPChronicPain_Prep c
	INNER JOIN Common.MasterPatient m
		ON c.Patient_ICN=m.PatientICN
	INNER JOIN LookUp.DivisionFacility d 
		ON c.Sta6a=d.Sta6a
	ORDER BY ROW_NUMBER() OVER (PARTITION BY m.MVIPersonSID ORDER BY Service_End_Date DESC);

	--Community Care combined
	DROP TABLE IF EXISTS #CommunityCare
	SELECT MVIPersonSID, ChecklistID, FlagType, FlagInfo, FlagInfo2, FlagDate
	INTO #CommunityCare
	FROM #CommunityCareOD
	UNION
	SELECT MVIPersonSID, ChecklistID, FlagType, FlagInfo, FlagInfo2, FlagDate
	FROM #CommunityCareED
	UNION
	SELECT MVIPersonSID, ChecklistID, FlagType, FlagInfo, FlagInfo2, FlagDate
	FROM #Compact
	UNION
	SELECT MVIPersonSID, ChecklistID, FlagType, FlagInfo, FlagInfo2, FlagDate
	FROM #CommunityOPMH
	UNION
	SELECT MVIPersonSID, ChecklistID, FlagType, FlagInfo, FlagInfo2, FlagDate
	FROM #CommunityOPChronicPain;

	--All together
	DROP TABLE IF EXISTS #RiskFlags
	SELECT MVIPersonSID
		,ChecklistID=OwnerChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,FlagDate
	INTO #RiskFlags
	FROM #HRF
	UNION
	SELECT MVIPersonSID
		,OwnerChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,ActionDateTime
	FROM #Behavioral
	UNION
	SELECT MVIPersonSID
		,OwnerChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,ActionDateTime
	FROM #Missing
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,FlagDate
	FROM #REACH
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,FlagDate
	FROM #SDV
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2=NULL
		,FlagDate
	FROM #OD
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,FlagType
		,FlagInfo
		,FlagInfo2
		,FlagDate
	FROM #CommunityCare;


-------------------------------------------------------------
-------------------------------------------------------------
/*
TABLE 4: [PBIReports].[Screening]

Get info needed for PBI visuals re: screening in CaseFactors.pbix and Clinical_Insights/pbix
Adapted from [App].[PowerBIReports_Screening] and includes:
	- Positive Drug Screen
	- MHA Screenings (AUDIT-C, C-SSRS, PHQ9, etc)
	- Social Driver Screenings (Homeless, Food Insecurity, etc)
	- Overdue Screens
*/
-------------------------------------------------------------
-------------------------------------------------------------
	--Positive Drug Screens
	DROP TABLE IF EXISTS #PositiveDS
	SELECT c.MVIPersonSID
		,Category='Lab Group'--'Positive Drug Screen'
		,ScreenType='Positive Drug Screen'
		,LabDate=MAX(u.LabDate)
		,u.LabGroup
		,u.ChecklistID
	INTO #PositiveDS
	FROM #FinalCohort c
	INNER JOIN Present.UDSLabResults u WITH (NOLOCK)
		ON u.MVIPersonSID=c.MVIPersonSID
	WHERE LabScore=1
	AND LabDate > DATEADD(year,-5,cast(getdate() as date))
	GROUP BY c.MVIPersonSID, c.PatientICN, u.LabGroup, u.ChecklistID;

	--MHA
	DROP TABLE IF EXISTS #MHA
	SELECT c.MVIPersonSID
		,mh.ChecklistID
		,mh.DisplayScore 
		,CAST(mh.SurveyGivenDatetime AS DATE) AS SurveyDate
		,Survey=
			CASE WHEN mh.Display_AUDC>-1 THEN 'AUDIT-C'
			WHEN mh.Display_CSSRS>-1 THEN 'C-SSRS'
			WHEN mh.display_I9>-1 THEN 'I9'
			WHEN mh.display_PHQ2>-1 THEN 'PHQ-2'
			WHEN mh.display_PHQ9>-1 THEN 'PHQ-9'
			WHEN mh.display_COWS>-1 THEN 'COWS'
			WHEN mh.display_CIWA>-1 THEN 'CIWA'
			WHEN mh.display_PTSD>-1 THEN 'PC-PTSD-5'
			END
		,RawScore
	INTO #MHA
	FROM #FinalCohort AS c
	INNER JOIN [OMHSP_Standard].[MentalHealthAssistant_v02] AS mh WITH (NOLOCK) 
		ON c.MVIPersonSID = mh.MVIPersonSID
	WHERE SurveyGivenDatetime > DATEADD(year,-5,cast(getdate() as date));
	
	DROP TABLE IF EXISTS #MHA_MostRecent
	SELECT TOP (1) WITH TIES MVIPersonSID
		,ChecklistID
		,ScreenType='Mental Health Screenings'
		,DisplayScore
		,SurveyDate
		,Survey
		,RawScore
	INTO #MHA_MostRecent
	FROM #MHA
	WHERE RawScore >= 0
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Survey ORDER BY SurveyDate DESC)
	
	--Social Drivers
	DROP TABLE IF EXISTS #SocialDrivers_Prep
	SELECT c.MVIPersonSID
		,h.ChecklistID
		,Category ='Homeless'
		,ScreenType='Social Drivers of Health'
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN s.Score=0 THEN 'Negative'
			WHEN s.Score=1 THEN 'Positive'
			ELSE 'Not Performed' END AS Score
	INTO #SocialDrivers_Prep
	FROM #FinalCohort AS c
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) 
		ON c.MVIPersonSID = h.MVIPersonSID 
		AND h.Category IN ('Homeless Screen')--limited to most recent screen
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) ON 
		h.MVIPersonSID=s.MVIPersonSID 
		AND h.HealthFactorDateTime=s.ScreenDateTime 
		AND h.Category=s.Category
	WHERE HealthFactorDateTime > DATEADD(year,-5,cast(getdate() as date))
	UNION
	SELECT c.MVIPersonSID
		,h.ChecklistID
		,Category =  'Food Insecurity'
		,ScreenType='Social Drivers of Health'
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN s.Score=0 THEN 'Negative'
			WHEN s.Score=1 THEN 'Positive'
			ELSE 'Not Performed' END AS Score
	FROM #FinalCohort AS c
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) 
		ON c.MVIPersonSID = h.MVIPersonSID 
		AND h.Category ='Food Insecurity Screen'--limited to most recent screen
	LEFT JOIN [SDH].[ScreenResults] AS s WITH (NOLOCK) 
		ON h.MVIPersonSID=s.MVIPersonSID 
		AND h.HealthFactorDateTime=s.ScreenDateTime 
		AND h.Category=s.Category
	WHERE HealthFactorDateTime > DATEADD(year,-5,cast(getdate() as date))
	UNION
	SELECT c.MVIPersonSID
		,h.ChecklistID
		,Category = 'Relationship Health and Safety'
		,ScreenType='Social Drivers of Health'
		,CAST(h.HealthFactorDateTime AS DATE) AS SurveyDate
		,CASE WHEN i.ScreeningScore>=7 THEN 'Positive'
			WHEN i.ViolenceIncreased=1 OR i.Choked=1 OR i.BelievesMayBeKilled=1 THEN 'Positive'
			WHEN i.ScreeningScore<7 THEN 'Negative'
			ELSE 'Not Performed' END AS Score
	FROM #FinalCohort AS c
	LEFT JOIN [SDH].[HealthFactors] AS h WITH (NOLOCK) 
		ON c.MVIPersonSID = h.MVIPersonSID  
		AND h.Category='IPV' --limited to most recent screen
	LEFT JOIN [SDH].[IPV_Screen] AS i WITH (NOLOCK) 
		ON h.MVIPersonSID = i.MVIPersonSID 
		AND h.HealthFactorDateTime = i.ScreenDateTime
	WHERE HealthFactorDateTime > DATEADD(year,-5,cast(getdate() as date));

	DROP TABLE IF EXISTS #SocialDrivers
	SELECT TOP (1) WITH TIES *
	INTO #SocialDrivers
	FROM #SocialDrivers_Prep
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Category ORDER BY SurveyDate DESC)

	--Overdue Screens
	DROP TABLE IF EXISTS #OverdueScreens
	SELECT *
	INTO #OverdueScreens
	FROM Present.OverdueScreens WITH (NOLOCK)
	WHERE OverdueFlag=1 OR Next30DaysOverdueFlag=1

	--Final data pull
	DROP TABLE IF EXISTS #Screening 
	SELECT MVIPersonSID
		,ChecklistID
		,Category  = CONCAT(LabGroup, ' (Positive)')
		,Score = 'Positive'
		,ScreenType
		,EvidenceDate=LabDate
	INTO #Screening
	FROM #PositiveDS
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,Category  = CONCAT(Survey, ' | ',CONCAT(DisplayScore, ' (Raw Score: ', RawScore,')'))
		,DisplayScore
		,ScreenType
		,SurveyDate
	FROM #MHA_MostRecent
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,Category = CONCAT(Category, ' | ',Score)
		,Score
		,ScreenType
		,SurveyDate
	FROM #SocialDrivers
	UNION
	SELECT MVIPersonSID
		,ChecklistID
		,Screen
		,Score = NULL
		,ScreenType='Potential Screening Need'
		,MostRecentScreenDate
	FROM #OverdueScreens


-------------------------------------------------------------
-------------------------------------------------------------
/*
Populate tables to be used in Views for Power BI reports:
	-CaseFactors.pbix
	-Clinical_Insights.pbix
*/
-------------------------------------------------------------
-------------------------------------------------------------


EXEC [Maintenance].[PublishTable] 'Common.PBIReportsCohort', '#FinalCohort';

EXEC [Maintenance].[PublishTable] 'PBIReports.ReportType', '#PowerBISlicers';

EXEC [Maintenance].[PublishTable] 'PBIReports.RiskFlags','#RiskFlags';

EXEC [Maintenance].[PublishTable] 'PBIReports.Screening','#Screening';


END