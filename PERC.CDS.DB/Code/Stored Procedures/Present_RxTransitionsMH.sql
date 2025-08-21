/***-- ===========================================================================
-- Author:		<Cora Bernard>
-- Create date: <4/27/2020>
-- Description:	<Identify recent changes in psychotropic and controlled substance Rx:
					provider discontinuation, no pills on hand, or change in formulation,
					including a new Rx.> 
-- Modifications: 
		-6/10/20: CB changed NoPoH category names to _RxDisc and _RxActive; DrugChange
			refers to StrengthNumeric instead of just DrugNameWithDose; refined 
			alternating drugs; refined trial length calculation taking summed days 
			suuply into account; added additional check for NoPoH to see if previous
			release still has PoH.
		-7/17/20: CB replaced PatientICN with MVIPersonSID as grouping level
				
		--20210518 - JEB - Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
		--20210913 - AI	 - Enclave Refactoring - Counts confirmed
    --20220524 - AR - Reworking to point to MPR Rockies
-- =================================================================================
*/ 

CREATE PROCEDURE [Code].[Present_RxTransitionsMH]

AS
BEGIN


/*
	The goal here is to find all psychotropic or controlled substance Rx for which a patient has
	no pills on hand (PoH) either from a missed refill or provider discontinuation. We also flag
	recent changes (new drug, new drug formulation) in the past 100 days.

	We group by DrugNameWithoutDose when it comes to determining if there are PoH, whereas we compare
	by DrugNameWithDose when it comes to determining changes in meds. All fill histories are at the
	MVIPersonSID level. 
	
	There are alternative ways to approach this code, which have tradeoffs on clarity, processing
	time, and consistency with other tables. We ultimately decided with JT's recommendation to build
	off of MPR. MPR, however, groups at the PatientSID level, and, for Opioids, at the DrugNameWithDose
	level. Therefore, it's not a straight shot for our requirements. We begin with the MPR structure and
	use it to flag possible situations of no PoH or drug changes, and then reconstruct fill histories 
	for these qualifying MVIPersonSID/DrugNameWithoutDose pairs according to our specifications. The code 
	is clunky because we are at all times trying to perform the calculations on the minimally-sized table
	or else run-time becomes an issue when trying to debug.
	*/



	--This will be our lookup table for all nationalDrugsids of interest
	DROP TABLE IF EXISTS #RxLookup
	SELECT nationalDrugsid
		,DrugICN as DrugNameWithoutDoseICN
		,DrugNameWithDose
		,DrugNameWithoutDose
    ,DrugNameWithoutDoseSID
		,StrengthNumeric
		,RxCategory
    ,Opioid_Rx
	INTO #RxLookup
	FROM (SELECT nd.nationalDrugsid
			,DrugICN
			,DrugNameWithDose
			,DrugNameWithoutDose
      ,DrugNameWithoutDoseSID
			,StrengthNumeric
      ,Opioid_Rx
			,CASE 
				WHEN Antipsychotic_Rx = 1 THEN 'Antipsychotic_Rx'
				WHEN Antidepressant_Rx = 1 THEN 'Antidepressant_Rx'
				WHEN Benzodiazepine_Rx = 1 THEN 'Benzodiazepine_Rx'
				WHEN Sedative_zdrug_Rx = 1 THEN 'Sedative_zdrug_Rx'
				WHEN MoodStabilizer_Rx = 1 THEN 'MoodStabilizer_Rx'
				WHEN Stimulant_Rx = 1 THEN 'Stimulant_Rx'
				WHEN OpioidForPain_Rx = 1 THEN 'OpioidForPain_Rx'
				WHEN OpioidAgonist_Rx = 1 THEN 'OpioidAgonist_Rx' --include??
				WHEN CSFederalSchedule IN ( --from App.ORM_NonVAMed
						'Schedule nvmI'
						,'Schedule II'
						,'Schedule II Non-Narcotics'
						,'Schedule III'
						,'Schedule III Non-Narcotics'
						,'Schedule IV'
						,'Schedule V'
						) 
					AND Antipsychotic_Rx = 0 AND Antidepressant_Rx = 0 AND Benzodiazepine_Rx = 0
					AND Sedative_zdrug_Rx = 0 AND MoodStabilizer_Rx = 0 AND Stimulant_Rx = 0 
					AND OpioidForPain_Rx = 0 AND OpioidAgonist_Rx = 0
				  THEN 'OtherControlledSub_Rx'
				ELSE NULL
			END RxCategory
		FROM [LookUp].[NationalDrug] as nd WITH (NOLOCK)
		left outer join PDW.OIT_Rockies_DOEx_OIT_Rockies_MPR_NationalDrugLookup  as m WITH (NOLOCK)  on nd.nationalDrugsid = m.nationalDrugsid
		) a
	WHERE RxCategory IS NOT NULL


	--We can use a smaller cohort table for testing in order to minimize run time
	DROP TABLE IF EXISTS #Cohort
	--select top 100000 * 
	SELECT a.*,p.PatientPersonSID as PatientSID
	INTO #Cohort 
	FROM [Present].[SPatient] as a WITH (NOLOCK) 
	inner join  [Common].[vwMVIPersonSIDPatientPersonSID]  as p WITH (NOLOCK) on p.MVIPersonSID = a.MVIPersonSID
  
