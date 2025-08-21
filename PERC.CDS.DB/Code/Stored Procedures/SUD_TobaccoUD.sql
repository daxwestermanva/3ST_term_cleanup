

-- =============================================
-- Author: Claire Hannemann
-- Create date: 2023-09-15
-- Description: Creating a cohort of patients with Tobacco Use Disorder to be used for outreach 

-- Points of contact: Jennifer Knoeppel (Jennifer.Knoeppel@va.gov) and Dana Christopherson (Dana.Christofferson@va.gov)

-- Cohort Definition: Patient was positive on their last tobacco screen conducted in the past 4 months AND had at least one MH encounter in prior year
-- See view SUD.TobaccoScreens for more details on tobacco screens
-- Assign patients to facility based on homestation. If no homestation, take facility of most recent tobacco screen
-- Patients with any outreach HFs will remain permanently on the report for the facility where the outreach began, regardless of timeframe for screen or MH appt
-- and regardless of homestation transfer

-- Health factor types:
-- VA-TOBACCO USER EVERY DAY – current use every day
-- VA-TOBACCO USER SOME DAYS – current use some days
-- VA-TOBACCO USE EVERY DAY CIGARETTES
-- VA-TOBACCO USE EVERY DAY CIGARS/PIPES
-- VA-TOBACCO USE EVERY DAY SMOKELESS
-- VA-TOBACCO USE SOME DAYS CIGARETTES
-- VA-TOBACCO USE SOME DAYS CIGARS/PIPES
-- VA-TOBACCO USE SOME DAYS SMOKELESS

--DTAs:
-- Cerner FactPowerForm DerivedDtaEventResult (where DerivedDtaEvent='Tobacco Use Status' ):
-- Yes - Current everyday tobacco user
-- Yes - Current some day tobacco user
-- Yes - current everyday user
-- Yes - current some day user
-- Yes-current everyday cigarette user
-- Yes-current everyday other tobacco user (not cigarettes)
-- Yes-current some day cigarette user
-- Yes-current some day other tobacco user (not cigarettes)

-- Per POCs, patients with the following HFs should not appear as positive on the dashboard even though I have them listed as 
-- positive in the SUD.TobaccoScreens view. Their reasoning: "The updated tobacco use screening clinical reminder does not require that a brief intervention 
-- (advise to quit, connection to treatment) be conducted for patients who exclusively vape or use other non-traditional tobacco products given the limited 
-- evidence about health harms. As such, we are not currently planning on proactive outreach for patients who exclusively vape or use other products like nicotine pouches."
--VA-TOBACCO USE EVERY DAY ENDS
--VA-TOBACCO USE EVERY DAY OTHER PRODUCT
--VA-TOBACCO USE EVERY DAY OTHER TYPE
--VA-TOBACCO USE SOME DAYS ENDS
--VA-TOBACCO USE SOME DAYS OTHER PRODUCT
--VA-TOBACCO USE SOME DAYS OTHER TYPE

-- Modifications:
-- 06-04-2025  CMH  Took welcome mailing out of intake needed algorithm
-- 06-12-2025  CMH  Added clause so that any outreach attempts or outreach staff assignments that occurred more than 9 months ago will no longer appear on report
-- 06-16-2025  CMH  Changed cohort from 6 months of screens to 4 months
-- 06-23-2025  CMH  Adding in information about most recent outreach to display on report for closed cases

-- ==============================================
CREATE PROCEDURE [Code].[SUD_TobaccoUD]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.SUD_TobaccoUseDisorder', @Description = 'Execution of Code.SUD_TobaccoUseDisorder SP'

--Per Jennifer Knoeppel and Dana Christopherson, patients with the following HFs should not appear as positive on the dashboard even though I have them listed as 
-- positive in the SUD.TobaccoScreens view. Their reasoning: "The updated tobacco use screening clinical reminder does not require that a brief intervention 
-- (advise to quit, connection to treatment) be conducted for patients who exclusively vape or use other non-traditional tobacco products given the limited 
-- evidence about health harms. As such, we are not currently planning on proactive outreach for patients who exclusively vape or use other products like nicotine pouches."
--VA-TOBACCO USE EVERY DAY ENDS
--VA-TOBACCO USE EVERY DAY OTHER PRODUCT
--VA-TOBACCO USE EVERY DAY OTHER TYPE
--VA-TOBACCO USE SOME DAYS ENDS
--VA-TOBACCO USE SOME DAYS OTHER PRODUCT
--VA-TOBACCO USE SOME DAYS OTHER TYPE

--I will set the Positive Screen indicator to 0 for these screens so they aren't pulled into the report and recalculate the OrderDesc
	DROP TABLE IF EXISTS #SUD_TobaccoScreens
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,ChecklistID
		,CASE WHEN HealthFactorType in ('VA-TOBACCO USE EVERY DAY ENDS','VA-TOBACCO USE EVERY DAY OTHER PRODUCT','VA-TOBACCO USE EVERY DAY OTHER TYPE',
										'VA-TOBACCO USE SOME DAYS ENDS','VA-TOBACCO USE SOME DAYS OTHER PRODUCT','VA-TOBACCO USE SOME DAYS OTHER TYPE')
		THEN 0 else PositiveScreen end as PositiveScreen
    INTO #SUD_TobaccoScreens
	FROM [SUD].[TobaccoScreens] WITH (NOLOCK) --script out this view for logic
	
	DROP TABLE IF EXISTS #SUD_TobaccoScreens2
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,ChecklistID
		,PositiveScreen
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC, PositiveScreen DESC) AS OrderDesc
    INTO #SUD_TobaccoScreens2
	FROM #SUD_TobaccoScreens

	DROP TABLE IF EXISTS #PosScreen
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,ChecklistID
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC, PositiveScreen DESC) AS OrderDesc
    INTO #PosScreen
	FROM #SUD_TobaccoScreens2
	WHERE PositiveScreen=1 and OrderDesc=1

	
--Grab all other health factors associated with the date of their most recent. Specifically interested in request for meds and request for counseling. Will need to figure out DTAs later
	DROP TABLE IF EXISTS #HealthFactors_counsel_med
	SELECT c.MVIPersonSID
			,b.HealthFactorType
			,a.HealthFactorDateTime
	INTO #HealthFactors_counsel_med
	FROM [HF].[HealthFactor] a WITH (NOLOCK)
	INNER JOIN [Dim].[HealthFactorType] b WITH (NOLOCK) on a.HealthFactorTypeSID=b.HealthFactorTypeSID
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK) on a.patientsid=c.PatientPersonSID
	WHERE b.HealthFactorType like 'VA-TOBACCO%' 
			and (b.HealthFactorType like '%COUNSEL%' or b.HealthFactorType like '%MED%')
			and a.HealthFactorDateTime > DATEADD(year,-5,cast(getdate() as date))

	DROP TABLE IF EXISTS #HealthFactors_counsel
	SELECT MVIPersonSID	
			,HealthFactorType
	INTO #HealthFactors_counsel
	FROM (
			SELECT b.MVIPersonSID
					,a.HealthFactorType
					,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY CASE WHEN b.HealthFactorType like '%YES%' THEN 1 ELSE 0 END DESC) AS RN
			FROM #HealthFactors_counsel_med a
			INNER JOIN #PosScreen b on a.MVIPersonSID=b.MVIPersonSID and a.HealthFactorDateTime=b.HealthFactorDateTime
			WHERE a.HealthFactorType like '%COUNSEL%' 
		) a
	WHERE RN=1 

	DROP TABLE IF EXISTS #HealthFactors_med
	SELECT MVIPersonSID	
			,HealthFactorType
	INTO #HealthFactors_med
	FROM (
			SELECT b.MVIPersonSID
					,b.HealthFactorType
					,ROW_NUMBER() OVER (PARTITION BY b.MVIPersonSID ORDER BY CASE WHEN b.HealthFactorType like '%YES%' or b.HealthFactorType like '%NOTIFY PROVIDER%' THEN 1 ELSE 0 END DESC) AS RN
			FROM #HealthFactors_counsel_med a
			INNER JOIN #PosScreen b on a.MVIPersonSID=b.MVIPersonSID and a.HealthFactorDateTime=b.HealthFactorDateTime
			WHERE a.HealthFactorType like '%MED%' 
		) a
	WHERE RN=1

	---- for DTAs 
--select distinct a.*
--from Cerner.FactPowerForm a
--inner join #PosScreen b on a.MVIPersonSID=b.MVIPersonSID and a.TZFormUTCDateTime=b.HealthFactorDateTime
--where DerivedDtaEvent in ('MH Tobacco Meds requested/provided')

