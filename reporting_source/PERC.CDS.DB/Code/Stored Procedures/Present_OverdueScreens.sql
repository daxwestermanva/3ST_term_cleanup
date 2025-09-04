-- ==========================================================================================
-- Authors:		Christina Wade
-- Create date: 
-- Description: Based on logic from [Code].[BHIP_PatientDetails]. Accounting for the following
--				screens and indicating due status of screen/survey:
--					-OverdueFlag = 1  means screen in non compliant (overdue/due now)
--					-OverdueFlag = 0  means screen is complaint (not overdue)
--					-OverdueFlag = -1 means patient excluded from screen requirement
--
--				1) Most Recent Suicide Screen
--				2) Most Recent AUDIT-C
--				3) Most Recent Depression Screen
--				4) Most Recent Homeless Screen
--				5) Most Recent Food Insecurity Screen
--				6) Most Recent MST Screen
--				7) Most Recent PTSD Screen
--				8) Most Recent Tobacco Screen
--
--				
-- Modifications:
-- 8/21/2024  - CW - Adding ChecklistID
-- 9/16/2024  - CW - Adding exclusionary criteria
-- 10/2/2024  - CW - Expanding logic to account for hospice criteria per XLA
-- 10/9/2024  - CW - Bug fix re: positive C-SSRS screen
-- 10/16/2024 - CW - Changing the starting cohort as result of timing issues. This 
--					 data source will now be used in [Code].[BHIP_PatientDetails] so 
--					 we cannot UNION [Present].[ActivePatient] and 
--					 [Common].[PBIReportsCohort] as the starting cohort.
--
--					 [Common].[PBIReportsCohort] is dependent on:
--							--Code.COMPACT				#: 1002
--							--Code.SUD_IVDU				#: 2010
--							--Code.SBOSR_SDVDetails_PBI	#: 2025
--							--Code.SUD_CaseFinderCohort	#: 3001
--							--Code.BHIP_PatientDetails	#: 3005 **
--					 
--					 Instead, we need to start with [Common].[MasterPatient] to 
--					 ensure all patient screens are pre-processed before downstream 
--					 codes can use the data. Without this change, we'll create a 
--					 circular dependency and/or insert additional data lags into the 
--					 BHIP.PatientDetails cohort as related to overdue screens.
-- 10/16/2024 - CW - Updating output so that when patients are excluded from screens we'll 
--					 be aware of the fact the exclusion happened (OverdueFlag = -1)
-- 10/21/2024 - CW - Changing data source for tobacco screen
-- 12/18/2024 - CW - Adding criteria for Next30DaysOverdueFlag
-- 1/7/2025   - CW - Fixing bug in PTSD method for Next30DaysOverdueFlag
-- ==========================================================================================
CREATE PROCEDURE [Code].[Present_OverdueScreens]
	
AS
BEGIN

	--Starting cohort
	DROP TABLE IF EXISTS #Cohort 
	SELECT DISTINCT a.MVIPersonSID
	INTO #Cohort
	FROM Common.MasterPatient a WITH (NOLOCK)
	WHERE TestPatient=0 AND DateOfDeath IS NULL;

