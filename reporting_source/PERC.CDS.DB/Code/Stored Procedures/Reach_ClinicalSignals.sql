/***--=============================================
Author:		Amy Robinson
Create DATE: 9/23/2024
Description:	REACH VET 2.0 variable computation 

Modifications:
	2025-01-30	LM	Added RunType to allow for a nighly run on the REACH cohort with only limited variables (as opposed to the monthly run on all patients for all variables)
	2025-2-13   AER Add monthly cohort logic and interactions from the new model
	2025-07-24  RAS Changed PDW reference ORNL_SDoH_RUCA_County to ORNL_SDoH_RUCC_County. RUCC seems to be the most recent ORNL object name based on their metadata.   
	--=============================================
*/


CREATE PROCEDURE [Code].[Reach_ClinicalSignals] 
(
	@PeriodEndDate DATE=NULL  --This is passed in at the last day of the previous month. 
	,@RunType VARCHAR(25) = NULL --Monthly OR Nightly to determine which staging table (Nightly if NULL)
)
AS
BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.Reach_ClinicalSignals' ,@Description = 'Execution of Code.Reach_ClinicalSignals'
	
	--FOR TESTING: 
        --DROP TABLE IF EXISTS #cohort DECLARE @RunType VARCHAR(25) = 'Nightly' DECLARE @PeriodEndDate DATE = '1/31/2025'
	/** Creating the cohort 
    Using patient report for nightly run (only pulling patients on the dashboard 
    Using reach active patient (entire population) for the monthly run
  **/
 
		EXEC [Log].[ExecutionBegin] 'Reach_ClinicalSignals Cohort','Creating #cohort for Reach_ClinicalSignals'

			    Drop table if exists #cohort
          CREATE TABLE #Cohort (
          [MVIPersonSID] int NOT NULL,
          [Sta3n_EHR] smallint NOT NULL,
          [ChecklistID] varchar(5) NULL,
          [PatientPersonSID] int NULL,
          [PatientICN] varchar(50) NULL)
      
				CREATE CLUSTERED INDEX [cdx_MVIPersonSID] ON #Cohort (MVIPersonSID ASC )
				WITH (SORT_IN_TEMPDB=ON, ONLINE=OFF, FILLFACTOR=100, DATA_COMPRESSION=PAGE) 
			-- The SP is called by other SPs IN CDS during the nightly OR monthly reach vet run, but for testing, 
			If @RunType = 'Nightly' 		--if this is run independently, it will use the PatientReport cohort that exists for RV
			BEGIN
  				Truncate Table #Cohort
          Insert into #cohort
  				SELECT DISTINCT a.MVIPersonSID, m.Sta3n AS Sta3n_EHR, a.ChecklistID, m.PatientPersonSID, m.PatientICN
  				FROM [REACH].[History] a WITH (NOLOCK) 
  				INNER JOIN Common.MVIPersonSIDPatientPersonSID m WITH (NOLOCK)
  					ON a.MVIPersonSID=m.MVIPersonSID
			End
      ELSE
      Begin
          Truncate Table #cohort
          Insert into #cohort
        	SELECT 
        		a.MVIPersonSID
        		,a.Sta3n_EHR
        		,a.ChecklistID
        		,a.PatientPersonSID
        		,v.MVIPersonICN AS PatientICN
        	FROM [REACH].[ActivePatient] a WITH (NOLOCK)
        	LEFT JOIN [SVeteran].[SMVIPerson] v WITH (NOLOCK)--added this join just to pull in the "RunDatePatientICN" into final table
        		ON v.MVIPersonSID=a.MVIPersonSID
      END

		EXEC [Log].[ExecutionEnd] 

		EXEC [Log].[ExecutionBegin] 'REACH.ClinicalSignals Main','Calculating main set of variables for REACH.ClinicalSignals'
	
	------------------------------------------------------------------------------------
	-- Create list of predictors and date variables and cohort --30 secs
	------------------------------------------------------------------------------------
	/********DEFINE TIME PERIOD *******/
  --for testing
	--DECLARE @PeriodEndDate DATE = '1/31/2025' DECLARE @RunType varchar(50) = 'Monthly'
	DECLARE @EndDate DATE

	IF @PeriodEndDate IS NULL 
		SET @EndDate =  dateadd(day, datediff(day, 0, getdate()),0)
		--Change default to: select DATEADD(d,1,EOMONTH(dateadd(m,-1,getdate())))
	ELSE
		SET @EndDate=@PeriodEndDate 



--Rest of the dates are calculated from the event date above
declare @EndDate30 datetime2(0)
declare @EndDate90 datetime2(0)
declare @EndDate180 datetime2(0)
declare @EndDate365 datetime2(0)
declare @EndDate730 datetime2(0)
Declare @EndDateHistoric datetime2(0)
set @EndDate30 = dateadd(day,-30,@EndDate)
set @EndDate90 = dateadd(day,-90,@EndDate)
set @EndDate180 = dateadd(day,-180,@EndDate)
set @EndDate365 = dateadd(day,-365,@EndDate)
set @EndDate730 = dateadd(day,-730,@EndDate)
set @EndDateHistoric = '1/1/2000'

--This date table is used to save the variables about so 
/** Creating Timeframes  **/
drop table if exists #date
select * ,@EndDate as EndDate ,@RunType as RunType
into #date
from (
select @EndDate as Date, '0' DateLabel ,'1' DateLabelforLead
UNION
select @EndDateHistoric as Date, '9999' DateLabel ,'9999' DateLabelforLead
UNION
select @EndDate30 as Date, '30' DateLabel ,'31' DateLabelforLead
UNION
select @EndDate90 , '90' ,'91'
UNION
select @EndDate180 , '180','181'
UNION
select @EndDate365 , '365' ,'366'
UNION
select @EndDate730 , '730','731'
) as a


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
  left outer join Config.REACH_ClinicalSignalsNightly n WITH (NOLOCK) ON n.InstanceVariable=vi.InstanceVariable
  inner join #Date as d on 1=1
  WHERE RunType='Monthly' OR ((RunType='Nightly' OR RunType IS NULL) AND n.InstanceVariable IS NOT NULL AND a.Theta>0)--limit nightly run to specific variables and only if they increase risk
 ) as a 


------------------------------Create variable table

	DROP TABLE IF EXISTS  #StageVariables
	CREATE TABLE  #StageVariables (
		MVIPersonSID INT NOT NULL
    ,VariableID int Not Null
		,Variable VARCHAR(250) NOT NULL
		,VariableValue VARCHAR(200) NULL
    ,ComputationalVariableValue decimal(18,5) not null  --need this many decimal points for the SDOH variables
		)
 

-----------------------------------------demographics --1 min

drop table if exists #demo
   SELECT a.MVIPersonSID
   ,cast(Age as varchar(50)) as Age
   ,cast(Gender as varchar (50)) Gender
   ,cast(MaritalStatus as varchar(50)) as MaritalStatus
   ,cast(OEFOIFStatus as varchar(50)) as OEFOIFStatus
   ,cast(Race as varchar(50)) as Race
   ,cast(PriorityGroup as varchar(50)) as PriorityGroup
   INTO #dEMO
   from common.masterpatient as a WITH(NOLOCK)
   inner join #Cohort as b on a.MVIPersonSID = b.MVIPERSONSID
   
   
  drop table if exists #demo_pivot
   SELECT  MVIPersonSID,Variable,VariableValue
  into #demo_pivot
   FROM #DEMO as a 
    UNPIVOT ( VariableValue 
               FOR Variable IN ( Age,Gender,MaritalStatus,OEFOIFStatus,Race,PriorityGroup) ) as a 


 INSERT INTO #StageVariables
select distinct  a.MVIPersonSID  
    , case when a.Variable = 'Age' then 1 else  b.VariableID end VariableID
		,b.Variable  
		,a.VariableValue 
    ,1
    from #demo_pivot as a 
  inner join #Predictors as b on a.variable = b.InstanceVariable
  ;
  

   INSERT INTO #StageVariables
select distinct  a.MVIPersonSID  
    , case when a.Variable = 'Age' then 1 else  b.VariableID end VariableID
		,b.Variable  
		,a.VariableValue 
    ,a.VariableValue 
    from #demo_pivot as a 
  inner join #Predictors as b on a.Variable ='AGE' and b.InstanceVariable='DateOfBirth'


  insert into #stagevariables
  select distinct MVIPersonSID,  512,'Ethnicity',a.Ethnicity,1
  from PDW.OHE_Consortium_RaceEthnicity as a WITH(NOLOCK)
  inner join #Cohort as b on a.PatientICN = b.PatientICN
  INNER JOIN #Predictors p ON p.InstanceVariable='Ethnicity'


-----------------------------------------------END Demographics
--drop temps
drop table if exists #demo
drop table if exists #demo_pivot


