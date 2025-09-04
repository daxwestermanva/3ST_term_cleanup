
/***-- =============================================
-- Author:		<Susana Martins/Amy Robinson>
-- Create date: <10/21/2015>
-- Description:	PERCEPTIVE REACH MODEL
-- Defined by SMITREC  using Harvard Machine Learning final output 

	2019-02-07 HES	Added an extra step to the publishing job to truncate the relevant tables in CDSDEV and CDSSbx and populate them with 
					data computed in CDS (the new run). 
	2019-02-16 JB	Commented out code that uses direct database connections that are not allowed in CDS
	2019-02-22 RAS	Corrected Sta6aID update statement that was joining with permanent table instead of temp table (necessary to fully implement publishtable).
	3019-04-05 RAS  Removed code for old logging architecture
	2019-06-04 RAS	Replaced middle code with new code from RiskScore that was already validated (these sections were marked as identical previously).
					Implemented Maintenance.PublishTable for Reach.ClinicalSignals.  Other best practice changes - e.g., WITH(NOLOCK), CamelCase
	2019-09-23 RAS  V02 - Using new view for displayed patient, new SP to get "clinical signals." Changed clinical signals from permanent to temp table.
	2020-01-27 RAS	Changed final join with Present.Appointments to use Present.Appointments_ICN. Original version was using the former, but joining incorrectly on ICN
	2020-07-28 RAS	Changed final join with RiskScore to use PatientSID and dynamically pull MVIPersonSID in case of change. 
					Added in RiskScoreSuicide and RiskRanking to final table so that this only has to be done here and not when the reports are run.
	2020-07-14 LM	Removed extraneous risk factors where Coefficient was not >0. Corrected code to pull in diagnoses for anxiety and personality disorders
	2020-08-11 RAS	Replace Present.Appointments_ICN join with Present.AppointmentsPast and Present.AppointmentsFuture
	2020-10-02 RAS	Removed address and phone (report now uses MasterPatient)
	2020-10-28 LM	Replaced reference to DisplayedPatient
	2021-01-19 LM	Added facility name for other future appointment
	2025-02-19 LM	Updated to use RV2 architecture
	2025-05-06 LM	Updated references to point to REACH 2.0 objects
-- =============================================
*/ 
CREATE PROCEDURE [Code].[Reach_PatientReport]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Reach_PatientReport','Execution of SP Code.Reach_PatientReport'

 --All SIDs for any Patient EVER identified, still living.
 DROP TABLE IF EXISTS #cohort_report;
 SELECT DISTINCT -- 2022-05-31 RAS Added DISTINCT due to duplicate values in REACH.History, but really that shouldn't happen (?)
	a.MVIPersonSID
 INTO #cohort_report
 FROM [REACH].[History] a WITH (NOLOCK) --always has the most recent PatientICN/MVIPersonSID associated with the PatientSID in RiskScoreHistoric
 INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) ON a.MVIPersonSID=b.MVIPersonSID 
 WHERE DateOfDeath IS NULL

	PRINT 'Cohort created ' + convert(varchar,GETDATE(),20)

/**********************************************************
BEGIN SAME AS Code.Reach_RiskScore
**********************************************************/	
EXEC [Log].[ExecutionBegin] 'Code.Reach_ClinicalSignals','Execution of SP Reach_PatientReport - getting ClinicalSignals'
	EXEC [Code].[REACH_ClinicalSignals] @PeriodEndDate=NULL, @RunType='Nightly'
		PRINT 'Risk variables computed ' + convert(varchar,GETDATE(),20)
		

/******************************************Patient Report **********************************************/
--Currently Admitted
DROP TABLE IF EXISTS #admitted;
SELECT DISTINCT MVIPersonSID,Admitted=1
INTO #admitted
FROM [Inpatient].[Bedsection] WITH (NOLOCK)
WHERE [DischargeDateTime] is null


