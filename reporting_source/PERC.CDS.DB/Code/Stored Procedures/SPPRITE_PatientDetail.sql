
/* =============================================
-- Author:		<Marcos Lau>
-- Create date: <7/13/18>
-- Description:	Gets details for SPPRITE cohort to display on report.
-- SPPRITE = Suicide Prevention Population Risk Identification and Tracking for Exigencies
-- REQUIREMENTS
	REACH VET: Local program (current or past), national high or very high risk tiers.
	PRF_HRS: Active Patient Record Flag - High Risk for Suicide currently or in past 6 months
	Inpatient discharge in past 30 days or current IP stay determined to be high risk for suicide (PDE definition)
	STORM: Currently identified as Very High, High, or Elevated (OUD) OR very high or high in past 90 days

--MODIFICATIONS
	--				Removed consult section
	--				Commented out survey code (new MHA table stuff to be added)
	--				Moved Next Appt code to separate procedure
	--				Removed Homicidal Ideations -- b.ICD10Code in ('R45.850')  
	--				Removed code for REACH, STORM, PRF_HRS and pointed to Present PatientCohort
	-- 20190215	RAS	Changed join with Present StationAssignments to LEFT instead of INNER because INNER using Homestation drops patients.
	-- 20190217	JB	Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
	-- 20190221	RAS	Removed only positive I9 and safety plan in past 12 months from keep criteria. 
					Added naloxone criteria for only patients with STORM risk above 2. Changed PDE row number to use Census2 DESC to get most reent.
	-- 20190222	CNB	Added criteria to find most recent CSREs to include Updated CSREs.
	-- 20190226 RAS Added ChecklistID for CSSRS and I9
	-- 20190401	CNB	UPDATED: Some CSREs are timestamped before an I9 and/or C-SSRS that occurred in the same day. E.g. CSRE timestamped at 10:30 am on 1/1/19 but CSSRS timestamped at 1 pm on 1/1/19. 
					Modified section 'Did positive screens get the CSRE follow-up they required?' to match DAY date of CSRE on >= DAY date of I9/CSSRS to account for these cases.
	-- 20190417 RAS Added SBOR and SPAN event data. 
	-- 20190423	CNB	Added more details to SBOR and SPAN event data. 
	-- 20190426	CNB	Added SBOR EventDateFormatted; this is more useful to the final report than the raw event date, which contains text and non-standard formatting.
	-- 20190501 RAS	Added where clause to #SBOR_SPAN to get only most recent suicide/overdose event, regardless of "EventType"
	-- 20190514	CNB	Added Most Recent Service Separation date (calculated like CRISTAL calculation from App.MBC_Patient_LSV)
	-- 20190522 RAS Added code from Present_PatientCohort so I can depracate that code, which doesn't work in a wider context as I was thinking originally.
	-- 20190528	CNB	Added a Drop if Exists statements where didn't exist; added to #SBOR temp table creation: (SuicidalSDV=1 or PreparatoryBehavior=1) with the goal to pull only the KNOWN Suicidal behaviors (excludes Undetermined Events)
    -- 20190528 CNB	Initiated Adding most recent suicide ATTEMPT and most recent PREPARATORY Behavior which are the 2 distinct suicidal behaviors needed for SPPRITE (Deceased patients/suicides fall out of the report; undetermined and non-suicial events are not the focus of the report).
	-- 20190529 CNB	Added clarifiying code to Suicide Behavior sections; separated and added details about Suicide ATTEMPTS and Suicide PREPARATORY so that the most recent of EACH can be displayed in separate columns. E.g. if a person had a suicidal preparatory behavior and a suicidal attempt, both will display in separate columns in SPPRITE.
	-- 20190530	CNB	Added DateofDeath from Present.RealPatients; this will allow us to identify those who have died, and suppress them from SPPRITE Dashboard display
	-- 20190607	CNB	Corrected the timeframe for suicide attempt and preparatory behaviors ELIGIBILITY TO SPPRITE to one year only; IGNORE - SEE 6/11/19 UPDATE: corrected the logic for finding Suicide Events in past year to look for suicide attempts and suicide behaviors only (not undetermined)
	-- 20190610	CNB	Updated STORM to include only in (3,4,5); also changed REACH table reference to Reach.History. We expect this change to cut the sample in half.
	-- 20190611 CNB	Changed RiskFactors 'F' reference from REACH_LocalPast=0 to REACH_LocalPast=1; changed the suicide attempt and suicide prep code to include the most recent of these from ANY time in the past for those in SPPRITE; however, the eligibility criteria for getting into SPPRITE remains having a suicide behavior in the past year
	-- 20190620	CNB	Updated I9 & C-SSRS portion to correctly identify -99 responses and include as appropriate; also added information about the last overdose (of any type - suicidal, non-suicidal).
	-- 20190625	CNB	Corrected #SBOR table; removed REACH Top 5% to streamline table
	-- 20191003 CNB	Removed references to I9 info from PHQ9s (because those do not count toward the official Risk ID Strategy)
    -- 20191022 CMH Changed code for pulling in contact information - previously address was only being pulled in for those with upcoming appointments so changed to all and no longer need SPPRITE.PatientApptSID. Phone number was being pulled in the App.SPPRITE_PatientReport_LSV SP and added to this code instead to try and speed up report
	-- 20191112 CMH Update Present.SuicideOverdoseEvent tables to new OMHSP_Standard.SuicideOverdoseEvent tables, added in 'where a.EventType NOT IN ('Ideation', 'Non-Suicidal SDV')'
	-- 20191114 CMH Updated Present.MentalHealthAssistant tables to OMHSP_Standard.MentalHealthAssistant
	-- 20191126 CMH Added Positive I9 screen in past week to cohort criteria/risk factor list. Also reorganized code to be clearer to read, but did not change any logic
	-- 20200106 RAS Added code to exclude SP_RefusedSafetyPlanning_HF=1 from #sp and #safetyplan
	-- 20200110 CMH Added most recent Community Status Note date
	-- 20200121 CMH Added in SP_RefusedSafetyPlanning_HF indicator (renamed to SafetyPlan_decline) and include dates of safety plan decline for patients with no other safety plan listed
	-- 20200131	LM	Updated REACH tables to new V02 versions of tables
	-- 20200318 CMH Adding COVID indictor and most recent MH use in prior 30, 60, 90 days to be included as risk factors 
	-- 20200319	RAS	Added SPED cohort
	-- 20200320 RAS Added appointment code to get most recent and next PC and MH
	-- 20200421 CMH Added Somatic Tx cohort, information on frailty indicator (HRHN - High Risk High Needs from Geriatric and Extended Care (GEC) VA office
	-- 20200423 CMH Updated SRM outreach section to also pull in first successful outreach date in addition to most recent, and updated COVID lab tests to pull in first detected and most recent (of any result)
	-- 20200512 CMH Changed HRF flag for inclusion criteria from 'Active in past 6 months' to past 12 months
	-- 20200512 RAS Changed last ED visit information to come from Present.AppointmentsPast instead of Present.Appointments
	-- 20200521 RAS Branched code and divided into 2.  This is section 2 from the previous version.
	-- 20200710 CMH Removed v02 from SP and table names
	-- 20200717 CLB Added no pills on hand/recent discontinuations indicator
	-- 20200722 CMH Added HRF_COVID follow-up and outreach indicators for display in SRM column
	-- 20200807 CMH Added AUDIT-C information to display 
	-- 20200818 CMH Added Homeless stop codes to MH engagement definition
	-- 20200901	CNB	Added CAN Score
	-- 20201027 CLB Removed I9; updated VCL caring contacts
	-- 20201028 LM  Added SourceEHR
	-- 20201125 CMH Added OFR Care (aka SP NOW) cohort to SPPRITE 
	-- 20210121	LM	Overlay for appointments; added NOLOCKs
	-- 20210316 CMH Added SMI Re-Engage cohort - will be added to risk factors parameter and risk summary
	-- 20210413 CMH Added additional ORF columns for report
	-- 20210514 JEB Change Synonym DWS_ reference to proper PDW_ reference
	-- 20210527 LM  Updated reference to MentalHealthAssistant_v02
	-- 20210622 CMH Added behavioral risk flag in last 6 months
	-- 20210715 JEB Enclave Refactoring - Counts confirmed
	-- 20210915 AW	Changed DerivedAppointmentLocalDateTime and TZDerivedAppointmentLocalDateTime to TZBeginDateTime to reflect changes made in the FactAppointments stored procedure
	-- 20210921 CMH Added DMC debt data
	-- 20210923 JEB Enclave Refactoring - Removed use of Partition ID
	-- 20220119 CMH Added third dose for COVID vax
	-- 20220121	LM	Changed behavioral flag to point to PRF.BehavioralMissingPatient; changed PDW_DWS references to Common references
	-- 20220323	LM	Added VCL caring letters extension
	-- 20220509	LM	Replaced MHRecent_Stop with MHOC_MentalHealth_Stop and MHOC_MentalHealth_Stop; pulled next/most recent visit from Present.Appointments
	-- 20220623 CEW Changed VCL caring letters to include most recent letter date for historical recipients (> 13 months)
	-- 20220708 JEB Updated Synonym references to point to Synonyms from Core
	-- 20220711 JEB Updated more Synonym references to point to Synonyms from Core (missed some)
	-- 20230322 CMH Added COMPACT Act info
	-- 20230322 CMH Limiting HRF COVID outreach dates to those occurring before 4/1/23
	-- 20230713 CMH Adding HRF Caring letters info, changing VCL to point to Present.CaringLetters
	-- 20240402	CMH Taking all COVID-related data out of SPPRITE
	-- 20240625 CNB Updating OFR Care most recent outreach logic to address cases previously unaddressed and erroneously being sorted 'else' into Chart Review
	-- 20241022 CMH Adding MST positive screen in past two years info (screen date and checklistID). This is not part of inclusion criteria
	-- 20241025 CNB Replaced VSSC SPED cohort with the one from RM MIRECC [PDW].[OMHSP_MIRECC_DOEx_SPEDCohort]; this file includes only SPED patients and has an indicator when a patient initially identified for SPED is determined ineligible per SRM F/U note
	-- 20241129 CMH Added safety plan review and facility
	-- 20250210 CMH Removed STORM 90 day code and column - no longer used in report
	-- 20250623 CMH Replacing SBOR attempt and prep event date with entry date when null
-- ============================================= */

CREATE PROCEDURE [Code].[SPPRITE_PatientDetail]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.SPPRITE_PatientDetail','Execution of Code.SPPRITE_PatientDetail SP'


