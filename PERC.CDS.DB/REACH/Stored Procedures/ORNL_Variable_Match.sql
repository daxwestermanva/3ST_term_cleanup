/* =============================================
Author:		Amy Robinson
Create DATE: 2024-09-23
Description:	Only run once to convert the ORNL output to REACH Predictors
Updates:
	
============================================== */
CREATE PROCEDURE [REACH].[ORNL_Variable_Match]

AS
BEGIN 


--Clean up naming differences 
--maintain orginal ORNL names


drop table if exists #reach_ORNLOutput
select * 
into #reach_ORNLOutput
from Config.REACH_ORNLOutput


update  #reach_ORNLOutput 
set Strat = replace(Strat,'ANXIOLYTIC','NonBENZO_ANXIOLYTIC')
where Strat like '%ANXIOLYTIC' and Strat not like '%nonva%'


--update  #reach_ORNLOutput 
--set Strat = replace(Strat,'NonBENZO_','')
--where Strat like '%ANXIOLYTIC' and Strat like '%NonVA%'

update  #reach_ORNLOutput 
set Strat = replace(Strat,'AUDC','AUDIT-C')
where Strat like '%AUDC'

update  #reach_ORNLOutput 
set Strat = replace(Strat,'Eating','EatingDisorder')
where Strat like '%Eating'

update  #reach_ORNLOutput 
set Strat = replace(Strat,'Opioid_ForPain','OpioidForPain')
where Strat like '%Opioid_ForPain'

update  #reach_ORNLOutput 
set Strat = replace(Strat,'FolicAcid','Folic_Acid')
where Strat like '%FolicAcid'

update   #reach_ORNLOutput 
set Strat = replace(Strat,'1to','0to')

update   #reach_ORNLOutput 
set Strat = replace(Strat,'30to','31to')


update   #reach_ORNLOutput 
set Strat = replace(Strat,'90to','91to')


update   #reach_ORNLOutput 
set Strat = replace(Strat,'180to','181to')

update   #reach_ORNLOutput 
set Strat = replace(Strat,'CPT_Amputation','Amputation_CPT')

update   #reach_ORNLOutput 
set Strat = replace(Strat,'Rx','NonVA_Rx')
where Strat like 'nonVA%'

update   #reach_ORNLOutput 
set Strat = replace(Strat,'CIWAAR_COWS_CPT_Detox','Any_Detox')
 
update   #reach_ORNLOutput 
set Strat = replace(Strat,'food_insecurity_rate','food_insr_rate')
 
 update   #reach_ORNLOutput 
 set Strat = replace(strat,'IntimatePartnerViolence','InterpersonalViolence')

 update   #reach_ORNLOutput 
 set Strat = replace(strat,'*','__')

 update   #reach_ORNLOutput 
 set Strat = replace(strat,'Attempts_Dx__','')

 update   #reach_ORNLOutput 
 set Strat = replace(strat,'Demographics__','Demographics_')

 update   #reach_ORNLOutput 
 set Strat = replace(strat,'Dx__','')
 
  update   #reach_ORNLOutput 
 set Strat = replace(strat,'OP__','')

  update   #reach_ORNLOutput 
 set Strat = replace(strat,'IP__Discharge_','')

  update   #reach_ORNLOutput 
 set Strat = replace(strat,'IP__','IP_')

  update   #reach_ORNLOutput 
 set Strat = replace(strat,'LabVitals__','LabVitals_')
 
  update   #reach_ORNLOutput 
 set Strat = replace(strat,' ','')
 
   update   #reach_ORNLOutput 
 set Strat = replace(strat,'days_INPATIENT','days__INPATIENT')
 
    update   #reach_ORNLOutput 
 set Strat = replace(strat,'Drug_Related_SAE_366to730days__OP_Emergency_or_Urgentcare_366to730days','Drug_Related_SAE__OP_Emergency_or_Urgentcare_366to730days')
 
    update   #reach_ORNLOutput 
 set Strat = replace(strat,'_____','__')
 


--select * from   #reach_ORNLOutput where strat like '%ip%'         
--SELECT * FROM  #reach_ORNLOutput WHERE Strat LIKE '%DOH%'
--SELECT * FROM Config.Risk_VariableClinicalConcepts  AS A WHERE A.DOMAIN LIKE '%SDOH%'
--select * from #match1


drop table if exists #match1
SELECT b.InstanceVariableID,b.InstanceVariable,Domain ,Strat,theta
into #match1
FROM  #reach_ORNLOutput as a 
left outer join Config.Risk_VariableClinicalConcepts as b 
          on a.Strat like '%' + b.InstanceVariable + '%'