--finall all the medication trials in the last 17 months

Drop table if exists #Medications17Months
select * , max(PoHDate) over (partition by mvipersonsid,drugnamewithoutdose) as LastPoHDate
into #Medications17Months
from (
select a.MVIPersonSid, r.ProviderSID,Sta6a,r.PatientSID,RxCategory
,DrugNameWithDose,rx.DrugNameWithoutDose,rx.nationalDrugsid
,rx.DrugNameWithoutdoseSID,cast(ReleaseDatetime as date) ReleaseDate,ReleaseDatetime,DaysSupply,b.RxoutpatSID,RxoutpatfillSid
,Opioid_Rx 
,QtyNumeric
,rx.StrengthNumeric
,max(cast(ReleaseDateTime as date))  over (partition by a.mvipersonsid,rx.DrugNameWithoutDose) as LastRelease
,dateAdd(d,DaysSupply,ReleaseDatetime) As PoHDate

from #Cohort as a 
inner join rxout.rxoutpatfill as b WITH (NOLOCK) on a.patientSID = b.patientSID
inner join rxout.rxoutpat as r WITH (NOLOCK) on b.rxoutpatsid = r.rxoutpatsid
inner join #RxLookup as rx on r.nationalDrugsid = rx.nationalDrugsid   
where  b.releasedatetime > dateadd(MONTH,-17,cast(getdate() as date))
) as a 


-- patients on multiple drugs
drop table if exists  #CheckForDrugChange
select a.MVIPersonSID,a.DrugNamewithoutdose, Count(distinct a.drugnamewithdose) as DrugCount
into #CheckForDrugChange
from #Medications17Months as a 
where releasedatetime > dateadd(month,-17,cast(getdate() as date))
group by a.MVIPersonSID,a.DrugNamewithoutdose
having  Count(distinct a.drugnamewithdose) > 1

--select * from  #Medications17Months where mvipersonsid = 8770454


	--Some patients may have simultaneous or near simultaneous releases of the same DrugNameWithoutDose
	--and different DrugNameWithDose, making it look like they are almost constantly having drug changes.
	--We attempt to weed these out by looking not just comparing the current DrugNameWithDose to the 
	--PreviousDrugNameWithDose but also the DrugNameWithDose 2 and 3 releases ago. If it shows up in 
	--either case, then we assume this should not be displayed as a drug change. 
	--Note, there are many release patterns and this is hard to automate in a way that maximizes both sen-
	--sitivity and specificity. We will capture...
		--E.g., release history of ...5MG, 10MG, 5MG, 10MG. No releases will be flagged.
		--E.g., release history of ....5MG, 10MG, 5MG, 5MG, 10MG, 10MG, 5MG, 10MG. No releases will be flagged.
		--E.g., release history of ...5MG, 5MG, 5MG, 10MG, 5MG, 5MG. The 10MG release will be flagged.
	--We will miss the case where drugs alternate simultaneously between 5 and 10 to give 15MG, 
	--but then the prescriber lowers the dose to 10 and the 5s stop.
  --select * from  #DrugChanges where mvipersonsid = 4453096 
  --select * from #CheckForDrugChange  where mvipersonsid = 4453096 
  drop table if exists  #DrugChanges
  select * , row_number() over (partition by MVIpersonsid, drugnamewithoutdose order by releasedatetime desc) as RN
into #DrugChanges
from (
select * 
from (
select *

, case 
when Prev1Drug is null  then 1
when DrugNameWithDose <> Prev1Drug and Prev2Drug is null then 1   --Current Drug is <> to previous drug and the previous drug is the first in the trial
when DrugNameWithDose <> Prev1Drug and DrugNameWithDose <> Prev2Drug and  Prev3Drug is null then 1 --Current Drug is <> to previous drug and the Drug is <> to 2 drugs ago and 2 drugs ago is the first in the trial
when Prev1Date is null then 1 --Current Drug  is the first in the trial
--when DrugNameWithDose <> Prev1Drug and Prev2Drug is null then 1 
when DrugNameWithDose <> Prev1Drug and DrugNameWithDose <> Prev2Drug  and DrugNameWithDose <> Prev3Drug then 1 --
else 0 end DrugChange
from(
select a.*, PatientSID,DrugNameWithDose,RxOutpatFillSID,ReleaseDateTime,QtyNumeric,ProviderSID,RxOutpatSID
,lag(DrugNameWithDose,1) over (partition by a.MVIpersonsid,a.drugnamewithoutdose order by releasedatetime) as Prev1Drug
,lag(ReleaseDateTime,1) over (partition by a.MVIpersonsid,a.drugnamewithoutdose order by releasedatetime) as Prev1Date
,lag(DrugNameWithDose,2)over (partition by a.MVIpersonsid,a.drugnamewithoutdose order by releasedatetime) as Prev2Drug
,lag(DrugNameWithDose,3)over (partition by a.MVIpersonsid,a.drugnamewithoutdose order by releasedatetime) as Prev3Drug
from #CheckForDrugChange as a 
inner join  #Medications17Months as b on a.mvipersonsid = b.mvipersonsid and a.drugnamewithoutdose = b.drugnamewithoutdose
where a.mvipersonsid = 25790
) as a 
) as b 
where releasedatetime >= getdate () - 100
) as c