DROP TABLE IF EXISTS #appointments
SELECT c.MVIPersonSID 
	  ,pcf.AppointmentDateTime		  as PCFutureAppointmentDateTime_ICN
	  ,pcf.PrimaryStopCode			  as PCFuturePrimaryStopCode_ICN
	  ,pcf.PrimaryStopCodeName		  as PCFutureStopCodeName_ICN
	  ,pcf.Facility					  as PCFutureAppointmentFacility_ICN
	  ,mhf.AppointmentDateTime		  as MHFutureAppointmentDateTime_ICN
	  ,mhf.PrimaryStopCode			  as MHFuturePrimaryStopCode_ICN
	  ,mhf.PrimaryStopCodeName		  as MHFutureStopCodeName_ICN
	  ,mhf.Facility					  as MHFutureAppointmentFacility_ICN
	  ,oth.AppointmentDateTime		  as OtherFutureAppointmentDateTime_ICN
	  ,oth.PrimaryStopCode			  as OtherFuturePrimaryStopCode_ICN
	  ,oth.PrimaryStopCodeName		  as OtherFutureStopCodeName_ICN
	  ,oth.Facility					  as OtherFutureAppointmentFacility_ICN
INTO #appointments
FROM #cohort_report c
LEFT JOIN (
	SELECT a.* , b.Facility
	FROM [Present].[AppointmentsFuture] a WITH(NOLOCK)
	INNER JOIN [Lookup].[ChecklistID] b WITH(NOLOCK) ON a.ChecklistID=b.ChecklistID
	WHERE ApptCategory = 'PCFuture'
		AND NextAppt_ICN=1
	) pcf on pcf.MVIPersonSID=c.MVIPersonSID
LEFT JOIN (
	SELECT a.* , b.Facility, ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY AppointmentDateTime) AS RN
	FROM [Present].[AppointmentsFuture] a WITH(NOLOCK)
	INNER JOIN [Lookup].[ChecklistID] b WITH(NOLOCK) ON a.ChecklistID=b.ChecklistID
	WHERE ApptCategory IN ('MHFuture','HomelessFuture')
		AND NextAppt_ICN=1
	) mhf on mhf.MVIPersonSID=c.MVIPersonSID AND RN=1
LEFT JOIN (
	SELECT a.* , b.Facility
	FROM [Present].[AppointmentsFuture] a WITH(NOLOCK)
	INNER JOIN [Lookup].[ChecklistID] b WITH(NOLOCK) ON a.ChecklistID=b.ChecklistID
	WHERE ApptCategory = 'OtherFuture'
		AND NextAppt_ICN=1
	) oth on oth.MVIPersonSID=c.MVIPersonSID
WHERE pcf.AppointmentDateTime IS NOT NULL
	OR mhf.AppointmentDateTime IS NOT NULL
	OR oth.AppointmentDateTime IS NOT NULL

DROP TABLE IF EXISTS #visits
SELECT c.MVIPersonSID 
	  ,pcv.VisitDateTime			as PCRecentVisitDate_ICN
	  ,pcv.PrimaryStopCode			as PCRecentStopCode_ICN
	  ,pcv.PrimaryStopCodeName		as PCRecentStopCodeName_ICN
	  ,pcv.Sta3n					as PCRecentSta3n_ICN
	  ,mhv.VisitDateTime			as MHRecentVisitDate_ICN
	  ,mhv.PrimaryStopCode			as MHRecentStopCode_ICN
	  ,mhv.PrimaryStopCodeName		as MHRecentStopCodeName_ICN
	  ,mhv.Sta3n					as MHRecentSta3n_ICN
	  ,oth.VisitDateTime			as OtherRecentVisitDate_ICN
	  ,oth.PrimaryStopCode			as OtherRecentStopCode_ICN
	  ,oth.PrimaryStopCodeName		as OtherRecentStopCodeName_ICN
	  ,oth.Sta3n					as OtherRecentSta3n_ICN
INTO #visits
FROM #cohort_report c
LEFT JOIN (
	SELECT * 
	FROM [Present].[AppointmentsPast] WITH (NOLOCK)
	WHERE ApptCategory = 'PCRecent'
		AND MostRecent_ICN=1
	) pcv on pcv.MVIPersonSID=c.MVIPersonSID