--select distinct DerivedDtaEvent
--from Cerner.FactPowerForm
--where DerivedDtaEvent like '%tobacco%' and DerivedDtaEvent like '%counsel%'

--select distinct TaskAssay
--from cerner.FactSocialHistory
--order by TaskAssay

--select distinct taskassay, DerivedSourceString
--from cerner.FactSocialHistory
--where TaskAssay like '%tobacco%' or TaskAssay like '%smok%'
--order by taskassay, DerivedSourceString

--select distinct a.*
--from cerner.FactSocialHistory a
--inner join #PosScreen b on a.MVIPersonSID=b.MVIPersonSID and a.TZPerformDateTime=b.HealthFactorDateTime
--where TaskAssay='SHX Tobacco readiness to change' and DerivedSourceString='Yes'
--order by TZPerformDateTime

--Retain patients with 1 or more MH encounters in past year
	DROP TABLE IF EXISTS #MH_Enc
	SELECT b.MVIPersonSID
			,a.VisitSID
			,cast(a.VisitDateTime as date) as VisitDate
	INTO #MH_Enc
	FROM [Outpat].[Visit] a WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] b WITH (NOLOCK) on a.PatientSID=b.PatientPersonSID
	INNER JOIN [LookUp].[StopCode] c WITH (NOLOCK) on a.PrimaryStopCodeSID=c.StopCodeSID
	LEFT JOIN [LookUp].[StopCode] d WITH (NOLOCK) on a.SecondaryStopCodeSID=d.StopCodeSID
	WHERE a.WorkloadLogicFlag='Y'
		and a.VisitDateTime BETWEEN DATEADD(year,-1,cast(getdate() as date)) and cast(getdate() as date)
		and (c.MHOC_MentalHealth_Stop=1 or d.MHOC_MentalHealth_Stop=1)
	UNION
	SELECT 
		 c.MVIPersonSID
		,c.EncounterSID
		,c.TZDerivedVisitDateTime
	FROM [Cerner].[FactUtilizationOutpatient] c WITH(NOLOCK)
	LEFT JOIN [LookUp].[ListMember] as a WITH (NOLOCK)
		ON a.ItemID = c.ActivityTypeCodeValueSID
	WHERE c.TZDerivedVisitDateTime BETWEEN DATEADD(year,-1,cast(getdate() as date)) and cast(getdate() as date)
	AND c.MVIPersonSID>0
	AND a.Domain = 'ActivityType' 
	AND a.List = 'MHOC_MH' 

	DROP TABLE IF EXISTS #MH_1ormore
	SELECT MVIPersonSID
			,TotalMHEnc
	INTO #MH_1ormore
	FROM (
			SELECT MVIPersonSID
				,count(distinct VisitDate) as TotalMHEnc
			FROM #MH_Enc
			GROUP BY MVIPersonSID
		) a
	WHERE TotalMHEnc >= 1


-- Retain 4 months of screens AND anyone who has ever had an outreach HF, regardless of last screen (bring in DTAs eventually)
	DROP TABLE IF EXISTS #PosScreen_Recent
	--ever had an outreach, regardless of recent screen or MH appt
	SELECT a.MVIPersonSID, d.HealthFactorDateTime, d.HealthFactorType, d.ChecklistID
	INTO #PosScreen_Recent
	FROM [Common].[MVIPersonSIDPatientPersonSID] a WITH (NOLOCK)
	INNER JOIN HF.HealthFactor b WITH (NOLOCK) on a.PatientPersonSID=b.PatientSID
	INNER JOIN (SELECT hft.* 
				FROM (
					   SELECT HealthFactorTypeSID 
					   FROM Dim.HealthFactorType WITH (NOLOCK) 
					   WHERE HealthFactorType like '%TOBACCO TREATMENT PROACTIVE OUTREACH%') as hfc   
	INNER JOIN [Dim].[HealthFactorType] as hft WITH (NOLOCK) on hfc.HealthFactorTypeSID = hft.CategoryHealthFactorTypeSID) c on b.HealthFactorTypeSID=c.HealthFactorTypeSID
	INNER JOIN #PosScreen d on a.MVIPersonSID=d.MVIPersonSID
	WHERE c.HealthFactorType <> 'PROACTIVE OUTREACH MAILING'
	UNION
	--pos screen in last 4 month and at lease one MH appt in last year 
	SELECT a.MVIPersonSID, a.HealthFactorDateTime, a.HealthFactorType, a.ChecklistID
	FROM #PosScreen a
	INNER JOIN #MH_1ormore m on a.MVIPersonSID=m.MVIPersonSID
	WHERE HealthFactorDateTime > DATEADD(month,-4,cast(getdate() as date))

----------------------------------------------------------------
--Pull in contact information and homestation, filter out deceased and test patients.
--For the handful of patients without a homestation assignment, assign tobacco screen facility.
----------------------------------------------------------------
	DROP TABLE IF EXISTS #Cohort
	SELECT a.MVIPersonSID
		,b.PatientICN
		,a.HealthFactorDateTime as TobaccoScreenDateTime
		,a.HealthFactorType as TobaccoScreenType
		,a.ChecklistID as TobaccoScreen_ChecklistID
		,d2.Facility as TobaccoScreen_Facility
		,case when a.HealthFactorDateTime >= DATEADD(day,-60,cast(getdate() as date)) then 1 else 0 end as TobaccoScreen_Past60Days
		,case when e.HealthFactorType like '%YES%' then 'Yes' else 'No' end as HF_Counsel
		,case when f.HealthFactorType like '%YES%' then 'Yes' when f.HealthFactorType like '%NOTIFY PROVIDER%' then 'Yes, notified provider' else 'No' end as HF_Med
		,case when e.HealthFactorType like '%YES%' or f.HealthFactorType like '%YES%' or f.HealthFactorType like '%NOTIFY PROVIDER%' then 1 else 2 end as HF_sorting
		,ISNULL(d1.VISN,d2.VISN) as Homestation_VISN
		,ISNULL(c.ChecklistID,a.ChecklistID) as Homestation_ChecklistID
		,ISNULL(d1.Facility,d2.Facility) as Homestation_Facility
		,b.PatientName
		,b.DisplayGender as PatientGender
		,b.Age as PatientAge
		,b.LastFour
		,b.DateOfBirth
		,b.Veteran
		,b.PhoneNumber
		,b.StreetAddress1
		,b.StreetAddress2
		,b.City
		,b.State
		,b.Zip
		,ISNULL(TotalMHEnc,0) AS TotalMHEnc
	INTO #Cohort
	FROM #PosScreen_recent a
	INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN [Present].[HomestationMonthly] c WITH (NOLOCK) on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN [LookUp].[ChecklistID] d1 WITH (NOLOCK) on c.ChecklistID=d1.ChecklistID
	LEFT JOIN [LookUp].[ChecklistID] d2 WITH (NOLOCK) on a.ChecklistID=d2.ChecklistID
	LEFT JOIN #HealthFactors_counsel e on a.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN #HealthFactors_med f on a.MVIPersonSID=f.MVIPersonSID
	LEFT JOIN #MH_1ormore m on a.MVIPersonSID=m.MVIPersonSID
	WHERE b.DateOfDeath IS NULL and b.TestPatient=0 


----------------------------------------------------------------
--TOBACCO TREATMENT PROACTIVE OUTREACH PILOT Health Factors
----------------------------------------------------------------
-- DTAs need to be figured out at later time
	DROP TABLE IF EXISTS #HF
	SELECT DISTINCT a.MVIPersonSID
		, a.HealthFactorDateTime
		, a.HealthFactorType
		, a.EncounterStaffSID
		, b.StaffSID
		, b.StaffName
		, b.NetworkUsername
	INTO #HF
	FROM (
			SELECT DISTINCT d.MVIPersonSID
				, a.HealthFactorDateTime
				, b.HealthFactorType
				, case when a.EncounterStaffSID=-1 then t.SignedbyStaffSID else a.EncounterStaffSID end as EncounterStaffSID
			FROM #Cohort d
			INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] e WITH (NOLOCK) on d.MVIPersonSID=e.MVIPersonSID
			INNER JOIN [HF].[HealthFactor] a WITH (NOLOCK) on e.PatientPersonSID=a.PatientSID
			INNER JOIN (SELECT hft.* 
						FROM (
							   SELECT HealthFactorTypeSID 
							   FROM [Dim].[HealthFactorType] WITH (NOLOCK)
							   WHERE HealthFactorType like '%TOBACCO TREATMENT PROACTIVE OUTREACH%') as hfc   
			INNER JOIN [Dim].[HealthFactorType] as hft WITH (NOLOCK) on hfc.HealthFactorTypeSID = hft.CategoryHealthFactorTypeSID) b on a.HealthFactorTypeSID=b.HealthFactorTypeSID
			LEFT JOIN [TIU].[TIUDocument] t WITH (NOLOCK) on a.VisitSID=t.VisitSID
		) a
	LEFT JOIN SStaff.SStaff b WITH (NOLOCK) on a.EncounterStaffSID=b.StaffSID
	WHERE a.HealthFactorType <> 'PROACTIVE OUTREACH MAILING' -- removing outreach mailing from counting as outreach