-- =======================================================================================================
--  Screening Indicators: Suicide Screen, AUDIT-C, Depression, Homeless/Food Insecurity, MST, PTSD, Tobacco
-- =======================================================================================================

	------------------------------------------
	-- Suicide Screen
	------------------------------------------
	--Get suicide screens in last 5 years
	-- CSRE
	DROP TABLE IF EXISTS #CSRE 
	SELECT TOP (1) WITH TIES
		 MVIPersonSID
		,ChecklistID
		,CSRE_DateTime=ISNULL(EntryDateTime,VisitDateTime)
	INTO #CSRE
	FROM [OMHSP_Standard].[CSRE] WITH(NOLOCK) 
	WHERE (EvaluationType='New CSRE' or EvaluationType='Updated CSRE')
			and ISNULL(EntryDateTime,VisitDateTime) > dateadd(year,-5,cast(getdate() as date))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ISNULL(EntryDateTime,VisitDateTime) DESC);

	-- C-SSRS
	--for display_cssrs column, 1 is positive, 0 is negative, -99 is missing/unknown/skipped
	DROP TABLE IF EXISTS #cssrs 
	SELECT TOP (1) WITH TIES
		 MVIPersonSID
		,ChecklistID
		,CSSRS_Date=SurveyGivenDateTime
		,SurveyName
	INTO #cssrs
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] m WITH (NOLOCK) 
	WHERE display_CSSRS > -1
		AND Surveyname<>'PHQ9'
		AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date))
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY SurveyGivenDateTime DESC, display_CSSRS DESC);

	--Most Recent Suicide Screen (due annually)
	DROP TABLE IF EXISTS #SuicideScreen 
	SELECT TOP (1) WITH TIES *
	INTO #SuicideScreen
	FROM (	SELECT DISTINCT co.MVIPersonSID
				,ChecklistID=
					case when cast(CSSRS_Date as date) > cast(cr.CSRE_DateTime as date) 
						 or cast(CSSRS_Date as date) IS NOT NULL AND cast(cr.CSRE_DateTime as date) IS NULL then a.ChecklistID
						 when cast(cr.CSRE_DateTime as date) > cast(CSSRS_Date as date) 
						 or cast(cr.CSRE_DateTime as date) IS NOT NULL AND cast(a.CSSRS_Date as date) IS NULL then cr.ChecklistID
						 when cast(cr.CSRE_DateTime as date) = cast(a.CSSRS_Date as date) then cr.ChecklistID END
				,RiskFactor='Suicide'
				,EventDate=
					case when ((cast(CSSRS_Date as date) > cast(cr.CSRE_DateTime as date))
						 or (cast(CSSRS_Date as date) IS NOT NULL and cast(cr.CSRE_DateTime as date) IS NULL))
						 then cast(CSSRS_Date as date) 
						 else cast(cr.CSRE_DateTime as date) end
				,OverdueFlag=
					case when (cast(CSSRS_Date as date) < DATEADD(d,-366,GETDATE()) or CSSRS_Date is NULL) and 
							(cast(cr.CSRE_DateTime as date) < DATEADD(d,-366,GETDATE()) or cr.CSRE_DateTime is NULL) then 1 
						 else 0 end
				,Next30DaysOverdueFlag=0
			FROM #Cohort co
			LEFT JOIN #cssrs a on a.MVIPersonSID=co.MVIPersonSID 
			LEFT JOIN #CSRE cr on co.MVIPersonSID=cr.MVIPersonSID 
		 ) Src
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY EventDate DESC);

	UPDATE #SuicideScreen
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE())

	DROP TABLE IF EXISTS #CSRE
	DROP TABLE IF EXISTS #cssrs
	------------------------------------------
	-- AUDIT-C for alcohol use
	------------------------------------------
	--Get Audit-C screens in last 5 years
	DROP TABLE IF EXISTS #AUDIT_C;
	SELECT TOP (1) WITH TIES
		 MVIPersonSID
		,ChecklistID
		,CAST(SurveyGivenDatetime AS DATE) AS AUDITC_SurveyDate
	INTO #AUDIT_C
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (NOLOCK) 
	WHERE display_AUDC > -1
	AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date)) 
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SurveyGivenDatetime DESC);

	--Most recent AUDIT-C (due annually)
	DROP TABLE IF EXISTS #AuditC_Screen
	SELECT DISTINCT co.MVIPersonSID
		,ChecklistID
		,RiskFactor='AUDIT-C'
		,EventDate=AUDITC_SurveyDate
		,OverdueFlag=
			case when (cast(AUDITC_SurveyDate as date) < DATEADD(d,-366,GETDATE())) or (cast(AUDITC_SurveyDate as date) is null) then 1
			else 0 end
		,Next30DaysOverdueFlag=0
	INTO #AuditC_Screen
	FROM #Cohort co
	LEFT JOIN #AUDIT_C a on a.MVIPersonSID=co.MVIPersonSID;

	UPDATE #AuditC_Screen
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE())

	DROP TABLE IF EXISTS #AUDIT_C
	---------------------------------------------------------------
	--PHQ-2 or PHQ-9 for Depression
	---------------------------------------------------------------
	--Get depression screens in last 5 years
	DROP TABLE IF EXISTS #dep 
	SELECT TOP (1) WITH TIES
		 MVIPersonSID
		,ChecklistID
		,cast(surveygivendatetime as date) as DepScr_date
	INTO #Dep
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (NOLOCK)
	WHERE (display_phq2 in ('1','0') or display_PHQ9>=0)
		AND SurveyGivenDateTime >= DATEADD(YEAR,-5,CAST(GETDATE() as date))
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY SurveyGivenDateTime DESC);

	--Most recent Dep screen(due annually)
	DROP TABLE IF EXISTS #Depression 
	SELECT DISTINCT co.MVIPersonSID
		--,co.Report
		,ChecklistID
		,RiskFactor='Depression'
		,EventDate=DepScr_date 
		,OverdueFlag=
			case when (cast(DepScr_date as date) < DATEADD(d,-366,GETDATE())) or (cast(DepScr_date as date) is null) then 1
			else 0 end
		,Next30DaysOverdueFlag=0
	INTO #Depression
	FROM #Cohort co
	LEFT JOIN #Dep d on co.MVIPersonSID=d.MVIPersonSID;

	UPDATE #Depression
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE())

	DROP TABLE IF EXISTS #Dep
	------------------------------------------
	-- Homeless/Food Insecurity/MST 
	------------------------------------------
	--Get SDH screens
	DROP TABLE IF EXISTS #Homeless_FoodInsecurity_MST
	SELECT TOP (1) WITH TIES
		 MVIPersonSID
		,ChecklistID
		,Category
		,Survey_Date=cast(ScreenDateTime as date)
	INTO #Homeless_FoodInsecurity_MST
	FROM SDH.ScreenResults r WITH(NOLOCK)
	WHERE Category IN ('Food Insecurity Screen', 'Homeless Screen', 'MST Screen')
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID, Category ORDER BY ScreenDateTime DESC);

	--Most recent Homeless Screen (due annually)
	DROP TABLE IF EXISTS #Homeless
	SELECT DISTINCT co.MVIPersonSID
		,ChecklistID
		,RiskFactor='Homeless'
		,EventDate=Survey_Date 
		,OverdueFlag=
			case when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 1
			else 0 end
		,Next30DaysOverdueFlag=0
	INTO #Homeless
	FROM #Cohort co
	LEFT JOIN (select * from #Homeless_FoodInsecurity_MST WHERE Category='Homeless Screen' AND Survey_Date >= DATEADD(YEAR,-5,CAST(GETDATE() as date))) a on a.MVIPersonSID=co.MVIPersonSID;

	UPDATE #Homeless
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE())

	--Most recent Food Insecurity Screen (due annually)
	DROP TABLE IF EXISTS #FoodInsecurity
	SELECT DISTINCT co.MVIPersonSID
		,ChecklistID
		,RiskFactor='Food Insecurity'
		,EventDate=Survey_Date 
		,OverdueFlag=
			case when (cast(Survey_Date as date) < DATEADD(d,-366,GETDATE())) or (cast(Survey_Date as date) is null) then 1
			else 0 end
		,Next30DaysOverdueFlag=0
	INTO #FoodInsecurity
	FROM #Cohort co
	LEFT JOIN (select * from #Homeless_FoodInsecurity_MST WHERE Category='Food Insecurity Screen' AND Survey_Date >= DATEADD(YEAR,-5,CAST(GETDATE() as date))) a on a.MVIPersonSID=co.MVIPersonSID;

	UPDATE #FoodInsecurity
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE())

	--Most recent MST Screen (due every 99 years)
	DROP TABLE IF EXISTS #MST
	SELECT DISTINCT co.MVIPersonSID
		,ChecklistID
		,RiskFactor='MST'
		,EventDate=Survey_Date 
		,case when (cast(Survey_Date as date) < DATEADD(year,-99,GETDATE())) or (cast(Survey_Date as date) is null) then 1
			  else 0 end OverdueFlag
		,Next30DaysOverdueFlag=0
	INTO #MST
	FROM #Cohort co
	LEFT JOIN (select * from #Homeless_FoodInsecurity_MST WHERE Category='MST Screen') a on a.MVIPersonSID=co.MVIPersonSID

	UPDATE #MST
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(month,-1187,getdate()) AND EventDate > DATEADD(month,-1188,GETDATE())

	DROP TABLE IF EXISTS #Homeless_FoodInsecurity_MST
	------------------------------------------
	-- Tobacco use screening
	------------------------------------------
	--Get most recent tobacco screen in last 5 years
	DROP TABLE IF EXISTS #Tobacco
	SELECT co.MVIPersonSID
		,ChecklistID
		,RiskFactor='Tobacco'
		,EventDate=cast(HealthFactorDateTime as date)
		,OverdueFlag=
			case when (cast(HealthFactorDateTime as date) < DATEADD(d,-366,GETDATE())) or (cast(HealthFactorDateTime as date) is null) then 1
			else 0 end	
		,Next30DaysOverdueFlag=0
	INTO #Tobacco
	FROM #Cohort co
	LEFT JOIN [SUD].[TobaccoScreens] t WITH (NOLOCK) on co.MVIPersonSID=t.MVIPersonSID
	WHERE OrderDesc=1;

	UPDATE #Tobacco
	SET Next30DaysOverdueFlag = 1
	WHERE EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE());

	------------------------------------------
	-- PTSD screening
	------------------------------------------
	/*
	Retain most recent PTSD screen. For the first 5 years after military 
	separation (based on service separation date), PTSD screens are due year; 
	after that they are due every 5 years.
	*/
	DROP TABLE IF EXISTS #PTSD_screen
	SELECT a.MVIPersonSID
		,a.ChecklistID
		,cast(a.SurveyGivenDatetime as date) as SurveyGivenDate
		,a.SurveyName
		,a.DisplayScore
		,b.ServiceSeparationDate
	INTO #PTSD_screen
	FROM (
			SELECT *
				,RN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY SurveyGivenDateTime DESC)
			FROM [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (NOLOCK)
			WHERE display_PTSD NOT IN (-1, -99) and SurveyGivenDatetime >= DATEADD(year,-5,CAST(GETDATE() as date)) --grab past 5 years worth of data and retain most recent
			) a
	LEFT JOIN Common.MasterPatient b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE RN=1;

	DROP TABLE IF EXISTS #PTSD
	SELECT DISTINCT co.MVIPersonSID
		,RiskFactor='PTSD'
		,ChecklistID
		,EventDate=cast(SurveyGivenDate as date)
		,OverdueFlag=
			case when (ServiceSeparationDate > DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(d,-366,GETDATE()))
				or (ServiceSeparationDate < DATEADD(year,-5,GETDATE()) and SurveyGivenDate < DATEADD(year,-5,GETDATE()))
				or SurveyGivenDate is null then 1
			else 0 end
		,Next30DaysOverdueFlag=0
	INTO #PTSD
	FROM #Cohort co
	LEFT JOIN #PTSD_screen a on a.MVIPersonSID=co.MVIPersonSID;

	UPDATE #PTSD
	SET Next30DaysOverdueFlag = 1
	FROM #PTSD p
	LEFT JOIN #PTSD_screen s ON p.MVIPersonSID=s.MVIPersonSID
	WHERE 
	--Note: if screen (EventDate) has not been completed in the past year, it's already overdue (OverdueFlag=1)
		((EventDate < DATEADD(d,-334,getdate()) AND EventDate > DATEADD(d,-366,GETDATE()))
		AND ServiceSeparationDate > DATEADD(year,-5,GETDATE()))
	OR
		(EventDate < DATEADD(MONTH,-59,getdate()) AND EventDate > DATEADD(MONTH,-60,GETDATE())
		AND ServiceSeparationDate < DATEADD(year,-5,GETDATE())
		AND OverdueFlag=0);

	DROP TABLE IF EXISTS #PTSD_screen