-- ==========================================================
-- Get SPPRITE cohort and Risk Factors on 1 line
-- ==========================================================
DROP TABLE IF EXISTS #Cohort
SELECT sr.MVIPersonSID
	  ,mp.PatientICN
	  ,STRING_AGG(RiskFactorID,',') as RiskFactors
INTO #Cohort
FROM (
	SELECT DISTINCT MVIPersonSID
		,RiskFactorID
	FROM [SPPRITE].[RiskIDandDisplay]
	) sr
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] mp WITH(NOLOCK) on mp.MVIPersonSID=sr.MVIPersonSID
GROUP BY sr.MVIPersonSID,mp.PatientICN

CREATE CLUSTERED INDEX CIX_CohortMVIPersonSID ON #Cohort (MVIPersonSID)

-- ===================================================================================================================================
-- Suicide Behavior Event Data (SBOR/SPAN): past year cohort + details for last available behaviors (even if more than 1 year ago)  --
--										Focus on Suicide ATTEMPTS and Suicide PREPARATORY											--
-- ===================================================================================================================================	

---------------------------------------------------------------------------------------------------------------------------------------------------------
--Obtain all PREPARATORY SUICIDE events (excluding undetermined preparatory) at the patient level from the anytime in the past, order them from newest to oldest
---------------------------------------------------------------------------------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #SBOR_SPAN_PrepA;
		SELECT a.MVIPersonSID
			  ,a.SDVClassification as SBOR_Detail_Prep
			  ,a.EventDate as SBOR_Date_Prep
			  ,a.EventDateFormatted as SBOR_DateFormatted_Prep
			  ,cast(a.EntryDateTime as date) as SBOR_EntryDate_Prep
			  ,c.Facility as SBOR_Facility_Prep
			  ,a.ChecklistID as SBOR_Checklistid_Prep
			  ,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EventDateFormatted,a.EntryDateTime) DESC, a.EntryDateTime DESC) AS SBOR_EventOrderDesc_Prep
		INTO #SBOR_SPAN_PrepA
		FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] a WITH(NOLOCK)
		INNER JOIN #Cohort co on co.MVIPersonSID=a.MVIPersonSID
		INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=a.ChecklistID
		WHERE a.PreparatoryBehavior=1 and a.SDVClassification not like '%Undetermined%' --remove the 'undetermined' preparatory behavior; should not be included
			AND (a.EventType NOT IN ('Ideation','Non-Suicidal SDV') or a.EventType is null)
			AND a.Fatal = 0
			
		--Obtain only the MOST RECENT SUICIDE PREPARATORY EVENT reported
		DROP TABLE IF EXISTS #SBOR_SPAN_Prep;
		SELECT MVIPersonSID
			  ,SBOR_Detail_Prep
			  ,SBOR_Date_Prep
			  ,ISNULL(SBOR_DateFormatted_Prep,SBOR_EntryDate_Prep) as SBOR_DateFormatted_Prep
			  ,SBOR_EntryDate_Prep
			  ,case when SBOR_DateFormatted_Prep is NULL then 1 else 0 end as SBOR_DateFormattedNULL_Prep
			  ,SBOR_Facility_Prep
			  ,SBOR_Checklistid_Prep
		INTO #SBOR_SPAN_Prep
		FROM #SBOR_SPAN_PrepA
		WHERE SBOR_EventOrderDesc_Prep=1

		DROP TABLE #SBOR_SPAN_PrepA

----------------------------------------------------------------------------------------------------------------
--Obtain all SUICIDE ATTEMPT events at the patient level from the anytime in the past, order them from newest to oldest
----------------------------------------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #SBOR_SPAN_AttA;
		SELECT a.MVIPersonSID
			  ,a.SDVClassification as SBOR_Detail_Att
			  ,a.EventDate as SBOR_Date_Att
			  ,a.EventDateFormatted as SBOR_DateFormatted_Att
			  ,cast(a.EntryDateTime as date) as SBOR_EntryDate_Att
			  ,c.Facility as SBOR_Facility_Att
			  ,a.ChecklistID as SBOR_Checklistid_Att
			  ,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EventDateFormatted,a.EntryDateTime) DESC, a.EntryDateTime DESC) AS SBOR_EventOrderDesc_Att
		INTO #SBOR_SPAN_AttA
		FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] a WITH(NOLOCK)
		INNER JOIN #Cohort co on co.MVIPersonSID=a.MVIPersonSID
		INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=a.ChecklistID
		WHERE a.SuicidalSDV=1 AND a.SDVClassification like '%Attempt%' 
			AND (a.EventType NOT IN ('Ideation','Non-Suicidal SDV') or a.EventType is null)
			AND Fatal = 0
	
		--Obtain only the MOST RECENT SUICIDE ATTEMPT reported
		DROP TABLE IF EXISTS #SBOR_SPAN_Att;
		SELECT MVIPersonSID
			  ,SBOR_Detail_Att
			  ,SBOR_Date_Att
			  ,ISNULL(SBOR_DateFormatted_Att,SBOR_EntryDate_Att) as SBOR_DateFormatted_Att
			  ,SBOR_EntryDate_Att
			  ,case when SBOR_DateFormatted_Att is NULL then 1 else 0 end as SBOR_DateFormattedNULL_Att
			  ,SBOR_Facility_Att
			  ,SBOR_Checklistid_Att
		INTO #SBOR_SPAN_Att
		FROM #SBOR_SPAN_AttA
		WHERE SBOR_EventOrderDesc_Att=1

		DROP TABLE #SBOR_SPAN_AttA

----------------------------------------------------------------------------------------------------------------
--Obtain all OVERDOSE events of ANY TYPE (Suicidal, non-suicidal) at the patient level from the anytime in the past, order them from newest to oldest
----------------------------------------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #SBOR_SPAN_AnyODA;
		SELECT a.MVIPersonSID
			  ,a.SDVClassification as SBOR_Detail_AnyOD
			  ,a.EventDate as SBOR_Date_AnyOD
			  ,a.EventDateFormatted as SBOR_DateFormatted_AnyOD
			  ,cast(a.EntryDateTime as date) as SBOR_EntryDate_AnyOD
			  ,c.Facility as SBOR_Facility_AnyOD
			  ,a.ChecklistID as SBOR_Checklistid_AnyOD
			  ,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY ISNULL(a.EventDateFormatted,a.EntryDateTime) DESC, a.EntryDateTime DESC) AS SBOR_EventOrderDesc_AnyOD
		INTO #SBOR_SPAN_AnyODA
		FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] a WITH(NOLOCK)
		INNER JOIN #Cohort co on co.MVIPersonSID=a.MVIPersonSID
		INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=a.ChecklistID
		WHERE Overdose = 1
			and (a.EventType NOT IN ('Ideation','Non-Suicidal SDV') or a.EventType is null)
			and Fatal = 0
		
		--Obtain only the MOST RECENT SUICIDE AnyODEMPT reported
		DROP TABLE IF EXISTS #SBOR_SPAN_AnyOD;
		SELECT MVIPersonSID
			  ,SBOR_Detail_AnyOD
			  ,SBOR_Date_AnyOD
			  ,ISNULL(SBOR_DateFormatted_AnyOD,SBOR_EntryDate_AnyOD) as SBOR_DateFormatted_AnyOD
			  ,SBOR_EntryDate_AnyOD
			  ,case when SBOR_DateFormatted_AnyOD is NULL then 1 else 0 end as SBOR_DateFormattedNULL_AnyOD
			  ,SBOR_Facility_AnyOD
			  ,SBOR_Checklistid_AnyOD
		INTO #SBOR_SPAN_AnyOD
		FROM #SBOR_SPAN_AnyODA
		WHERE SBOR_EventOrderDesc_AnyOD=1

		DROP TABLE #SBOR_SPAN_AnyODA


-- =================================================================================================
-- REACH VET Facility
-- =================================================================================================
   DROP TABLE IF EXISTS #RVFacility;
   SELECT MVIPersonSID	--RAS: removed DISTINCT 
	     ,RV_ChecklistID=r.ChecklistID
	     ,RV_Facility=c.Facility
   INTO #RVFacility 
   FROM [SPPRITE].[RiskIDandDisplay] r WITH(NOLOCK) 
   INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=r.ChecklistID
   WHERE RiskFactorID IN (
		SELECT ID FROM [Config].[SPPRITE_RiskFactors]
		WHERE Label LIKE 'REACH VET%'
		)

-- =================================================================================================
-- STORM
-- =================================================================================================

------------------------------------------
-- STORM Risk Mitigation
------------------------------------------
	DROP TABLE IF EXISTS #ORM_RMS;
	SELECT co.MVIPersonSID
		  ,count(distinct MitigationID) as STORM_RMS_Denominator
		  ,sum(Checked) as STORM_RMS_TimelyPerformed
		  --,STRING_AGG(CASE WHEN Checked=1 THEN PrintName ELSE NULL END, ',') STORM_RMS
		  --,STRING_AGG(CASE WHEN Checked=0 THEN PrintName ELSE NULL END, ',') STORM_RMSNeeded
	INTO #ORM_RMS
	FROM [ORM].[RiskMitigation] rm WITH(NOLOCK)
	INNER JOIN #Cohort co on co.MVIPersonSID=rm.MVIPersonSID
	WHERE MetricInclusion=1
	GROUP BY co.MVIPersonSID


------------------------------------------
-- STORM Risk Category
------------------------------------------
	DROP TABLE IF EXISTS #STORM
	SELECT co.MVIPersonSID 
		  ,STORM=1
		  ,max(orm.RiskCategory) as STORM_RiskCategory
		  ,max(orm.RiskCategoryLabel) as STORM_RiskCategoryLabel
	INTO #STORM
	FROM [ORM].[PatientReport] orm WITH(NOLOCK) 
	INNER JOIN #Cohort co on co.MVIPersonSID=orm.MVIPersonSID
	GROUP BY co.MVIPersonSID


-------------------------------------------------------
-- STORM Opioid Facility & 90-Day Opioid Facility
-------------------------------------------------------
-- STORM Lead facility: where there is an active opioid prescription
	DROP TABLE IF EXISTS #ORM_Facility;
	SELECT MVIPersonSID
		  ,STRING_AGG(r.ChecklistID, ',') STORM_ChecklistIDs
		  ,STRING_AGG(c.Facility, ',') STORM_Facilities
	INTO #ORM_Facility
    FROM (
		SELECT DISTINCT MVIPersonSID,ChecklistID
		FROM [SPPRITE].[RiskIDandDisplay] WITH(NOLOCK) 
		WHERE ChecklistID IS NOT NULL 
			AND RiskFactorID IN (
				SELECT ID FROM [Config].[SPPRITE_RiskFactors]
				WHERE Label LIKE 'STORM%'
				)		
		) r 
    INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=r.ChecklistID
	GROUP BY MVIPersonSID