-- Limit to display intake and follow-up attempts on report that happened within the past 9 months
	DROP TABLE IF EXISTS #HF_current
	SELECT *
	INTO #HF_current
	FROM #HF
	WHERE HealthFactorDateTime > DATEADD(month,-9,cast(getdate() as date)) 

----------------------------------------------------------------
--"Assigned to me" -pull in name of provider most recently completing one of these HFs and the date completed:
	--PROACTIVE OUTREACH ATTEMPTED
	--PROACTIVE PT INELIGIBLE
	--PROACTIVE OUTREACH ATTEMPTED (PN)

	DROP TABLE IF EXISTS #HF_staff
	SELECT MVIPersonSID
		,HF_staffsid
		,HF_staff
		,HF_staff_datetime
		,row_number() over (PARTITION BY MVIPersonSID ORDER BY HF_staff_datetime) AS ProviderCount
	INTO #HF_staff
	FROM (
		 SELECT	MVIPersonSID
		 ,StaffSID as HF_staffsid
		,StaffName as HF_staff
		,HealthFactorDateTime as HF_staff_datetime
		,row_number() over (PARTITION BY MVIPersonSID, StaffName ORDER BY HealthFactorDateTime) AS RN
		FROM #HF_current 
		WHERE (HealthFactorType like 'PROACTIVE OUTREACH ATTEMPTED%' or HealthFactorType='PROACTIVE PT INELIGIBLE' or HealthFactorType like 'PROACTIVE CASE CLOSED%')
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #HF_staff2
	SELECT a.MVIPersonSID
		,a.HF_staffsid as HF_staffsid1
		,a.HF_staff as HF_staff1
		,a.HF_staff_datetime HF_staff_datetime1
		,b.HF_staffsid as HF_staffsid2
		,b.HF_staff as HF_staff2
		,b.HF_staff_datetime HF_staff_datetime2
	INTO #HF_staff2
	FROM (SELECT * FROM #HF_staff WHERE ProviderCount=1) a
	LEFT JOIN (SELECT * FROM #HF_staff WHERE ProviderCount=2) b on a.MVIPersonSID=b.MVIPersonSID
		
----------------------------------------------------------------
--Intake Attempts: Pulls in any records of intake attempts and corresponding date/time (each person is allowed 3 attempts so just grab 3 most recent)
	--PROACTIVE ABLE TO REACH
	--PROACTIVE UNABLE TO REACH
	--PROACTIVE CASE CLOSED UNREACHABLE
	--PROACTIVE PT INELIGIBLE

	--dedupe where there are multiple qualifying intake HFs on the same call - prioritize case closed first
	DROP TABLE IF EXISTS #HF_intakeattempts_dedupe
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
	INTO #HF_intakeattempts_dedupe
	FROM (
			SELECT MVIPersonSID
				,HealthFactorDateTime
				,HealthFactorType
				,row_number() over (PARTITION BY MVIPersonSID, HealthFactorDateTime ORDER BY (case when HealthFactorType='PROACTIVE CASE CLOSED UNREACHABLE' then 4
																								   when HealthFactorType='PROACTIVE PT INELIGIBLE' then 3
																								   when HealthFactorType='PROACTIVE UNABLE TO REACH' then 2
																								   when HealthFactorType='PROACTIVE ABLE TO REACH' then 1 end)) as RN
			FROM #HF_current 
			WHERE HealthFactorType IN ('PROACTIVE ABLE TO REACH','PROACTIVE UNABLE TO REACH','PROACTIVE CASE CLOSED UNREACHABLE','PROACTIVE PT INELIGIBLE')
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #HF_intakeattempts
	SELECT MVIPersonSID
		,HealthFactorType
		,HealthFactorDateTime
		,row_number() over (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime) AS orderby --order them earliest to latest 
	INTO #HF_intakeattempts
	FROM 
		(SELECT MVIPersonSID
		,HealthFactorType
		,HealthFactorDateTime
		,row_number() over (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime desc) AS RN --grab most recent
		FROM #HF_intakeattempts_dedupe
		) a
	WHERE RN < 4 --retain 3 most recent attempts if there happen to be more than 3

	DROP TABLE IF EXISTS #HF_intakeattempt1
	SELECT MVIPersonSID
		,HealthFactorType as HF_IntakeAttempt1
		,HealthFactorDateTime as HF_IntakeAttempt1_date
	INTO #HF_intakeattempt1
	FROM  #HF_intakeattempts
	WHERE orderby=1

	DROP TABLE IF EXISTS #HF_intakeattempt2
	SELECT MVIPersonSID
		,HealthFactorType as HF_IntakeAttempt2
		,HealthFactorDateTime as HF_IntakeAttempt2_date
	INTO #HF_intakeattempt2
	FROM  #HF_intakeattempts
	WHERE orderby=2

	DROP TABLE IF EXISTS #HF_intakeattempt3
	SELECT MVIPersonSID
		,HealthFactorType as HF_IntakeAttempt3
		,HealthFactorDateTime as HF_IntakeAttempt3_date
	INTO #HF_intakeattempt3
	FROM  #HF_intakeattempts
	WHERE orderby=3

----------------------------------------------------------------
--Follow-up Outreach Attempts: Pulls in any records of follow-up attempts and corresponding date/time
	--PROACTIVE ABLE TO REACH (PN)
	--PROACTIVE UNABLE TO REACH (PN)
	--PROACTIVE CASE CLOSED UNREACHABLE (PN)

	--dedupe where there are multiple qualifying follow-up HFs on the same call - prioritize case closed first
	DROP TABLE IF EXISTS #HF_followupattempts_dedupe
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
	INTO #HF_followupattempts_dedupe
	FROM (
			SELECT MVIPersonSID
				,HealthFactorDateTime
				,HealthFactorType
				,row_number() over (PARTITION BY MVIPersonSID, HealthFactorDateTime ORDER BY (case when HealthFactorType='PROACTIVE CASE CLOSED UNREACHABLE (PN)' then 3
																								   when HealthFactorType='PROACTIVE UNABLE TO REACH (PN)' then 2
																								   when HealthFactorType='PROACTIVE ABLE TO REACH (PN)' then 1 end)) as RN
			FROM #HF_current 
			WHERE HealthFactorType IN ('PROACTIVE ABLE TO REACH (PN)','PROACTIVE UNABLE TO REACH (PN)','PROACTIVE CASE CLOSED UNREACHABLE (PN)')
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #HF_followupattempts
	SELECT MVIPersonSID
		,HealthFactorType
		,HealthFactorDateTime
		,row_number() over (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime) AS orderby --order them earliest to latest 
	INTO #HF_followupattempts
	FROM 
		(SELECT MVIPersonSID
		,HealthFactorType
		,HealthFactorDateTime
		,row_number() over (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime desc) AS RN --grab most recent
		FROM #HF_followupattempts_dedupe
		) a
	WHERE RN < 4 --retain 3 most recent attempts if there happen to be more than 3

	DROP TABLE IF EXISTS #HF_followupattempt1
	SELECT MVIPersonSID
		,HealthFactorType as HF_FollowUpAttempt1
		,HealthFactorDateTime as HF_FollowUpAttempt1_date
	INTO #HF_followupattempt1
	FROM  #HF_followupattempts
	WHERE orderby=1

	DROP TABLE IF EXISTS #HF_followupattempt2
	SELECT MVIPersonSID
		,HealthFactorType as HF_FollowUpAttempt2
		,HealthFactorDateTime as HF_FollowUpAttempt2_date
	INTO #HF_followupattempt2
	FROM  #HF_followupattempts
	WHERE orderby=2

	DROP TABLE IF EXISTS #HF_followupattempt3
	SELECT MVIPersonSID
		,HealthFactorType as HF_FollowUpAttempt3
		,HealthFactorDateTime as HF_FollowUpAttempt3_date
	INTO #HF_followupattempt3
	FROM  #HF_followupattempts
	WHERE orderby=3


---------------------------------------------------------------- 
--Case Closed: Patient is considered "case closed" based on most recent completion of any of the following HFs OR if last recorded HF was more than 6 months ago
--Pull most recent, regardless of whether it was more than 9 months ago, in order to display for "Last Completed Outreach"
--Will need to eventually factor in DTAs here as well
	--PROACTIVE PLANS NOT INTERESTED
	--PROACTIVE PT INELIGIBLE
	--PROACTIVE PT DECLINES
	--PROACTIVE CASE CLOSED UNREACHABLE
	--PROACTIVE CASE CLOSED UNREACHABLE (PN)
	--PROACTIVE CARE NOT INTERESTED (PN)
	--PROACTIVE CARE NEEDS YES (PN)
	--PROACTIVE CARE NEEDS NO (PN)

	DROP TABLE IF EXISTS #HF_caseclosed
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,StaffName
		,HF_CaseClosed='Yes'
	INTO #HF_caseclosed
	FROM #HF
	WHERE HealthFactorType in ('PROACTIVE PLANS NOT INTERESTED','PROACTIVE PT INELIGIBLE', 'PROACTIVE PT DECLINES', 
								'PROACTIVE CASE CLOSED UNREACHABLE', 'PROACTIVE CASE CLOSED UNREACHABLE (PN)','PROACTIVE CARE NOT INTERESTED (PN)',
								'PROACTIVE CARE NEEDS YES (PN)','PROACTIVE CARE NEEDS NO (PN)')
										
	--grab their most recent HF datetime - retain Case Closed status from that 
	DROP TABLE IF EXISTS #HF_caseclosed2
	SELECT *
	INTO #HF_caseclosed2
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) AS RN
			FROM #HF_caseclosed
		) a
	WHERE RN=1

	--now grab max HF datetime for all patients - if more than 6 months old, automatically set HF_CaseClosed='Yes'
	DROP TABLE IF EXISTS #HF_caseclosed_6mo
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,StaffName
		,HF_CaseClosed='Yes'
	INTO #HF_caseclosed_6mo
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) AS RN
			FROM #HF
		) a
	WHERE a.RN=1 and a.HealthFactorDateTime < DATEADD(month,-6,cast(getdate() as date))

	--Union the two together
	DROP TABLE IF EXISTS #HF_caseclosed2b
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,StaffName
		,HF_CaseClosed
	INTO #HF_caseclosed2b
	FROM #HF_caseclosed_6mo
	WHERE MVIPersonSID not in (select distinct MVIPersonSID from #HF_caseclosed2)
	UNION
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,StaffName
		,HF_CaseClosed
	FROM #HF_caseclosed2

 ---------------------------------------------------------------- 
 -- Reopened cases: If patient's most recent positive tobacco screen falls 9 months or more after case closed='Yes', set back to 'No' so that they can get additional outreach 
	DROP TABLE IF EXISTS #HF_caseclosed3
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType as HF_CaseClosed_HealthFactorType
		,StaffName
		,CASE WHEN HF_CaseClosed='Yes' and DATEADD(MONTH,9,HealthFactorDateTime) < PosScreenDate THEN 1 else 0 end as CaseReopened
		,CASE WHEN HF_CaseClosed='Yes' and DATEADD(MONTH,9,HealthFactorDateTime) < PosScreenDate THEN 'No' ELSE HF_CaseClosed END AS HF_CaseClosed
	INTO #HF_caseclosed3
	FROM ( SELECT a.*, b.HealthFactorDateTime as PosScreenDate
		   FROM #HF_caseclosed2b a
		   LEFT JOIN #PosScreen_Recent b on a.MVIPersonSID=b.MVIPersonSID
		 ) a

	DROP TABLE IF EXISTS #HF_caseclosed4
	SELECT MVIPersonSID
		,HealthFactorDateTime as HF_CaseClosed_MostRecentDateTime
		,CASE WHEN HF_CaseClosed_HealthFactorType='PROACTIVE CARE NEEDS NO (PN)' then 'Successful Outreach, Care Needs: No'
			  WHEN HF_CaseClosed_HealthFactorType='PROACTIVE CARE NEEDS YES (PN)' then 'Successful Outreach, Care Needs: Yes'
			  WHEN HF_CaseClosed_HealthFactorType='PROACTIVE CARE NOT INTERESTED (PN)' or HF_CaseClosed_HealthFactorType='PROACTIVE PLANS NOT INTERESTED' then 'Patient Not Interested'
			  WHEN HF_CaseClosed_HealthFactorType like 'PROACTIVE CASE CLOSED UNREACHABLE%' then 'Patient Unreachable'
			  WHEN HF_CaseClosed_HealthFactorType='PROACTIVE PT DECLINES' then 'Patient Declined'
			  WHEN HF_CaseClosed_HealthFactorType='PROACTIVE PT INELIGIBLE' then 'Patient Ineligible'
			  ELSE 'No Case Closed HF recorded'
			  END AS HF_CaseClosed_HealthFactorType
		,StaffName as HF_CaseClosedStaff
		,CaseReopened
		,HF_CaseClosed
	INTO #HF_caseclosed4
	FROM #HF_caseclosed3

---------------------------------------------------------------- 
--Outcome from last outreach - Declined, Ineligible, Unable to reach, Completed (treatment referral yes/no)
	DROP TABLE IF EXISTS #HF_caseclosed_outcome
	SELECT MVIPersonSID
		,max(HF_RecentCase_Declined) as HF_RecentCase_Declined
		,max(HF_RecentCase_Ineligible) as HF_RecentCase_Ineligible
		,max(HF_RecentCase_Unreachable) as HF_RecentCase_Unreachable
		,max(HF_RecentCase_AbleToReach) as HF_RecentCase_AbleToReach
		,max(HF_RecentCase_TreatmentReferral) as HF_RecentCase_TreatmentReferral
	INTO #HF_caseclosed_outcome
	FROM (
			SELECT a.MVIPersonSID
				,case when b.HealthFactorType like '%DECLINE%' then 1 else 0 end as HF_RecentCase_Declined
				,case when b.HealthFactorType like '%INELIGIBLE%' then 1 else 0 end as HF_RecentCase_Ineligible
				,case when b.HealthFactorType like '%UNREACHABLE%' or b.HealthFactorType like 'PROACTIVE UNABLE TO REACH%' then 1 else 0 end as HF_RecentCase_Unreachable
				,case when b.HealthFactorType like 'PROACTIVE ABLE TO REACH%' then 1 else 0 end as HF_RecentCase_AbleToReach
				,case when b.HealthFactorType like 'PROACTIVE PLANS%' and b.HealthFactorType <> 'PROACTIVE PLANS NOT INTERESTED' then 1 else 0 end as HF_RecentCase_TreatmentReferral
			FROM #HF_caseclosed4 a
			INNER JOIN #HF b on a.MVIPersonSID=b.MVIPersonSID
			WHERE DATEDIFF(day,b.HealthFactorDateTime,a.HF_CaseClosed_MostRecentDateTime) >=0
				and DATEDIFF(day,b.HealthFactorDateTime,a.HF_CaseClosed_MostRecentDateTime) < 90
		) a
	GROUP BY MVIPersonSID

	DROP TABLE IF EXISTS #HF_caseclosed_outcome2
	SELECT MVIPersonSID
		,case when HF_RecentCase_Declined=1 then 'Patient declined'
		      when HF_RecentCase_Ineligible=1 then 'Ineligible'
		      when HF_RecentCase_TreatmentReferral=1 then 'Completed, patient received treatment referral'
			  when HF_RecentCase_AbleToReach=1 and HF_RecentCase_TreatmentReferral=0 then 'Completed, patient did not receive treatment referral'
			  when HF_RecentCase_Unreachable=1 and HF_RecentCase_AbleToReach=0 then 'Unable to reach'
			  end as HF_RecentCase_Outcome
	INTO #HF_caseclosed_outcome2
	FROM #HF_caseclosed_outcome

	DROP TABLE IF EXISTS #HF_caseclosed5
	SELECT a.*
		,b.HF_RecentCase_Outcome
	INTO #HF_caseclosed5
	FROM #HF_caseclosed4 a
	LEFT JOIN #HF_caseclosed_outcome2 b on a.MVIPersonSID=b.MVIPersonSID

----------------------------------------------------------------
--Days since last call and next call needed
	DROP TABLE IF EXISTS #DaysSinceOutreach
	SELECT *
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY OutreachDate DESC) AS RN
	INTO #DaysSinceOutreach
	FROM (
			SELECT MVIPersonSID
					,HF_IntakeAttempt1_date as OutreachDate
					,OutreachAttemptNumber='Intake Attempt 1'
			FROM #HF_intakeattempt1
			UNION
			SELECT MVIPersonSID
					,HF_IntakeAttempt2_date as OutreachDate
					,OutreachAttemptNumber='Intake Attempt 2'
			FROM #HF_intakeattempt2
			UNION
			SELECT MVIPersonSID
					,HF_IntakeAttempt3_date as OutreachDate
					,OutreachAttemptNumber='Intake Attempt 3'
			FROM #HF_intakeattempt3
			UNION
			SELECT MVIPersonSID
					,HF_FollowUpAttempt1_date as OutreachDate
					,OutreachAttemptNumber='Follow Up Attempt 1'
			FROM #HF_followupattempt1
			UNION
			SELECT MVIPersonSID
					,HF_FollowUpAttempt2_date as OutreachDate
					,OutreachAttemptNumber='Follow Up Attempt 2'
			FROM #HF_followupattempt2
			UNION
			SELECT MVIPersonSID
					,HF_FollowUpAttempt3_date as OutreachDate
					,OutreachAttemptNumber='Follow Up Attempt 3'
			FROM #HF_followupattempt3
		) a

	DROP TABLE IF EXISTS #DaysSinceOutreach2
	SELECT a.MVIPersonSID
			,a.OutreachDate
			,a.OutreachAttemptNumber
			,b.HF_CaseClosed
	INTO #DaysSinceOutreach2
	FROM #DaysSinceOutreach a
	LEFT JOIN #HF_caseclosed5 b on a.MVIPersonSID=b.MVIPersonSID
	WHERE RN=1

	DROP TABLE IF EXISTS #DaysSinceOutreach3
	SELECT MVIPersonSID
			,OutreachDate
			,CASE WHEN HF_CaseClosed='Yes' THEN NULL ELSE DATEDIFF(day,OutreachDate,getdate()) END AS DaysSinceLastCall
	INTO #DaysSinceOutreach3
	FROM #DaysSinceOutreach2

----------------------------------------------------------------
--Combine all outreach data into staging table and create 'Case Status' and 'Outreach Needed' variables to use for filter (Intake needed, Follow-up needed, None)
	DROP TABLE IF EXISTS  #Stage_Outreach
	SELECT a.*
		  ,ISNULL(hf2.HF_staffsid1,-9) as HF_staffsid1
		  ,ISNULL(hf2.HF_staff1,'*Unassigned') as HF_staff1
		  ,hf2.HF_staff_datetime1
		  ,HF_staffsid2
		  ,HF_staff2
		  ,hf2.HF_staff_datetime2
		  --,ISNULL(hf3.HF_IntakeNeeded,'No') as HF_IntakeNeeded
		  ,hf4.HF_IntakeAttempt1
		  ,hf4.HF_IntakeAttempt1_date
		  ,hf5.HF_IntakeAttempt2
		  ,hf5.HF_IntakeAttempt2_date
		  ,hf6.HF_IntakeAttempt3
		  ,hf6.HF_IntakeAttempt3_date
		  --,ISNULL(hf7.HF_FollowUpNeeded,'No') as HF_FollowUpNeeded
		  ,hf8.HF_FollowUpAttempt1
		  ,hf8.HF_FollowUpAttempt1_date
		  ,hf9.HF_FollowUpAttempt2
		  ,hf9.HF_FollowUpAttempt2_date
		  ,hf10.HF_FollowUpAttempt3
		  ,hf10.HF_FollowUpAttempt3_date
		  ,ISNULL(hf11.HF_CaseClosed,'No') as HF_CaseClosed
		  ,hf11.HF_CaseClosed_MostRecentDateTime
		  ,hf11.HF_CaseClosed_HealthFactorType
		  ,hf11.CaseReopened
		  ,hf11.HF_CaseClosedStaff
		  ,hf11.HF_RecentCase_Outcome
		  ,case when hf11.HF_CaseClosed='Yes' then 4 --'Closed'
				when (hf11.HF_CaseClosed='No' or hf11.HF_CaseClosed is null) and hf11.CaseReopened=1 then 3 --'Open: Reopened due to new positive screen'
				when (hf11.HF_CaseClosed='No' or hf11.HF_CaseClosed is null) and (hf4.HF_IntakeAttempt1 is not null or hf8.HF_FollowUpAttempt1 is not null) then 2 --'Open: Active outreach'
				else 1 --'Open: Inactive (no previous outreach attempt)' 
				end as CaseStatus
		  ,dso.DaysSinceLastCall
		  --,outr.OutreachNeeded
	INTO #Stage_Outreach
	FROM #Cohort a
	--LEFT JOIN #HF_mailing hf1 on a.MVIPersonSID=hf1.MVIPersonSID
	LEFT JOIN #HF_staff2 hf2 on a.MVIPersonSID=hf2.MVIPersonSID
	LEFT JOIN #HF_intakeattempt1 hf4 on a.MVIPersonSID=hf4.MVIPersonSID
	LEFT JOIN #HF_intakeattempt2 hf5 on a.MVIPersonSID=hf5.MVIPersonSID
	LEFT JOIN #HF_intakeattempt3 hf6 on a.MVIPersonSID=hf6.MVIPersonSID
	LEFT JOIN #HF_followupattempt1 hf8 on a.MVIPersonSID=hf8.MVIPersonSID
	LEFT JOIN #HF_followupattempt2 hf9 on a.MVIPersonSID=hf9.MVIPersonSID
	LEFT JOIN #HF_followupattempt3 hf10 on a.MVIPersonSID=hf10.MVIPersonSID
	LEFT JOIN #HF_caseclosed5 hf11 on a.MVIPersonSID=hf11.MVIPersonSID
	LEFT JOIN #DaysSinceOutreach3 dso on a.MVIPersonSID=dso.MVIPersonSID

--Pull all HFs from most recent outreach for patients with active outreach according to Case Status variable (categories 2 or 3) to determine whether they need intake or follow-up outreach
	DROP TABLE IF EXISTS #HF_current_mostrecent
	SELECT MVIPersonSID
		,max(HealthFactorDateTime) as HealthFactorDateTime
	INTO #HF_current_mostrecent
	FROM #HF_current
	GROUP BY MVIPersonSID

	DROP TABLE IF EXISTS #HF_current_mostrecent2
	SELECT a.*
	INTO #HF_current_mostrecent2
	FROM #HF_current a
	INNER JOIN #HF_current_mostrecent b on a.MVIPersonSID=b.MVIPersonSID and a.HealthFactorDateTime=b.HealthFactorDateTime

	DROP TABLE IF EXISTS #OutreachNeeded
	SELECT a.MVIPersonSID
		,HealthFactorDateTime
		,b.HealthFactorType
		,CASE WHEN b.HealthFactorType in ('PROACTIVE PT INELIGIBLE','PROACTIVE PT DECLINES','PROACTIVE CASE CLOSED UNREACHABLE','PROACTIVE CHANGE YES','PROACTIVE CHANGE NO','PROACTIVE PLANS NOT INTERESTED') THEN 'No'
				  WHEN b.HealthFactorType='PROACTIVE UNABLE TO REACH' and b.HealthFactorDateTime > DATEADD(day,-1,cast(getdate() as date)) THEN 'No'
				  WHEN b.HealthFactorType like '%(PN)%' then 'No'
				  ELSE 'Yes'
				  END AS HF_IntakeNeeded
			,CASE WHEN HealthFactorType in ('PROACTIVE PT INELIGIBLE','PROACTIVE PT DECLINES','PROACTIVE PLANS NOT INTERESTED','PROACTIVE CASE CLOSED UNREACHABLE','PROACTIVE CASE CLOSED UNREACHABLE										(PN)','PROACTIVE CARE NOT INTERESTED (PN)',
										'PROACTIVE CARE NEEDS YES (PN)','PROACTIVE CARE NEEDS NO (PN)') THEN 'No'
				  WHEN HealthFactorType in ('PROACTIVE CHANGE YES','PROACTIVE CHANGE NO') and HealthFactorDateTime < DATEADD(day,-14,cast(getdate() as date)) THEN 'Yes'
				  WHEN HealthFactorType='PROACTIVE UNABLE TO REACH (PN)' and b.HealthFactorDateTime < DATEADD(day,-1,cast(getdate() as date)) THEN 'Yes'
				  --ELSE 'No'
				  END AS HF_FollowUpNeeded
	INTO #OutreachNeeded
	FROM #Stage_Outreach a
	LEFT JOIN #HF_current_mostrecent2 b on a.MVIPersonSID=b.MVIPersonSID
	WHERE CaseStatus in (2,3)

	--prioritize no over yes for each outreach
	DROP TABLE IF EXISTS #OutreachNeeded2
	SELECT MVIPersonSID
		,HealthFactorDateTime
		,ISNULL(min(HF_IntakeNeeded),'No') as HF_IntakeNeeded
		,ISNULL(min(HF_FollowUpNeeded),'No') as HF_FollowUpNeeded
	INTO #OutreachNeeded2
	FROM #OutreachNeeded
	GROUP BY MVIPersonSID
		,HealthFactorDateTime

--Create 'Outreach Needed' variable to use for filter
	DROP TABLE IF EXISTS #Stage_Outreach2
	SELECT a.*
		,b.HF_IntakeNeeded
		,b.HF_FollowUpNeeded
		,case when b.HF_IntakeNeeded='Yes' or a.CaseStatus=1 then 1 --'Yes: Intake Outreach Needed'
			  when b.HF_FollowUpNeeded='Yes' then 2 --'Yes: Followup Outreach Needed'
			  else 3 --'No'
			  end as OutreachNeeded
	INTO #Stage_Outreach2
	FROM #Stage_Outreach a
	LEFT JOIN #OutreachNeeded2 b on a.MVIPersonSID=b.MVIPersonSID


----------------------------------------------------------------
--Create indicator of whether Veteran uses ENDS (electronic nicotine delivery system, aka vapes) or other types of tobacco
----------------------------------------------------------------
	DROP TABLE IF EXISTS #ENDS
	SELECT MVIPersonSID	
			,ENDS_HealthFactorType
	INTO #ENDS
	FROM (
			SELECT a.MVIPersonSID
				,b.HealthFactorType as ENDS_HealthFactorType
				,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY b.HealthFactorDateTime DESC) AS RN
			FROM #Cohort a
			INNER JOIN [SUD].[TobaccoScreens] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
			WHERE b.HealthFactorType in ('VA-TOBACCO USE EVERY DAY ENDS','VA-TOBACCO USE EVERY DAY OTHER PRODUCT','VA-TOBACCO USE SOME DAYS ENDS','VA-TOBACCO USE SOME DAYS OTHER PRODUCT')
				AND b.HealthFactorDateTime > DATEADD(month,-9,cast(getdate() as date))
		) a
	WHERE RN=1

