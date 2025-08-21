/***--=============================================
Author:		Amy Robinson
Create DATE: 9/23/2024
Description:	REACH VET 2.0 risk score and top 0.1% computation
--Updates:
  12/27/2024 AER: Split out clinical signals calculation into its own procedure
  01/30/2025 LM:  Set Code.REACH_ClinicalSignals to be executed from this procedure to populate REACH.ClincialSignals_Monthly
	02/21/2025 AER: Change order of chort query
  
  Helpful Auditing Scripts

		SELECT TOP 10 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'Code.Reach_RiskScore'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 10 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE SchemaName = 'REACH' AND TableName = 'Stage_RiskScore' ORDER BY 1 DESC


--=============================================
*/


CREATE PROCEDURE [Code].[Reach_RiskScore] 
(
	@PeriodEndDate DATE=NULL
)
AS
BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.Reach_RiskScore' ,@Description = 'Execution of Code.Reach_RiskScore'
	
	------------------------------------------------------------------------------------
	-- Create list of predictors and date variables and cohort --30 secs
	------------------------------------------------------------------------------------


	
	/********COMPUTE RISK VARIABLES*******/
-- The following SP will compute risk variables for the patients defined in the table #cohort
-- The previous step is needed to create #cohort table with unique MVIPersonSID
-- The results are published to [REACH].[ClinicalSignals_Monthly] (AS specified by the RunType parameter)
-- If #cohort is NOT defined, this SP would run with default cohort from PatientReport and RunType Nightly.
	EXEC [Code].[REACH_ClinicalSignals] @PeriodEndDate=NULL, @RunType='Monthly' 

	--THROW ERROR IF VALIDATION IN REACH_ClinicalSignals CAUSES AN ERROR
	DROP TABLE IF EXISTS #RVerror;
	SELECT TOP 1 m.* 
	INTO #RVerror
	FROM [Log].[MessageLog] m WITH (NOLOCK)
	INNER JOIN 
		(
			SELECT TOP 1 rv.*
			FROM [Log].[ExecutionLog] rv WITH (NOLOCK)
			INNER JOIN 
				(
					SELECT TOP 1 ExecutionLogID
					FROM [Log].[ExecutionLog] WITH (NOLOCK)
					WHERE NAME LIKE 'Code.Reach_RiskScore'
						--AND ExecutionLogID=3748 --testing error
					ORDER BY 1 DESC
				) e 
				ON rv.ParentExecutionLogID=e.ExecutionLogID
		) l 
		ON l.ExecutionLogID=m.ExecutionLogID
	WHERE m.Type IN ('Error','Warning')

	IF EXISTS (SELECT * FROM #RVerror)
	BEGIN
		DECLARE @msg varchar(250) = (SELECT 'Error in Code.REACH_ClinicalSignals. '+ [Message] FROM #RVerror)
		PRINT  @msg
		EXEC [Log].[Message] 'Error','REACH.RiskScore',@msg

		EXEC [Log].[ExecutionEnd] @Status='Error'
		RETURN
	END
  
  
  
	/********DEFINE COHORT*******/
	DROP TABLE IF EXISTS #cohort
	SELECT 
		a.MVIPersonSID
		,a.Sta3n_EHR
		,a.ChecklistID
		,a.PatientPersonSID
		,v.MVIPersonICN AS PatientICN
	INTO #cohort
	FROM [REACH].[ActivePatient] a WITH (NOLOCK)
	LEFT JOIN [SVeteran].[SMVIPerson] v WITH (NOLOCK)--added this join just to pull in the "RunDatePatientICN" into final table
		ON v.MVIPersonSID=a.MVIPersonSID		
  
  
  
	/********Variables To Calculate*******/
  
drop table if exists #Predictors
  select distinct * 
   into #Predictors
  from 
  (select distinct vi.InstanceVariableID,vi.InstanceVariable
  ,vl.VariableID,vl.Variable
  ,cast(TimeframeStart as int) as TimeframeStart, cast(TimeframeEnd as int) as TimeframeEnd
  ,'d' as TimeFrameUnits
  , case when vi.domain in   ( 'Dx', 'Inpat Ux', 'OutpatientUx',  'Rx', 'RxOpioid')
   then 1 else 0 end XLA
   ,vi.Domain
   ,a.Strat
  ,a.theta 
  ,ValueLow,ValueHigh,ValueVarchar
  from REACH.Predictors as a WITH(NOLOCK)
  inner join Config.Risk_VariableClinicalConcepts vi WITH(NOLOCK) on 
                  a.InstanceVariableID = vi.InstanceVariableID
  left outer join Config.Risk_Variable vl WITH(NOLOCK) on a.VariableID=vl.VariableID
 ) as a 
 
  
  
  
  
  
  
drop table if exists #PredictorsWithoutInteractions
select * 
into #PredictorsWithoutInteractions --deleted below
from #Predictors 

delete from #PredictorsWithoutInteractions WHERE STRAT LIKE '%/_/_/_/_/_%' ESCAPE '/'

  -------------------------------------Risk Score Calculation

--2.5 min
 drop table if exists #stageRisk
 select MVIPersonSID,VariableID,Variable,VariableValue,ComputationalVariableValue,Strat,theta
 into #stageRisk
 from (
 select a.*,Strat,theta 
 from REACH.ClinicalSignals_Monthly as a WITH (NOLOCK)
 inner join #PredictorsWithoutInteractions as b on a.VariableID = b.VariableID and a.VariableValue=b.ValueVarchar
 
 union 
 
 select a.*,Strat,theta 
 from REACH.ClinicalSignals_Monthly as a WITH (NOLOCK)
 inner join #PredictorsWithoutInteractions as b on a.VariableID = b.VariableID and  try_cast(a.VariableValue as int) between b.ValueLow and b.ValueHigh
 where isnumeric(variablevalue) = 1

  union 
 
 select a.* ,Strat,theta  
 from REACH.ClinicalSignals_Monthly as a WITH (NOLOCK)
 inner join #PredictorsWithoutInteractions as b on a.VariableID = b.VariableID 
 where b.ValueVarchar is null and    b.ValueLow is null  and b.ValueHigh is null 
) as z 
 
 --INTERACTIONS


INSERT INTO #stageRisk
select MVIPersonSID,z.InteractionID,z.Interaction,null as VariableValue
, 1 ComputationalVariableValue
,z.Strat,z.Theta 
from (
SELECT distinct 
MVIPersonSID,a.InteractionID,a.Interaction,null as VariableValue
, COUNT(distinct a.VariableID) InteractionCount
,a.Strat,a.Theta
FROM config.risk_variableinteractions AS A WITH (NOLOCK)
inner join REACH.ClinicalSignals_Monthly as b WITH (NOLOCK) on a.variableid = b.VariableID
inner join reach.predictors as p WITH (NOLOCK) on a.THETA = p.THETA  and (p.ValueVarchar = b.variablevalue or b.VariableValue is null)
group by MVIPersonSID,a.InteractionID,a.Interaction,a.Strat,a.Theta
)as z
where InteractionCount >1
  
  
   drop table if exists #Values
 select * 
 ,ComputationalVariableValue*theta as Term 
  into #Values
 from #stageRisk
  
  
--1 min
 Drop table if exists #RiskScore
 select MVIPersonSID, Exp([RiskScoreStep1])/(1+ Exp([RiskScoreStep1])) as RiskScoreSuicide
 into #RiskScore
 from (
 select mvipersonsid, sum(Term) + (select Intercept from Stage.RiskModel where ModelName = 'Reach Vet 2.0') as RiskScoreStep1
 from #Values as a 
  group by mvipersonsid ) as z 
  
  
  
  
    ---------------------------------------End Risk Score Calculation
  --drop temps 
drop table if exists #Values
drop table if exists #stageRisk




  
	------------------------------------------------------------------------------------
	-- Identification of risk ranking and REACH VET dashboard patients  --2min
	------------------------------------------------------------------------------------
	/******* Identify Priority Groups *******/
	DROP TABLE IF EXISTS #RiskScore_PriorityGroups
	SELECT 
		rs.MVIPersonSID
		,rs.RiskScoreSuicide
		,mp.PriorityGroup
		,mp.PrioritySubGroup
		,PriorityGroupBit = CASE WHEN mp.PriorityGroup > 0 THEN 1 ELSE 0 END
	INTO #RiskScore_PriorityGroups
	FROM #RiskScore rs
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID=rs.MVIPersonSID



	DROP TABLE #RiskScore

	--SELECT COUNT(*) FROM #RiskScore_PriorityGroups							--6790503
	--SELECT COUNT(*) FROM #RiskScore_PriorityGroups where PriorityGroupBit=0	-- 562004

	/********N patients in each site and top 0.1%*******/
	DROP TABLE IF EXISTS #Population;
	SELECT 
		c.ChecklistID
		,COUNT(rs.MVIPersonSID) AS TotalPatients
		,ROUND(COUNT(rs.MVIPersonSID) *0.001,0) AS DashboardCutOff
	INTO #Population
	FROM #RiskScore_PriorityGroups AS rs 
	INNER JOIN #cohort AS c ON rs.MVIPersonSID=c.MVIPersonSID
	WHERE rs.PriorityGroupBit = 1 -- filter out those without PriorityGroup in determining facility size
	GROUP BY c.ChecklistID



	/* FOR VALIDATION
	SELECT cl.Facility,p.*,old.TotalPatients,old.TopPercent 
	FROM #Population p
	LEFT JOIN (

		SELECT c.ChecklistID
			  ,Count(rs.MVIPersonSID) AS TotalPatients
			  ,Round(Count(rs.MVIPersonSID) *0.001,0) AS TopPercent
		FROM #RiskScore_PriorityGroups AS rs 
		INNER JOIN #cohort AS c ON rs.MVIPersonSID=c.MVIPersonSID
		--WHERE rs.PriorityGroupBit = 1 -- filter out those without PriorityGroup in determining facility size
		GROUP BY c.ChecklistID
		) old ON old.ChecklistID=p.ChecklistID
	INNER JOIN LookUp.ChecklistID cl ON cl.ChecklistID=p.ChecklistID
	ORDER BY p.ChecklistID
	*/



	/******** Rank by RiskScoreSuicide, within ChecklistIDs *******/
	---- Dashboard patients will have a valid PriorityGroup (PriorityGroupBit=1) and a 
	---- RiskRanking_PriorityGroups (a risk ranking that excludes the non-priority groups)
	---- meeting the threshold for the facility.
	DROP TABLE IF EXISTS #RiskRanking;
	SELECT 
		b.MVIPersonSID
		,rs.RiskScoreSuicide 
		,b.ChecklistID 
	  
		-- RiskRanking is needed for displaying relative risk ON tools like CRISTAL (regardless of Enrollment PriorityGroup)
		,RANK() OVER(PARTITION BY b.ChecklistID ORDER BY rs.RiskScoreSuicide DESC) AS RiskRanking 
		-- If we didn't filter anyone out, the following would be the dashboard list.  For comparison only.
		,CASE WHEN RANK() OVER(PARTITION BY b.ChecklistID ORDER BY rs.RiskScoreSuicide DESC) <= pop.DashboardCutOff THEN 1 ELSE 0 END TopPercentAllGroups

		-- Rank using partition for PriorityGroups to get only patients WITH a valid priority group. RiskRanking_PriorityGroups column for troubleshooting only
		,RANK() OVER(PARTITION BY b.ChecklistID,rs.PriorityGroupBit ORDER BY rs.RiskScoreSuicide DESC) AS RiskRanking_PriorityGroups	  
		,CASE WHEN RANK() OVER(PARTITION BY b.ChecklistID,rs.PriorityGroupBit ORDER BY rs.RiskScoreSuicide DESC) <= pop.DashboardCutOff AND rs.PriorityGroupBit=1 THEN 1 ELSE 0 END DashboardPatient
		,rs.PriorityGroup
		,rs.PrioritySubGroup
    ,rs.PriorityGroupBit
		,pop.DashboardCutOff
	INTO #RiskRanking
	FROM #RiskScore_PriorityGroups rs
	INNER JOIN #cohort b ON rs.MVIPersonSID=b.MVIPersonSID
	INNER JOIN #Population pop ON pop.ChecklistID=b.ChecklistID;
	-- WHERE ChecklistID = '556' ORDER BY a.RiskScoreSuicide DESC

	/* FOR VALIDATION
	SELECT * FROM #RiskRanking WHERE CHECKLISTID = '637'
	WHERE DashboardPatient<>TopPercentAllGroups
	*/

	/******** National ranking for all patients  *******/
	DROP TABLE IF EXISTS #RiskScorePopulation; 
	SELECT 
		a.MVIPersonSID
    , 1 as Randomized 
   	,a.ChecklistID
		,a.RiskScoreSuicide
		,a.RiskRanking
		,a.DashboardPatient
		,RANK() OVER(ORDER BY RiskScoreSuicide DESC) AS NationalRanking
		,CAST(RANK() OVER(ORDER BY RiskScoreSuicide DESC) AS DECIMAL(18,10))/(SELECT COUNT(*) FROM #RiskRanking) AS PercRanking
		,a.PriorityGroup
		,a.PrioritySubGroup
		,a.TopPercentAllGroups
    ,DashboardCutOff
    ,PriorityGroupBit
    ,RiskRanking_PriorityGroups
	INTO #RiskScorePopulation
	FROM #RiskRanking AS a 
	ORDER BY RiskScoreSuicide DESC
	;

---anyone who has ever been randomized will stay in that way
  Update #RiskScorePopulation
  set Randomized = 2 
  where mvipersonsid in (  select v1.MVIPersonSID  from  REACH.RiskScoreHistoric rv 
  inner join Common.MVIPersonSIDPatientPersonSIDLog v1 on rv.PatientPersonSID = v1.PatientPersonSID
  where rv.Randomized =2)

  
  
  
 ---new patients who have not had a chance to be randomized yet
 drop table if exists #newtoRVPatients
  select checklistID, mvipersonsid 
  into #newtoRVPatients
  from #riskscorepopulation 
   except 
   select checklistID, v1.MVIPersonSID
  from  REACH.RiskScoreHistoric rv WITH (NOLOCK)
  inner join Common.MVIPersonSIDPatientPersonSIDLog v1 WITH (NOLOCK) on rv.PatientPersonSID = v1.PatientPersonSID
  where rv.RunDate > '7/1/2023'
   
   
  Update #RiskScorePopulation
  set Randomized = 2 
  where mvipersonsid in (  Select a.MVIPersonSID 
  from (   select CheckListID, MVIPersonSID,row_number() over (partition by CheckListID order by ABS(CHECKSUM(NEWID()))) as RN
   from  #newtoRVPatients
   ) as a 
  inner join (
  select * ,round(PatientsPerSite * 0.5,0) as TotalPatientsToRand 
  from (
  select CheckListID,count(MVIPersonSID) as PatientsPerSite
  from  #newtoRVPatients 
  group by CheckListID) as a
  ) as b on a.CheckListID = b.checklistid
  where RN <=TotalPatientsToRand
  )
  
  -----------------------------------------------Code to run when the rand level increases 
  --current rand level 50%
  
  /* 
--TotalPatientCount - count of all the patient eligible for reach vet at a site
--AlreadyRandomized - patients randomized by code.reach_RiskScore - either because
   -- they were randomized in a past reach run or they are new to reach and randomized
   -- based on the current ramonization level 
--RandomizedCountNextRelease - number of patients in the who should be randomized based 
   -- on the current randomization level rounded down 
--ExtraPatientsToRandomize - (RandomizedCountNextRelease-AlreadyRandomized) New patients 
   -- who need to be randomized to meet the current randomization level 
 
 
 
 --find the total number of patients - how many should be randomized and how many are aleady randomized 
 drop table if exists #PatientNumbers
  select * ,RandomizedCountNextRelease-AlreadyRandomized as ExtraPatientsToRandomize
  into  #PatientNumbers
  from (
  select a.ChecklistID, TotalPatientCount, AlreadyRandomized
                          ---Update based current ramonization level 
  , Floor(TotalPatientCount * 0.5) as RandomizedCountNextRelease
  
  from 
        (
        select ChecklistID,count(distinct rv.MVIPersonSID) TotalPatientCount
        from #RiskScorePopulation rv
        where randomized >= 1 
        group by ChecklistID
        ) as a 
  inner join 
        (
        select ChecklistID,count(distinct rv.MVIPersonSID) AlreadyRandomized
        from #RiskScorePopulation rv 
        where rv.Randomized =2
        group by ChecklistID 
        ) as b on a.checklistid = b.ChecklistID
      ) as c
    
 
   update #RiskScorePopulation  
   set Randomized = 2 
   where MVIPersonSID in (
   select mvipersonsid  
   from (   
   select rv.MVIPersonSID, rv.ChecklistID
    --gives each not randomized patient a random number
   ,row_number() over (partition by CheckListID order by ABS(CHECKSUM(NEWID()))) as RN
   from #RiskScorePopulation rv 
   --1= non radomized and eligible patients
   where randomized = 1 ) as a 
   inner join #patientnumbers as b on a.checklistid = b.checklistid      
   where RN <= b.ExtraPatientsToRandomize)
   
   
   --end increase rand code
  */
  
  -------------------------------------------Find appointments
  drop table if exists #LookUP_StopCode
SELECT StopCodeSID
	  ,StopCode
	  ,StopCodeName
	  ,Sta3n
	  ,Telephone_MH_Stop
into   #LookUP_StopCode
FROM [LookUp].[StopCode] WITH(NOLOCK)
where MHOC_MentalHealth_Stop =1

--Don't use stop codes for Cerner MH visits
DELETE #Lookup_StopCode WHERE Sta3n = 200 
-----------------------------------
--Cerner Activity types - use for visits
--------------------------------
/*MHOC MH, MHOC Homeless, MHOC GMH, MHOC HBPC, MHOC PTSD, MHOC PCT, MHOC SUD, MHOC TSES, MHOC PRRC, MHOC MHICM, MHOC PCMHI, MHOC RRTP, Reach_Homeless, 
Reach_MH, MHRecent (STORM), WHole Health
*/
Drop table if exists #LookUp_ActivityTypesMill
SELECT ItemID
	  ,AttributeValue
	  ,List
  into #LookUp_ActivityTypesMill
  FROM [LookUp].[ListMember] WITH(NOLOCK)
	WHERE Domain = 'ActivityType' and List = 'MHOC_MH'


	DROP TABLE IF EXISTS #VistaSIDs
	SELECT 
		 v.MVIPersonSID
		,v.PatientSID
		,v.VisitSID
		,v.VisitDateTime
		,v.Sta3n
		,v.PrimaryStopCodeSID
		,v.SecondaryStopCodeSID
		,v.DivisionSID
	INTO #VistaSIDs
	FROM [App].[vwOutpatWorkload_StatusShowed] v WITH(NOLOCK)
	WHERE v.VisitDateTime between dateadd(d,-30,getdate()) and getdate()  
	AND v.MVIPersonSID>0

	DROP TABLE IF EXISTS #PastAppointmentVista;
	SELECT
		 v.MVIPersonSID
		,v.PatientSID
		,v.VisitSID
		,v.VisitDateTime
		,v.Sta3n
		,d.ChecklistID
		,a.StopCode AS PrimaryStopCode
		,a.StopCodeName AS PrimaryStopCodeName
		,b.StopCode AS SecondaryStopCode
		,b.StopCodeName AS SecondaryStopCodeName
		,CASE WHEN a.Telephone_MH_Stop=1 OR b.Telephone_MH_Stop=1 THEN 0 ELSE 1 END AS F2F_CVT
	INTO #PastAppointmentVista
	FROM #VistaSIDs v WITH(NOLOCK)
	LEFT JOIN #LookUp_StopCode AS a WITH(NOLOCK) on a.StopCodeSID=v.PrimaryStopCodeSID
	LEFT JOIN #LookUp_StopCode AS b WITH(NOLOCK) on b.StopCodeSID=v.SecondaryStopCodeSID
	LEFT JOIN [LookUp].[DivisionFacility] d WITH(NOLOCK) on v.DivisionSID=d.DivisionSID
	WHERE a.StopCodeSID IS NOT NULL OR b.StopCodeSID IS NOT NULL

	DELETE FROM #PastAppointmentVista
	WHERE SecondaryStopCode = '697'
	
  
  
	DROP TABLE IF EXISTS #VistaSIDs;
  
  
  
---------------------------------
-- Cerner PAST OUTPATIENT VISITS
---------------------------------
--add in PatientSID
	--DECLARE @BeginDate Date
	--DECLARE @EndDate Date
	--SET @BeginDate=DateAdd(d,-366,getdate())
	--SET @EndDate=DateAdd(d,1,getdate())

	DROP TABLE IF EXISTS #PastAppointmentMill
	SELECT 
		 c.MVIPersonSID
		,c.PersonSID
		,c.EncounterSID
		,c.TZDerivedVisitDateTime
		,ch.ChecklistID
		,c.Location
		,ActivityType=a.AttributeValue
		,ActivityTypeCodeValueSID=a.ItemID
		,c.EncounterType
		,c.MedicalService
		,c.UrgentCareFlag as UrgentCare
		,c.EmergencyCareFlag as EmergencyCare
		,CASE WHEN c.EncounterType='Telephone' THEN 0 ELSE 1 END AS F2F_CVT
	INTO #PastAppointmentMill
	FROM [Cerner].[FactUtilizationOutpatient] c WITH(NOLOCK)
	INNER JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
		ON c.StaPa = ch.StaPa
	inner JOIN  #LookUp_ActivityTypesMill as a 
		ON a.ItemID = c.ActivityTypeCodeValueSID
	WHERE   c.TZDerivedVisitDateTime between dateadd(d,-30,getdate()) and getdate()  
	AND c.MVIPersonSID>0
	
	--Combine Vista and Mill
	DROP TABLE IF EXISTS #Visits
	SELECT DISTINCT MVIPersonsid
		,count(distinct VisitSID) as Visits
		,SUM(F2F_CVT) AS F2F_CVT --at least one visit must be face-to-face or CVT (not telephone)
	INTO #Visits 
	FROM (
		SELECT MVIPersonSID
		  ,PatientSID
		  ,VisitSID
		  ,F2F_CVT
			FROM #PastAppointmentVista v
		UNION ALL 
		SELECT c.MVIPersonSID
		  ,c.PersonSID
		  ,c.EncounterSID
		  ,F2F_CVT
			FROM #PastAppointmentMill c
) as a 
group by mvipersonsid


	DROP TABLE IF EXISTS #PastAppointmentMill
	DROP TABLE IF EXISTS #PastAppointmentVista;

  
 drop table if exists #appt
 select a.MVIPersonSID,count(distinct b.VisitSID) as Visits 
into #Appt
from #RiskScorePopulation as a 
inner join present.appointmentsFuture  as b WITH (NOLOCK) on b.MVIPersonSID = a.MVIPersonSID 
              and appointmentdatetime < getdate() + 14 
where  primarystopcode in (
	select stopcode from LookUp.StopCode sv WITH (NOLOCK)
	where sv.MHOC_MentalHealth_Stop = 1 and sv.MHOC_Homeless_Stop = 0) 
	or b.SecondaryStopCode in  (
	select stopcode from LookUp.StopCode sv WITH (NOLOCK)
	where sv.MHOC_MentalHealth_Stop = 1 and sv.MHOC_Homeless_Stop = 0) 
 group by a.MVIPersonSID

-----
drop table if exists #Engagement
select *
, 0 as DashboardPatient
into #Engagement
from (
select distinct a.ChecklistID
,a.RiskScoreSuicide
,a.RiskRanking_PriorityGroups
,a.MVIPersonSID
,a.Randomized
,DashboardCutOff as Top01CutOff
,b.Visits
,b.F2F_CVT
, case when b.Visits >=2 AND b.F2F_CVT >=1 AND c.MVIPersonSID is not null then 1 else 0 end Engaged 
from #RiskScorePopulation as a 
--inner join #Patients as p on a.ChecklistID = p.ChecklistID
left outer join #Visits as b on  b.MVIPersonSID = a.MVIPersonSID
left outer join #Appt as c on  c.MVIPersonSID = a.MVIPersonSID
---only patients eligible for care are considered in the remove replace for the dashboard
WHERE a.PriorityGroupBit = 1
) as a 

-----non randomized patients use orginal logic 
 update #Engagement
 set DashboardPatient = 1 
 where randomized = 1 and mvipersonsid in (select mvipersonsid from #RiskScorePopulation where dashboardpatient = 1 )
 
 -----randomized patients who are not engaged who would have been in dashboard with orginal logic
 update #Engagement
 set DashboardPatient = 1 
 where randomized = 2 and Engaged = 0 and mvipersonsid in (select mvipersonsid from #RiskScorePopulation where dashboardpatient = 1 )
 
 
 
 
 
drop table if exists #RemovedPatients
select a.* ,DashboardPatients
into #RemovedPatients
from #Engagement as a 
left outer join (
select checklistID , count(distinct MVIPersonSID) as DashboardPatients
from #Engagement where DashboardPatient = 1
group by ChecklistID) as b on a.ChecklistID = b.checklistid



drop table if exists #NewPatients
select distinct ChecklistID, Top01CutOff-DashboardPatients as NewPatients
Into #NewPatients
FROM #RemovedPatients

--select * from #NewPatients
 
update #Engagement 
set DashboardPatient = 1
where MVIPersonSID in (
select MVIPersonSID from (
select * ,row_number()over (partition by checklistid order by RiskRanking_PriorityGroups) as RN
from (
select checklistID,MVIPersonSID,RiskRanking_PriorityGroups,Top01CutOff-DashboardPatients as NewPatients
from #RemovedPatients
where Randomized  = 2 and isnull(Engaged,0) = 0 and RiskRanking_PriorityGroups > Top01CutOff
) as a ) as b
where RN<=NewPatients
)
 
 
 
 
 
	------------------------------------------------------------------------------------
	-- STAGE AND PUBLISH
	------------------------------------------------------------------------------------
	-- DECLARE @EndDate DATE = dateadd(day, datediff(day, 0, getdate()),0) 
	DROP TABLE IF EXISTS #staging
	SELECT 
		c.MVIPersonSID
		,c.ChecklistID
		,c.Sta3n_EHR
		,c.PatientPersonSID
		,b.RiskScoreSuicide
		,b.RiskRanking 
  --  ,B.DashboardPatient AS DashboardPatientoLD
		,ISNULL(e.DashboardPatient ,0) AS  DashboardPatient
		,b.PercRanking
		,RunDate=GetDate()
		,RunDatePatientICN=c.PatientICN
		,b.PriorityGroup
		,b.PrioritySubGroup
		,b.TopPercentAllGroups
	--	,EndDate=@EndDate
    ,case when ISNULL(e.DashboardPatient,0) <> b.DashboardPatient then 1 else 0 end ImpactedByRandomization
    ,ISNULL(e.Randomized ,-1) AS Randomized --patients without ADR eligibility recieve a -1
    ,isnull(e.Engaged,0) as Engaged
  ---MH visits past 60 days used in engagement logic
    ,isnull(e.Visits,0) as MHVisits
	INTO #staging
	FROM #cohort c
	INNER JOIN #RiskScorePopulation AS b ON c.MVIPersonSID=b.MVIPersonSID
  LEFT OUTER join #Engagement as e on c.MVIPersonSID = e.MVIPersonSID and  b.ChecklistID = e.ChecklistID
	


  EXEC [Maintenance].[PublishTable] 'Reach.Stage_RiskScore','#staging'

	EXEC [Tool].[DoBackup] 'Stage_RiskScore', 'Reach','OMHSP_PERC_CDSArchive' -- backup staging table as a reference for monthly validation

	--Clean up
	DROP TABLE #Population
	DROP TABLE #RiskRanking
	DROP TABLE #RiskScore_PriorityGroups
	DROP TABLE #RiskScorePopulation

	EXEC [Log].[Message] 'Information','Step completed','Risk computation is complete, beginning validation steps.'









	------------------------------------------------------------------------------------
	-- BEGIN VALIDATION [CODE].[REACH_RISKSCORE]
	------------------------------------------------------------------------------------

	-- There should be no one without a riskscoresuicide. 

	-- CREATE VARIABLES
	DECLARE	@ProcedureName NVARCHAR(256) = NULL
	DECLARE @ValidationType NVARCHAR(256) = NULL
	DECLARE	@Results NVARCHAR(256) = NULL
	DECLARE	@RunDate SMALLDATETIME = CAST(GETDATE() AS SMALLDATETIME)
	DECLARE	@ErrorFlag INT = 0
	DECLARE @ErrorResolution NVARCHAR(256) = NULL

	SET @ProcedureName = 'Code.REACH_RiskScore'

	-- a.Comprehensive - OK
	-- This is a confirmation that risk scores were computed for all patients
	-- and not only for new unassigned patients. A null result is correct.
	SET @ValidationType='Patients missing a risk score'
	SET @Results = 
		(
			SELECT COUNT(DISTINCT a.MVIPersonSID) AS Patients 
			FROM [REACH].[ActivePatient] a WITH (NOLOCK) -- current run with initial cohort
			LEFT JOIN [Reach].[Stage_RiskScore] b WITH (NOLOCK) ON a.PatientPersonSID = b.PatientPersonSID -- new riskscores
			LEFT JOIN [REACH].[History] d WITH (NOLOCK) ON a.MVIPersonSID = d.MVIPersonSID  -- new and previous displayed patients
			LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID=d.MVIPersonSID
			WHERE b.RiskScoreSuicide IS NULL -- where there is no riskscore
				AND mp.DateOfDeath IS NULL
		)   -- for patients that are alive 

	IF @Results > 0
		SELECT 
			@ErrorFlag = 1
			,@ErrorResolution = 'Error'
	ELSE
		SELECT 
			@ErrorFlag = 0
			,@Results = '0'
			,@ErrorResolution = 'OK';		
		
	INSERT INTO [REACH].[ReachRunResults] 
	(
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
	)
	VALUES 
	(
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,CASE 
			WHEN @Results > 0 THEN 1
			WHEN @Results = 0 OR @Results = NULL THEN 0
		END
		,@ErrorResolution
	);
	
	-- b.: Checking if we computed scores for all 'displayed' patients that are alive
	-- c. Make sure everyone confirmed AS alive has a riskscoresuicide
	---- RAS removed this - not needed with v02

	-- Make sure no rec-recruits are in the cohort -- 
	-- results should be 334 or fewer (they were reinserted because they were in reach.displayedpatient (grandfathered in) 
	-- 2021-04-14 Update: results should be 0 because they are included in active patient and get a risk score computed
	-- but they do NOT get included ON the dashboard
	SET @ValidationType = 'Rec-Recruits'
	
	DROP TABLE IF EXISTS #temp2
	
	SELECT COUNT(DISTINCT mvi.MVIPersonSID) AS 'Recruits'
	INTO #temp2
	FROM [PatSub].[SecondaryEligibility] se WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON se.PatientSID = mvi.PatientPersonSID 
	INNER JOIN 
		(
			SELECT 
				Sta3n
				,EligibilitySID
				,Eligibility
			FROM [Dim].[Eligibility] WITH (NOLOCK)
			WHERE Eligibility = 'REC-RECRUIT'
		) b 
		ON se.EligibilitySID = b.EligibilitySID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] p WITH(NOLOCK) ON p.PatientPersonSID = se.PatientSID
	INNER JOIN [REACH].[Stage_RiskScore] rs  WITH (NOLOCK) ON rs.PatientPersonSID=p.PatientPersonSID
	WHERE rs.DashboardPatient = 1

	IF EXISTS (SELECT Recruits FROM #temp2 WHERE Recruits > 0)
		SELECT 
			@ErrorFlag = 1
			,@Results = (SELECT Recruits from #temp2)
			,@ErrorResolution = 'Error';
	ELSE
		SELECT 
			@ErrorFlag = 0
			,@Results = '0'
			,@ErrorResolution = 'OK';

	INSERT INTO [REACH].[ReachRunResults]
	(
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
	)
	VALUES 
	(
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
	);	

	-- Add validation with old ActiveDuty code (just AS a double-check)
	/******** Flag ActiveDuty in order to exclude from dashboard cohort *******/
	SET @ValidationType = 'ActiveDuty'

	--Define exlusion of Active Duty
	DROP TABLE IF EXISTS #DimActiveDuty
	SELECT 
		EligibilitySID
		,Eligibility
		,EligibilityPrintName
		,Sta3n
	INTO #DimActiveDuty
	FROM [Dim].[Eligibility] WITH (NOLOCK)
	WHERE Eligibility IN 
		(
			'ACTIVE DUTY'
			,'ACTIVE DUTY - FEE FOR SERVICE'
			,'ACTIVE DUTY - MANAGED CARE'
			,'ACTIVE DUTY - SHARING'
			,'ACTIVE DUTY DOD-NON SHARING'
			,'AD-ACTIVE DUTY'
			,'ADD-ACTIVE DUTY DEPENDENT'
			,'AF EMPLOYEE'
			,'AIR NATIONAL GUARD'
			,'AIR NATIONAL GUARD-MOODY AFB'
			,'ARMY NATIONAL GUARD'
			,'DOD AIR FORCE ACTIVE DUTY'
			,'DOD AIR FORCE RESERVES'
			,'DOD ARMY ACTIVE DUTY'
			,'DOD ARMY RESERVES'
			,'DOD COAST GUARD ACTIVE DUTY'
			,'DOD COAST GUARD RESERVES'
			,'DOD DEPENDENT'
			,'DOD MARINE ACTIVE DUTY'
			,'DOD MARINE RESERVES'
			,'DOD NAVY ACTIVE DUTY'
			,'DOD NAVY RESERVES'
			,'FL ARMY NATIONAL GUARD'
			,'FORT KNOX'
			,'NAVAL AIR STATION'
			,'REC-RECRUIT'
			,'RESERVIST/CIVILIAN HAFRB'
			,'RES-RESERVIST'
			,'RETD-RETIREE DEPENDENT'
			,'SHARE AGREE 89TH RSC'
			,'SHARE AGREE AIR FORCE'
			,'SHARE AGREE ARMY'
			,'SHARE AGREE IOWA NATL GUARD'
			,'SHARE AGREE NAVY'
			,'SHARING AGREEMENT-NOAA'
			,'SHARING AGREEMENT-USPHS'
			,'SHARING DOD-AIR GUARD'
			,'SHARING DOD-ARMY GUARD'
			,'SHARING DOD-FALLON'
			,'SHARING DOD-HERLONG'
			,'SHARING DOD-STEAD'
			,'SHARING DOD-TREADMILL HERLONG'
			,'SHARING-COMBAT CLIMATOLOGY'
			,'SHARING-RECRUITER BATTALION'
			,'SOUTHCOM-SHARING AGREEMENT'
			,'ZZDOM. PATIENT(DO NOT USE)'
			,'ZZSHARING AGREEMENT-AIR FORCE'
			,'ZZSHARING AGREEMENT-ARMY'
			,'ZZSHARING AGREEMENT-COAST GU'
			,'ZZSHARING AGREEMENT-NAVY/MARIN'
			,'ZZSHARING AGREEMENT-PET'
			,'ZZTEST CODE ONLY'
		)	

	--Create cohort with the Active Duty flag
	DECLARE @ActiveDutyCount VARCHAR = 
		(
			SELECT COUNT(*) 
			FROM Reach.Stage_RiskScore c
			LEFT JOIN 
				(
					SELECT 
						c.MVIPersonSID
						,ActiveDuty = MAX(CASE WHEN dims.EligibilitySID IS NOT NULL OR dimp.EligibilitySID IS NOT NULL THEN 1 ELSE 0 END)
					FROM Reach.Stage_RiskScore c WITH (NOLOCK)
					INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
						ON c.MVIPersonSID = mvi.MVIPersonSID
					INNER JOIN [SPatient].[SPatient] sp WITH (NOLOCK)
						ON sp.PatientSID = mvi.PatientPersonSID
					LEFT JOIN [PatSub].[SecondaryEligibility] se WITH (NOLOCK)
						ON sp.PatientSID = se.PatientSID
					LEFT JOIN #DimActiveDuty dims ON dims.EligibilitySID = se.EligibilitySID 
					LEFT JOIN #DimActiveDuty dimp ON dimp.EligibilitySID = sp.EligibilitySID
					WHERE c.DashboardPatient = 1 -- no active duty patients should be included ON dashboard
					GROUP BY c.MVIPersonSID
				) ad 
				ON c.MVIPersonSID=ad.MVIPersonSID
			WHERE ActiveDuty = 1
		)
	
	SET @Results		 = @ActiveDutyCount
	SET @ErrorFlag		 = CASE WHEN @ActiveDutyCount > 0 THEN 1 ELSE 0 END
	SET @ErrorResolution = CASE WHEN @ActiveDutyCount > 0 THEN 'Error' ELSE 'OK' END

	INSERT INTO [REACH].[ReachRunResults]
	(
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
	)
	VALUES 
	(
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
	);	
	
	-- Log count of patients who do not have a valid ADRPriorityGroup who otherwise would have been ON the dashboard
	-- create a threshold for this after monitoring for some months?
	SET @ValidationType = 'TopPercentFiltered'
	
	SET @Results = 
		(
			SELECT COUNT(*) 
			FROM [REACH].[Stage_RiskScore] WITH (NOLOCK)
			WHERE TopPercentAllGroups = 1 
				AND DashboardPatient = 0
				AND NOT (PriorityGroup > 0)
		)
	SET @ErrorFlag		 = 0
	SET @ErrorResolution = 'OK'

	INSERT INTO [REACH].[ReachRunResults]
	(
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
	)
	VALUES 
	(
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
	);	

	-- COMPARE AVERAGE RISK SCORE TO PREVIOUS RELEASE AVERAGE RISK SCORE
	SET @ValidationType = 'AverageRiskScore'
	
	DECLARE @AvgCompare DECIMAL(12,10) = 
		(
			SELECT 1-(SELECT AVG(RiskScoreSuicide) FROM [REACH].[Stage_RiskScore] WITH (NOLOCK)) /
			(SELECT AVG(RiskScoreSuicide) FROM [REACH].[RiskScoreHistoric] WITH (NOLOCK) WHERE ReleaseDate = (SELECT MAX(ReleaseDate) FROM [REACH].[ReleaseDates] WITH (NOLOCK) WHERE ReleaseDate < @RunDate))
		)
	--PRINT @AvgCompare

	SET @Results		 = @AvgCompare
	SET @ErrorFlag		 = CASE WHEN @AvgCompare > 0.01 THEN 1 ELSE 0 END -- setting tolerance to 1% change in average risk score
	SET @ErrorResolution = CASE WHEN @ErrorFlag = 1 THEN 'Error' ELSE 'OK' END

	INSERT INTO [REACH].[ReachRunResults]
	(
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
	)
	VALUES 
	(
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
	);	

	-- END VALIDATION 

	DROP TABLE if exists #staging

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END