-- =================================================================================================
-- HRF (Clinical High Risk Flag) 
-- =================================================================================================
   DROP TABLE IF EXISTS #hrf
   SELECT MVIPersonSID 
		 ,OwnerChecklistID as PatRecFlag_ChecklistID
		 ,Facility as PatRecFlag_Facility
		 ,LastActionDateTime as PatRecFlag_Date
		 ,LastActionDescription as PatRecFlag_Status
   INTO #hrf 
   FROM [PRF_HRS].[PatientReport_v02] a WITH(NOLOCK) --this table contains most recent HRF status for patients in past year
   INNER JOIN [LookUp].[ChecklistID] b WITH(NOLOCK) on a.OwnerChecklistID=b.ChecklistID


-- =================================================================================================
-- HRF Caring Letters 
-- =================================================================================================
	DROP TABLE IF EXISTS #HRF_letters
	SELECT DISTINCT a.MVIPersonSID
			,b.EligibleDate AS HRFLetters_EligDate
			,CASE WHEN b.DoNotSend_Reason IS NOT NULL THEN 'No, ' + b.DoNotSend_Reason
				WHEN b.CurrentEnrolled=0 AND b.DoNotSend_Reason IS NULL THEN 'No, most recent letter ' + CONVERT(VARCHAR(10),b.LastScheduledLetterDate)
				ELSE 'Yes'
				END AS HRFLetters_Status
	INTO #HRF_letters
	FROM #cohort a
	LEFT JOIN Present.CaringLetters b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE b.Program='HRF Caring Letters' and (b.CurrentEnrolled=1 or b.PastYearEnrolled=1) and (b.DoNotSend_Reason <> 'Reported deceased' or b.DoNotSend_Reason is null)
	--don't worry about pulling in ChecklistID because it's identical to PatRecFlag_ChecklistID pulled above

-- =================================================================================================
--  VCL Caring Contacts
-- =================================================================================================
	DROP TABLE IF EXISTS #VCL
	SELECT DISTINCT a.MVIPersonSID
			,b.EligibleDate AS VCL_Call_Date
			,b.ChecklistID AS VCL_ChecklistID
			,CASE WHEN b.DoNotSend_Reason IS NOT NULL THEN 'No, ' + b.DoNotSend_Reason
				WHEN b.CurrentEnrolled=0 AND b.DoNotSend_Reason IS NULL THEN 'No, most recent letter ' + CONVERT(VARCHAR(10),b.LastScheduledLetterDate)
				ELSE 'Yes'
				END AS VCL_Status
	INTO #VCL
	FROM #cohort a
	LEFT JOIN Present.CaringLetters b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE b.Program='VCL Caring Letters' and (b.CurrentEnrolled=1 or b.PastYearEnrolled=1) and (b.DoNotSend_Reason <> 'Reported deceased' or b.DoNotSend_Reason is null)


	--grab most recent call date if more than one
	DROP TABLE IF EXISTS #VCL2
	SELECT MVIPersonSID
			,VCL_Call_Date
			,VCL_ChecklistID
			,VCL_Status
	INTO #VCL2
	FROM (
		  SELECT *
			,row_number() over (PARTITION BY MVIPersonSID ORDER BY VCL_Call_Date desc) AS RN
		  FROM #VCL
		 ) a
	WHERE RN=1


-- =================================================================================================
-- Suicide Risk Screening and Evaluation (C-SSRS, CSRE, AUDIT-C for alcohol use)
-- =================================================================================================

------------------------------------------
-- C-SSRS
------------------------------------------
	DROP TABLE IF EXISTS #screen2;
	SELECT m.MVIPersonSID
		  ,c.Facility
		  ,m.ChecklistID
		  ,m.SurveyGivenDateTime
		  ,m.SurveyName
		  ,m.display_CSSRS
		  ,Row_Number() OVER(PARTITION BY MVIPersonSID,display_CSSRS ORDER BY SurveyGivenDateTime DESC) as RecentCSSRS
	INTO #screen2
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] m WITH(NOLOCK) --need to get rid of duplicates
	INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=m.ChecklistID
	WHERE display_CSSRS<>-1 
		AND Surveyname<>'PHQ9'

	--Get most recent C-SSRS result
	DROP TABLE IF EXISTS #cssrs;
	SELECT MVIPersonSID,CSSRS_Facility,CSSRS_Date,display_CSSRS,CSSRS_ChecklistID
	INTO #cssrs
	FROM (
		SELECT MVIPersonSID
			  ,Facility as CSSRS_Facility
			  ,ChecklistID as CSSRS_ChecklistID
			  ,SurveyGivenDateTime as CSSRS_Date
			  ,display_CSSRS
			  ,Row_Number() OVER(Partition By MVIPersonSID ORDER BY SurveyGivenDateTime DESC,display_CSSRS DESC) as RN
		FROM #screen2
		WHERE (display_CSSRS=1 AND RecentCSSRS=1)
			OR (display_CSSRS=0 AND RecentCSSRS=1)
			OR (display_CSSRS=-99 AND RecentCSSRS=1)
		) a
	WHERE RN=1

	--C-SSRS Risk ID 
	----Not necessarily the most recent
	DROP TABLE IF EXISTS #CSSRS_ID
	SELECT * 
	INTO #CSSRS_ID
	FROM (
		SELECT MVIPersonSID
			  ,Facility as CSSRS_Facility
			  ,ChecklistID as CSSRS_ChecklistID
			  ,SurveyGivenDateTime as CSSRS_Date
			  ,display_CSSRS
			  ,Row_Number() OVER(Partition By MVIPersonSID ORDER BY SurveyGivenDateTime DESC) as RN
		FROM #screen2
		WHERE display_CSSRS=1
		) a
	WHERE RN=1


------------------------------------------
-- CSRE
------------------------------------------
	--Grab all CSREs in past 6 months 
	DROP TABLE IF EXISTS #CSRE
	SELECT a.MVIPersonSID
			,CSRE_DateTime=ISNULL(a.EntryDateTime,a.VisitDateTime)
			,a.ChecklistID
			,b.Facility
			,a.AcuteRisk as CSRE_Acute
			,a.ChronicRisk as CSRE_Chronic
			,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ISNULL(EntryDateTime,VisitDateTime) DESC) AS RN
	INTO #CSRE
	FROM [OMHSP_Standard].[CSRE] a  WITH(NOLOCK)
	LEFT JOIN [Lookup].[ChecklistID] b WITH(NOLOCK) on a.ChecklistID=b.ChecklistID
	WHERE (EvaluationType='New CSRE' or EvaluationType='Updated CSRE') 
			--and (AcuteRisk in ('High','Intermediate') or ChronicRisk in ('High','Intermediate'))
			and ISNULL(EntryDateTime,VisitDateTime) > dateadd(month,-6,cast(getdate() as date))

	--Details of most recent CSRE
	DROP TABLE IF EXISTS #CSRERecentResult;
	SELECT MVIPersonSID
	  ,CSRE_DateTime
	  ,ChecklistID
	  ,Facility
	  ,CSRE_Acute
	  ,CSRE_Chronic
	INTO #CSRERecentResult
	FROM #CSRE
	WHERE RN=1


	--CSRE Risk ID - for high or intermediate CSREs
	DROP TABLE IF EXISTS #CSRE_RiskID;
	SELECT TOP 1 WITH TIES
		MVIPersonSID,CSRE_DateTime,ChecklistID,Facility,CSRE_Acute,CSRE_Chronic	
	INTO #CSRE_RiskID
	FROM #CSRE
	WHERE CSRE_Acute LIKE '%High%'
		OR CSRE_Acute LIKE '%Interm%'
		OR CSRE_Chronic LIKE '%High%'
		OR CSRE_Chronic LIKE '%Interm%'
	ORDER BY row_number() OVER (Partition By MVIPersonSID order by CSRE_DateTime DESC);

	--Did positive screens get the CSRE follow-up they required?
	DROP TABLE IF EXISTS #CSRE_SurveyDates;
	SELECT MVIPersonSID
		  ,SurveyGivenDateTime
		  ,SurveyWithCSRE
		  ,SurveyCSRE_DateTime
	INTO #CSRE_SurveyDates
	FROM (
		SELECT s.MVIPersonSID
			  ,s.CSSRS_Date as SurveyGivenDateTime
			  ,'CSSRS' as SurveyWithCSRE
			  ,c.CSRE_DateTime as SurveyCSRE_DateTime
			  ,Row_Number() OVER(Partition By s.MVIPersonSID ORDER BY DateDiff(d,s.CSSRS_Date,c.CSRE_DateTime)) as DateMatch
		FROM #cssrs s
		INNER JOIN #CSRE c on 
			c.MVIPersonSID=s.MVIPersonSID
			AND cast(c.CSRE_DateTime as date)>=cast(s.CSSRS_Date as date)
		WHERE display_CSSRS=1
		) a
	WHERE DateMatch=1 --CSRE with date closest to the screen that required follow-up


------------------------------------------
--  AUDIT-C for alcohol use
------------------------------------------
	--Find most recent AUDIT-C result
	DROP TABLE IF EXISTS #AUDIT_C;
	SELECT TOP (1) WITH TIES
		MVIPersonSID
		,mh.ChecklistID as AUDITC_ChecklistID
		,c.Facility as AUDITC_Facility
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
	ORDER BY ROW_NUMBER() OVER (PARTITION BY mh.MVIPersonSID ORDER BY mh.SurveyGivenDatetime DESC)
	

------------------------------------------
--  CAN for CAN risk score
------------------------------------------
	--Find most recent CAN hospitalization risk score
	DROP TABLE IF EXISTS #CAN_hosp;
	SELECT TOP (1) WITH TIES
		 co.MVIPersonSID
		,CAST(HospRiskDate AS DATE) AS CAN_HospRiskDate
		,can.cHosp_90d AS CAN_cHosp_90d
	INTO #CAN_hosp
	FROM [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] can WITH (NOLOCK) 
	INNER JOIN #Cohort co 
		ON co.MVIPersonSID=can.MVIPersonSID
	ORDER BY ROW_NUMBER() OVER (PARTITION BY can.MVIPersonSID ORDER BY can.HospRiskDate DESC)

	--Find most recent CAN mortality risk score
	DROP TABLE IF EXISTS #CAN_mort;
	SELECT TOP (1) WITH TIES
		 co.MVIPersonSID
		,CAST(MortRiskDate AS DATE) AS CAN_MortRiskDate
		,can.cMort_90d AS CAN_cMort_90d
	INTO #CAN_mort
	FROM [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] can WITH (NOLOCK) 
	INNER JOIN #Cohort co 
		ON co.MVIPersonSID=can.MVIPersonSID
	ORDER BY ROW_NUMBER() OVER (PARTITION BY can.MVIPersonSID ORDER BY can.MortRiskDate DESC)