----------------------------------------------------------------
--Tobacco pharmacotherapy in past year
--BUPROPION Include: SR 150mg, IR 75mg, XL 150mg or 300mg 
----------------------------------------------------------------
	DROP TABLE IF EXISTS #Pharm
	SELECT b.*
	INTO #Pharm
	FROM #Cohort a
	INNER JOIN [Present].[Medications] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE (DrugNameWithoutDose like '%BUPROPION%' --and StrengthNumeric in (75,100,150))
			or DrugNameWithoutDose like '%NICOTINE%' 
			or DrugNameWithoutDose like '%VARENICLINE%')
		  AND LastReleaseDateTime is not null

	DROP TABLE IF EXISTS #Pharm_Bup
	SELECT MVIPersonSID
			,LastReleaseDateTime as Bup_ReleaseDate
			,DrugNameWithDose as Bup_DrugName
			,RxStatus as Bup_RxStatus
			,ChecklistID as Bup_ChecklistID
	INTO #Pharm_Bup
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%BUPROPION%'
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #Pharm_NicotinePatch
	SELECT MVIPersonSID
			,LastReleaseDateTime as NicotinePatch_ReleaseDate
			,DrugNameWithDose as NicotinePatch_DrugName
			,RxStatus as NicotinePatch_RxStatus
			,ChecklistID as NicotinePatch_ChecklistID
	INTO #Pharm_NicotinePatch
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%NICOTINE%' and DrugNameWithDose like '%PATCH%'
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #Pharm_NicotineGum
	SELECT MVIPersonSID
			,LastReleaseDateTime as NicotineGum_ReleaseDate
			,DrugNameWithDose as NicotineGum_DrugName
			,RxStatus as NicotineGum_RxStatus
			,ChecklistID as NicotineGum_ChecklistID
	INTO #Pharm_NicotineGum
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%NICOTINE%' and DrugNameWithDose like '%GUM%'
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #Pharm_NicotineLozenge
	SELECT MVIPersonSID
			,LastReleaseDateTime as NicotineLozenge_ReleaseDate
			,DrugNameWithDose as NicotineLozenge_DrugName
			,RxStatus as NicotineLozenge_RxStatus
			,ChecklistID as NicotineLozenge_ChecklistID
	INTO #Pharm_NicotineLozenge
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%NICOTINE%' and DrugNameWithDose like '%LOZENGE%'
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #Pharm_NicotineSpray
	SELECT MVIPersonSID
			,LastReleaseDateTime as NicotineSpray_ReleaseDate
			,DrugNameWithDose as NicotineSpray_DrugName
			,RxStatus as NicotineSpray_RxStatus
			,ChecklistID as NicotineSpray_ChecklistID
	INTO #Pharm_NicotineSpray
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%NICOTINE%' and (DrugNameWithDose like '%ORAL%' or DrugNameWithDose like '%NASAL%')
		) a
	WHERE RN=1

	DROP TABLE IF EXISTS #Pharm_Varenicline
	SELECT MVIPersonSID
			,LastReleaseDateTime as Varenicline_ReleaseDate
			,DrugNameWithDose as Varenicline_DrugName
			,RxStatus as Varenicline_RxStatus
			,ChecklistID as Varenicline_ChecklistID
	INTO #Pharm_Varenicline
	FROM (
			SELECT *
					,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY LastReleaseDateTime DESC) AS RN
			FROM #Pharm
			WHERE DrugNameWithoutDose like '%VARENICLINE%'
		) a
	WHERE RN=1
	