-----------------------------------------------Patient Record flags
drop table if exists #DateBDF
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
into #DateBDF
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  p.Variable like '%BDF%'


insert into #StageVariables
select distinct  a.MVIPERSONSID,VariableID,d.Variable,null,1 as VariableValue 
from #Cohort as a 
inner join [PRF].[Behavioral_EpisodeDates] AS h WITH (NOLOCK) on a.mvipersonsid = h.mvipersonsid
inner join #DateBDF as d 
	ON d.StartDate BETWEEN h.EpisodeBeginDateTime AND h.EpisodeEndDateTime --Episode started between start and end dates
	OR d.EndDate BETWEEN h.EpisodeBeginDateTime AND h.EpisodeEndDateTime --Episode ended between start and end dates
	OR (d.StartDate < h.EpisodeBeginDateTime AND (d.EndDate > h.EpisodeEndDateTime OR h.EpisodeEndDateTime IS NULL)) --Episode started before start date and ended after end date

-----------------------------------------------END Patient Record flags
drop table if exists #DateBDF


-----------------------------------------------END Patient Record flags
drop table if exists #DateBDF

-----------------------------------------------MST --2sec

insert into #StageVariables
select distinct b.MVIPersonSID,285,'mst_AnyYes',null,1
 FROM PatSub.[MilitarySexualTrauma] as a WITH(NOLOCK)
 inner join Common.MVIPersonSIDPatientPersonSID  as b WITH(NOLOCK) on a.PatientSID = b.PatientPersonSID
inner join #cohort as c on b.mvipersonsid = c.mvipersonsid
inner join #Predictors as p on 'mst_AnyYes' = p.Variable
where a.MilitarySexualTraumaIndicator like 'yes%'



-----------------------------------------------END MST


--------------------------------CPT --3 mins

drop table if exists #DateCPT
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when InstanceVariable like '%Naltrexone%' then 'NaltrexoneInj'
 when InstanceVariable like '%Buprenorphine%'  then 'BuprenorphineMedications'
else  replace(Replace(replace(replace(p.InstanceVariable,'CPT',''),'_',''),'Detox','Detoxification'),'Rx','')  end  as InstanceVariable
into #DateCPT
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  domain =  'CPT' or p.Variable like '%Naltrexone%' or p.Variable like 'Rx_Buprenorphine%'



-- Begin code for: CPT / Procedure / Cerner Millenium (OMHSP_PERC_Cerner.MillCDS.FactProcedure)
        drop table if exists #cernerCPT
				SELECT DISTINCT 
					c.MVIPersonSID,
          p.VariableID,
					p.Variable
        into #cernerCPT
				FROM [CERNER].[FactProcedure] s1 WITH(NOLOCK)
				INNER JOIN #Cohort c WITH (NOLOCK) ON c.PatientPersonSID = s1.PersonSID
				INNER JOIN ( 
					SELECT distinct sv.SetTerm,NomenclatureSID
					FROM [XLA].[Lib_SetValues_ALEX] sv WITH (NOLOCK)
					INNER JOIN Cerner.DimNomenclature mid WITH (NOLOCK) 
						ON sv.Value = mid.SourceIdentifier
          WHERE (sv.SetTerm in ('Detoxification' ,'Amputation','NaltrexoneInj'
          ,'BuprenorphineMedications'))
						AND sv.Vocabulary in( 'CPT','HCPCS')
					) l ON s1.NomenclatureSID = l.NomenclatureSID	
          inner join #DateCPT as p on s1.TZDerivedProcedureDateTime between p.StartDate and p.enddate
                            and p.InstanceVariable = l.setterm 
				WHERE    s1.SourceVocabulary in ('HCPCS', 'CPT4')



-- Begin code for: CPT / Procedure / VistA CDW (Outpat.VProcedure)
	DROP TABLE IF EXISTS #CPTSetTerm
	SELECT distinct sv.SetTerm , c1.*
	INTO #CPTSetTerm
		FROM XLA.Lib_SetValues_ALEX sv WITH (NOLOCK)
		inner join Dim.CPT c1 on sv.[Value] = c1.CPTCode
		WHERE  (sv.SetTerm in ('Detoxification' ,'Amputation','NaltrexoneInj','BuprenorphineMedications'))-- CHANGE THIS FOR SAMPLE RUN
			AND sv.Vocabulary in( 'CPT','HCPCS')
	
	drop table if exists #vistaCPT
	SELECT DISTINCT c.MVIPersonSID,p.VariableID,
					p.Variable
	into #vistaCPT
	FROM [Outpat].[VProcedure] s1 WITH(NOLOCK)
	INNER JOIN [Outpat].[Visit] s3 WITH (NOLOCK) ON s3.VisitSID = s1.VisitSID 
	INNER JOIN #Cohort as c WITH (NOLOCK) ON c.PatientPersonSID = s1.PatientSID
	INNER JOIN #CPTSetTerm l ON s1.CPTSID = l.CPTSID	
	inner join  #DateCPT as p on s1.EventDateTime between p.StartDate and p.enddate
		and p.InstanceVariable = l.setterm 
        
	
drop table if exists #inpatCPT
SELECT DISTINCT 
					c.MVIPersonSID,VariableID
					,p.Variable
          ,1 as VariableValue
				into #inpatCPT
				FROM Inpat.InpatientCPTProcedure s1 WITH(NOLOCK)
				inner join Inpat.Inpatient s3 WITH(NOLOCK) ON  s3.InpatientSID = s1.InpatientSID
				inner join  #Cohort  as c on c.PatientPersonSID = s1.PatientSiD
        INNER JOIN #CPTSetTerm l ON s1.CPTSID = l.CPTSID	
          inner join #DateCPT as p on s1.CPTProcedureDateTime between p.StartDate and p.enddate
                             and p.InstanceVariable = l.setterm 
 
 
 drop table if exists #XLA_CPT
 select Distinct MVIPersonSID,VariableID, Variable,null as VariableValue ,1 as ComputationalVariableValue
 into #XLA_CPT
from #vistaCPT
UNION
select MVIPersonSID,VariableID, Variable,null,1 as VariableValue from #cernerCPT
UNION
select  MVIPersonSID,VariableID, Variable,null,1 as VariableValue from #inpatCPT       
         
                
insert into #StageVariables
select Distinct *
from #XLA_CPT
where variable like '%amp%' --detox/NaltrexoneInj used in a combo variable down the line



 ---------------------------------END CPT
 --drop temps
 drop table if exists #inpatCPT
 drop table if exists #vistaCPT
 drop table if exists #DateCPT
 drop table if exists #cernerCPT
 --drop table if exists #XLA_CPT  --Not dropped - Used in the multi domain query below
     
---------------------------------Diagnosis

---See XLA Table below


------------------------------FIPS/EDOH --1 min

---------need to get OMHSP_PERC access to add to PDW
drop table if exists  #FIPS
select a.MVIPersonSID
,CountyFIPS as FIPS
--,max(a. ) over (partition by mvipersonsid) as LastDate
INTO #FIPS
from Common.MasterPatient_Contact  as a WITH(NOLOCK)
inner join #Cohort as b on a.MVIPersonSID = b.MVIPERSONSID
INNER JOIN #Predictors p ON p.Domain='SDOH' 

	CREATE CLUSTERED INDEX [cdx_FIPS] ON #FIPS (FIPS ASC )
			WITH (SORT_IN_TEMPDB=ON, ONLINE=OFF, FILLFACTOR=100, DATA_COMPRESSION=PAGE) 
		
insert into #StageVariables
select distinct * 
from (
select MVIPERSONSID,1012 as VariableID
,'rucc_MostRecent' as Variable,b.rucc as VariableValue ,b.rucc ComputationalVariableValue
from #FIPS as a 
inner join [PDW].[ORNL_SDoH_RUCC_County] as b on a.FIPS = b.FIPS
WHERE b.rucc_year = 2013 -- Amy: I set this to 2013 to match previous query, but 2023 is available now.

UNION

select MVIPERSONSID,985,'food_insr_rate' as Variable,b.food_insr_rate as VariableValue ,b.food_insr_rate
from #FIPS as a 
inner join  PDW.ORNL_SDoH_Food_Insecurity_County  
      as b WITH (NOLOCK) on a.FIPS = b.FIPS
where year = (select max(year) from PDW.ORNL_SDoH_Food_Insecurity_County WITH(NOLOCK) )  

UNION


select MVIPERSONSID,981,'median_household_income_estimate'
,b.median_household_income_estimate ,b.median_household_income_estimate
from #FIPS as a 
inner join PDW.ORNL_SDoH_Income_County
      as b  WITH (NOLOCK) on a.FIPS = b.FIPS
where year = (select max(year) from PDW.ORNL_SDoH_Income_County WITH(NOLOCK))  

UNION

select MVIPERSONSID,980,'mean_elevation_meters',b.mean_elevation_meters ,b.mean_elevation_meters
from #FIPS as a 
inner join PDW.ORNL_SDoH_Elevation_County
      as b WITH (NOLOCK) on a.FIPS = b.FIPS
 

UNION 

select MVIPERSONSID,975,'gd_rate_18up',gd_rate_18up,gd_rate_18up
from #FIPS as a 
inner join PDW.ORNL_SDoH_Education_County 
      as b WITH (NOLOCK) on a.FIPS = b.FIPS
where  year = (select max(year) from PDW.ORNL_SDoH_Education_County  WITH(NOLOCK) )  

UNION 

select MVIPERSONSID,976,'unemployment_rate', b.unemployment_rate,b.unemployment_rate
from #FIPS as a 
inner join  PDW.ORNL_SDoH_Unemployment_County
      as b WITH (NOLOCK) on a.FIPS = b.FIPS
where  year = (select max(year) from PDW.ORNL_SDoH_Unemployment_County WITH(NOLOCK) )  


UNION 

select MVIPERSONSID,977,'hsd_rate_18up',gd_rate_18up,gd_rate_18up
from #FIPS as a 
inner join PDW.ORNL_SDoH_Education_County 
      as b WITH (NOLOCK) on a.FIPS = b.FIPS
where  year = (select max(year) from PDW.ORNL_SDoH_Education_County  WITH(NOLOCK) )  
) as a 
where ComputationalVariableValue is not null