-- ==================================================
-- PDE
-- ==================================================
DROP TABLE IF EXISTS #PDE
SELECT MVIPersonSID
	  ,ISNULL(DischargeDateTime,Admitdatetime) as PDE_InpatDate
	  ,Disch_BedSecName as PDE_Disch_BedSecName
	  ,PDE_Facilities=CONCAT(ChecklistID_Discharge,',',ChecklistID_Home,',',ChecklistID_Metric)
	  ,pde.ChecklistID_Discharge
	  ,c.Facility as Facility_Discharge
INTO #PDE
FROM (
	SELECT MVIPersonSID,Admitdatetime,DischargeDateTime,Disch_BedSecName,ChecklistID_Discharge,ChecklistID_Metric,ChecklistID_Home
		  ,RN=ROW_NUMBER() OVER(Partition By MVIPersonSID ORDER BY ISNULL(DischargeDateTime,'2050-01-01') DESC)
	FROM [PDE_Daily].[PDE_PatientLevel] WITH(NOLOCK)
	WHERE Exclusion30=0
	) pde
LEFT JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=pde.ChecklistID_Discharge
WHERE RN=1

-- ==================================================
-- Inpatient Records (including Census)
-- ==================================================
DROP TABLE IF EXISTS #Inpatient
SELECT i.MVIPersonSID
	  ,i.Census
	  ,CASE WHEN i.Census=1 THEN i.AdmitDateTime ELSE i.DischargeDateTime END as InpatDate
	  ,i.ChecklistID as InpatChecklistID
	  ,i.BedSectionName as Disch_BedSecName
	  ,c.Facility as InpatFacility
	  ,case when LastRecord=1 and Census=1 and 1 in (MentalHealth_TreatingSpecialty,RRTP_TreatingSpecialty) then 1 end as Inpat_MH_current
	  ,case when LastRecord=1 and Census=1 and 1 in (MedSurgInpatient_TreatingSpecialty) then 1 end as Inpat_Med_current
INTO #Inpatient
FROM [Inpatient].[BedSection] i WITH(NOLOCK)
INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=i.ChecklistID
WHERE LastRecord=1
	AND (Census=1 OR DischargeDateTime >= DATEADD(DAY,-91,CAST(GETDATE() AS DATE)))
	--RAS added time limitation for efficiency and limit to necessary data

-- =================================================================================================
-- Last ED Visit 
-- =================================================================================================
	DROP TABLE IF EXISTS #EDVisit;
	SELECT appt.MVIPersonSID
		  ,LastEDVisit=appt.VisitDateTime
	INTO #EDVisit
	FROM [Present].[AppointmentsPast] appt WITH(NOLOCK)
	INNER JOIN #Cohort co on co.MVIPersonSID=appt.MVIPersonSID
	WHERE ApptCategory='EDRecent'
		AND MostRecent_ICN=1

-- ==================================================
-- SPED
-- ==================================================
DROP TABLE IF EXISTS #SPED
SELECT mp.MVIPersonSID
	  ,l.ChecklistID as SPED_ChecklistID
	  ,v.timein as SPED_DateTime
	  ,l.ADMPARENT_FCDM as SPED_Facility
	  ,SPED_6mo=1
INTO #SPED
FROM (
	SELECT PatientICN
		  ,timein
		  ,station = d.checklistid
		  ,RN=ROW_NUMBER() OVER(Partition By PatientICN ORDER BY timein DESC) 	--grab most recent SPED date
	FROM [PDW].[OMHSP_MIRECC_DOEx_SPEDCohort]  v WITH(NOLOCK)
	inner join Lookup.DivisionFacility as d --use this because RM MIRECC's file contains sta6a e.g. 659BY, 568A4, 573A4, 659BZ and others that need to be rolled up to main HCS
	on d.sta6a=v.sta6a
	WHERE ineligibledatetime is null --removes the cases that are identified as SPED ineligible per an SRM F/U entry
	) v
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] mp WITH(NOLOCK) on mp.PatientICN=v.PatientICN
INNER JOIN [LookUp].[Sta6a] l WITH(NOLOCK) on l.Sta6a=v.Station
WHERE v.timein >= DATEADD(MONTH,-6,CAST(GETDATE() as date))
	and v.RN=1


-- ==================================================
-- Somatic Tx
-- ==================================================
--Note: code for this created in [SPPRITE].[SomaticTx] view
DROP TABLE IF EXISTS #somatictx
SELECT MVIPersonSID
	  ,SomaticTx_Date
	  ,SomaticTx_Type
	  ,stx.ChecklistID as SomaticTx_ChecklistID
	  ,c.Facility as SomaticTx_FacilityName
INTO #somatictx
FROM [SPPRITE].[SomaticTx] stx WITH(NOLOCK)
INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on c.ChecklistID=stx.ChecklistID
WHERE TxOrderDesc = 1

-- =================================================================================================
--  Safety Plan
-- =================================================================================================
--Expand to include safety plan declines in cases where a patient had no other safety plans listed
DROP TABLE IF EXISTS #safetyplan
SELECT MVIPersonSID
	  ,SafetyPlanDateTime
	  ,SP_RefusedSafetyPlanning_HF as SafetyPlan_decline
	  ,case when List='SP_SafetyPlanReviewed_HF' then 1 else 0 end as SafetyPlan_Review
	  ,SafetyPlan_ChecklistID
	  ,SafetyPlan_Facility
INTO #safetyplan
FROM (
	SELECT MVIPersonSID
		  ,SafetyPlanDateTime
		  ,a.ChecklistID as SafetyPlan_ChecklistID
		  ,b.Facility as SafetyPlan_Facility
		  ,SP_RefusedSafetyPlanning_HF
		  ,HealthFactorType
		  ,List
		  --order by SP_RefusedSafetyPlanning_HF first to get last completed, then date of declined if no completed exists
		  ,RN=ROW_NUMBER() OVER(Partition By MVIPersonSID ORDER BY SP_RefusedSafetyPlanning_HF,SafetyPlanDateTime DESC)
	FROM [OMHSP_Standard].[SafetyPlan] a WITH(NOLOCK)
	LEFT JOIN Lookup.ChecklistID b WITH(NOLOCK) on a.ChecklistID=b.ChecklistID
	) sp
WHERE RN=1


-- =================================================================================================
--  Psychotropics and controlled substances with no pills on hand ("recently discontinued")
-- =================================================================================================
--Include the minimum days without pills on hand in each category and
--overall for easier sorting in the report.
DROP TABLE IF EXISTS #RxTransitions
SELECT piv.MVIPersonSID
	,Antidepressant_Rx as RxTransitions_Antidepressant
	,Antipsychotic_Rx as RxTransitions_Antipsychotic
	,Benzodiazepine_Rx as RxTransitions_Benzodiazepine
	,Stimulant_Rx as RxTransitions_Stimulant
	,MoodStabilizer_Rx as RxTransitions_MoodStabilizer
	,Sedative_zdrug_Rx as RxTransitions_Sedative_zdrug
	,OpioidAgonist_Rx as RxTransitions_OpioidAgonist
	,OpioidForPain_Rx as RxTransitions_OpioidForPain
	,OtherControlledSub_Rx as RxTransitions_OtherControlledSub
	,s.MinDays as RxTransitions_MinDaysForSorting
INTO #RxTransitions
FROM (
		SELECT MVIPersonSID
			,RxCategory
			,MIN(DaysWithNoPoH) as MinDaysWithNoPoH
		FROM Present.RxTransitionsMH rx WITH(NOLOCK)
		WHERE NoPoH = 1 and DaysWithNoPoH >= 0
		GROUP BY MVIPersonSID, RxCategory
	) a
	PIVOT (SUM(MinDaysWithNoPoH) for RxCategory in ([Antidepressant_Rx],[Sedative_zdrug_Rx],[Benzodiazepine_Rx]
				,[Stimulant_Rx],[OpioidForPain_Rx],[OtherControlledSub_Rx],[Antipsychotic_Rx]
				,[OpioidAgonist_Rx],[MoodStabilizer_Rx])
		   ) piv
	INNER JOIN (
		SELECT MVIPersonSID
			,MIN(DaysWithNoPoH) as MinDays
		FROM Present.RxTransitionsMH WITH(NOLOCK)
		WHERE NoPoH = 1
		GROUP BY MVIPersonSID
	) s
		ON piv.MVIPersonSID = s.MVIPersonSID


-- =================================================================================================
--  Community Status Note
-- =================================================================================================
	DROP TABLE IF EXISTS #communitystatus;
	SELECT MVIPersonSID
		  ,HealthFactorDateTime as CommunityStatusDateTime
	INTO #communitystatus
	FROM [Present].[CommunityStatusNote] WITH(NOLOCK)
	WHERE MostRecent=1

-- =================================================================================================
--  Create Patient-Provider relationship (PCP and MHTC counts)
-- =================================================================================================
DROP TABLE IF EXISTS #ProviderFacilities1;
SELECT MVIPersonSID
	  ,count(distinct ChecklistID) ProviderFacilityCount
	  ,ProviderType
INTO #ProviderFacilities1
FROM (
	SELECT a.MVIPersonSID
		  ,a.ChecklistID
		  ,CASE WHEN PCP=1 THEN 'PCP'
				WHEN MHTC=1 THEN 'MHTC'
				END as ProviderType
	FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
	INNER JOIN #Cohort AS b ON a.MVIPersonSID = b.MVIPersonSID
	WHERE PCP=1 OR MHTC=1
	) a
GROUP BY MVIPersonSID,ProviderType

DROP TABLE IF EXISTS #ProviderFacilities;
SELECT MVIPersonSID,PCP,MHTC
INTO #ProviderFacilities
FROM (
	SELECT * FROM #ProviderFacilities1
	)p
Pivot (max(ProviderFacilityCount)
FOR ProviderType IN (PCP,MHTC)
) up


-- =================================================================================================
-- MH Non-Engagement: most recent MH care 0-30, 31-60, 61-90 or 91+ days
-- =================================================================================================
-- Want to isolate distinct groups that may not be engaged in MH care:
-- 0: Currently engaged (currently admitted inpatient, or upcoming appointment in next 7 days)
-- 1: Most recent MH care was 0-30 days prior, not currently admitted anywhere in VA (MH & non-MH), next MH visit (if any) > 7 days from current date
-- 2: Most recent MH care was 31-60 days prior, not currently admitted anywhere in VA (MH & non-MH), next MH visit (if any) > 7 days from current date
-- 3: Most recent MH care was 61-90 days prior, not currently admitted anywhere in VA (MH & non-MH), next MH visit (if any) > 7 days from current date
-- 4: Most recent MH care was 91+ days prior or never engaged in MH care, not currently admitted anywhere in VA (MH & non-MH), next MH visit (if any) > 7 days from current date