--Add column for sorting
	DROP TABLE IF EXISTS #Pharm_Sorting
	SELECT MVIPersonSID
			,MAX(LastReleaseDateTime) as MostRecentTxDate_sorting
	INTO #Pharm_Sorting
	FROM #Pharm
	GROUP BY MVIPersonSID



----------------------------------------------------------------
--Diagnoses in past year
----------------------------------------------------------------
	DROP TABLE IF EXISTS #Diagnosis
	SELECT DISTINCT a.MVIPersonSID
		,c.Category
		,case when c.PrintName like '%suicide%' then 'Suicide Attempt or Ideation'
			  when c.PrintName like '%Bipolar%' then 'Bipolar Disorder'
			  when c.PrintName like '%Depression%' then 'Depression'
			  when c.PrintName like '%Psychosis%' then 'Psychosis'
			  when c.PrintName like '%Alcohol%' then 'Alcohol Use Disorder'
			  when c.PrintName like '%Amphetamine%' then 'Amphetamine Use Disorder'
			  when c.PrintName like '%Cannabis%' then 'Cannabis Use Disorder'
			  when c.PrintName like '%Cocaine%' then 'Cocaine Use Disorder' 
			  when c.PrintName like '%Nicotine%' then 'Nicotine Use Disorder'
			  when c.PrintName like '%Opioid%' then 'Opioid Use Disorder' 
			  when c.PrintName like '%Sedative%' then 'Sedative Use Disorder' 
			  when c.PrintName like '%Other SUD%' then 'Other SUD Dx'
			  else c.PrintName
			  end as PrintName
	INTO #Diagnosis
	FROM #Cohort a
	INNER JOIN [Present].[Diagnosis] b WITH (NOLOCK) 
		ON a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK)
		ON b.DxCategory = c.ColumnName
	WHERE c.TableName = 'ICD10' 
			AND (b.Outpat=1 or b.Inpat=1) 
			AND c.Category in ('Mental Health','Substance Use Disorder')
			AND PrintName not in ('Other Mental Health per STORM paper','Any MH diagnosis','Binge Eating Disorder','MHSUDdx_poss','Drug abuse','Substance Use Disorder','Serious Mental Illness','Other MH Disorder','Other MH Disorders')

	--select distinct category,printname
	--from #Diagnosis
	--order by category,printname

	--DROP TABLE IF EXISTS #Diagnoses2
	--SELECT MVIPersonSID	
	--	,case when PrintName='Anxiety Disorder' then 1 end as Anxiety
	--	,case when PrintName like '%suicide%' then 1 end as SuicideAttempt
	--	,case when PrintName like '%Bipolar%' then 1 end as Bipolar
	--	,case when PrintName like '%Depression%' then 1 end as Depression
	--	,
	--FROM #Diagnoses

	DROP TABLE IF EXISTS #MH_Diagnosis
	SELECT MVIPersonSID	
		,string_agg(PrintName,'<br>') as MH_Diagnosis --read as html code in SSRS
	INTO #MH_Diagnosis
	FROM #Diagnosis
	WHERE Category='Mental Health'
	GROUP BY MVIPersonSID	

	DROP TABLE IF EXISTS #SUD_Diagnosis
	SELECT MVIPersonSID	
		,string_agg(PrintName,'<br>') as SUD_Diagnosis --read as html code in SSRS
	INTO #SUD_Diagnosis
	FROM #Diagnosis
	WHERE Category='Substance Use Disorder'
	GROUP BY MVIPersonSID	