---------------------End SDOH
--drop temps 
drop table if exists #FIPS

---------------------inpat 

--------See XLA table below

 ---------------------------------------------------Lab


 ----------------------------UDS --5min

 drop table if exists #DateUDS
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when InstanceVariable = 'Phencyclidine_PCP' 
        then 'Phencyclidine (PCP)' 
         when InstanceVariable in ('Drug_Screen','Other_Opiate')
        then replace(InstanceVariable,'_',' ') 
        else InstanceVariable 
        end InstanceVariable
into #DateUDS
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  domain =  'Urine Drug Screen'
 
 
 
 update #DateUDS
set StartDate = (select  min(startdate) from #DateUDS )
where Variable like '%MostRecent%'

 

DROP TABLE IF EXISTS #UDSStep1
select
a.Sta3n
,RequestingLocationSID
,a.PatientSID
,c.MVIPersonSID
--,LabChemTestName
,cast(isnull(LabChemSpecimenDateTime,LabChemCompleteDateTime) as date) as LabDate
,a.LabChemResultValue
,a.LabChemResultNumericValue
--,LabChemSID
--,LOINCSID
--,a.LabChemTestSID
,DTGroup as UDTGroup
,Topography
,VariableID,Variable
INTO #UDSStep1
FROM Chem.LabChem as a WITH(NOLOCK)
join [PDW].[PBM_AD_DOEx_Dim_LabChemTest_DrugScreens] u WITH(NOLOCK)
       on u.labchemtestsid = a.labchemtestsid 
join dim.Topography_ehr as t WITH(NOLOCK)
       on t.Topographysid = a.TopographySID
inner join #cohort as c on a.patientsid = c.patientpersonsid
inner join #DateUDS as d on u.DTGroup = d.InstanceVariable 
        and  LabChemSpecimenDateTime between startdate and Enddate
  where (topography like '%URINE%' or topography like '%CLEAN%CATCH%' or labchemtestname like '%URINE%') -- urine only
             --and CDWPossibleTestPatientFlag <> 'Y' 
			 and PatientICN <> '*Unknown at this time*' 
;

drop table if exists #UDS_Results
select MVIPersonSID,VariableID,Variable

, Case WHEN LabChemResultValue like'<%' -- less then means not detected
							OR	LabChemResultValue like '%Negative%' 
							OR	LabChemResultValue like '%Negative%' 
							OR	LabChemResultValue like '%NEGATIVE CONFIRMED%'
							OR	LabChemResultValue like '%Negative%' 
							OR	LabChemResultValue like '%Negative%' 
							OR	LabChemResultValue like '%NEG' 
							OR	LabChemResultValue like '%Neagtive%' 
							OR	LabChemResultValue like '%Nedative%' 
							OR	LabChemResultValue like '%NEGAITVE%' 
							OR	LabChemResultValue like '%NEGATIAVE%' 
							OR	LabChemResultValue like '%NEGATVIE%' 
							OR	LabChemResultValue like '%NEGTAIVE%' 
							OR	LabChemResultValue like '%NEGTIAVE%'
							OR	LabChemResultValue like '%NEGTIVE%'
							OR	LabChemResultValue like '%NEHGATIVE%'
							OR	LabChemResultValue like '%Ngeative%'
							OR	LabChemResultValue like '%NON-DET%'
							OR	LabChemResultValue like '%None Detected%'
							OR	LabChemResultValue like '%NONE-DETECTED%'
							OR	LabChemResultValue like '%NOT DETECTED%'
							OR	LabChemResultValue like '%NOT-DETECTED%'
							OR	LabChemResultValue like 'N'
							OR	LabChemResultValue like 'ND'
							OR	LabChemResultValue like 'NEGTATIVE'
							OR	LabChemResultValue like 'NGATIVE'
							OR	LabChemResultValue like 'Undetec'
							OR	LabChemResultValue like 'NEG.'
							OR	LabChemResultValue like '%NEG%'
							OR	LabChemResultValue like 'ABSENT'
							OR	LabChemResultValue like 'N.D.' -- not detected?
							OR	LabChemResultValue like 'None Seen'
							OR	LabChemResultValue like 'None Det'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
							OR	LabChemResultValue like 'none'
						THEN 'NEGATIVE'

						WHEN	LabChemResultValue like '%***POS%'  
							OR	LabChemResultValue like '%SCREE POS%'
							OR	LabChemResultValue like 'P'
							OR	LabChemResultValue like '%SCREEN POS%'
							OR	LabChemResultValue like '>%' -- generic pattern for detected
							OR	LabChemResultValue like '%POSITIVE%'
							OR	LabChemResultValue like 'pos'
							OR	LabChemResultValue like '%Detected%' 
							OR	LabChemResultValue like 'POSITVE' 
							OR	LabChemResultValue like 'POSTIVE' 
							OR	LabChemResultValue like 'PRESUMPTIVE POS' 
							OR	LabChemResultValue like 'SCRN POS' 
							OR	LabChemResultValue like 'PRES POS' 
							OR	LabChemResultValue like '*POS'
							OR	LabChemResultValue like 'PRESUMP_POS'
							OR	LabChemResultValue like 'PRESUMPPOS'
							OR	LabChemResultValue like 'PRESUMP POS'
							OR	LabChemResultValue like 'Presumptive Pos.'
							OR	LabChemResultValue like 'SCRNPOS'
							OR	LabChemResultValue like '*POS'
							OR	LabChemResultValue like 'POS.'
							OR	LabChemResultValue like '*POS100.0'
							OR	LabChemResultValue like 'PresumptvePOS'
							OR	LabChemResultValue like 'POS=>300'
							OR	LabChemResultValue like 'POS%'
							OR	LabChemResultValue like 'PRESPOS'
							OR	LabChemResultValue like 'PRESENT'
							OR	LabChemResultValue like 'PRES_SCR_POS'
							OR	LabChemResultValue like '*POS%'
							OR	LabChemResultValue like 'PRESUMP POSITIV'
							OR	LabChemResultValue like 'Presumptive Pos%'
							OR	LabChemResultValue like '%POS'
							OR	LabChemResultValue like '%H' -- value + H - high?
							OR	LabChemResultValue like '%H)' -- value + H - high?
						--	OR	LabChemResultNumericValue >0  --can't be sure presence of numeric value means positive UDS
						THEN 'POSITIVE'

						WHEN	LabChemResultValue like 'comment' OR 
								LabChemResultValue like 'TNP' OR  --test not performed
								LabChemResultValue like 'Sent For Confirmation' OR 
								LabChemResultValue like 'pending' OR 
								LabChemResultValue like 'See Final Results' OR 
								LabChemResultValue like 'See Note' OR 
								LabChemResultValue like 'canc' OR 
								LabChemResultValue like 'SEE COMMENT' OR 
								LabChemResultValue like 'NONREPORTABLE' OR 
								LabChemResultValue like 'Reflex testing not required' OR 
								LabChemResultValue like 'N/A' OR
								LabChemResultValue like 'NULL' OR
								LabChemResultValue like 'Cancel' OR
								LabChemResultValue like 'DNR' OR
								LabChemResultValue like 'Final Results' OR
								LabChemResultValue like '%INTERFERENCE%' OR
								LabChemResultValue like 'NA' OR
								LabChemResultValue like 'NOT PERFORMED' OR
								LabChemResultValue like 'Comment:' OR
								LabChemResultValue like 'Complete' OR
								LabChemResultValue like 'Final Results' OR
								LabChemResultValue like 'SEE FINAL REPORT' OR
								LabChemResultValue like 'SEE SCANNED REPORT' OR
								LabChemResultValue like 'The presumptive screen for' OR
								LabChemResultValue like 'TNP202' OR
								LabChemResultValue like 'DNR' OR --Did not receive
								LabChemResultValue like 'NR' OR --  not received
								LabChemResultValue like 'NSER' OR --No serum received??? (maybe)
								LabChemResultValue like 'QNS' OR -- quantity not sufficient
								LabChemResultValue like 'RTP' OR  --Reflex test performed (the confirmation was performed)
								LabChemResultValue like '"SEE VISTA IMAGING FOR RESULTS"'  OR
								LabChemResultValue like 'SENT OUT FOR CONFIRM.'  OR
								LabChemResultValue like 'Conf Sent'  OR
								LabChemResultValue like 'Not Applicable'  OR
								LabChemResultValue like 'SentForConfirmation'  OR
								LabChemResultValue like 'SEENOTE'  OR
								LabChemResultValue like 'PEND_CONF'  OR
								LabChemResultValue like 'Specimen Collected'  OR
								LabChemResultValue like 'FINAL'  OR
								LabChemResultValue like 'INCONSISTENT'  OR
								LabChemResultValue like 'SEE BELOW'  OR
								LabChemResultValue like 'Pending/conf'  OR
								LabChemResultValue like 'INCONSISTENT'  OR
								LabChemResultValue like 'INCONSISTENT'  OR
								LabChemResultValue like 'INCONSISTENT'  OR
								LabChemResultValue like 'SEE LABCORP REP'  OR
								LabChemResultValue like 'PP'  OR  --John Forno - Can’t tell for sure (probably means Presumptive Positive)
								LabChemResultValue like 'CONSISTENT'  OR --John Forno - Can’t tell for sure (Could mean screen and reflex matched as positive)
								LabChemResultValue like 'PRELIM'  OR    --John Forno - Sent for reflex/confirmation testing
								LabChemResultValue like 'Reflexed'  OR   --John Forno - Sent for reflex/confirmation testing
								LabChemResultValue like 'See Interp'  OR --John Forno - Resulted as text in the comment field (I don’t think CDW picks up this field from Vista)
								LabChemResultValue like 'I'  OR         --John Forno - Can’t tell for sure (icteric, incomplete, inside normal range…)
								LabChemResultValue like 'C'  OR        --John Forno - Can’t tell for sure (collected, completed, cancelled…)
								LabChemResultValue like 'A'  OR       -- John Forno - Can’t tell for sure (abnormal, add reflex test…)
								LabChemResultValue like 'NOT'          -- John Forno - Can’t tell for sure (not ordered, not completed, not received…)
								THEN 'NA'
						ELSE NULL END VariableValue
            ,LabDate
INTO #UDS_Results
from #UDSStep1

Insert into #StageVariables
select DISTINCT MVIPersonSID,VariableID,Variable,VariableValue,1
from #UDS_Results 
where VariableValue = 'Positive' and variable not like '%mostrecent%'


Insert into #StageVariables
select DISTINCT b.MVIPersonSID,b.VariableID,b.Variable,b.VariableValue,1
from #UDS_Results as b 
inner join (
select MVIPersonSID,VariableID,Variable,max(LabDate) as LastDate
from #UDS_Results 
where variable  like '%mostrecent%'
group by MVIPersonSID,VariableID,Variable
) as a on a.mvipersonsid = b.mvipersonsid and b.LabDate = lastdate and b.Variable = a.variable
where b.VariableValue = 'Positive' 

 --------------------------------------- End Lab
--drop temps 
 drop table if exists #UDS_Results
 drop table if exists #UDSStep1
 drop table if exists #Labs1
 
 ---------------------------------------------------HF --1 sec
drop table if exists #DateHF
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
, InstanceVariable 
into #DateHF
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  domain =  'HF'
 
 
drop table if exists #healthfactor
 SELECT a.MVIPersonSID,VariableID,Variable
 into #healthfactor
 from sdh.IPV_Screen as a WITH(NOLOCK)
 inner join #cohort as c on a.MVIPersonSID = c.MVIPersonSID
 inner join #dateHF as b on b.InstanceVariable = 'InterpersonalViolence_HF' and a.ScreenDateTime between  b.startdate and b.enddate
 where screeningscore>=6 or violenceincreased=1 or choked=1 or believesmaybekilled=1


 --------------------------------------- End HF
--drop temps 
drop table if exists #DateHF
--drop table if exists #healthfactor -- Used in multi domains below
 ---------------------------------------------------MEDD --20 sec

--find dates for all possible MEDD variables 
drop table if exists #MEDDDate
select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date)), 30) AS DATE) as Date,273 VariableID , 'MEDD_0MonthPrior' as Variable
into #MEDDDate
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-1, 30) AS DATE),276 , 'MEDD_1MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-2, 30) AS DATE),277 , 'MEDD_2MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-3, 30) AS DATE),278 , 'MEDD_3MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-4, 30) AS DATE) ,279, 'MEDD_4MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-5, 30) AS DATE),280 , 'MEDD_5MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-6, 30) AS DATE),281 , 'MEDD_6MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-7, 30) AS DATE),282 , 'MEDD_7MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-8, 30) AS DATE) ,283, 'MEDD_8MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-9, 30) AS DATE),284 , 'MEDD_9MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-10, 30) AS DATE),274 , 'MEDD_10MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-11, 30) AS DATE),275 , 'MEDD_11MonthPrior'
UNION
Select CAST(DATEADD(month, DATEDIFF(month, 0, (select top 1 EndDate from #Date))-12, 30) AS DATE),1023 , 'MEDD_12MonthPrior'

---select * from config.risk_variable where variable like '%12%'
--only pull the variables which are predictors 
drop table if exists #MEDDPredictorDate
select distinct a.* 
into #MEDDPredictorDate
from #MEDDDate as a 
inner join #Predictors as b on a.Variable = b.Variable


insert into #StageVariables
select distinct MVIPERSONSID,VariableID,
Variable --,cast(VariableDate as date)
,MEDD_Month,1
from (
SELECT distinct mp.MVIPERSONSID,p.* ,

case 
when p.FiscalMonth  between 4 and 12 then cast(FiscalMonth-3 as varchar(5))
when p.FiscalMonth in (1)  then '10'
when p.FiscalMonth in (2)  then '11'
when p.FiscalMonth in (3)  then '12'
end
 +'/'+ 
case when p.FiscalMonth in (1,3,4,6,8,10,11) then '31'
when p.FiscalMonth in (12,7,9,2)  then '30'
when p.FiscalMonth in (5) and p.FiscalYear in (2016,2020,2024,2028) then '29' --leap years
when p.FiscalMonth in (5)   then '28'
end
+'/' + case 
when p.FiscalMonth in (1,2,3)  then cast(FiscalYear-1 as varchar(5)) --First 3 months of fiscal year are in previous calendar year
else cast(FiscalYear as varchar(5)) 
end  as VariableDate
FROM PDW.PBM_AD_DOEx_OSI_PatientMEDDTrend p WITH(NOLOCK)
inner join  Common.MasterPatient as mp WITH(NOLOCK) on p.patienticn = mp.patienticn
) as a
inner join  #MEDDPredictorDate as b on b.[Date] = a.VariableDate 

--select distinct variable from #StageVariables


 ---------------------------------------End MEDD

------------------------------------MHA --3 mins


--the Any Detox metric has non standard documentation and is made of CIWA COWS and CPT 
    -- cleaning up the survey anmes here to improve perfromance
drop table if exists #DateMHA
select distinct VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when p.InstanceVariable = 'CPT_Detox' then 'CIWA-AR'
when p.InstanceVariable = 'PHQ' then 'phq9'
else InstanceVariable end InstanceVariable
into #DateMHA
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  domain =  'MHA' or instancevariable = 'CPT_Detox'

insert into #DateMHA
select distinct VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when p.InstanceVariable = 'CPT_Detox' then 'CIWA-AR-'
else InstanceVariable end InstanceVariable
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  instancevariable = 'CPT_Detox'


insert into #DateMHA
select distinct VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when p.InstanceVariable = 'AUDIT-C' then 'AUDC'
else InstanceVariable end InstanceVariable
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  instancevariable = 'AUDIT-C'

insert into #DateMHA
select distinct VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case when p.InstanceVariable = 'CPT_Detox' then 'COWS'
else InstanceVariable end InstanceVariable
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where instancevariable = 'CPT_Detox'

--MHA Most Recent is looking back all time 
update #DateMHA
set StartDate = '1/1/2000'
where Variable like '%MostRecent%'


--select * from #DateMHA
--select * from #AllInstance_MHA_RawScore

drop table if exists #AllInstance_MHA_RawScore
--AUDC
select distinct  
a.MVIPersonSID,VariableID
,Variable
,RawScore as VariableValue
,mv.SurveyGivenDateTime as VariableDate
into #AllInstance_MHA_RawScore
FROM #Cohort as a
inner join OMHSP_Standard.MentalHealthAssistant_v02 mv WITH (NOLOCK) on a.MVIPersonSID = mv.MVIPersonSID
inner join #dateMHA as da on mv.SurveyGivenDatetime between da.startdate and da.enddate 
              and InstanceVariable IN ('AUDC','AUDIT-C') AND mv.display_AUDC>=0
UNION ALL
--CIWA
select distinct  
a.MVIPersonSID,VariableID
,Variable
,RawScore as VariableValue
,mv.SurveyGivenDateTime as VariableDate
FROM #Cohort as a
inner join OMHSP_Standard.MentalHealthAssistant_v02 mv WITH (NOLOCK) on a.MVIPersonSID = mv.MVIPersonSID
inner join #dateMHA as da on mv.SurveyGivenDatetime between da.startdate and da.enddate 
              and InstanceVariable IN ('CIWA-AR','CIWA-AR-') AND mv.display_CIWA>=0
UNION ALL
--COWS
select distinct  
a.MVIPersonSID,VariableID
,Variable
,RawScore as VariableValue
,mv.SurveyGivenDateTime as VariableDate
FROM #Cohort as a
inner join OMHSP_Standard.MentalHealthAssistant_v02 mv WITH (NOLOCK) on a.MVIPersonSID = mv.MVIPersonSID
inner join #dateMHA as da on mv.SurveyGivenDatetime between da.startdate and da.enddate 
              and InstanceVariable IN ('COWS') AND mv.display_COWS>=0
UNION ALL
--I9
select distinct  
a.MVIPersonSID,VariableID
,Variable
,RawScore as VariableValue
,mv.SurveyGivenDateTime as VariableDate
FROM #Cohort as a
inner join OMHSP_Standard.MentalHealthAssistant_v02 mv WITH (NOLOCK) on a.MVIPersonSID = mv.MVIPersonSID
inner join #dateMHA as da on mv.SurveyGivenDatetime between da.startdate and da.enddate 
              and InstanceVariable IN ('PHQ_Question9') AND mv.display_I9>=0
UNION ALL
--PHQ9
select distinct  
a.MVIPersonSID,VariableID
,Variable
,RawScore as VariableValue
,mv.SurveyGivenDateTime as VariableDate
FROM #Cohort as a
inner join OMHSP_Standard.MentalHealthAssistant_v02 mv WITH (NOLOCK) on a.MVIPersonSID = mv.MVIPersonSID
inner join #dateMHA as da on mv.SurveyGivenDatetime between da.startdate and da.enddate 
              and InstanceVariable IN ('PHQ9') AND mv.display_PHQ9>=0



insert into #stagevariables
select distinct MVIPersonsID,VariableID,
Variable
,case when variable not like '%question9%' then cast(VariableValue as varchar)
when VariableValue = 0 then  'Not at all'
when VariableValue = 1 then 'Several Days'
when VariableValue = 2 then 'More than half the days'
when VariableValue = 3 then 'Nearly every day' 
end VariableValue
,1 AS CompVariableValue
from (
select distinct MVIPersonsID,VariableID,
Variable
, max(VariableValue) as VariableValue, max(VariableValue) as CompVariableValue
from #AllInstance_MHA_RawScore
where Variable like '%HighestResult%' and variable not like '%MostRecent%'
group by  mvipersonsid,variableID,variable
 ) as a 

insert into #stagevariables
select distinct a.MVIPersonsID,VariableID,a.Variable
,case when a.variable not like '%question9%' then cast(VariableValue as varchar)
when VariableValue = 0 then  'Not at all'
when VariableValue = 1 then 'Several Days'
when VariableValue = 2 then 'More than half the days'
when VariableValue = 3 then 'Nearly every day' 
end VariableValue 
, 1 CompVariableValue
from #AllInstance_MHA_RawScore as a 
inner join (select mvipersonsid,variable ,Max(VariableDate) as LastDate from #AllInstance_MHA_RawScore 
group by  mvipersonsid,VariableID,variable) as b 
    on a.MVIPersonSID = b.mvipersonsid and a.variable = b.variable and a.VariableDate = lastdate
where a.variable  like '%MostRecent%' 



 ---------------------------------------End MHA 
 --drop temps
drop table if exists #questions
drop table if exists #DateMHA
drop table if exists  #i9
--drop table if exists #AllInstance_MHA_RawScore --used in multi domain



--------------------------------Non VA Meds --44secs
--non va med STARTED in the timeframe - PER ORNL's code this is the logic they used in RV3 we might want to update this

drop table if exists #DateNonVA
select VariableID,Variable,StartDate,EndDate,
case 
when CPP_Variable = 'NonPainSNRI' then 'SNRINonpain'
 when replace(replace(replace(InstanceVariable,'NonVA_RX_',''),'_Rx',''),'_','') = 'NonPainTCA' then 'TCANonPain'
 else CPP_Variable
end CPP_Variable
,case 
when InstanceVariable like '%TCA%' then 'TCA'
when InstanceVariable like '%SNRI%' then 'SNRI'
else InstanceVariable end VariableForCount 
into #DateNonVA
from (
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,replace(replace(replace(p.InstanceVariable,'NonVA_RX_',''),'_Rx',''),'_','') as CPP_Variable
,InstanceVariable
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  domain =  'nonvameds') as a 
 

  insert into #stagevariables
  select distinct b.MVIPersonsID,VariableID,a.Variable
  ,null VariableValue 
  , 1 CompVariableValue
  from #DateNonVA as a 
  inner join Present.NonVAMed as b on a.CPP_Variable = b.SetTerm and 
                     (b.InstanceFromDate between a.StartDate and a.EndDate )--started during the timeframe
                      --  or b.InstanceToDate between a.StartDate and a.EndDate --ended during the timeframe
                      --  or a.StartDate between  b.InstanceFromDate and  b.InstanceToDate) --active during the start of the timeframe
  inner join #cohort as c on b.MVIPersonSID = c.mvipersonsid
  where a.Variable not like '%total%'



--total Classes
insert into #StageVariables
SELECT DISTINCT 
	ISNULL(b.MVIPersonSID, 0) AS MVIPersonSID
  ,a.VariableID
	,a.Variable 
  ,count(distinct VariableForCount) count1
  ,count(distinct VariableForCount) count2
FROM Present.NonVAMed b WITH(NOLOCK)
inner JOIN #Cohort  mvi WITH (NOLOCK)
	ON b.mvipersonsid = mvi.mvipersonsid  
inner join #DateNonVA as a on a.CPP_Variable = b.SetTerm and 
                       (b.InstanceFromDate between a.StartDate and a.EndDate) --started during the timeframe
                        --or b.InstanceToDate between a.StartDate and a.EndDate --ended during the timeframe
                        --or a.StartDate between  b.InstanceFromDate and  b.InstanceToDate) --active during the start of the timeframe
where a.variable like '%total%'
group by variableid,variable,b.MVIPersonSID



 ---------------------------------------End NonVA Med
 
 -------------------------------Orderable item --4 mins
 drop table if exists #DateOrderable
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,p.InstanceVariable as CPP_Variable,InstanceVariable
into #DateOrderable
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  variable like '%NALTREXONE%'


DROP TABLE IF EXISTS #Orderable
SELECT OrderableItemSID
      ,OrderableItemName
      ,DisplayGroupName
INTO #Orderable
FROM dim.orderableitem as a WITH (NOLOCK) 
inner join Dim.DisplayGroup d1 on a.DisplayGroupSID = d1.DisplayGroupSID
	WHERE OrderableItemName LIKE '%NALTREXONE%'
		AND OrderableItemName NOT LIKE '%methyl%'
		AND DisplayGroupName = 'Pharmacy'
		AND OrderableItemName LIKE '%INJ%'
		AND OrderableItemName NOT LIKE '%STUDY%' 
		AND OrderableItemName NOT LIKE '%INV%'


-- Qualifying orders
DROP TABLE IF EXISTS #Qualifying_Orders
SELECT 	ISNULL(c.MVIPersonSID, 0) AS MVIPersonSID
  ,o.VariableID
	,o.Variable  
INTO #Qualifying_Orders
FROM CPRSOrder.CPRSOrder a WITH (NOLOCK)
	INNER JOIN CPRSOrder.OrderedItem  b WITH (NOLOCK) ON a.CPRSOrderSID = b.CPRSOrderSID
	INNER JOIN #Orderable e		ON e.OrderableItemSID = b.OrderableItemSID
	INNER JOIN #cohort c	ON a.PatientSID = c.PatientPersonSID
  inner join #DateOrderable as o on a.OrderStartDateTime between o.startdate and o.EndDate
	INNER JOIN Dim.VistaPackage d WITH (NOLOCK) 	ON a.VistaPackageSID = d.VistaPackageSID
	WHERE d.VistaPackage <> 'Outpatient Pharmacy'
	AND d.VistaPackage NOT LIKE '%Non-VA%' 

--CERNER?

 ---------------------------------------End Orderable item
--drop temps
drop table if exists #Orderable
--drop table if exists #Qualifying_Orders --Used in multi domain



-------------------------------Rx  --6min

--antidepressant group breakouts 
drop table if exists #DateRx
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,case 
   when p.InstanceVariable LIKE '%NonPainTCA%' then 'TCANonPain' 
  when p.InstanceVariable LIKE '%NonPainSNRI%' then 'SNRINonPain' 
  else  replace(replace(replace(p.InstanceVariable,'RX_',''),'_rx',''),'_','') end as CPP_Variable,InstanceVariable
into #DateRx
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where  Variable in ('Rx_TotalAntidepressantClasses_0to365days'
,'Rx_TotalNonOpioidPainClasses_0to365days')
or variable like 'Rx_antidepressant%'
or variable like 'Rx_Buprenorphine%' 
or variable like 'Rx_Naltrexone%'


drop table if exists #step1_VA
select distinct SetTerm ,variableID,variable ,Value as VUID , Detail as DrugNamewithDose
into #step1_VA
from XLA.Lib_SetValues_CDS as a 
inner join #DateRx as b on a.setterm = CPP_Variable


drop table if exists #LookUpDrug
select a.VUID, NationalDrugSID, DrugNameWithoutDose,SetTerm ,variableID,variable 
, case 
when Setterm like '%SNRI%'  then 'SNRI'
when  Setterm like '%TCA%'   then 'TCA'
else SetTerm
end AntiDepressantType
, SetTerm  DrugType
 into #LookUpDrug
 FROM #step1_VA as a 
 inner join lookup.nationaldrug as b WITH (NOLOCK) on a.VUID = b.VUID


--vista
drop table if exists #Fills
	SELECT  DISTINCT
					  ppsid.MVIPersonSID,d.VariableID
					  ,d.Variable
            ,AntiDepressantType
            ,  drugtype 
        into #Fills
				FROM [RxOut].[RxOutpatFill] s1  WITH(NOLOCK)
				INNER JOIN  #Cohort ppsid WITH (NOLOCK) ON ppsid.PatientPersonSID = s1.PatientSID
				INNER JOIN #LookUpDrug l ON s1.NationalDrugSID = l.NationalDrugSID
		    inner join #dateRx as d on d.variableid = l.variableid and s1.ReleaseDateTime between startdate and enddate
 
 
 --paton logic for patients with pills on hand
 insert into   #Fills
	SELECT  DISTINCT
					  ppsid.MVIPersonSID,d.VariableID
					  ,d.Variable
             ,AntiDepressantType
            ,  drugtype 
				FROM [RxOut].[RxOutpatFill] s1  WITH(NOLOCK)
				INNER JOIN  #Cohort ppsid ON ppsid.PatientPersonSID = s1.PatientSID
				INNER JOIN #LookUpDrug l ON s1.NationalDrugSID = l.NationalDrugSID
		    inner join #dateRx as d on d.variableid = l.variableid and d.variable like '%paton' and startdate between releasedatetime and dateadd(d,dayssupply,releasedatetime)
 

-- cerner
insert into   #Fills
				SELECT  DISTINCT
					 ppsid.MVIPersonSID,d.VariableID
           ,d.Variable
					  ,AntiDepressantType
            ,  drugtype 
				FROM [CERNER].[FactPharmacyOutpatientDispensed] s1 WITH(NOLOCK)
					INNER JOIN  #Cohort ppsid ON ppsid.PatientPersonSID = s1.PersonSID
				INNER JOIN #LookUpDrug l ON s1.VUID=s1.VUID
		    inner join #dateRx as d on d.variableid = l.variableid and s1.TZDerivedCompletedUTCDateTime between startdate and enddate
    
      
  
 insert into   #Fills
	SELECT DISTINCT 
					  ppsid.MVIPersonSID,d.VariableID
					  ,d.Variable
            	  ,AntiDepressantType
            ,  drugtype 
				FROM [CERNER].[FactPharmacyOutpatientDispensed] s1  WITH(NOLOCK)
				INNER JOIN  #Cohort ppsid ON ppsid.PatientPersonSID = s1.PersonSID
				INNER JOIN #LookUpDrug l ON  s1.VUID=s1.VUID
		    inner join #dateRx as d on d.variableid = l.variableid and d.variable like '%paton' and startdate between TZDerivedCompletedUTCDateTime and dateadd(d,s1.DaysSupply,TZDerivedCompletedUTCDateTime)
      
      
      
      
      
	
  insert into #StageVariables
  SELECT DISTINCT  
           MVIPersonSID,VariableID
					  ,Variable
            ,  null
             , 1
from  #Fills
where variable like 'Rx_antidepressant%'
group by   MVIPersonSID,VariableID ,Variable
           

--Count classes between CERNER and VISTA for each timeframe
	insert into #StageVariables
  SELECT DISTINCT 
					 MVIPersonSID,VariableID
					  ,Variable
            ,  count(distinct AntiDepressantType) as VariableValueForCount
             ,  count(distinct AntiDepressantType) as VariableValueForCount
from  #Fills
where variable like 'Rx_TotalAntidepressantClasses%'
       group by   MVIPersonSID,VariableID
					  ,Variable


--Count no opioid classes between CERNER and VISTA for each timeframe
	insert into #StageVariables
  SELECT DISTINCT 
					 MVIPersonSID,VariableID
					  ,Variable
            ,  count(distinct drugtype) as VariableValueForCount
             ,  count(distinct drugtype) as VariableValueForCount
from  #Fills
where variable like 'Rx_TotalNonOpioidPainClasses%'
       group by   MVIPersonSID,VariableID
					  ,Variable

 ---------------------------------------End Rx
--drop temps
drop table if exists #step1
drop table if exists #LookUpDrug
drop table if exists #dateRx
drop table if exists #Antidepress

------------------------------------------------------------standard event --2 sec
drop table if exists #DateEvent
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,replace(p.InstanceVariable,'_event','') as CPP_Variable,InstanceVariable
into #DateEvent
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where Domain ='OMHSP Standard Event'



	insert into #StageVariables
	SELECT distinct 		 a.MVIPersonSID,VariableID
					  ,Variable,null
            ,  1 as VariableValue 
            from [OMHSP_Standard].[SuicideOverdoseEvent] a WITH(NOLOCK)
		inner join  [Present].[ActivePatient]  b WITH(NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
		INNER JOIN #Cohort c ON a.MVIPersonSID=c.MVIPersonSID
    inner join #DateEvent as da on isnull(EventDateFormatted,EntryDateTime) between da.startdate and da.enddate and CPP_Variable ='SuicideAttempt'
		where  SuicidalSDV=1   
		-- EVENT TYpe = includes suicide attempts, suicide deaths, preparatory behaviors for suicide, as well as events that had possible but undetermined intent for suicide
		-- SuicidalSDV= 'clean' suicide attempts and deaths

		UNION 

		--Overdose
			SELECT distinct
     a.MVIPersonSID,VariableID
					  ,Variable,null
            ,  1 as VariableValue
     from  [OMHSP_Standard].[SuicideOverdoseEvent] a WITH(NOLOCK)
		inner join  [Present].[ActivePatient]   b WITH(NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
		INNER JOIN #Cohort c ON a.MVIPersonSID=c.MVIPersonSID
	 inner join   #DateEvent as da on isnull(EventDateFormatted,EntryDateTime) between da.startdate and da.enddate
    where  overdose=1 and SuicidalSDV=0  

 ---------------------------------------End standard event
 --drop temps 
 drop table if exists #DateEvent
 
 
 
 
------------------------------------------------------------Vitals --4.5min
 drop table if exists #Datevitals
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,replace(p.InstanceVariable,'_event','') as CPP_Variable,InstanceVariable
,Domain
into #DateVitals
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where Domain like '%Vital'
 
 update #DateVitals
 set StartDate = getdate() - 365 
 
 Drop table if exists #OH_Oxymetry
SELECT DISTINCT
MVIPersonSID
,PatientPersonSID=PersonSID
,Event
,[ClinicalEventSID]
,SIDType='ClinicalEventSID'
,[TZPerformedUTCDateTime]
,[DerivedResultValueNumeric]
,Source='OracleHealth'
,VariableID
,Variable
INTO #OH_Oxymetry
FROM
(
SELECT
 a.MVIPersonSID
,PersonSID
,Event
,[ClinicalEventSID]
,[TZPerformedUTCDateTime]
,[DerivedResultValueNumeric] 
,v.VariableID
,v.Variable
FROM #Cohort a -- cohort
INNER JOIN 	Cerner.[FactVitalSign]  b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
inner join #DateVitals as v on b.TZPerformedUTCDateTime between startdate and enddate
where ( event like '%Oxygen Saturation%' or event like '%SpO2%')
AND [DerivedResultValueNumeric] IS NOT NULL
)a


	
-- VistA  
Drop table if exists  #Vista_Oxymetry
SELECT DISTINCT 
a.MVIPersonSID		
,PatientPersonSID
,VitalCategory=VitalType
,VitalSignSID
,SIDType='VitalSignSID'
,VitalSignTakenDateTime
,[VitalResultNumeric]
,Source='VistA'
,VariableID
,Variable
INTO  #Vista_Oxymetry
FROM
(
	SELECT
a.MVIPersonSID		
,a.PatientPersonSID
,VitalType
,VitalSignSID
,[VitalResultNumeric]
,VitalSignTakenDateTime
,v.VariableID
,v.Variable
FROM #Cohort as a   -- cohort
JOIN  vital.VitalSign b  WITH (NOLOCK) ON a.PatientPersonSID = b.PatientSID
JOIN  Dim.VitalType c WITH (NOLOCK) ON b.VitalTypeSID = c.VitalTypeSID
join #DateVitals as v on b.VitalSignTakenDateTime between   v.StartDate and v.enddate
WHERE	
		 c.VitalType = 'PULSE OXIMETRY'
		AND b.VitalResultNumeric IS NOT NULL
		 )a 

drop table if exists #Oxymetry
 select *
 into #Oxymetry
 from #Vista_Oxymetry
 UNION 
 select * from #OH_Oxymetry
 
 drop table if exists #mostrecent
 select a.* 
 into #mostrecent
 from #Oxymetry as a 
 inner join (select mvipersonsid , max(a.VitalSignTakenDateTime) as LastDate 
              from #Oxymetry as a  group by mvipersonsid) as b 
      on a.MVIPersonSID = b.mvipersonsid and VitalSignTakenDateTime = lastdate
 
 
insert into #StageVariables
 select distinct A.MVIPersonSID,a.VariableID,a.Variable,avg(a.VitalResultNumeric),avg(a.VitalResultNumeric)
 from #Oxymetry as a 
 inner join #mostrecent as b on a.mvipersonsid=b.mvipersonsid and a.VitalSignTakenDateTime between
                                dateadd(hour,-24, b.VitalSignTakenDateTime) and  b.VitalSignTakenDateTime
group by A.MVIPersonSID,a.VariableID,a.Variable

 ---------------------------------------End Vitals
 drop table if exists #Vista_Oxymetry
 drop table if exists #OH_Oxymetry
 drop table if exists #Oxymetry
 drop table if exists #mostrecent
------------------------------------------------------------XLA --1.5 min

------using a different version of the XLA run for nightly and monthly run. The monthly runs have all variables nightly runs only those displayed on dashboards
	If (select top 1 RunType from #date) = 'Nightly' 		
			BEGIN
  				insert into #StageVariables
          select distinct a.MVIPersonSID,VariableID,Variable,null,1
          from XLA.[RiskNightly_Summary] as a WITH(NOLOCK) --dashboard patients and dashboard variables
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          inner join #Predictors as p on a.ExternalID = p.VariableID --and t.TimeframeEnd = p.TimeframeEnd and t.TimeframeStart = p.TimeframeStart


			End
      ELSE
      Begin
         insert into #StageVariables
          select distinct a.MVIPersonSID,VariableID,Variable,null,1
          from XLA.[RiskMonthly_Summary] as a WITH(NOLOCK) --all patients and all predictors
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          inner join #Predictors as p on a.ExternalID = p.VariableID --and t.TimeframeEnd = p.TimeframeEnd and t.TimeframeStart = p.TimeframeStart

          --interactions only need to run monthly 


          --inserting interactions which were not requested in XLA 
          insert into #StageVariables 
          select a.MVIPersonSID,1000,	'IP_Homelessness_0to730days' ,null,1 from XLA.[RiskMonthly_Summary] as a WITH (NOLOCK)
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          where  externalid in (select distinct variableid from config.risk_variable where Variable like '%IP_Homelessness%') 

          insert into #StageVariables 
          select a.MVIPersonSID,1002,	'IP_MENTAL_HEALTH_RESIDENTIAL_OTHER_0to730days' ,null,1 from XLA.[RiskMonthly_Summary] as a WITH (NOLOCK)
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          where  externalid in (select distinct variableid from config.risk_variable where Variable like '%IP_MENTAL_HEALTH_RESIDENTIAL_OTHER%') 

          insert into #StageVariables 
          select a.MVIPersonSID,1022,	'IP_SUBSTANCE_USE_RESIDENTIAL_0to730days' ,null,1 from XLA.[RiskMonthly_Summary] as a WITH (NOLOCK)
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          where  externalid in (select distinct variableid from config.risk_variable where Variable like '%IP_SUBSTANCE_USE_RESIDENTIAL%') 

      END


--Opioid short acting --1.5 sec
-----Using XLA instance level data to find patients with no short acting opioids in the past 6m/Year
drop table if exists #osa
 select distinct d.Value as VUID,d.Detail as DrugNameWithDose,NationalDrugSID
 into #OSA
 from lookup.nationaldrug as a WITH(NOLOCK)
 inner join XLA.Lib_SetValues_ALEX as d WITH(NOLOCK) on a.vuid=d.value
 left outer join XLA.Lib_SetValues_ALEX as c WITH(NOLOCK) on d.value=c.value and c.setterm in ('OpioidLongActing')
 where d.SetTerm = 'OpioidForPain' and c.value is null and d.Detail not like '%Tramadol%'

 
 
Drop table if exists #ShortActingOneYear
CREATE TABLE #ShortActingOneYear (
[mvipersonsid] int NOT NULL,
[VariableValue] int NULL)

Drop table if exists #ShortActing6m
CREATE TABLE #ShortActing6m (
[mvipersonsid] int NOT NULL,
[VariableValue] int NULL)




 
------using a different version of the XLA run for nightly and monthly run. The monthly runs have all variables nightly runs only those displayed on dashboards
	If (select top 1 RunType from #date) = 'Nightly' 		
			BEGIN
  				 --One Year
            ----Summing all the days supply from the Opioid For Pain 0-180 and 181-365 variables
              truncate table #ShortActingOneYear
              insert into #ShortActingOneYear
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , DaysSupply ,ReleaseDateTime
              from XLA.[RiskNightly_Instance]  as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join rxout.rxoutpatfill as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.RxOutpatFillSID and a.PrimaryInstanceMatchIDName = 'RxOutpatFillSID'
              inner join #osa as o on b.nationaldrugsid = o.nationaldrugsid
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611) ) as a 
              group by a.MVIPersonSID

              insert into #ShortActingOneYear
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , b.DaysSupply,b.DerivedCompletedUTCDateTime
              from XLA.[RiskNightly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join [Cerner].[FactPharmacyOutpatientDispensed] as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.DispenseHistorySID and a.PrimaryInstanceMatchIDName = 'DispenseHistorySID'
              inner join #osa as o on b.vuid = o.vuid 
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611) ) as a 
              group by a.MVIPersonSID


              --6 month
              ----Summing all the days supply from the Opioid For Pain 0-180 
              truncate table #ShortActing6m
              insert into #ShortActing6m
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , DaysSupply ,ReleaseDateTime
              from XLA.[RiskNightly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join rxout.rxoutpatfill as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.RxOutpatFillSID and a.PrimaryInstanceMatchIDName = 'RxOutpatFillSID'
              inner join #osa as o on b.nationaldrugsid = o.nationaldrugsid
              --Opioid for pain  1 year
              where ExternalID  in (611) and b.ReleaseDateTime > getdate() - 180 ) as a 
              group by a.MVIPersonSID

              ;

              insert into #ShortActing6m
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , b.DaysSupply,b.DerivedCompletedUTCDateTime
              from XLA.[RiskNightly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join  [Cerner].[FactPharmacyOutpatientDispensed] as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.DispenseHistorySID and a.PrimaryInstanceMatchIDName = 'DispenseHistorySID'
              inner join #osa as o on b.vuid = o.vuid 
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611)  and b.DerivedCompletedUTCDateTime > getdate() - 180) as a 
              group by a.MVIPersonSID

          
			End
      ELSE
      Begin
              --One Year
            ----Summing all the days supply from the Opioid For Pain 0-180 and 181-365 variables
              truncate table #ShortActingOneYear
              insert into #ShortActingOneYear
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , DaysSupply ,ReleaseDateTime
              from XLA.[RiskMonthly_Instance]  as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join rxout.rxoutpatfill as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.RxOutpatFillSID and a.PrimaryInstanceMatchIDName = 'RxOutpatFillSID'
              inner join #osa as o on b.nationaldrugsid = o.nationaldrugsid
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611) ) as a 
              group by a.MVIPersonSID

              insert into #ShortActingOneYear
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , b.DaysSupply,b.DerivedCompletedUTCDateTime
              from XLA.[RiskMonthly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join [Cerner].[FactPharmacyOutpatientDispensed] as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.DispenseHistorySID and a.PrimaryInstanceMatchIDName = 'DispenseHistorySID'
              inner join #osa as o on b.vuid = o.vuid 
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611) ) as a 
              group by a.MVIPersonSID


              --6 month
              ----Summing all the days supply from the Opioid For Pain 0-180 
              truncate table #ShortActing6m
              insert into #ShortActing6m
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , DaysSupply ,ReleaseDateTime
              from XLA.[RiskMonthly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join rxout.rxoutpatfill as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.RxOutpatFillSID and a.PrimaryInstanceMatchIDName = 'RxOutpatFillSID'
              inner join #osa as o on b.nationaldrugsid = o.nationaldrugsid
              --Opioid for pain  1 year
              where ExternalID  in (611) and b.ReleaseDateTime > getdate() - 180 ) as a 
              group by a.MVIPersonSID

              insert into #ShortActing6m
              select mvipersonsid,sum(DaysSupply)as VariableValue
              from(
              select distinct a.MVIPersonSID
              , b.DaysSupply,b.DerivedCompletedUTCDateTime
              from XLA.[RiskMonthly_Instance] as a WITH(NOLOCK)
              INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
              inner join  [Cerner].[FactPharmacyOutpatientDispensed] as b WITH(NOLOCK) on a.PrimaryInstanceMatchID = b.DispenseHistorySID and a.PrimaryInstanceMatchIDName = 'DispenseHistorySID'
              inner join #osa as o on b.vuid = o.vuid 
              --Opioid for pain 6 month 1 year
              where ExternalID  in (611)  and b.DerivedCompletedUTCDateTime > getdate() - 180) as a 
              group by a.MVIPersonSID


      END
 
 