--grab all MH OP and IP encounters for past 90 days. Anyone who doesnt have MH encounter in last 90 days will fall into 91+ days grou
DROP TABLE IF EXISTS #MH_prior
SELECT 
	ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
	,CASE 
		WHEN a.VisitDateTime <= CAST(GETDATE() AS DATE) AND a.VisitDateTime >= DATEADD(d,-30,CAST(GETDATE() AS DATE)) 
			THEN 1 
		WHEN a.VisitDateTime < DATEADD(d,-30,CAST(GETDATE() AS DATE)) AND a.VisitDateTime >= DATEADD(d,-60,CAST(GETDATE() AS DATE)) 
			THEN 2
		WHEN a.VisitDateTime < DATEADD(d,-60,cast(GetDate() AS DATE)) 
			THEN 3
	END AS MH_prior
INTO #MH_prior
FROM [Present].[AppointmentsPast] a WITH (NOLOCK)
LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON a.PatientSID = mvi.PatientPersonSID 
WHERE (a.ApptCategory='MHRecent' or a.ApptCategory='HomelessRecent')
	AND a.VisitDateTime >= DATEADD(d,-90,CAST(GETDATE() AS DATE))

UNION ALL	

--Inpatient MH
--Per Jodie on 3/24/20:
--We are going to use the inpatient psychiatry and MH RRTP bedsections as defined in PDE to define MH engagement on SPPRITE for the “MH engagement” slicer and the “last MH contact” display.  The date of discharge will be used to define the last date of MH engagement for stays in these bedsections.  We will exclude the component of the definition of PDE cohorts that looks for patients with a high risk for suicide diagnosis or flag in other bedsections.  
--RRTP bedsections per PDE:  (1K, 1L, 1M, 25, 26, 27, 28, 29, 37, 38, 39, 68, 75, 77, 85, 86, 88)
--Inpatient bedsection per PDE :  (33, 70, 71, 72, 73, 74, 76, 79, 84, 89, 90, 91, 92, 93, 94)
--Note: 1K=109, 1L=110, 1M=111

SELECT MVIPersonSID
	,case when BsOutDateTime<= cast(GetDate() as date) and BsOutDateTime >= DATEADD(d,-30,cast(GetDate() as date)) then 1
		 when  BsOutDateTime<= DATEADD(d,-30,cast(GetDate() as date)) and BsOutDateTime >= DATEADD(d,-60,cast(GetDate() as date)) then 2
		 when  BsOutDateTime < DATEADD(d,-60,cast(GetDate() as date)) then 3
		 end as MH_prior
FROM [Inpatient].[BedSection] WITH (NOLOCK)
WHERE BedSection in ('25', '26', '27', '28', '29', '37', '38', '39', '68', '75', '77', '85', '86', '88', '109', '110', '111', --RRTP bedsections per PDE
					 '33', '70', '71', '72', '73', '74', '76', '79', '84', '89', '90', '91', '92', '93', '94') --Inpatient bedsection per PDE
	AND BsOutDateTime >= DATEADD(d,-90,cast(GetDate() as date))

DROP TABLE IF EXISTS #MH_prior2
SELECT MVIPersonSID
	,min(MH_prior) as MH_prior --grab the most recent time frame in which they had care
INTO #MH_prior2
FROM #MH_prior
GROUP BY MVIPersonSID

--merge in with SPPRITE cohort, assign MH_prior=4 when null
DROP TABLE IF EXISTS #MH_prior3
SELECT a.MVIPersonSID
	  ,case when MH_prior is NULL then 4 else MH_prior end as MHengage
INTO #MH_prior3
FROM #Cohort a
LEFT JOIN #MH_prior2 b on a.MVIPersonSID=b.MVIPersonSID

-- Currently admitted in VA or MH appointment in the next 7 days - to use as exclusion criteria for these risk factor groupings 
DROP TABLE IF EXISTS #exclude
--Current inpatient
SELECT MVIPersonSID
INTO #exclude
FROM [Inpatient].[BedSection] WITH(NOLOCK)
WHERE Census=1
UNION ALL
--Future MH appointments
SELECT 
	ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
FROM [Present].[AppointmentsFuture] appt WITH(NOLOCK)
LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON appt.PatientSID = mvi.PatientPersonSID 
WHERE appt.AppointmentDateTime <= DATEADD(d,8,CAST(GETDATE() AS DATE)) -- want to account for day lag
	AND appt.AppointmentDateTime >= CAST(GETDATE() AS DATE)
	AND ISNULL(mvi.MVIPersonSID,0) > 0
	AND (appt.ApptCategory='MHFuture' or appt.ApptCategory='HomelessFuture')

DROP TABLE IF EXISTS #MH_prior4
SELECT MVIPersonSID
	  ,MHengage
INTO #MH_prior4
FROM #MH_prior3
WHERE MVIPersonSID NOT IN (
	SELECT MVIPersonSID 
	FROM #exclude
	) 


-- =================================================================================================
--  Suicide Risk Management 
-- =================================================================================================
--First successful outreach date
DROP TABLE IF EXISTS #SRM_success
SELECT MVIPersonSID
	  ,cast(min(Entrydatetime) as date) as SRM_DateTime_success
INTO #SRM_success
FROM [OMHSP_Standard].[SuicideRiskManagement] WITH(NOLOCK)
WHERE OutreachStatus='Success' 
GROUP BY MVIPersonSID

-- Most recent outreach (Result and Date)
DROP TABLE IF EXISTS #SRM_recent
SELECT MVIPersonSID
	  ,CASE WHEN OutreachStatus='Success' THEN 2
			WHEN OutreachStatus='Declined' THEN 1
			ELSE 0 END as SRM_VeteranReached_recent --Unsuccess / "Unable to contact"
	  ,cast(EntryDateTime as date) as SRM_DateTime_recent
INTO #SRM_recent
FROM (
	SELECT MVIPersonSID		  
		  ,OutreachStatus
		  ,EntryDateTime
		  ,row_number() over (PARTITION BY MVIPersonSID ORDER BY EntryDateTime desc) AS RN
	FROM [OMHSP_Standard].[SuicideRiskManagement] WITH(NOLOCK)
	WHERE OutreachStatus <> 'Chart Review' 
	) a
WHERE RN=1


-- =================================================================================================
--  High Risk High Needs (HRHN) indicator
-- =================================================================================================
--High Risk High Needs (frail) in the past QUARTER by the Geriatric and Extended Care (GEC) VA office - will be updated on quarterly basis
DROP TABLE IF EXISTS #HNHR
SELECT p.MVIPersonSID
	  ,h.StaPa
	  ,h.InstitutionName as HNHR_Facility
	  ,HNHR=1 --all patients in this file are considered 'High Risk High Needs' aka HNHR
INTO #HNHR 
FROM [PDW].[GEC_GECDACA_DOEx_HBPCExp_HNHR_list] h WITH(NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] p WITH(NOLOCK) on p.PatientPersonSID=h.PatientSID 
--for now there are no patients in the HNHR list who are only Cerner patients but we may need to revisit this join later on


-- =================================================================================================
--  Behavioral risk flag - active in past 6 months
-- =================================================================================================
-- Pull in most recent behavioral flag (active/inactive)
DROP TABLE IF EXISTS #behavior
SELECT r.MVIPersonSID		  
	 , CASE WHEN b.ActiveFlag='Y' THEN 'Active' ELSE 'Inactive' END AS Behavioral_ActiveFlag
	 , b.ActionDateTime AS Behavioral_ActionDateTime
	 , b.ActionTypeDescription AS Behavioral_ActionName
	 , r.ChecklistID as Behavioral_ChecklistID
	 , c.Facility as Behavioral_Facility
INTO #behavior
FROM [SPPRITE].[RiskIDandDisplay] r WITH(NOLOCK) 
INNER JOIN [PRF].[BehavioralMissingPatient] b WITH(NOLOCK) 
	ON r.MVIPersonSID = b.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
	ON r.ChecklistID = c.ChecklistID
WHERE b.NationalPatientRecordFlag = 'BEHAVIORAL'
AND b.EntryCountDesc = 1
AND r.RiskFactorID IN 
	(SELECT rf.ID FROM [Config].[SPPRITE_RiskFactors] rf WITH (NOLOCK)
		WHERE rf.Label LIKE '%Behavioral%')

-- =================================================================================================
--  Outreach to Facilitate Return to Care (OFR Care) and SRM outreach for ORM cohort
	-- (getting data from SMITREC)
-- =================================================================================================
DROP TABLE IF EXISTS #ofr
SELECT *
INTO #ofr
FROM (
		SELECT b.MVIPersonSID
				,a.LastVisitDate as OFR_LastVisitDate
				,a.ChecklistID as OFR_ChecklistID
				,c.Facility as OFR_Facility
				,a.FirstTop1_Date as OFR_FirstSPPRITEDate
				,case when FirstTop1_Date >= dateadd(month,-3,cast(getdate() as date)) then 1 else 0 end as OFR_NewPrior3Months
				,case when e.PriorityGroup=8 and e.PrioritySubGroup in ('e','g') then 1 else 0 end as OFR_EligibilityFlag --flag if 8e or 8g (they may not be eligible for care but are still included in RV)
				,nursing_home as OFR_nursinghome
				,row_number() over (PARTITION BY b.MVIPersonSID ORDER BY a.FirstTop1_Date desc) AS RN
		FROM [PDW].[SMITR_SMITREC_DOEx_SPNowPlank3_PBNRVets] a WITH(NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientICN] b WITH(NOLOCK) on a.PatientICN=b.PatientICN
		INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) on a.ChecklistID=c.ChecklistID
		INNER JOIN [Config].[SPPRITE_OFRCare] d WITH(NOLOCK) on a.ChecklistID=d.ChecklistID
		INNER JOIN [Common].[MasterPatient] e WITH(NOLOCK) on b.MVIPersonSID=e.MVIPersonSID
		WHERE a.Top1_RiskTier=1 
				and a.FirstTop1_Date > DATEADD(year,-1,getdate()) 
				and d.StartDate is not NULL 
				and d.EndDate is NULL
				and a.FirstTop1_Date > DATEADD(month,-3,d.StartDate) 
				and a.FirstTop1_Date >= a.PilotStart_Date
	) a