;
select * from #drugchanges where mvipersonsid = 25675390

drop table if exists #PossibleChanges
select * 
into #PossibleChanges
from (

select distinct   a.MVIPersonSID,a.PatientSID,StaffName as PrescriberName,Facility as PrescribingFacility
,a.RxoutPatSID,RxCategory,  ReleaseDate --should we rename to DateofChange
,a.DrugNameWithoutDose,a.DrugNameWithDose

,case when cast(isnull(mpr.TrialStartDateTime ,mpro.TrialStartDateTime )as date ) >= dateadd(d,-100,cast(getdate() as date) ) 
            and releasedate = cast(isnull(mpr.TrialStartDateTime ,mpro.TrialStartDateTime )as date )                  then 1 
      else isnull(DrugChange ,0) 
      end as DrugChange --drug change in the last 100 days
,case when cast(isnull(mpr.TrialStartDateTime ,mpro.TrialStartDateTime ) as date ) >= dateadd(d,-100,cast(getdate() as date) )  then 'New Start' 
      else Prev1Drug 
      end as  PreviousDrugNameWithDose
,DaysSupply
,datediff(d,ReleaseDate  , getdate()  ) as DaysSinceRelease
,case when LastPoHDate  = PoHDate and  DATEDIFF(DAY,  a.PoHDate, GETDATE()) <= 100  and  LastPoHDate  < cast(getdate() as date) then 1 else 0 end NoPoH
,case when  LastPoHDate  = PoHDate and DATEDIFF(DAY,  a.PoHDate, GETDATE()) <= 100 and   LastPoHDate  < cast(getdate() as date) and isnull(mpr.ActiveMedicationFlag,mpro.ActiveMedicationFlag) = 'False'  then 1 else 0 end NoPoH_RxDisc
,case when  LastPoHDate  = PoHDate and DATEDIFF(DAY,  a.PoHDate, GETDATE()) <= 100  and  LastPoHDate  < cast(getdate() as date) and isnull(mpr.ActiveMedicationFlag,mpro.ActiveMedicationFlag) = 'True'  then 1 else 0 end NoPoH_RxActive
,case 
when  datediff(d, a.PoHDate  , cast(getdate() as date) ) < 0 then 0  
when datediff(d, dateadd(d,a.dayssupply,LastRelease  ) , cast(getdate() as date) ) < 0 then 0 
      else datediff(d, dateadd(d,a.dayssupply,LastRelease  ) , cast(getdate() as date) ) End as DaysWithNoPoH
,isnull(mpr.MonthsInTreatment,mpro.MonthsInTreatment) as  TrialLength 
, isnull(mpr.trialstartdatetime,mpro.trialstartdatetime) as TrialStart 
from #Medications17Months  as a
inner join sstaff.sstaff as b WITH (NOLOCK) on a.ProviderSID = b.staffsid  
left outer join  lookup.sta6a as c WITH (NOLOCK) on a.sta6a = c.STA6A 
left outer join   lookup.checklistid as l WITH (NOLOCK) on c.checklistid = l.checklistid or ( a.Sta6a='*Missing*' and b.sta3n  = l.sta3n) 
left outer join #drugchanges as dc on a.RxOutpatFillSID = dc.RxOutpatFillSID 
 left outer join  PDW.OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug as mpr WITH (NOLOCK) on a.mvipersonsid = mpr.mvipersonsid  and a.Opioid_Rx = 0 
                                  and mpr.DrugNameWithoutdose = a.drugnamewithoutdose and mpr.mostrecenttrialflag = 'true'
 left outer join  PDW.OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid as mprO WITH (NOLOCK) on a.mvipersonsid = mprO.mvipersonsid  and a.Opioid_Rx = 1 
                                  and mprO.DrugNameWithdose = a.drugnamewithdose and mpro.mostrecenttrialflag = 'true'
                    
  ) as a 


drop table if exists #Final
select * 
into #Final
from #PossibleChanges
where (DrugChange=1 or NoPoH=1) 


EXEC [Maintenance].[PublishTable] 'Present.RxTransitionsMH','#Final'





END