----------------------------------------------------------------
--HRF - past year
----------------------------------------------------------------
   DROP TABLE IF EXISTS #hrf
   SELECT a.MVIPersonSID 
		 ,MostRecentActivation as PatRecFlag_Date
		 ,ActionTypeDescription as PatRecFlag_Status
   INTO #hrf 
   FROM [PRF_HRS].[ActivePRF] a WITH(NOLOCK) --this table contains most recent HRF status for patients in past year
   INNER JOIN #Cohort b on a.MVIPersonSID=b.MVIPersonSID


----------------------------------------------------------------
--Assigned PCP and MHTC
----------------------------------------------------------------
	DROP TABLE IF EXISTS #PCP
	SELECT MVIPersonSID
			,PCP_Name
			,PCP_ChecklistID
			,PCP_Facility
	INTO #PCP
	FROM (
			SELECT a.MVIPersonSID
				,a.Homestation_ChecklistID
				,b.StaffName as PCP_Name
				,b.ChecklistID as PCP_ChecklistID
				,c.Facility as PCP_Facility
				,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY CASE WHEN a.Homestation_ChecklistID=b.ChecklistID THEN 1 ELSE 0 END DESC) AS RN
			FROM #Cohort a
			INNER JOIN [Present].[Provider_PCP] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
			INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
		  ) a
	WHERE RN=1

	DROP TABLE IF EXISTS #MHTC
	SELECT MVIPersonSID
			,MHTC_Name
			,MHTC_ChecklistID
			,MHTC_Facility
	INTO #MHTC
	FROM (
			SELECT a.MVIPersonSID
				,a.Homestation_ChecklistID
				,b.StaffName as MHTC_Name
				,b.ChecklistID as MHTC_ChecklistID
				,c.Facility as MHTC_Facility
				,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY CASE WHEN a.Homestation_ChecklistID=b.ChecklistID THEN 1 ELSE 0 END DESC) AS RN
			FROM #Cohort a
			INNER JOIN [Present].[Provider_MHTC] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
			INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
		  ) a
	WHERE RN=1