Insert into #stageVariables
select MVIPersonSID,611 as VariableID,'OpioidShortActingSupplyPastYear' as Variable
, sum(VariableValue) as VariableValue, 1 ComputationalVariableValue
from #ShortActingOneYear
group by MVIPersonSID

;

Insert into #stageVariables
select MVIPersonSID,610 as VariableID,'OpioidShortActingSupplyPast6m' as Variable
, sum(VariableValue) as VariableValue --summing betwn cerner and vista
, 1 ComputationalVariableValue
from #ShortActing6m
group by MVIPersonSID




-----------------Length of Stays --22sec
 drop table if exists #DateInpat
select VariableID,Variable,a.[Date] as StartDate,isnull(b.[Date],c.[Date]) as EndDate
,p.InstanceVariable as CPP_Variable,InstanceVariable
,Domain
into #DateInpat
from #Predictors as p
left outer join  #date as a on a.DateLabel = abs(p.TimeframeStart)
left outer join  #date as b on b.DateLabelForLead = abs(p.TimeframeEnd)
left outer join  #date as c on c.DateLabel = abs(p.TimeframeEnd)
where Domain like '%Inpat Ux%' and
variableid in (select variableid from  reach.predictors where Strat like '%sum%')





------using a different version of the XLA run for nightly and monthly run. The monthly runs have all variables nightly runs only those displayed on dashboards
	If (select top 1 RunType from #date) = 'Nightly' 		
			BEGIN
                ----Adding up all the days the patient was admitted in each grouping 
                insert into #stageVariables
                select MVIPersonSID,VariableID,Variable,LengthOfStay,LengthOfStay
                from (
                select MVIPersonSID,VariableID,Variable, sum(datediff(d,SecondaryInstanceFromDateTime,SecondaryInstanceToDateTime)) as LengthOfStay
                from (
                select distinct a.MVIPersonSID,VariableID,Variable
                ,case when SecondaryInstanceFromDateTime < startdate then startdate else SecondaryInstanceFromDateTime end SecondaryInstanceFromDateTime
                ,case when SecondaryInstanceToDateTime > enddate then EndDate else SecondaryInstanceToDateTime end SecondaryInstanceToDateTime
                from XLA.[RiskNightly_Instance] as a WITH(NOLOCK)
                INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
                inner join #DateInpat as b WITH(NOLOCK) on a.ExternalID = b.VariableID
                where VariableName like '%itx1%' 
                ) as a 
                group by MVIPersonSID,VariableID,Variable
                ) as b
          
			End
      ELSE
      Begin
            ----Adding up all the days the patient was admitted in each grouping 
            insert into #stageVariables
            select MVIPersonSID,VariableID,Variable,LengthOfStay,LengthOfStay
            from (
            select MVIPersonSID,VariableID,Variable, sum(datediff(d,SecondaryInstanceFromDateTime,SecondaryInstanceToDateTime)) as LengthOfStay
            from (
            select distinct a.MVIPersonSID,VariableID,Variable
            ,case when SecondaryInstanceFromDateTime < startdate then startdate else SecondaryInstanceFromDateTime end SecondaryInstanceFromDateTime
            ,case when SecondaryInstanceToDateTime > enddate then EndDate else SecondaryInstanceToDateTime end SecondaryInstanceToDateTime
            from XLA.[RiskMonthly_Instance] as a WITH(NOLOCK)
            INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
            inner join #DateInpat as b WITH(NOLOCK) on a.ExternalID = b.VariableID
            where VariableName like '%itx1%' 
            ) as a 
            group by MVIPersonSID,VariableID,Variable
            ) as b

      END





 ---------------------------------------End XLA
 Drop table if exists #ShortActing6m
 Drop table if exists #ShortActingOneYear
 ------------------------------------------------------------Multi Domain --48secs
 
  --Detox = CPT + MHA 
              
insert into #StageVariables
select distinct Mvipersonsid,VariableID,Variable,null, 1 AS VariableValue
from (
select Distinct Mvipersonsid,VariableID,Variable
from #XLA_CPT
where variable like '%anydetox%' --detox is used in a combo variable down the line

UNION 

select Distinct Mvipersonsid,VariableID,Variable
from #AllInstance_MHA_RawScore
where variable like '%anydetox%' --detox is used in a combo variable down the line
) as a
 
 
 --IPV = XLA + HF
 	If (select top 1 RunType from #date) = 'Nightly' 
			BEGIN
 	        insert into #StageVariables
          select distinct * from (
          select  a.MVIPersonSID,VariableID,Variable,null as variablevalue,1 as ComputationalVariableValue 
          from XLA.[RiskNightly_Summary] as a WITH(NOLOCK)
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          inner join #Predictors as p on a.ExternalID = p.VariableID 
          where p.Variable   in ('InterpersonalViolence_0to180days','InterpersonalViolence_181to365days') --remove this where once i get the XLA output using variableID

           UNION
           
          select DISTINCT a.*,null , 1 
          from #healthfactor a
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
           ) as a 
      End
      ELSE
      Begin
          insert into #StageVariables
          select distinct * from (
          select  a.MVIPersonSID,VariableID,Variable,null as variablevalue,1 as ComputationalVariableValue 
          from XLA.[RiskMonthly_Summary] as a WITH(NOLOCK)
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
          inner join #Predictors as p on a.ExternalID = p.VariableID 
          where p.Variable   in ('InterpersonalViolence_0to180days','InterpersonalViolence_181to365days') --remove this where once i get the XLA output using variableID

           UNION
           
          select DISTINCT a.*,null , 1 
          from #healthfactor a
          INNER JOIN #cohort as c ON a.MVIPersonSID=c.MVIPersonSID
           ) as a 
      END
      
--Bup/Nalox = CPT + OrderableItem + Rx

insert into #StageVariables
select distinct * ,null,1
from (
select MVIPersonSID, VariableID,Variable
from #fills
where variable like 'Rx_bup%' or variable like 'Rx_Naltrexone%'

UNION

select   MVIPersonSID, VariableID,Variable
from #Qualifying_Orders
 
 UNION 
select   MVIPersonSID, VariableID,Variable
from #xla_cpt 
where variable like 'Rx_bup%' or variable like 'Rx_Naltrexone%'
) as a 
 

  ---------------------------------------End Multi Domain
  --drop temps 
 drop table if exists #AllInstance_MHA_RawScore
 drop table if exists #XLA_CPT
  
 --publish table 10 mins
  	--DECLARE @RunType VARCHAR(25) = 'Nightly'
	IF @RunType='Monthly' 
	BEGIN
		EXEC [Maintenance].[PublishTable] 'REACH.ClinicalSignals_Monthly','#StageVariables'
	END

	IF @RunType='Nightly' OR @RunType IS NULL
	BEGIN
		EXEC [Maintenance].[PublishTable] 'REACH.ClinicalSignals_Nightly','#StageVariables'
	END


END