WHERE RN=1

-- Most recent OFR outreach (Result and Date)
DROP TABLE IF EXISTS #ofr_srm
SELECT a.MVIPersonSID
	, case when OutreachStatus='Unsuccess' and (FutureFollowup is null or FutureFollowup in ('Continue', 'Discontinue-Other Reason', 'Discontinue-Engaged in Care')) and NoContact is null then 'Unable to Contact' 
             when OutreachStatus='Success' and (FutureFollowup is null or FutureFollowup in ('Continue', 'Discontinue-Other Reason', 'Discontinue-Engaged in Care')) and NoContact is null then 'Successful' --count successful only if the patient didn't decline
             when OutreachStatus='Declined' then 'Veteran Declined Outreach' -- the old version of the SRM F/U note had a 'decline' outreach status option
             when OutreachStatus='Unsuccess' and FutureFollowup='Declined' and nocontact is null then 'Veteran Declined Outreach' -- the new version of the SRM F/U note moved the 'decline' to the Followup section of successful outreach notes or chart review notes
             when OutreachStatus='Success' and FutureFollowup='Declined' and nocontact is null then 'Veteran Declined Outreach'
             when OutreachStatus='Chart Review' and FutureFollowup='Declined' and nocontact is null then 'Veteran Declined Outreach'
             when OutreachStatus='Unsuccess' and NoContact in ('Ineligible-Chart Review', 'Ineligible-Consult') and futurefollowup is null then 'Veteran Ineligible per chart/consult' --add option to identify those determined ineligible
             when OutreachStatus='Success' and NoContact in ('Ineligible-Chart Review', 'Ineligible-Consult') and futurefollowup is null then 'Veteran Ineligible per chart/consult' --add option to identify those determined ineligible
             when OutreachStatus='Chart Review' and NoContact in ('Ineligible-Chart Review', 'Ineligible-Consult') and futurefollowup is null then 'Veteran Ineligible per chart/consult' --add option to identify those determined ineligible
             when OutreachStatus is NULL then 'Not Attempted'
             else 'Chart Review - no outreach completed'
             end as OFR_OutreachStatus_Recent
	  ,cast(EntryDateTime as date) as OFR_OutreachDate_Recent
INTO #ofr_srm
FROM #ofr a
LEFT JOIN ( SELECT * ,row_number() over (PARTITION BY MVIPersonSID ORDER BY EntryDateTime desc) AS RN
            FROM OMHSP_Standard.SuicideRiskManagement WITH(NOLOCK)
            WHERE OFRCare=1
            ) b
                on a.MVIPersonSID=b.MVIPersonSID AND b.RN=1

-- First Successful OFR outreach
DROP TABLE IF EXISTS #ofr_srm_success
SELECT a.MVIPersonSID
	  ,min(cast(EntryDateTime as date)) as OFR_OutreachDate_Success
INTO #ofr_srm_success
FROM #ofr a
LEFT JOIN ( SELECT *
			FROM OMHSP_Standard.SuicideRiskManagement WITH(NOLOCK)
			WHERE OFRCare=1 
				and OutreachStatus='Success' 
				and (FutureFollowUp <> 'Declined' or FutureFollowUp is null) 
				and (NoContact not in ('Ineligible-Chart Review', 'Ineligible-Consult') or NoContact is null)
			) b 
				on a.MVIPersonSID=b.MVIPersonSID
GROUP BY a.MVIPersonSID


-- =================================================================================================
--  SMI Re-Engage cohort from SMITREC (point of contact - Stephanie Merrill or Kristen Abraham)
-- =================================================================================================
DROP TABLE IF EXISTS #SMI_Reengage
SELECT  b.MVIPersonSID
		,c.ChecklistID as SMI_ReEngage_ChecklistID
		,d.Facility as SMI_ReEngage_Facility
		,a.Wave as SMI_ReEngage_Wave
INTO #SMI_ReEngage
FROM [PDW].[SMITR_SMITREC_DOEx_ReEngage_SPPRITE] a WITH(NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] b WITH(NOLOCK) on a.PatientICN=b.PatientICN
INNER JOIN [Lookup].[Sta6a] c WITH (NOLOCK) on a.LRC_Facility=c.Sta6a
LEFT JOIN [LookUp].[ChecklistID] d WITH (NOLOCK) on c.ChecklistID=d.ChecklistID


-- =================================================================================================
--  Debt Management Center (DMC) data from VBA
-- =================================================================================================
DROP TABLE IF EXISTS #DMC
SELECT MVIPersonSID,	  
	   Patient_Debt_Count as DMC_count,
	   Patient_Debt_Sum as DMC_TotalDebt,
	   MostRecentContact_Date as DMC_MostRecentDate,
	   MostRecentContact_Letter as DMC_MostRecentLetter,
	   DisplayMessage as DMC_DisplayMessage
INTO #DMC
FROM (SELECT *
			,row_number() over (PARTITION BY MVIPersonSID ORDER BY MostRecentContact_Date desc) AS RN
	  FROM VBA.DebtManagementCenter WITH (NOLOCK)  
	 ) a 
WHERE a.RN=1


-- =================================================================================================
--  Military Sexual Trauma (MST) postive screen
-- =================================================================================================
DROP TABLE IF EXISTS #MST
SELECT MVIPersonSID
	  ,MST_ChecklistID
	  ,MST_ScreenDateTime
INTO #MST
FROM (
		SELECT MVIPersonSID
			  ,ChecklistID as MST_ChecklistID
			  ,ScreenDateTime as MST_ScreenDateTime
			  ,row_number() over (PARTITION BY MVIPersonSID ORDER BY ScreenDateTime desc) AS RN
		FROM [SDH].[ScreenResults] WITH (NOLOCK)  
		WHERE Category IN ('MST Screen')
			AND Score=1
			AND ScreenDateTime > dateadd(year,-2,cast(getdate() as date))
	) a
WHERE RN=1

-- =================================================================================================
--  COMPACT Act 
-- =================================================================================================
DROP TABLE IF EXISTS #CompactAct
SELECT  a.MVIPersonSID
	,a.EpisodeBeginDate as COMPACT_EpisodeBeginDate
	,a.EpisodeEndDate as COMPACT_EpisodeEndDate
	,CASE WHEN CommunityCare = 1 AND EpisodeBeginSetting <> 'Community Care' THEN CONCAT(a.EpisodeBeginSetting, ' Community Care')
		ELSE a.EpisodeBeginSetting END as COMPACT_EpisodeBeginSetting
	,a.InpatientEpisodeEndDate as COMPACT_InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate as COMPACT_OutpatientEpisodeBeginDate
	,a.ActiveEpisode as COMPACT_ActiveEpisode
	,a.ActiveEpisodeSetting as COMPACT_ActiveEpisodeSetting
	,a.ChecklistID_EpisodeBegin as COMPACT_ChecklistID
	,b.Facility as COMPACT_Facility
	,CASE WHEN mp.PriorityGroup BETWEEN 1 AND 6 THEN CONCAT('Yes (Priority Group ',mp.PriorityGroup,')')
			WHEN mp.PrioritySubGroup IN ('e','g') AND mp.COMPACTEligible=1 THEN CONCAT('Yes (COMPACT eligible only, ',mp.PriorityGroup,mp.PrioritySubgroup,')')
			WHEN mp.PriorityGroup BETWEEN 7 AND 8 AND mp.COMPACTEligible=1 THEN CONCAT('Yes (Priority Group ',mp.PriorityGroup,mp.PrioritySubgroup,')')
			WHEN mp.COMPACTEligible = 1 THEN 'Yes (COMPACT eligible only)'
			ELSE 'Not verified as eligible'
			END AS COMPACT_Eligible
	,a.ConfirmedStart as COMPACT_ConfirmedStart
	,a.EncounterCodes as COMPACT_EncounterCodes
INTO #CompactAct
FROM [COMPACT].[Episodes] a WITH (NOLOCK) 
LEFT JOIN [Lookup].[ChecklistID] b WITH (NOLOCK) on a.ChecklistID_EpisodeBegin=b.ChecklistID
LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK) on a.MVIPersonSID=mp.MVIPersonSID
WHERE ( a.ActiveEpisode=1 
		or a.EpisodeBeginDate >= dateadd(YEAR,-1,cast(getdate() as date)) 
		or (a.EpisodeEndDate >= dateadd(YEAR,-1,cast(getdate() as date)) and a.EpisodeEndDate < cast(getdate() as date))
	  )
		and a.EpisodeRankDesc=1


-- =================================================================================================
--  Next appointment and last visit information
-- =================================================================================================
--Past Appointments/Encounters
DROP TABLE IF EXISTS #PAST_MH
SELECT 
	p.MVIPersonSID
	,CAST(p.VisitDateTime AS date) AS LastMHVisit_Date
	,p.Sta3n AS LastMHVisit_Sta3n
	,p.PrimaryStopCodeName AS LastMHVisit_StopCodeName
	,p.ChecklistID AS LastMHVisit_ChecklistID
	,ch.Facility AS LastMHVisit_Facility
INTO #PAST_MH
FROM #Cohort c 
INNER JOIN Present.AppointmentsPast p WITH (NOLOCK)
	ON c.MVIPersonSID=p.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH(NOLOCK) ON p.ChecklistID=ch.ChecklistID
WHERE p.ApptCategory = 'MHRecent' AND p.MostRecent_ICN=1

DROP TABLE IF EXISTS #PAST_PC
SELECT 
	p.MVIPersonSID
	,CAST(p.VisitDateTime AS date) AS LastPCVisit_Date
	,p.Sta3n AS LastPCVisit_Sta3n
	,p.PrimaryStopCodeName AS LastPCVisit_StopCodeName
	,p.ChecklistID AS LastPCVisit_ChecklistID
	,ch.Facility AS LastPCVisit_Facility
INTO #PAST_PC
FROM #Cohort c 
INNER JOIN Present.AppointmentsPast p WITH (NOLOCK)
	ON c.MVIPersonSID=p.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH(NOLOCK) ON p.ChecklistID=ch.ChecklistID
WHERE p.ApptCategory = 'PCRecent' AND p.MostRecent_ICN=1


----Future Appointments
DROP TABLE IF EXISTS #FUTURE_MH
SELECT 
	f.MVIPersonSID
	,CAST(f.AppointmentDateTime AS date) AS NextMHAppt_Date
	,f.Sta3n AS NextMHAppt_Sta3n
	,f.PrimaryStopCodeName AS NextMHAppt_StopCodeName
	,f.ChecklistID AS NextMHAppt_ChecklistID
	,ch.Facility AS NextMHAppt_Facility