----------------------------------------------------------------
--Last PC and MH visit
----------------------------------------------------------------
	DROP TABLE IF EXISTS #PCRecentVisit
	SELECT a.MVIPersonSID
			,b.PrimaryStopCode as PCRecent_StopCode
			,b.PrimaryStopCodeName as PCRecent_StopCodeName
			,b.VisitDateTime as PCRecent_VisitDateTime
			,b.ChecklistID as PCRecent_ChecklistID
			,c.Facility as PCRecent_Facility
	INTO #PCRecentVisit
	FROM #Cohort a
	INNER JOIN [Present].[AppointmentsPast] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	WHERE b.ApptCategory in ('PCRecent') and b.MostRecent_ICN=1

	DROP TABLE IF EXISTS #MHRecentVisit
	SELECT a.MVIPersonSID
			,b.PrimaryStopCode as MHRecent_StopCode
			,b.PrimaryStopCodeName as MHRecent_StopCodeName
			,b.VisitDateTime as MHRecent_VisitDateTime
			,b.ChecklistID as MHRecent_ChecklistID
			,c.Facility as MHRecent_Facility
	INTO #MHRecentVisit
	FROM #Cohort a
	INNER JOIN [Present].[AppointmentsPast] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	WHERE b.ApptCategory in ('MHRecent') and b.MostRecent_ICN=1

--Add column for sorting
	DROP TABLE IF EXISTS #RecentEnc_Sorting
	SELECT MVIPersonSID
			,Max(VisitDateTime) as RecentEnc_Sorting
	INTO #RecentEnc_Sorting
	FROM (
			SELECT MVIPersonSID, PCRecent_VisitDateTime as VisitDateTime FROM #PCRecentVisit
			UNION
			SELECT MVIPersonSID, MHRecent_VisitDateTime as VisitDateTime FROM #MHRecentVisit
		) a
	GROUP BY MVIPersonSID

----------------------------------------------------------------
--Next scheduled PC and MH visit
----------------------------------------------------------------
	DROP TABLE IF EXISTS #PCNextAppt
	SELECT a.MVIPersonSID
			,b.PrimaryStopCode as PCAppt_StopCode
			,b.PrimaryStopCodeName as PCAppt_StopCodeName
			,b.AppointmentDateTime as PCAppt_VisitDateTime
			,b.ChecklistID as PCAppt_ChecklistID
			,c.Facility as PCAppt_Facility
	INTO #PCNextAppt
	FROM #Cohort a
	INNER JOIN [Present].[AppointmentsFuture] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	WHERE b.ApptCategory in ('PCFuture') and b.NextAppt_ICN=1

	DROP TABLE IF EXISTS #MHNextAppt
	SELECT a.MVIPersonSID
			,b.PrimaryStopCode as MHAppt_StopCode
			,b.PrimaryStopCodeName as MHAppt_StopCodeName
			,b.AppointmentDateTime as MHAppt_VisitDateTime
			,b.ChecklistID as MHAppt_ChecklistID
			,c.Facility as MHAppt_Facility
	INTO #MHNextAppt
	FROM #Cohort a
	INNER JOIN [Present].[AppointmentsFuture] b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
	WHERE b.ApptCategory in ('MHFuture') and b.NextAppt_ICN=1

	--Add column for sorting
	DROP TABLE IF EXISTS #NextAppt_Sorting
	SELECT MVIPersonSID
			,Max(VisitDateTime) as NextAppt_Sorting
	INTO #NextAppt_Sorting
	FROM (
			SELECT MVIPersonSID, PCAppt_VisitDateTime as VisitDateTime FROM #PCNextAppt
			UNION
			SELECT MVIPersonSID, MHAppt_VisitDateTime as VisitDateTime FROM #MHNextAppt
		) a
	GROUP BY MVIPersonSID


----------------------------------------------------------------
--Date of most recent tobacco counseling encounter (707/708 secondary stop codes)
----------------------------------------------------------------
	DROP TABLE IF EXISTS #Tobacco_counseling
	SELECT b.MVIPersonSID
			,a.VisitSID
			,cast(a.VisitDateTime as date) as VisitDate
			,d.StopCodeName 
	INTO #Tobacco_counseling
	FROM [Outpat].[Visit] a WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] b WITH (NOLOCK) on a.PatientSID=b.PatientPersonSID
	LEFT JOIN [LookUp].[StopCode] d WITH (NOLOCK) on a.SecondaryStopCodeSID=d.StopCodeSID
	WHERE a.WorkloadLogicFlag='Y'
		and a.VisitDateTime BETWEEN DATEADD(year,-1,cast(getdate() as date)) and cast(getdate() as date)
		and d.StopCode in ('707','708')
	UNION
	SELECT 
		 c.MVIPersonSID
		,c.EncounterSID
		,c.TZDerivedVisitDateTime
		,StopCodeName=NULL
	FROM [Cerner].[FactUtilizationStopCode] c WITH(NOLOCK)
	WHERE c.TZDerivedVisitDateTime BETWEEN DATEADD(year,-1,cast(getdate() as date)) and cast(getdate() as date)
	AND c.MVIPersonSID>0
	AND c.GenLedgerCompanyUnitAliasNumber in ('707','708')

	DROP TABLE IF EXISTS #Tobacco_counseling_recent
	SELECT MVIPersonSID	
			,Max(VisitDate) as TobaccoCounseling_VisitDateTime
	INTO #Tobacco_counseling_recent
	FROM #Tobacco_counseling
	GROUP BY MVIPersonSID