--select * from #match3 where strat  like '%INPATIENT_STAYS%'
drop table if exists #match2
SELECT b.InstanceVariableID,b.InstanceVariable,Domain  , a.Strat,theta
into #match2
FROM  #reach_ORNLOutput as a 
left outer join  Config.Risk_Variable as b 
          on a.Strat like '%' + replace(replace(b.Variable,'_' + isnull(Suffix,''),''),'Rx_','') + '%'
          OR (Strat LIKE '%ANY_DETOX%' AND b.Variable LIKE '%ANY%DETOX%') and b.Variable not like '%\_\_%' escape '\'
where a.Strat in (select Strat from #match1 where instancevariableid is null)



drop table if exists #match3
select  
InstanceVariableID
,InstanceVariable,Strat,theta
into #match3
from #match1
where InstanceVariableID is not null
UNION 
select 
InstanceVariableID
,InstanceVariable,Strat,theta
from #match2



--final match for all non interaction variables
drop table if exists #variableMatch
select distinct   a.InstanceVariableID,a.InstanceVariable,a.Domain
, vl.VariableID as VA_VariableID,vl.Variable as VA_Variable,vl.Suffix
,c1.Strat as ORNL_Variable,theta
into #variableMatch
from Config.Risk_VariableClinicalConcepts as a 
inner join Config.Risk_Variable vl on a.InstanceVariableID = vl.InstanceVariableID and  vl.Variable not like '%\_\_%' escape '\'
left outer join #match3 c1 on c1.InstanceVariableID = a.InstanceVariableID and (A.Domain ='sdoh' or c1.Strat like '%' + isnull(vl.Suffix,'') + '%' and c1.Strat is not null)      
where  a.Ready =1 and a.Predictor = 1 and a.REACHExcluded = 0
 
 




--manual variable match
insert into #variableMatch
select  b.InstanceVariableID,b.InstanceVariable,b.Domain
, b.VariableID as VA_VariableID,b.Variable as VA_Variable,b.Suffix
,a.Strat as ORNL_Variable,theta
from #reach_ORNLOutput as a 
inner join Config.Risk_Variable as b on b.VariableID = 1024
where strat like 'NonVAMeds_total__count__to365days_TotalNonOpioidPainClasses'

insert into #variableMatch
select  b.InstanceVariableID,b.InstanceVariable,b.Domain
, b.VariableID as VA_VariableID,b.Variable as VA_Variable,b.Suffix
,a.Strat as ORNL_Variable,theta
from #reach_ORNLOutput as a 
inner join Config.Risk_Variable as b on b.VariableID = 1025
where strat like 'NonVAMeds_total__count__to365days_TotalNonOpioidPainClasses'

insert into #variableMatch
select  b.InstanceVariableID,b.InstanceVariable,b.Domain
, b.VariableID as VA_VariableID,b.Variable as VA_Variable,b.Suffix
,a.Strat as ORNL_Variable,theta
from #reach_ORNLOutput as a 
inner join Config.Risk_Variable as b on b.VariableID = 1026
where strat like 'NonVAMeds_all__binary_0to180days_NonVA_Rx_Antidepressant'


insert into #variableMatch
select  b.InstanceVariableID,b.InstanceVariable,b.Domain
, b.VariableID as VA_VariableID,b.Variable as VA_Variable,b.Suffix
,a.Strat as ORNL_Variable,theta
from #reach_ORNLOutput as a 
inner join Config.Risk_Variable as b on b.VariableID = 1024
where strat like 'NonVAMeds_total__count__to365days_TotalAntidepressantClasses'

 
insert into #variableMatch
select  b.InstanceVariableID,b.InstanceVariable,b.Domain
, b.VariableID as VA_VariableID,b.Variable as VA_Variable,b.Suffix
,a.Strat as ORNL_Variable,theta
from #reach_ORNLOutput as a 
inner join Config.Risk_Variable as b on b.VariableID = 1029
where strat like 'NonVAMeds_all__binary_181to365days_NonVA_Rx_Antidepressant'



;


--the similarity of the instance variable names is causing an issue for these
--Gender interactions
delete from #variablematch where ORNL_variable like '%Gender_%_MostRecent__IPV__binary_%Violence__to730days' and VA_VariableID = '85' --ID for VIABLE_PREGNANCY


--Pregnancy
delete from #variablematch where ORNL_variable like '%NONVIABLE_PREGNANCY' and InstanceVariableID = '237' --ID for VIABLE_PREGNANCY

--COCAINE
delete from #variablematch where ORNL_variable = 'binary_0to365days_COCAINE_USE_DISORDER' and InstanceVariableID = '33'
delete from #variablematch where ORNL_variable = 'binary_366to730days_COCAINE_USE_DISORDER' and InstanceVariableID = '33'
delete from #variablematch where ORNL_variable = 'binary_0to365days_NON_COCAINE_STIMULANT_USE_DISORDER' and InstanceVariableID = '33'
delete from #variablematch where ORNL_variable = 'binary_366to730days_NON_COCAINE_STIMULANT_USE_DISORDER' and InstanceVariableID = '33'


--suicide related events 
delete from #variablematch where ORNL_variable = 'binary_91to365days_Suicide_Related_Events' and VA_VariableID in (67, 590)

--discharge MH variables  
delete from #variablematch where ORNL_variable = 'IP_sum_0to730days_IP_NON_MENTALHEALTH'  and VA_VariableID in (1021)
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_181to365days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER'  and VA_VariableID in (392)
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_0to30days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER' and VA_VariableID in (392)
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_181to365days_IP_SUBSTANCE_USE_RESIDENTIAL' and VA_VariableID in (402)
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_0to30days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER' and VA_VariableID =391 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_0to30days_IP_SUBSTANCE_USE_RESIDENTIAL' and VA_VariableID =401 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_31to90days_IP_CLC' and VA_VariableID =359
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_31to90days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER' and VA_VariableID =394 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_366to730days_IP_CLC' and VA_VariableID =358
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_366to730days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER' and VA_VariableID =393 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_366to730days_IP_SUBSTANCE_USE_RESIDENTIAL' and VA_VariableID =403 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_91to180days_IP_CLC' and VA_VariableID =355 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_91to180days_IP_MENTAL_HEALTH_RESIDENTIAL_OTHER' and VA_VariableID =390 
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_91to180days_IP_SUBSTANCE_USE_RESIDENTIAL' and VA_VariableID = 400 
delete from #variablematch where ORNL_variable = 'IP_sum_0to730days_IP_MENTAL_HEALTH_ACUTE_OTHER' and VA_VariableID = 1021 
delete from #variablematch where ORNL_variable = 'IP_sum_0to730days_IP_SUBSTANCE_USE_ACUTE' and VA_VariableID = 1021
delete from #variablematch where ORNL_variable = 'IP_count_Discharge_91to180days_IP_HOMELESSNESS' and VA_VariableID = 375

--MEDD 
delete from #variablematch where ORNL_variable = 'MEDD__cat_10MonthPrior_MEDD_Month_180over' and VA_VariableID =273 
delete from #variablematch where ORNL_variable = 'MEDD__cat_11MonthPrior_MEDD_Month_180over' and VA_VariableID =276
delete from #variablematch where ORNL_variable = 'MEDD__cat_11MonthPrior_MEDD_Month_20to49' and VA_VariableID =276 
delete from #variablematch where ORNL_variable = 'MEDD__cat_11MonthPrior_MEDD_Month_91to179' and VA_VariableID = 276 
delete from #variablematch where ORNL_variable = 'MEDD__cat_12MonthPrior_MEDD_Month_180over' and VA_VariableID = 277 
delete from #variablematch where ORNL_variable = 'MEDD__cat_12MonthPrior_MEDD_Month_20to49' and VA_VariableID = 277
delete from #variablematch where ORNL_variable = 'MEDD__cat_12MonthPrior_MEDD_Month_91to179' and VA_VariableID = 277 



--phq
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_0to90days_PHQ_Question9_1_SeveralDays' and VA_VariableID =292 
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_0to90days_PHQ_Question9_3_NearlyEveryDay' and VA_VariableID =292
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_366to730days_PHQ_Question9_0_NotAtAll' and VA_VariableID =294 
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_366to730days_PHQ_Question9_1_SeveralDays' and VA_VariableID = 294
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_366to730days_PHQ_Question9_2_MoreThanHalfTheDays' and VA_VariableID = 294 
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_366to730days_PHQ_Question9_3_NearlyEveryDay' and VA_VariableID = 294

delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_91to365days_PHQ_Question9_0_NotAtAll' and VA_VariableID =293
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_91to365days_PHQ_Question9_1_SeveralDays' and VA_VariableID = 293
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_91to365days_PHQ_Question9_2_MoreThanHalfTheDays' and VA_VariableID = 293 
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_91to365days_PHQ_Question9_3_NearlyEveryDay' and VA_VariableID = 293

delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_MostRecent_PHQ_Question9_0_NotAtAll' and VA_VariableID =291
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_MostRecent_PHQ_Question9_1_SeveralDays' and VA_VariableID = 291
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_MostRecent_PHQ_Question9_2_MoreThanHalfTheDays' and VA_VariableID = 291
delete from #variablematch where ORNL_variable = 'MHA__cat_HighestResult_MostRecent_PHQ_Question9_3_NearlyEveryDay' and VA_VariableID = 291

--Non VA meds
delete from #variablematch where ORNL_variable = 'NonVAMeds_all__binary_181to365days_NonVA_Rx_ALCOHOL_PHARMACOTHERAPY' and VA_VariableID = 313 
delete from #variablematch where ORNL_variable = 'NonVAMeds_all__binary_181to365days_NonVA_Rx_ANALGESIC_COMBINED' and VA_VariableID = 325

--total opioid classes
delete from #variablematch where ORNL_variable = 'Rx__count_0to365days_TotalNonOpioidPainClasses' and VA_VariableID = 307 


delete from #variablematch 
where ORNL_variable = 'NonVAMeds_all__binary_181to365days_NonVA_Rx_Antidepressant' 
and va_variable not like '%nonVA%'

delete from #variablematch 
where ORNL_variable like '%NonVA%' 
and va_variable not like '%nonVA%'

delete from  #variablematch 
where ornl_variable not like '%discharge%' 
and va_variable like '%Discharge%'



--finding the new supersets added over the summer
delete from #variablematch 
where ornl_variable = 'binary_366to730days_Drug_Related_SAE'
and va_variable not like '%Drug_Related_SAE%'


delete from #variablematch 
where ornl_variable = 'binary_0to365days_SAE_Accidents'
and va_variable not like '%SAE_Accidents%'


delete from  #variablematch 
where ornl_variable like '%NonVAMeds%TotalNonOpioidPainClasses%'
and va_variable  like '%TotalAntidepressantClasses%'
 

 
 --adding all interactions
 insert into #variablematch
  select c.InstanceVariableID,c.InstanceVariable,c.Domain,d.VariableID,d.Variable,d.Suffix,b.strat,b.theta 
 from  Config.Risk_VariableInteractions as b 
  inner join config.risk_variable as d on b.VariableID = d.variableid
  inner join Config.Risk_VariableClinicalConcepts as c on c.InstanceVariableID = d.InstanceVariableID
  where theta <> 0 
  
  
 -----matching the values to the ORNL strat
drop table if exists  #VariableValues
select Strat,theta
,case when ValueVarchar is  null 
          and ValueLow is null 
          and ValueHigh is null  then null 
      else  a.VariableValue 
  end VariableValue
,ValueLow,ValueHigh,ValueVarchar
into #VariableValues
from(
select * ,reverse(substring(reverse(Strat),0,charindex('_',reverse(strat)))) as VariableValue
from  #reach_ORNLOutput as a 
) as a 
left outer join  Config.Risk_VariableValues as b on a.VariableValue = b.VariableValue
where strat  not like '%Gender%binary%' --finds the interactions containing binary




--manually match interactions to variables 
insert into  #VariableValues
select Strat,theta,case when strat like '%female%' then 'Female'
else 'Male' 
end VariableValue,null,null
,case when strat like '%female%' then 'F'
else 'M' 
end VariableValue
from #reach_ORNLOutput  
where Strat like '%Gender%binary%' --adding the binary second pulls the interactions (which have the value in the middle instead of the end)


truncate table REACH.Predictors
insert into REACH.Predictors
select distinct o.Strat,o.theta
,b.InstanceVariableID
, b.InstanceVariable, b.VA_VariableID as VariableID,b.VA_Variable as Variable,ValueLow,ValueHigh,ValueVarchar
--into  REACH.Predictors
from Config.REACH_ORNLOutput as o
left outer join #variableMatch  as b on o.theta = b.theta 
left outer join #VariableValues as a on a.theta = o.theta
where --o.Strat like '%Gender%binary%' and
o.theta <> 0 and o.strat <> '(Intercept)'
and o.strat is not null





/*
truncate table omhsp_perc_cds.REACH.Predictors
insert into omhsp_perc_cds.REACH.Predictors
select * from omhsp_perc_cdsdev.REACH.Predictors
*/

END