LEFT JOIN (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC) AS RN
	FROM [Present].[AppointmentsPast] WITH (NOLOCK)
	WHERE ApptCategory IN ('MHRecent','HomelessRecent')
		AND MostRecent_ICN=1
	) mhv on mhv.MVIPersonSID=c.MVIPersonSID AND RN=1
LEFT JOIN (
	SELECT * 
	FROM [Present].[AppointmentsPast] WITH (NOLOCK)
	WHERE ApptCategory = 'OtherRecent'
		AND MostRecent_ICN=1
	) oth on oth.MVIPersonSID=c.MVIPersonSID
WHERE pcv.VisitDateTime IS NOT NULL
	OR mhv.VisitDateTime IS NOT NULL
	OR oth.VisitDateTime IS NOT NULL
	   
--Stage PatientReport
DROP TABLE IF EXISTS #StageReachPatRpt;
WITH RiskScore AS (--Need to get most recent MVIPersonSID to join detail of risk score
	SELECT DISTINCT r.MVIPersonSID,r.PatientPersonSID AS PatientSID,r.ChecklistID,r.RiskRanking,r.RiskScoreSuicide,r.DashboardPatient
	FROM [REACH].[RiskScore] r WITH (NOLOCK)
	)
SELECT DISTINCT 
	 c.MVIPersonSID
	,rs.PatientSID
	,h.ChecklistID --get most recent Coordinator location from Reach.History
    ,h.FirstRVDate as DateEnteredDashboard
	,rs.RiskScoreSuicide
    ,rs.RiskRanking
    ,rs.DashboardPatient as Top01Percent
	,IsNull (x.admitted,0) as Admitted
    ,fa.PCFutureAppointmentDateTime_ICN
    ,fa.PCFuturePrimaryStopCode_ICN
    ,fa.PCFutureStopCodeName_ICN
    ,fa.PCFutureAppointmentFacility_ICN
    ,fa.MHFutureAppointmentDateTime_ICN
    ,fa.MHFuturePrimaryStopCode_ICN
    ,fa.MHFutureStopCodeName_ICN
    ,fa.MHFutureAppointmentFacility_ICN
    ,fa.OtherFutureAppointmentDateTime_ICN
    ,fa.OtherFuturePrimaryStopCode_ICN
    ,fa.OtherFutureStopCodeName_ICN
	,fa.OtherFutureAppointmentFacility_ICN
    ,pv.MHRecentVisitDate_ICN
    ,pv.MHRecentStopCode_ICN
    ,pv.MHRecentStopCodeName_ICN
    ,pv.MHRecentSta3n_ICN
    ,pv.PCRecentVisitDate_ICN
    ,pv.PCRecentStopCode_ICN
    ,pv.PCRecentStopCodeName_ICN
    ,pv.PCRecentSta3n_ICN
    ,pv.OtherRecentVisitDate_ICN
    ,pv.OtherRecentStopCode_ICN
    ,pv.OtherRecentStopCodeName_ICN
    ,pv.OtherRecentSta3n_ICN
INTO #StageReachPatRpt 
FROM #cohort_report c 
INNER JOIN [REACH].[History] h WITH (NOLOCK) on h.MVIPersonSID=c.MVIPersonSID
INNER JOIN RiskScore rs on rs.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #appointments fa on fa.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #visits pv on pv.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #admitted as x on x.MVIPersonSID=c.MVIPersonSID
;

UPDATE #StageReachPatRpt
SET ChecklistID=pr.ChecklistID
FROM (
	SELECT a.MVIPersonSID
		  ,b.ChecklistID
	FROM #StageReachPatRpt as a 
	INNER JOIN [REACH].[HealthFactors] as b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID 
	WHERE a.ChecklistID <> b.ChecklistID 
	    AND b.QuestionNumber = 0 
		AND b.QuestionStatus = 1 
		AND b.ChecklistID is not null 
		AND MostRecentFlag=1 
	) as PR 
INNER JOIN #StageReachPatRpt as r on pr.MVIPersonSID = r.MVIPersonSID 
;
--Publish PatientReport
EXEC [Maintenance].[PublishTable] 'REACH.PatientReport','#StageReachPatRpt';	

EXEC [Log].[ExecutionEnd]
END