----------------------------------------------------------------
--Create staging table
----------------------------------------------------------------
	DROP TABLE IF EXISTS #Stage_SUD_TobaccoUD
	SELECT a.*
		  ,ISNULL(stg.HF_staffsid1,-9) as HF_staffsid1
		  ,ISNULL(stg.HF_staff1,'*Unassigned') as HF_staff1
		  ,stg.HF_staff_datetime1
		  ,stg.HF_staffsid2
		  ,stg.HF_staff2
		  ,stg.HF_staff_datetime2
		  ,ISNULL(stg.HF_IntakeNeeded,'No') as HF_IntakeNeeded
		  ,stg.HF_IntakeAttempt1
		  ,stg.HF_IntakeAttempt1_date
		  ,stg.HF_IntakeAttempt2
		  ,stg.HF_IntakeAttempt2_date
		  ,stg.HF_IntakeAttempt3
		  ,stg.HF_IntakeAttempt3_date
		  ,ISNULL(stg.HF_FollowUpNeeded,'No') as HF_FollowUpNeeded
		  ,stg.HF_FollowUpAttempt1
		  ,stg.HF_FollowUpAttempt1_date
		  ,stg.HF_FollowUpAttempt2
		  ,stg.HF_FollowUpAttempt2_date
		  ,stg.HF_FollowUpAttempt3
		  ,stg.HF_FollowUpAttempt3_date
		  ,ISNULL(stg.HF_CaseClosed,'No') as HF_CaseClosed
		  ,stg.HF_CaseClosed_MostRecentDateTime
		  ,stg.HF_CaseClosed_HealthFactorType
		  ,stg.CaseReopened
		  ,stg.HF_CaseClosedStaff
		  ,stg.HF_RecentCase_Outcome
		  ,stg.CaseStatus
		  ,stg.DaysSinceLastCall
		  ,stg.OutreachNeeded
		  ,ends.ENDS_HealthFactorType as ENDS_OtherProducts
		  ,bup.Bup_DrugName
		  ,bup.Bup_ReleaseDate
		  ,bup.Bup_RxStatus
		  ,bup.Bup_ChecklistID
		  ,ng.NicotineGum_DrugName
		  ,ng.NicotineGum_ReleaseDate
		  ,ng.NicotineGum_RxStatus
		  ,ng.NicotineGum_ChecklistID
		  ,np.NicotinePatch_DrugName
		  ,np.NicotinePatch_ReleaseDate
		  ,np.NicotinePatch_RxStatus
		  ,np.NicotinePatch_ChecklistID
		  ,nl.NicotineLozenge_DrugName
		  ,nl.NicotineLozenge_ReleaseDate
		  ,nl.NicotineLozenge_RxStatus
		  ,nl.NicotineLozenge_ChecklistID
		  ,ns.NicotineSpray_DrugName
		  ,ns.NicotineSpray_ReleaseDate
		  ,ns.NicotineSpray_RxStatus
		  ,ns.NicotineSpray_ChecklistID
		  ,var.Varenicline_DrugName
		  ,var.Varenicline_ReleaseDate
		  ,var.Varenicline_RxStatus
		  ,var.Varenicline_ChecklistID
		  ,sor.MostRecentTxDate_sorting
		  ,case when ng.NicotineGum_RxStatus in ('ACTIVE', 'Ordered')
					or np.NicotinePatch_RxStatus in ('ACTIVE', 'Ordered')
					or nl.NicotineLozenge_RxStatus in ('ACTIVE', 'Ordered')
					or ns.NicotineSpray_RxStatus in ('ACTIVE', 'Ordered')
					or var.Varenicline_RxStatus in ('ACTIVE', 'Ordered')
					or bup.Bup_RxStatus in ('ACTIVE', 'Ordered')
			then 1 else 0 end as ActiveTobaccoTx
			,case when (ng.NicotineGum_DrugName is null or ng.NicotineGum_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
					and (np.NicotinePatch_DrugName is null or np.NicotinePatch_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
					and (nl.NicotineLozenge_DrugName is null or nl.NicotineLozenge_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
					and (ns.NicotineSpray_DrugName is null or ns.NicotineSpray_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
					and (var.Varenicline_DrugName is null or var.Varenicline_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
					and (bup.Bup_DrugName is null or bup.Bup_ReleaseDate < DATEADD(day,-60,cast(getdate() as date)))
			then 0 else 1 end as AnyTobaccoTx_60days
		  ,b.PCP_Name
		  ,b.PCP_ChecklistID
		  ,b.PCP_Facility
		  ,c.MHTC_Name
		  ,c.MHTC_ChecklistID
		  ,c.MHTC_Facility
		  ,ISNULL(b.PCP_Name,c.MHTC_Name) as Provider_Sorting
		  ,d.PCRecent_VisitDateTime
		  ,d.PCRecent_StopCode
		  ,d.PCRecent_StopCodeName
		  ,d.PCRecent_ChecklistID
		  ,d.PCRecent_Facility
		  ,e.MHRecent_VisitDateTime
		  ,e.MHRecent_StopCode
		  ,e.MHRecent_StopCodeName
		  ,e.MHRecent_ChecklistID
		  ,e.MHRecent_Facility
		  ,rec.RecentEnc_Sorting
		  ,f.PCAppt_VisitDateTime
		  ,f.PCAppt_StopCode
		  ,f.PCAppt_StopCodeName
		  ,f.PCAppt_ChecklistID
		  ,f.PCAppt_Facility
		  ,g.MHAppt_VisitDateTime
		  ,g.MHAppt_StopCode
		  ,g.MHAppt_StopCodeName
		  ,g.MHAppt_ChecklistID
		  ,g.MHAppt_Facility
		  ,nex.NextAppt_Sorting
		  ,counsel.TobaccoCounseling_VisitDateTime
		  ,m.MH_Diagnosis
		  ,s.SUD_Diagnosis
		  ,h.PatRecFlag_Date as HRF_Date
		  ,h.PatRecFlag_Status as HRF_Status
	INTO #Stage_SUD_TobaccoUD
	FROM #Cohort a
	--LEFT JOIN #HF_mailing hf1 on a.MVIPersonSID=hf1.MVIPersonSID
	LEFT JOIN #Stage_Outreach2 stg on a.MVIPersonSID=stg.MVIPersonSID
	LEFT JOIN #Pharm_Bup bup on a.MVIPersonSID=bup.MVIPersonSID
	LEFT JOIN #Pharm_NicotineGum ng on a.MVIPersonSID=ng.MVIPersonSID
	LEFT JOIN #Pharm_NicotinePatch np on a.MVIPersonSID=np.MVIPersonSID
	LEFT JOIN #Pharm_NicotineLozenge nl on a.MVIPersonSID=nl.MVIPersonSID
	LEFT JOIN #Pharm_NicotineSpray ns on a.MVIPersonSID=ns.MVIPersonSID
	LEFT JOIN #Pharm_Varenicline var on a.MVIPersonSID=var.MVIPersonSID
	LEFT JOIN #Pharm_Sorting sor on a.MVIPersonSID=sor.MVIPersonSID
	LEFT JOIN #PCP b on a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN #MHTC c on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #PCRecentVisit d on a.MVIPersonSID=d.MVIPersonSID
	LEFT JOIN #MHRecentVisit e on a.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN #RecentEnc_Sorting rec on a.MVIPersonSID=rec.MVIPersonSID
	LEFT JOIN #PCNextAppt f on a.MVIPersonSID=f.MVIPersonSID
	LEFT JOIN #MHNextAppt g on a.MVIPersonSID=g.MVIPersonSID
	LEFT JOIN #NextAppt_Sorting nex on a.MVIPersonSID=nex.MVIPersonSID
	LEFT JOIN #MH_Diagnosis m on a.MVIPersonSID=m.MVIPersonSID
	LEFT JOIN #SUD_Diagnosis s on a.MVIPersonSID=s.MVIPersonSID
	LEFT JOIN #hrf h on a.MVIPersonSID=h.MVIPersonSID
	LEFT JOIN #ENDS ends on a.MVIPersonSID=ends.MVIPersonSID
	LEFT JOIN #Tobacco_counseling_recent counsel on a.MVIPersonSID=counsel.MVIPersonSID

EXEC [Maintenance].[PublishTable] 'SUD.TobaccoUD', '#Stage_SUD_TobaccoUD'


EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END