INTO #FUTURE_MH
FROM #Cohort c 
INNER JOIN Present.AppointmentsFuture f WITH (NOLOCK)
	ON f.MVIPersonSID=c.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH(NOLOCK) ON f.ChecklistID=ch.ChecklistID
WHERE f.ApptCategory = 'MHFuture' AND f.NextAppt_ICN=1

DROP TABLE IF EXISTS #FUTURE_PC
SELECT 
	f.MVIPersonSID
	,CAST(f.AppointmentDateTime AS date) AS NextPCAppt_Date
	,f.Sta3n AS NextPCAppt_Sta3n
	,f.PrimaryStopCodeName AS NextPCAppt_StopCodeName
	,f.ChecklistID AS NextPCAppt_ChecklistID
	,ch.Facility AS NextPCAppt_Facility
INTO #FUTURE_PC
FROM #Cohort c 
INNER JOIN Present.AppointmentsFuture f WITH (NOLOCK)
	ON f.MVIPersonSID=c.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH(NOLOCK) ON f.ChecklistID=ch.ChecklistID
WHERE f.ApptCategory = 'PCFuture' AND f.NextAppt_ICN=1

-- ===================================================================================================================================
-- ===================================================================================================================================
--								     ADD ALL INFO TO STAGING TABLE AND SAVE AS PERMANENT
-- ===================================================================================================================================
-- ===================================================================================================================================	

	DROP TABLE IF EXISTS #PatientBasetable;
	SELECT  
		p.MVIPersonSID
		,p.RiskFactors

	  ,stx.SomaticTx_ChecklistID
	  ,stx.SomaticTx_FacilityName
	  ,stx.SomaticTx_Date
	  ,stx.SomaticTx_Type

	  ,prep.SBOR_DateFormatted_Prep as SBOR_Date_Prep
	  ,prep.SBOR_DateFormattedNULL_Prep
	  ,prep.SBOR_ChecklistID_Prep
	  ,prep.SBOR_Facility_Prep

	  ,att.SBOR_DateFormatted_Att as SBOR_Date_Att
	  ,att.SBOR_DateFormattedNULL_Att
	  ,att.SBOR_ChecklistID_Att	
	  ,att.SBOR_Facility_Att

      ,orm.STORM
      ,orm.STORM_RiskCategory
      ,orm.STORM_RiskCategoryLabel
	  ,sped.SPED_DateTime
	  ,sped.SPED_ChecklistID
	  ,sped.SPED_Facility
  
      --Most recent CSRE
	  ,CSRE_DateTime=c.CSRE_DateTime
      ,CSRE_ClinImpressAcute=c.CSRE_Acute
	  ,CSRE_ClinImpressChronic=c.CSRE_Chronic
	  ,CSRE_ChecklistID=c.ChecklistID
	  ,CSRE_Facility=c.Facility

	  --CSRE Risk ID
	  ,CSRE_ID_DateTime=cc.CSRE_DateTime
	  ,CSRE_ID_Acute=cc.CSRE_Acute
	  ,CSRE_ID_Chronic=cc.CSRE_Chronic
	  ,CSRE_ID_ChecklistID=cc.ChecklistID
	  ,CSRE_ID_Facility=cc.Facility

	  --Most recent C-SSRS
	  ,CSSRS_Date=cssrs.CSSRS_Date
	  ,CSSRS_Facility=cssrs.CSSRS_Facility
	  ,cssrs.CSSRS_ChecklistID
	  ,display_CSSRS=cssrs.display_CSSRS

	  --C-SSRS Risk ID
	  ,CSSRS_ID_Date=ci.CSSRS_Date
	  ,CSSRS_ID_ChecklistID=ci.CSSRS_ChecklistID
	  ,CSSRS_ID_Facility=ci.CSSRS_Facility

	  --Most recent CSSRS follow up CSRE
	  ,CSSRS_CSREDateTime=c3.SurveyGivenDateTime

	  -- Most recent AUDIT C
	  ,aud.AUDITC_ChecklistID
	  ,aud.AUDITC_Facility
	  ,aud.AUDITC_SurveyDate
	  ,aud.AUDITC_SurveyResult

	  -- Most recent CAN
	  ,can1.CAN_HospRiskDate
	  ,can1.CAN_cHosp_90d as CAN_cHosp_90d
	  ,can2.CAN_MortRiskDate
	  ,can2.CAN_cMort_90d as CAN_cMort_90d
   
	  ,sp.SafetyPlanDateTime
	  ,sp.SafetyPlan_Decline
	  ,sp.SafetyPlan_Review
	  ,sp.SafetyPlan_ChecklistID
	  ,sp.SafetyPlan_Facility

	   --No pills on hand/recent discontinuation
	  ,rx.RxTransitions_Antipsychotic
	  ,rx.RxTransitions_Antidepressant
	  ,rx.RxTransitions_Benzodiazepine 
	  ,rx.RxTransitions_Sedative_zdrug
	  ,rx.RxTransitions_MoodStabilizer
	  ,rx.RxTransitions_Stimulant
	  ,rx.RxTransitions_OpioidForPain
	  ,rx.RxTransitions_OpioidAgonist
	  ,rx.RxTransitions_OtherControlledSub
	  ,ISNULL(rx.RxTransitions_MinDaysForSorting, '9999') as RxTransitions_MinDaysForSorting

	  ,case when p.RiskFactors like '%P%' then 1 else 0 end as Homeless

	  ,cs.CommunityStatusDateTime
	  
	  ,e.LastEDVisit -- ED/Urgent Care visits in the past 1 year
	  		  
      ,hrf.PatRecFlag_Status
      ,hrf.PatRecFlag_ChecklistID
      ,hrf.PatRecFlag_Facility
	  ,hrf.PatRecFlag_Date

	  ,hrf2.HRFLetters_EligDate
	  ,hrf2.HRFLetters_Status

	  ,ipb.Census
	 --,ipb.Inpat_Med_current
	 --,ipb.Inpat_MH_current
	  ,ipb.InpatDate
	  ,ipb.InpatChecklistID
	  ,ipb.InpatFacility
	  ,ipb.Disch_BedSecName

	  ,i.PDE_InpatDate
	  ,i.PDE_Disch_BedSecName
	  ,PDE_InpatChecklistID=i.ChecklistID_Discharge
	  ,PDE_InpatFacility=i.Facility_Discharge
	  ,i.PDE_Facilities as PDE_ChecklistIDs

	  --,ss.STORM_RMS
	  --,ss.STORM_RMSNeeded
      ,ss.STORM_RMS_TimelyPerformed
      ,ss.STORM_RMS_Denominator
	  ,rf.STORM_Facilities
	  ,rf.STORM_ChecklistIDs
	  ,rvf.RV_ChecklistID
	  ,rvf.RV_Facility
	  ,MHTCCount=pf.MHTC
	  ,PCPCount=pf.PCP

	  ,isnull(mhp.MHengage,0) as MHengage

	  ,vcl.VCL_Call_Date
	  ,vcl.VCL_ChecklistID
	  ,vcl.VCL_Status

	  ,hnhr.HNHR
	  ,hnhr.HNHR_Facility

	  ,behav.Behavioral_ActiveFlag
	  ,behav.Behavioral_ActionDateTime
	  ,behav.Behavioral_ChecklistID
	  ,behav.Behavioral_Facility

	  ,ofr.OFR_LastVisitDate
	  ,ofr.OFR_ChecklistID
	  ,ofr.OFR_Facility
	  ,ofr.OFR_FirstSPPRITEDate
	  ,ofr.OFR_NewPrior3Months
	  ,ofr.OFR_EligibilityFlag
	  ,ofr.OFR_nursinghome
	  ,ofr2.OFR_OutreachDate_Recent
	  ,ofr2.OFR_OutreachStatus_Recent
	  ,ofr3.OFR_OutreachDate_Success

	  ,srm1.SRM_DateTime_success
	  ,srm2.SRM_VeteranReached_recent
	  ,srm2.SRM_DateTime_recent

	  ,smi.SMI_ReEngage_ChecklistID
	  ,smi.SMI_ReEngage_Facility
	  ,smi.SMI_ReEngage_Wave

	  ,dmc.DMC_count
	  ,dmc.DMC_TotalDebt
	  ,dmc.DMC_MostRecentDate
	  ,dmc.DMC_MostRecentLetter
	  ,dmc.DMC_DisplayMessage

	  ,mst.MST_ChecklistID
	  ,mst.MST_ScreenDateTime
	  
	  ,com.COMPACT_EpisodeBeginDate
	  ,com.COMPACT_EpisodeEndDate
	  ,com.COMPACT_EpisodeBeginSetting
	  ,com.COMPACT_InpatientEpisodeEndDate
	  ,com.COMPACT_OutpatientEpisodeBeginDate
	  ,com.COMPACT_ActiveEpisode
	  ,com.COMPACT_ActiveEpisodeSetting
	  ,com.COMPACT_ChecklistID
	  ,com.COMPACT_Facility
	  ,com.COMPACT_Eligible
	  ,com.COMPACT_ConfirmedStart
	  ,com.COMPACT_EncounterCodes

	  ,n1.NextPCAppt_Date as NextPCApptICN
	  ,n1.NextPCAppt_ChecklistID as NextPCApptChecklistID_ICN
	  ,n1.NextPCAppt_Facility as NextPCApptFacilityICN
	  ,n2.NextMHAppt_Date as NextMHApptICN
	  ,n2.NextMHAppt_ChecklistID as NextMHApptChecklistID_ICN
	  ,n2.NextMHAppt_Facility as NextMHApptFacilityICN
	  ,p1.LastMHVisit_Date as LastMHVisitICN
	  ,p1.LastMHVisit_Sta3n as LastMHVisitICN_Sta3n
	  ,p1.LastMHVisit_Facility as LastMHVisitICN_Facility
	  ,p1.LastMHVisit_StopCodeName as LastMHVisitICN_StopCodeName
	  ,p2.LastPCVisit_Date as LastPCVisitICN
	  ,p2.LastPCVisit_Sta3n as LastPCVisitICN_Sta3n
	  ,p2.LastPCVisit_Facility as LastPCVisitICN_Facility	  

	INTO #PatientBasetable
	FROM  #cohort p
	LEFT JOIN #hrf as hrf on p.MVIPersonSID=hrf.MVIPersonSID
	LEFT JOIN #HRF_letters as hrf2 on p.MVIPersonSID=hrf2.MVIPersonSID
	LEFT JOIN #PDE as i			on p.MVIPersonSID = i.MVIPersonSID
	LEFT JOIN #ORM_RMS as ss	on p.MVIPersonSID = ss.MVIPersonSID
	LEFT JOIN #ORM_Facility as rf on p.MVIPersonSID = rf.MVIPersonSID
	LEFT JOIN #EDVisit e on p.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN #RVFacility rvf on p.MVIPersonSID=rvf.MVIPersonSID
	LEFT JOIN #CSRERecentResult c on p.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #CSRE_RiskID cc on p.MVIPersonSID=cc.MVIPersonSID
	LEFT JOIN #cssrs cssrs on p.MVIPersonSID=cssrs.MVIPersonSID
	LEFT JOIN #cssrs_id ci on p.MVIPersonSID=ci.MVIPersonSID
	LEFT JOIN (SELECT * FROM #CSRE_SurveyDates WHERE SurveyWithCSRE ='CSSRS') c3 on 
		p.MVIPersonSID=c3.MVIPersonSID
		AND cssrs.CSSRS_Date=c3.SurveyCSRE_DateTime
	LEFT JOIN #CAN_hosp can1 on p.MVIPersonSID=can1.MVIPersonSID
	LEFT JOIN #CAN_mort can2 on p.MVIPersonSID=can2.MVIPersonSID
	LEFT JOIN #AUDIT_C aud on p.MVIPersonSID=aud.MVIPersonSID
	LEFT JOIN #ProviderFacilities pf on pf.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #RxTransitions rx ON p.MVIPersonSID=rx.MVIPersonSID  
	LEFT JOIN #safetyplan sp ON p.MVIPersonSID=sp.MVIPersonSID  
	LEFT JOIN #communitystatus cs on p.MVIPersonSID=cs.MVIPersonSID
	LEFT JOIN #SBOR_SPAN_Prep as prep on prep.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #SBOR_SPAN_Att as att on att.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #MH_prior4 as mhp on mhp.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #VCL2 as vcl on vcl.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #HNHR as hnhr on hnhr.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #behavior as behav on behav.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #SRM_success as srm1 on srm1.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #SRM_recent as srm2 on srm2.MVIPersonSID=p.MVIPersonSID 
	LEFT JOIN #Past_MH p1 on p1.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #Past_PC p2 on p2.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #FUTURE_PC n1 on n1.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #FUTURE_MH n2 on n2.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #STORM as orm on orm.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #SPED sped on sped.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #somatictx stx on stx.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #inpatient ipb on ipb.MVIPersonSID=p.MVIPersonSID	
	LEFT JOIN #OFR ofr on ofr.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #ofr_srm ofr2 on ofr2.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #ofr_srm_success ofr3 on ofr3.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #SMI_ReEngage smi on smi.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #DMC dmc on dmc.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #CompactAct com on com.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #MST mst on mst.MVIPersonSID=p.MVIPersonSID

	CREATE CLUSTERED INDEX CIX_PatientBasetable ON #PatientBasetable (MVIPersonSID)

DROP TABLE IF EXISTS #StageSPPRITEPatientDetail
SELECT DISTINCT co.MVIPersonSID
	  ,mp.PatientICN
	  ,mp.PatientName
	  ,mp.LastFour as Last4
	  ,mp.Age
	  ,mp.DisplayGender as Gender
	  ,mp.PercentServiceConnect
	  ,mp.ServiceSeparationDate
	  ,co.CommunityStatusDateTime
	  ,mp.SensitiveFlag
	  ,co.RiskFactors				
	  ,co.Homeless			
	  ,mp.DateofDeath				
	  ,co.CSSRS_ID_Date
	  ,co.CSSRS_ID_ChecklistID
	  ,co.CSSRS_ID_Facility
	  ,co.CSRE_ID_DateTime
	  ,co.CSRE_ID_Acute
	  ,co.CSRE_ID_Chronic
	  ,co.CSRE_ID_ChecklistID
	  ,co.CSRE_ID_Facility
	  ,co.CSRE_DateTime
	  ,co.CSRE_ClinImpressAcute
	  ,co.CSRE_ClinImpressChronic
	  ,co.CSRE_ChecklistID
	  ,co.CSRE_Facility
	  ,co.CSSRS_Date
	  ,co.display_CSSRS
	  ,co.CSSRS_ChecklistID
	  ,co.CSSRS_Facility
	  ,co.CSSRS_CSREDateTime
	  ,co.AUDITC_ChecklistID
	  ,co.AUDITC_Facility
	  ,co.AUDITC_SurveyDate
	  ,co.AUDITC_SurveyResult
	  ,co.CAN_HospRiskDate
	  ,co.CAN_cHosp_90d
	  ,co.CAN_MortRiskDate
	  ,co.CAN_cMort_90d
	  ,co.SafetyPlanDateTime
	  ,co.SafetyPlan_Decline
	  ,co.SafetyPlan_Review
	  ,co.SafetyPlan_ChecklistID
	  ,co.SafetyPlan_Facility
	  ,co.RxTransitions_Antipsychotic
	  ,co.RxTransitions_Antidepressant
	  ,co.RxTransitions_Benzodiazepine 
	  ,co.RxTransitions_Sedative_zdrug
	  ,co.RxTransitions_MoodStabilizer
	  ,co.RxTransitions_Stimulant
	  ,co.RxTransitions_OpioidForPain
	  ,co.RxTransitions_OpioidAgonist
	  ,co.RxTransitions_OtherControlledSub
	  ,co.RxTransitions_MinDaysForSorting
	  ,co.PatRecFlag_Status
	  ,co.PatRecFlag_Date
	  ,co.PatRecFlag_ChecklistID
	  ,co.PatRecFlag_Facility
	  ,co.HRFLetters_EligDate
	  ,co.HRFLetters_Status
	  ,co.Behavioral_ActiveFlag
	  ,co.Behavioral_ActionDateTime
	  ,co.Behavioral_ChecklistID
	  ,co.Behavioral_Facility
	  ,co.RV_ChecklistID
	  ,co.RV_Facility
	  ,co.SBOR_Date_Prep
	  ,co.SBOR_DateFormattedNULL_Prep
	  ,co.SBOR_ChecklistID_Prep
	  ,co.SBOR_Facility_Prep
	  ,co.SBOR_Date_Att
	  ,co.SBOR_DateFormattedNULL_Att
	  ,co.SBOR_ChecklistID_Att
	  ,co.SBOR_Facility_Att
	  ,co.SomaticTx_ChecklistID
	  ,co.SomaticTx_FacilityName
	  ,co.SomaticTx_Date
	  ,co.SomaticTx_Type
	  ,co.Census
	  ,co.InpatDate
	  ,co.InpatChecklistID
	  ,co.InpatFacility
	  ,co.Disch_BedSecName
	  ,co.PDE_InpatDate
	  ,co.PDE_Disch_BedSecName
	  ,co.PDE_InpatChecklistID
	  ,co.PDE_InpatFacility
	  ,co.PDE_ChecklistIDs
	  ,co.STORM
	  ,co.STORM_RiskCategory
	  ,co.STORM_RiskCategoryLabel
	  ,co.STORM_RMS_TimelyPerformed
	  ,co.STORM_RMS_Denominator
	  ,co.STORM_ChecklistIDs
	  ,co.STORM_Facilities
	  ,co.SPED_DateTime
	  ,co.SPED_ChecklistiD
	  ,co.SPED_Facility
	  ,co.SRM_DateTime_success
	  ,co.SRM_VeteranReached_recent
	  ,co.SRM_DateTime_recent
	  ,co.LastEDVisit
	  ,co.PCPCount
	  ,co.MHTCCount
	  ,co.VCL_Call_Date
	  ,co.VCL_ChecklistID
	  ,co.VCL_Status
	  ,co.HNHR
	  ,co.HNHR_Facility
	  ,co.OFR_LastVisitDate
	  ,co.OFR_ChecklistID
	  ,co.OFR_Facility
	  ,co.OFR_FirstSPPRITEDate
	  ,co.OFR_NewPrior3Months
	  ,co.OFR_EligibilityFlag
	  ,co.OFR_OutreachDate_Recent
	  ,co.OFR_OutreachStatus_Recent
	  ,co.OFR_OutreachDate_Success
	  ,co.OFR_nursinghome
	  ,co.MHengage
	  ,co.SMI_ReEngage_ChecklistID
	  ,co.SMI_ReEngage_Facility
	  ,co.SMI_ReEngage_Wave
	  ,co.DMC_count
	  ,co.DMC_TotalDebt
	  ,co.DMC_MostRecentDate
	  ,co.DMC_MostRecentLetter
	  ,co.DMC_DisplayMessage
	  ,co.MST_ChecklistID
	  ,co.MST_ScreenDateTime
	  ,co.COMPACT_EpisodeBeginDate
	  ,co.COMPACT_EpisodeEndDate
	  ,co.COMPACT_EpisodeBeginSetting
	  ,co.COMPACT_InpatientEpisodeEndDate
	  ,co.COMPACT_OutpatientEpisodeBeginDate
	  ,co.COMPACT_ActiveEpisode
	  ,co.COMPACT_ActiveEpisodeSetting
	  ,co.COMPACT_ChecklistID
	  ,co.COMPACT_Facility
	  ,co.COMPACT_Eligible
	  ,co.COMPACT_ConfirmedStart
	  ,co.COMPACT_EncounterCodes
	  ,co.NextPCApptICN
	  ,co.NextPCApptChecklistID_ICN
	  ,co.NextPCApptFacilityICN
	  ,co.NextMHApptICN
	  ,co.NextMHApptChecklistID_ICN
	  ,co.NextMHApptFacilityICN
	  ,co.LastPCVisitICN
	  ,co.LastPCVisitICN_Sta3n
	  ,co.LastPCVisitICN_Facility
	  ,co.LastMHVisitICN
	  ,co.LastMHVisitICN_Sta3n
	  ,co.LastMHVisitICN_Facility
	  ,co.LastMHVisitICN_StopCodeName
	  ,mp.StreetAddress1
	  ,mp.StreetAddress2
	  ,mp.StreetAddress3
	  ,mp.City
	  ,mp.State as StateAbbrev
	  ,mp.Zip
	  ,mp.PhoneNumber as PatientResidence
	  ,mp.CellPhoneNumber as PatientCell
	  ,mp.SourceEHR
	  ,cast(GetDate() as date) as RunDate
INTO #StageSPPRITEPatientDetail
FROM #PatientBasetable co
LEFT JOIN [Common].[MasterPatient] mp WITH(NOLOCK) on mp.MVIPersonSID=co.MVIPersonSID


-----------------------------------------------------------
-- Publish
-----------------------------------------------------------
EXEC [Maintenance].[PublishTable] 'SPPRITE.PatientDetail','#StageSPPRITEPatientDetail'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'
	

END