-- =======================================================================================================
--  Exclusionary criteria - Past year
-- =======================================================================================================
	--Hospice XLA criteria based on CPT Codes, Medical Service, PTFCodes, and StopCodes
	--Create lookup table
	DROP TABLE IF EXISTS #HospiceXLA
	SELECT DISTINCT SetTerm
		,CPTCode=CASE WHEN Vocabulary='CPT' THEN Value END
		,StopCode=CASE WHEN Vocabulary='StopCodePrimary' THEN Value END
		,StopCodeSID=CASE WHEN Vocabulary='StopCodePrimary' THEN s.StopCodeSID END
		,MedicalService=CASE WHEN Vocabulary IN ('MedicalService') THEN Value END
		,PTFCode=CASE WHEN Vocabulary IN ('PTFCode') THEN Value END
	INTO #HospiceXLA
	FROM XLA.Lib_SetValues_CDS x WITH (NOLOCK)
	LEFT JOIN LookUp.StopCode s WITH (NOLOCK)
		ON x.Value=s.StopCode
	WHERE SetTerm='Hospice'

	--VISTA hospice patients in past year 
	--Stop Code
	DROP TABLE IF EXISTS #VistaStopCode
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #VistaStopCode
	FROM #Cohort c
	INNER JOIN App.vwCDW_Outpat_Workload w WITH (NOLOCK)
		ON c.MVIPersonSID=w.MVIPersonSID	
	WHERE 
		((  w.PrimaryStopCodeSID IN (SELECT StopCodeSID FROM #HospiceXLA WITH (NOLOCK) WHERE StopCodeSID IS NOT NULL) OR
		    w.SecondaryStopCodeSID IN (SELECT StopCodeSID FROM #HospiceXLA WITH (NOLOCK) WHERE StopCodeSID IS NOT NULL)) AND
		    w.VisitDateTime >= GETDATE() - 365)

	--CPT Codes
	DROP TABLE IF EXISTS #VistaCPT
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #VistaCPT
	FROM #Cohort c
	INNER JOIN Common.vwMVIPersonSIDPatientPersonSID m WITH (NOLOCK)
		ON c.MVIPersonSID=m.MVIPersonSID
	INNER JOIN Outpat.VProcedure p WITH (NOLOCK)
		ON m.PatientPersonSID=p.PatientSID
		AND p.WorkloadLogicFlag='Y'
	INNER JOIN LookUp.CPT cpt WITH (NOLOCK)
		ON p.CPTSID=cpt.CPTSID
	WHERE cpt.CPTCode IN (SELECT CPTCode FROM #HospiceXLA WHERE CPTCode IS NOT NULL) AND
		  p.VisitDateTime >= GETDATE() - 365;

	--PTF codes
	DROP TABLE IF EXISTS #VistaPTF
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #VistaPTF
	FROM #Cohort c
	INNER JOIN Inpatient.BedSection i WITH (NOLOCK)
		ON c.MVIPersonSID=i.MVIPersonSID	
	WHERE i.BedSection IN (SELECT PTFCode FROM #HospiceXLA WITH (NOLOCK) WHERE PTFCode IS NOT NULL) AND
		 (i.DischargeDateTime >= GETDATE() - 365 OR i.DischargeDateTime IS NULL)

	--CERNER hospice patients in past year 
	--CPT Codes
	DROP TABLE IF EXISTS #CernerCPT
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #CernerCPT
	FROM #Cohort c
	INNER JOIN Cerner.FactProcedure p WITH (NOLOCK)
		ON c.MVIPersonSID=p.MVIPersonSID
	INNER JOIN LookUp.CPT cpt WITH (NOLOCK)
		ON p.NomenclatureSID=cpt.CPTSID
	WHERE cpt.CPTCode IN (SELECT CPTCode FROM #HospiceXLA WHERE CPTCode IS NOT NULL) AND
		  p.TZDerivedProcedureDateTime >= GETDATE() - 365;

	--Medical Service
	DROP TABLE IF EXISTS #CernerFactUtilizationOutpatient
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #CernerFactUtilizationOutpatient
	FROM #Cohort c
	INNER JOIN Cerner.FactUtilizationOutpatient o WITH (NOLOCK)
		ON c.MVIPersonSID=o.MVIPersonSID
	WHERE
		(   o.MedicalService IN (SELECT MedicalService FROM #HospiceXLA WHERE MedicalService IS NOT NULL) AND
		    o.TZDerivedVisitDateTime >= GETDATE() - 365)

	--Medical Service or PTFCode
	DROP TABLE IF EXISTS #CernerFactInpatient
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #CernerFactInpatient
	FROM #Cohort c
	INNER JOIN Cerner.FactInpatient i WITH (NOLOCK)
		ON c.MVIPersonSID=i.MVIPersonSID
	WHERE
		(i.MedicalService IN (SELECT MedicalService FROM #HospiceXLA WHERE MedicalService IS NOT NULL) AND
		(i.TZDischargeDateTime >= GETDATE() - 365 OR i.TZDischargeDateTime IS NULL))
	 OR	(i.PTFCode IN (SELECT PTFCode FROM #HospiceXLA WHERE PTFCode IS NOT NULL) AND
		(i.TZDischargeDateTime >= GETDATE() - 365 OR i.TZDischargeDateTime IS NULL))

	--Medical Service or PTFCode
	DROP TABLE IF EXISTS #CernerFactInpatientSpecialtyTransfer
	SELECT DISTINCT c.MVIPersonSID, Hospice=1
	INTO #CernerFactInpatientSpecialtyTransfer
	FROM #Cohort c
	INNER JOIN Cerner.FactInpatient s WITH (NOLOCK)
		ON c.MVIPersonSID=s.MVIPersonSID
	WHERE
		(s.MedicalService IN (SELECT MedicalService FROM #HospiceXLA WHERE MedicalService IS NOT NULL) AND
		(s.TZDischargeDateTime >= GETDATE() - 365 OR s.TZDischargeDateTime IS NULL))
	 OR	(s.PTFCode IN (SELECT PTFCode FROM #HospiceXLA WHERE PTFCode IS NOT NULL) AND
		(s.TZDischargeDateTime >= GETDATE() - 365 OR s.TZDischargeDateTime IS NULL))

	DROP TABLE IF EXISTS #HospiceXLA

	--Combine hospice patients
	DROP TABLE IF EXISTS #Hospice
	SELECT MVIPersonSID, Hospice
	INTO #Hospice
	FROM #VistaStopCode
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #VistaCPT
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #VistaPTF
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #CernerCPT
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #CernerFactUtilizationOutpatient
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #CernerFactInpatient
	UNION
	SELECT MVIPersonSID, Hospice
	FROM #CernerFactInpatientSpecialtyTransfer

	DROP TABLE IF EXISTS #VistaStopCode
	DROP TABLE IF EXISTS #VistaCPT
	DROP TABLE IF EXISTS #VistaPTF
	DROP TABLE IF EXISTS #CernerCPT
	DROP TABLE IF EXISTS #CernerFactUtilizationOutpatient
	DROP TABLE IF EXISTS #CernerFactInpatient
	DROP TABLE IF EXISTS #CernerFactInpatientSpecialtyTransfer

	--Diagnosis in past year
	DROP TABLE IF EXISTS #Dx
	SELECT DISTINCT c.MVIPersonSID, ICD10Code
	INTO #Dx
	FROM #Cohort c
	INNER JOIN Present.DiagnosisDate d WITH (NOLOCK) ON c.MVIPersonSID=d.MVIPersonSID
	WHERE MostRecentDate >= GETDATE() - 365;

	--Persistent Depressive D/O, Major Depressive D/O, Bipolar, Dementia, Hospice
	DROP TABLE IF EXISTS #Exclusions
	SELECT c.MVIPersonSID
		,PDD=MAX(PDD)
		,MDD=MAX(MDD)
		,Bipolar=MAX(Bipolar)
		,PTSD=MAX(PTSD)
		,Dementia=MAX(Dementia)
		,Hospice=MAX(Hospice)
	INTO #Exclusions
	FROM #Cohort c
	LEFT JOIN (	SELECT a.MVIPersonSID
					,PDD=CASE WHEN SetTerm IN ('PersistentDepressiveDisorder') THEN 1 ELSE 0 END
					,MDD=CASE WHEN SetTerm IN ('MajorDepression') THEN 1 ELSE 0 END
					,Bipolar=CASE WHEN SetTerm IN ('Bipolar') THEN 1 ELSE 0 END
					,PTSD=CASE WHEN SetTerm IN ('PTSD') THEN 1 ELSE 0 END
					,Dementia=CASE WHEN SetTerm IN ('Dementia') THEN 1 ELSE 0 END
				FROM #Dx a
				INNER JOIN XLA.Lib_SetValues_CDS b WITH (NOLOCK) ON a.ICD10Code=b.Value
				WHERE (SetTerm IN ('PersistentDepressiveDisorder', 'MajorDepression', 'Bipolar', 'PTSD', 'Dementia') AND Vocabulary='ICD10CM')
			  ) a
		ON a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN #Hospice h
		ON h.MVIPersonSID=c.MVIPersonSID
	GROUP BY c.MVIPersonSID;

	DROP TABLE IF EXISTS #Dx
	DROP TABLE IF EXISTS #Hospice
	DROP TABLE IF EXISTS #Cohort

	--Suicide: Exclude when Dementia or Hospice
	UPDATE #SuicideScreen
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #SuicideScreen s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Dementia=1 OR e.Hospice=1;

	--Audit-C: Exclude when Dementia or Hospice
	UPDATE #AuditC_Screen
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #AuditC_Screen s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Dementia=1 OR e.Hospice=1;

	--Depression: Exclude when Dementia, Hospice, PDD, MDD, or Bipolar
	UPDATE #Depression
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #Depression s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Dementia=1 OR e.Hospice=1 OR e.PDD=1 OR e.MDD=1 OR e.Bipolar=1;

	--Homeless: Exclude when Hospice
	UPDATE #Homeless
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #Homeless s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Hospice=1;

	--Food Insecurity: Exclude when Hospice
	UPDATE #FoodInsecurity
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #FoodInsecurity s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Hospice=1;

	--PTSD: Exclude when Dementia, Hospice, or PTSD
	UPDATE #PTSD
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #PTSD s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Dementia=1 OR e.Hospice=1 OR e.PTSD=1;

	--Tobacco: Exclude when Hospice
	UPDATE #Tobacco
	SET OverdueFlag = -1,
		Next30DaysOverdueFlag = -1
	FROM #Tobacco s
	LEFT JOIN #Exclusions e
		ON s.MVIPersonSID=e.MVIPersonSID
	WHERE e.Hospice=1;

	DROP TABLE IF EXISTS #Exclusions

	------------------------------------------
	-- Final table
	------------------------------------------
	DROP TABLE IF EXISTS #OverdueScreens
	SELECT MVIPersonSID, ChecklistID, Screen=RiskFactor, OverdueFlag, Next30DaysOverdueFlag, MostRecentScreenDate=EventDate
	INTO #OverdueScreens
	FROM #SuicideScreen
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #Depression
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #Homeless
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #FoodInsecurity
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #AuditC_Screen
	
	UNION
	
	SELECT MVIPersonSID,ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #MST
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #PTSD
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, RiskFactor, OverdueFlag, Next30DaysOverdueFlag, EventDate
	FROM #Tobacco;

	DROP TABLE IF EXISTS #AuditC_Screen
	DROP TABLE IF EXISTS #Depression
	DROP TABLE IF EXISTS #FoodInsecurity
	DROP TABLE IF EXISTS #Homeless
	DROP TABLE IF EXISTS #MST
	DROP TABLE IF EXISTS #PTSD
	DROP TABLE IF EXISTS #SuicideScreen
	DROP TABLE IF EXISTS #Tobacco

EXEC [Maintenance].[PublishTable] 'Present.OverdueScreens', '#OverdueScreens';


END