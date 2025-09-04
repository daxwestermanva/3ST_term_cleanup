CREATE PROCEDURE [Code].[SUD_IVDU]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.SUD_IVDU','EXEC Code.SUD_IVDU'

/* 
Rules for possible IDU cohort denominator - any of these items qualify a patient for the dashboard:
1. IDU Health Factor
2. MHA Survey
3. SSP Evidence
4. Note Mentions

----------------------------------------------------------------------------
1.  IDU Health Factor 
     a. The patient has a heath factor in the past year indicating 
		current IDU in the last year

2. MHA Survey 
     a. Patient answered in the affirmative to the IDU questions in 
		the ASSIST-WHOV3 or ASSIST-NIDA in the past last year

3. SSP Evidence
     a. Patient a health factor indicating patient has used the sterile syringe
		program (SSP) in the last year or had an order placed for harm reduction

4. Note Mentions 
     a. Mentions of key terms indicting IDU extracted through national 
		language processing in the last 6 months
------------------------------------------------------------------------------

MODIFICATIONS:
-- 11-14-23		CW		Adding multiple case factors (SUD Dx, SUD Tx, HIV labs, etc) per IDU 
						workgroup request for Phase 1 roll out
-- 11-22-23		CW		Changing order of MHA Survey details for PBI display
-- 07-02-24		CW		Removing note titles and adjusting health factors based on consensus 
						decision between HHRC and SUD
-- 07-23-24		CW		Removing auto confirmation for every case factor; only providers will be
						able confirm IVDU moving forward
-- 07-29-24		CW		Removing need to confirm every year, confirmed with Karine.
-- 08-07-24		CW		Fixing bug re: syringes; Reducing columns for SUD.IDU_Rx to pull only
						information needed for PBI report
-- 9/18/2024	CW		Adding in additional wound codes - HHRC/Karine request.
--						Updating to "Abscess/Wound" label in IDUEvidence
-- 2/13/2025	CW		Updating criteria for tracking Fentanyl
--						Adding additional column to SUD.IDUCohort (ActiveHepVL)
-- 2/14/2025    CW      Re-architecting code to improve ChecklistID tracking
--						Adding Naloxone HFs and non-VA med Rx for Naloxone
-- 3/5/2025     CW	    Hotfix: Correcting bug in unexpected positive drug screen logic
-- 4/23/2025	CW		Per HHRC/OMHSUD request:
							1. Remove VHA Rx FTS orders. They should not exist and are not
							   operational options enterprise-wide.
							2. Add condom Health factor VA-SSP KIT ADD HARM RED SUPPLY CONDOMS.
							3. Add Syringe HF to be credited in IDURx output if presence of:
									VA-SSP KIT PHARMACY
									VA-SSP OTHER KIT (and comment > 0)
									VA-SSP KIT CLINIC/LOGISTICS
							4. Add Naxolone HF: VA-NALOXONE RX ORDERED
--
--
*/

	------------------------
	-- Get ChecklistID without need to use Sta3nFlag for ChecklistID tracking
	-- Pulling all encounters (Vista) in past year for non deceased patients
	-- Not limiting to workload because health factors may be entered in non-workload encounters and we don't want to exclude those encounters
	------------------------ 
	--Visit information
	DROP TABLE IF EXISTS #VistAOPChecklistID365
	SELECT DISTINCT mvi.MVIPersonSID, VisitSID, o.InstitutionSID, LocationSID, VisitDateTime, ChecklistID
	INTO #VistAOPChecklistID365
	FROM Outpat.Visit o WITH (NOLOCK)
	INNER JOIN Common.vwMVIPersonSIDPatientPersonSID m WITH (NOLOCK) on o.PatientSID=m.PatientPersonSID
	INNER JOIN Common.MasterPatient mvi WITH (NOLOCK) on m.MVIPersonSID=mvi.MVIPersonSID
	INNER JOIN Dim.Institution d on o.InstitutionSID=d.InstitutionSID
	INNER JOIN LookUp.ChecklistID ck ON d.StaPa=ck.StaPa
	WHERE o.VisitDateTime > DATEADD(DAY,-365,CAST(GETDATE() as date))
	  AND o.VisitDateTime <= GETDATE()
	  AND mvi.DateOfDeath IS NULL
		

	------------------------
	-- IDU health factors in the past year
	------------------------
	--IVDU health factors (only reference ones specific to IVDU)
	--Note: Vista only health factors until Cerner has DTAs we can use
	drop table if exists #HF
	select distinct HealthFactorType
		,HxCurrent=
			case when HealthFactorType like '%current%' or HealthFactorType like '%PRIOR%' then 'CURRENT'
			 	 when HealthFactorType like '%hx%' or HealthFactorType like '%hist%' or healthfactortype like '%past%'  or healthfactortype like '%prior%'  or healthfactortype like '%h/o%'  then 'HISTORY'
				 else 'CURRENT' end 
		,a.HealthFactorTypeSID
	INTO #HF
	from Dim.HealthFactorType as a WITH (NOLOCK)
	where HealthFactorType in
	('HEP C IVDU',
	 'HEP C RISK - PAST IVDU',
	 'HEPC CURRENT IVDA', 
	 'HIV CURRENT IVDA', 
	 'HX OF IVDU/INTRANASAL COCAINE',
	 'HEP C RISK - CURRENT IV DRUG USE', 
	 'HEP C RISK - PAST IV DRUG USE', 
	 'HEP C RISK ILLICIT IV DRUG USE', 
	 'HETRO IV DRUG USER', 
	 'HF PCC NOTE - IV DRUG/ILLICIT DRUG USE', 
	 'HIV RISK INJECTION DRUG USE', 
	 'HX OF ILLEGAL IV DRUG USE', 
	 'IV DRUG USE', 
	 'IV DRUG USE YES, MID', 
	 'IV DRUG USE, MID', 
	 'NP-RED H/O IV DRUG USE', 
	 'ONGOING IV/NASAL DRUG USE',
	 'PRIOR OR CURRENT IV DRUG USE',
	 'RISK FACTOR - IV DRUG USE',
	 'SSTI IV DRUG USE',
	 'HCV RISK: INTRAVENOUS DRUG USE', 
	 'PAST INTRAVENOUS DRUG USE', 
	 'PRESENT INTRAVENOUS DRUG USE',
	 'ILLEGAL DRUG ROUTE - INJECTED',
	 --'VA-OVERDOSE SUD RF-INJECTION DRUG USE' --remove per Karine (7/2/2024)
	 'INJECTABLE DRUG USE',
	 --'BIR ANES NB INJECTION DRUG' --this is actually about ANESTHESIA 
	 'HX OF ILLEGAL IV DRUG USE'
	);


	drop table if exists #HealthFactor  
	select ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n), p.MVIPersonSID, HealthFactorType, HxCurrent, HealthFactorDateTime, Comments 
	into #HealthFactor
	from HF.HealthFactor as a WITH (NOLOCK)
	inner join #HF as b WITH (NOLOCK) on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on a.PatientSID = p.PatientPersonSID
	left join #VistAOPChecklistID365 ck on a.VisitSID=ck.VisitSID
	where healthfactordatetime > getdate() - 365;


	------------------------
	-- SSP evidence in the past year
	------------------------
	--SSP related health factors
	drop table if exists #HFSSP 
	select distinct HealthFactorType, a.HealthFactorTypeSID
	INTO #HFSSP
	from Dim.HealthFactorType as a WITH (NOLOCK)
	where HealthFactorType in ('VA-SSP IDU', 'VA-SSP KIT PHARMACY')


	drop table if exists #HealthFactorSSP 
	select ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n),p.MVIPersonSID,HealthFactorType,HealthFactorDateTime,Comments 
	into #HealthFactorSSP
	from HF.HealthFactor as a WITH (NOLOCK)
	inner join #HFSSP as b on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on a.PatientSID = p.PatientPersonSID
	left join #VistAOPChecklistID365 ck on a.VisitSID=ck.VisitSID
	where healthfactordatetime > getdate() - 365;
 

	--Harm reduction
	drop table if exists #HarmReduction 
	select st.ChecklistID, MVIPersonSID,LocalDrugNameWithDose ,a.Rxoutpatsid,Sig,a.IssueDate
	into #HarmReduction
	from RxOut.RxOutpat as a  WITH (NOLOCK)
	inner join RxOut.RxOutpatSig as s  WITH (NOLOCK) on a.RxOutpatSID = s.RxOutpatSID
	inner join Common.MVIPersonSIDPatientPersonSID as c  WITH (NOLOCK) on a.PatientSID = c.PatientPersonSID
	inner join Dim.LocalDrug as d  WITH (NOLOCK) on a.LocalDrugSID = d.LocalDrugSID
	inner join lookup.sta6a as st  WITH (NOLOCK) on a.Sta6a = st.Sta6a
	where a.IssueDate > getdate() - 365
	and (sig like '%harm RED%' or LocalDrugNameWithDose like '%harm REDUCTION%');


	--Combine, indication of any SSP
	drop table if exists #AnySSP 
	select distinct ChecklistID,Mvipersonsid, ReferenceDateTime=HealthFactorDateTime
	into #AnySSP
	from #HealthFactorSSP as a 

	UNION

	select distinct ChecklistID,MVIPersonSID ,A.IssueDate
	from #HarmReduction AS A 
	where LocalDrugNameWithDose like '%needle%' OR 
		  LocalDrugNameWithDose like '%syr%' OR
		  LocalDrugNameWithDose like '%SHARPS DISPOSAL%' OR
		  LocalDrugNameWithDose like '%ALCOHOL PREP PAD%' OR
		  LocalDrugNameWithDose like '%COTTON BALL%';
 

 	------------------------
	-- MHA Survey in the past year
	------------------------
	--Find surveys where injections were endorsed
	drop table if exists #Survey
	SELECT distinct *
	into #Survey
	FROM Dim.SurveyQuestion as a  WITH (NOLOCK)
	where SurveyQuestionText like '%injec%';


	drop table if exists #SurveyAnswer 
	select  distinct p.MVIPersonSID,ChecklistID=ISNULL(ck.ChecklistID,an.Sta3n), an.SurveyGivenDateTime, an.SurveyName, SurveyQuestionText,SurveyChoiceText
	into #SurveyAnswer
	from MH.SurveyAnswer as an  WITH (NOLOCK) 
	inner join MH.SurveyAdministration ad WITH (NOLOCK) on an.SurveyAdministrationSID=ad.SurveyAdministrationSID and an.PatientSID=ad.PatientSID
	left outer join Dim.SurveyChoice as a  WITH (NOLOCK) on an.SurveyChoiceSID = a.SurveyChoiceSID
	inner join #Survey as b WITH (NOLOCK) on an.SurveyQuestionSID = b.SurveyQuestionSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on ad.PatientSID = p.PatientPersonSID
	left join #VistAOPChecklistID365 ck on p.MVIPersonSID=ck.MVIPersonSID 
										   and ad.LocationSID=ck.LocationSID 
										   and cast(an.SurveyGivenDateTime as date)=cast(ck.VisitDateTime as date)
	where an.surveygivendatetime > getdate() - 365
	and SurveyChoiceText in ('Fewer than 3 days in a row','Three or more days in a row','Yes, but not in the past 3 months','Yes, in the past 3 months');
 
	
	----------------all together 
	drop table if exists #Cohort 
	select CheckListID,MVIPersonSID,Confirmed,InSSP,Max(InclusionDate) over (partition by mvipersonsid) as LastInclusionDate
	into #Cohort
	from (
	select distinct 
	CheckListID,MVIPersonSID, 0 as Confirmed  ,'Uses SSP: NO ' AS InSSP, a.SurveyGivenDateTime as InclusionDate
	from #SurveyAnswer as a 

	UNION 

	select distinct CheckListID, MVIPersonSID, 0 as Confirmed 
	,'Uses SSP: NO '  AS InSSP,a.HealthFactorDateTime
	from #HealthFactor as a 
	where HxCurrent = 'Current' 

	UNION 

	select distinct CheckListID, MVIPersonSID, 0 as Confirmed 
	,'Uses SSP: NO '   AS InSSP,ReferenceDateTime
	from #AnySSP as a 
	) as b ;


	------------------------
	-- Note Mentions  in the past 6 months
	------------------------
	insert into #Cohort
	select distinct 
	Checklistid, MVIPersonSID , 0 as Confirmed  ,'Uses SSP: NO '  AS InSSP
	,Max(ReferenceDateTime) over (partition by mvipersonsid) as LastReference
	from Present.NLP_Variables nv 
	where concept='IDU' and nv.ReferenceDateTime > getdate() -180; -- and stapc is null
	

	-- Prepping cohort for below steps, before finalizing
	update #Cohort 
	set InSSP = 'Uses SSP: Yes' where mvipersonsid in (select mvipersonsid from #Anyssp);


		/*
		- Commenting this section out per HHRC request (7/2024)... 
		- Confirmations will only occur by providers moving forward
		- Leaving in code for now in case there are portions they wish 
		  to auto-confirm in the future
		*/

		--update #Cohort 
		--set Confirmed = 1  where mvipersonsid in 
		--(select mvipersonsid from #Anyssp
		--UNION 
		--select mvipersonsid from #HealthFactor
		--UNION 
		--select mvipersonsid from #SurveyAnswer
		--);


	------------------------
	-- Updating cohort based on writeback data
	------------------------
	select *
	into #MostRecentWriteback
	from (
	select mvipersonsid,ExecutionDate,Confirmed
	,max(ExecutionDate) over (partition by mvipersonsid) as LastDate
	from [SUD].[IDU_Writeback] 
	--where ExecutionDate > getdate() - 365, 7/29/2024: Confirmed with Karine that there's no need to re-confirm every year
	) as a 
	where lastdate = ExecutionDate;

	update #cohort
	set Confirmed = 1 
	where mvipersonsid in (
		  select mvipersonsid 
		  from #MostRecentWriteback
		  where Confirmed=1) ;

	--find patients with a removal writeback more recently than any inclusion criteria 
	select A.MVIPERSONSID
	into #RemovedByProviders
	from #cohort as a 
	inner join #MostRecentWriteback as b 
		--This accounts for instances where a provider has removed a Veteran from IVDU
		--cohort, but new evidence has been recorded. Clinically, providers will
		--need to re-review the new evidence and either re-remove, or newly confirm.
		on a.mvipersonsid = b.mvipersonsid and b.ExecutionDate >= LastInclusionDate 
	where b.confirmed = 0 ;

	--change Confirmed from 0 to -1 for instances where a provider has removed a Veteran 
	--from IVDU cohort and no new evidence has been recorded.
	update #cohort
	set Confirmed = -1 
	where mvipersonsid in (SELECT MVIPERSONSID FROM #RemovedByProviders);


	------------------------
	-- Moving forward with final/set cohort for data run
	------------------------
	--Find unexpected positive drug screens
	drop table if exists #PositiveResults
	select a.*
	into #PositiveResults
	from Present.UDSLabResults as a WITH (NOLOCK)
	inner join #Cohort as b on a.MVIPersonSID = b.mvipersonsid
	where LabScore = 1;

	select a.MVIPersonSID,a.LabGroup,a.LabDate, count(distinct b.LabDate) as Neg
	into #MoreRecentNeg
	from #PositiveResults as a 
	left outer join (select a.MVIPersonSID,LabDate,LabGroup
					from Present.UDSLabResults as a  WITH (NOLOCK) 
					where LabScore=0) as b --finding negative results (use for count of negative results after most recent positive result)
					on a.MVIPersonSID = b.MVIPersonSID
					and a.LabGroup = b.LabGroup and a.LabDate < b.LabDate
	group by a.MVIPersonSID,a.LabGroup,a.LabDate;


	------------------------
	--Lookup Table for + Drugs Screen
	--Find instances where + Drug Screen is not expected
	------------------------
	drop table if exists #PosIVD
	select distinct  
	a.ChecklistID,a.MVIPersonSID,a.LabDate
	,a.PrintNameLabResults as  LabChemResultNumericValue
	,a.LabGroup as UDTGroup
	,Neg
	into #PosIVD
	from #PositiveResults as a 
	left outer join #MoreRecentNeg as b on a.mvipersonsid = b.mvipersonsid 
			  and a.labgroup = b.labgroup and a.labdate = b.labdate
	Where a.LabGroup in ( 'heroin','cocaine','Amphetamine','Oxycodone','Hydromorphone','Fentanyl');
	
	--finding positive labs re: 'Oxycodone','Hydromorphone','Fentanyl' where associated DrugNameWithoutDose wasn't found as expected
	drop table if exists #PosIVDo
	select a.*,d.drugnamewithoutdose 
	into #PosIVDo
	from #PosIVD as a 
	left outer join (select MVIPersonSID, PatientSID,DrugNameWithoutDose,IssueDate
				from rxout.rxoutpat as b  WITH (NOLOCK)
				inner join lookup.NationalDrug as c WITH (NOLOCK) on b.nationaldrugSID = c.nationaldrugSID
				inner join Common.MVIPersonSIDPatientPersonSID as m WITH (NOLOCK) on b.patientsid = m.PatientPersonSID
				where issuedate > getdate() -730 and  c.PrimaryDrugClassCode = 'CN101' ) as d --getting DrugNameWithoutDose associated with an opioid
						  on a.MVIPersonSID = d.MVIPersonSID 
						  and issuedate BETWEEN dateadd(d,-365,LabDate) AND dateadd(d,-1,a.LabDate) --checking to see if issue date for DrugNameWithoutDose happened between a year before the lab date and a day before the positive lab
						  and a.UDTGroup in ('Oxycodone','Hydromorphone','Fentanyl')
	where d.mvipersonsid is null; --pulls only patients with a pos lab and no medication/DrugNameWithoutDose released before that lab that would cause positive screen within the year
	
	drop table if exists #PosIVD2
	select a.*,e.DrugNameWithoutdose as AMPHETAMINE
	into #PosIVD2
	from #PosIVDo as a 
	left outer join (select MVIPersonSID, PatientSID,DrugNameWithoutDose ,IssueDate
				from rxout.rxoutpat as b  WITH (NOLOCK)
				inner join  lookup.NationalDrug as c WITH (NOLOCK) on b.nationaldrugSID = c.nationaldrugSID
				inner join Common.MVIPersonSIDPatientPersonSID as m WITH (NOLOCK) on b.patientsid = m.PatientPersonSID
				where issuedate > getdate() -730 and StimulantADHD_Rx=1 ) as e --getting DrugNameWithoutDose associated with a stimulant
						  on a.MVIPersonSID = e.MVIPersonSID 
						  and issuedate BETWEEN dateadd(d,-365,LabDate) AND dateadd(d,-1,a.LabDate) --checking to see if issue date for DrugNameWithoutDose happened between a year before the lab date and a day before the positive lab
						  and a.UDTGroup in ('AMPHETAMINE')
	where e.mvipersonsid is null;  --pulls only patients with a pos lab and no medication/DrugNameWithoutDose released before that lab that would cause positive screen within the year


	------------------------
	--Get list of IDU and SUD related Dx
	------------------------
	--SUD Dx
	DROP TABLE IF EXISTS #SUDDx 
	SELECT DISTINCT d.MVIPersonSID
		,d.ChecklistID
		,SUDDx=1
		,d.ICD10Code
		,v.ICD10Description
		,d.MostRecentDate
		,row_number() over (partition by m.mvipersonsid, d.ICD10Code order by d.MostRecentDate DESC) as RN
	INTO #SUDDx
	FROM Present.DiagnosisDate as d WITH (NOLOCK) 
	INNER JOIN #Cohort as m WITH (NOLOCK) ON d.MVIPersonSID=m.MVIPersonSID
	INNER JOIN LookUp.ICD10_Vertical as v WITH (NOLOCK) ON d.ICD10Code=v.ICD10Code
	WHERE v.DxCategory IN ('SUDdx_poss') AND
			d.MostRecentDate > getdate() - 365; --primarily within past year but some older dates in the Present.DiagnosisDate dataset

	--IDU Dx
	DROP TABLE IF EXISTS #IDUDx 
	SELECT DISTINCT d.MVIPersonSID
		,d.ChecklistID
		,IDUDx=1
		,d.ICD10Code
		,v.ICD10Description
		,d.MostRecentDate
		,row_number() over (partition by m.mvipersonsid, d.ICD10Code order by d.MostRecentDate DESC) as RN
	INTO #IDUDx
	FROM Present.DiagnosisDate as d WITH (NOLOCK)
	INNER JOIN #Cohort as m WITH (NOLOCK) ON d.MVIPersonSID=m.MVIPersonSID
	INNER JOIN LookUp.ICD10_Vertical as v  WITH (NOLOCK) ON d.ICD10Code=v.ICD10Code
	WHERE (d.ICD10Code not in( 'Z79.85','Z83.0','F40.23','F40.231','Z30.013','A51.45') AND
			d.ICD10Code not like 'G44%' AND 
			((v.ICD10Description like '%inject%' AND ICD10Description NOT LIKE '%therapeutic%') OR
			(v.ICD10Description like '%HIV%' and d.ICD10Code not in ('Z11.4')) OR
			d.ICD10Code like 'c22%' OR
			v.ICD10Description like '%intravenous%' OR
			(v.ICD10Description like '%hepatitis%' AND icd10description not like '%Alcoholic%' and icd10description not like '%Autoimmune%') OR
			d.ICD10Code in ('I33.0','B37.6','I33.','I33.9','I39.','B33.21','I38.','B43.2','L02.41','L02.411','L02.412','L02.413','L02.414','L02.415','L02.416','L02.419','L02.5','L02.51','L02.511','L02.512','L02.519','L02.6','L02.61','L02.611','L02.612','L02.619','L02.8','L02.81','L02.811','L02.818','L02.9','L02.91','M65.02','M65.021','M65.022','M65.029','M65.03','M65.031','M65.032','M65.039','A48.0','G06.2','L03.019','L03.039','L03.211','L03.221','L03.319','L03.119','L03.317','L03.119','L03.818','L03.90','M72.6')))
	AND MostRecentDate > getdate() - 365; --primarily within past year but some older dates in the Present.DiagnosisDate dataset

	--Combine for complete Dx table
	DROP TABLE IF EXISTS #DxDetails
	SELECT 
		 MVIPersonSID
		,ChecklistID
		,SUDDx
		,IDUDx = NULL
		,ICD10Code
		,ICD10Description
		,MostRecentDate
		,RN
	INTO #DxDetails
	FROM #SUDDx
	UNION
	SELECT 
		 MVIPersonSID
		,ChecklistID
		,SUDDx = NULL
		,IDUDx 
		,ICD10Code
		,ICD10Description
		,MostRecentDate
		,RN
	FROM #IDUDx;


	------------------------
	--Most recent labs
	------------------------
	--HIV
	drop table if exists #MostRecentHIV
	select MVIPersonSID,CheckListID,LabType=Test,LabChemResultValue=resultCategory
	,Interpretation=Result,LabChemCompleteDateTime
	into #MostRecentHIV
	from (
	select a.* ,Max(LabChemSID) over (partition by m.MVIPersonSID,Test) as LastLabChemSID,m.MVIPersonSid
	from PDW.PCS_LABMed_DOEx_HIV as a WITH (NOLOCK) 
	inner join Common.MVIPersonSIDPatientPersonSID as m WITH (NOLOCK) on a.PatientSID = m.PatientPersonSID
	inner join #cohort as c WITH (NOLOCK) on m.MVIpersonsid = c.mvipersonsid
	where LabChemCompleteDateTime > getdate()-1825 
	) as a 
	inner join lookup.Sta6a as s  WITH (NOLOCK)on a.Sta6a = s.Sta6a
	where LastLabChemSID=LabChemSID;

	--HepC
	drop table if exists #MostRecentHep
	select MVIPersonSID,CheckListID,LabType,LabChemResultValue
	,Interpretation,LabChemSpecimenDateSID,Date
	into #MostRecentHep
	from (
	select a.* ,Max(LabChemSID) over (partition by a.PatientICN,LabType) as LastLabChemSID
	,b.[Date],m.MVIPersonSid
	from PDW.SCS_HLIRC_DOEx_HepCLabAllPtAllTime as a WITH (NOLOCK) 
	inner join dim.date as b WITH (NOLOCK) on a.LabChemSpecimenDateSID = b.DateSID
	inner join common.masterpatient as m WITH (NOLOCK) on a.patienticn = m.patienticn
	inner join #cohort as c WITH (NOLOCK) on m.MVIpersonsid = c.mvipersonsid
	where date > getdate()-1825 
	) as a 
	inner join lookup.stationcolors as s  WITH (NOLOCK)on cast(a.sta3n as varchar(5)) = s.CheckListID
	where LastLabChemSID=LabChemSID;

	drop table if exists #ActiveHepVL
	select * 
	into #ActiveHepVL
	from #MostRecentHep
	where Interpretation in ( 'POSITIVE', 'DETECTABLE') and LabType = 'VL';

	--removing hep diagonsis from IDUDx cohort for patients who have been cured 
	--cured hep patients with other qualifing dx will still be included
	DELETE FROM #DxDetails
	WHERE ICD10Description like '%hepatitis%' AND IDUDx=1 AND
			MVIPersonSID NOT IN (SELECT MVIPersonSID FROM #ActiveHepVL); -- only keep people with Hep C Dx and IDU Dx and detectable HCV VL in the #DxDetails temp table

	--Staph info
	--VistA
	drop table if exists #Micro
	select distinct StaPa,p.MVIPersonSID,Organism,a.SpecimenTakenDateTime,Topography
	into #Micro
	from #Cohort as u 
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on p.MVIPersonSID = u.MVIPersonSID
	inner join Micro.Microbiology as a WITH (NOLOCK) on p.PatientPersonSID = a.PatientSID
	inner join Micro.AntibioticSensitivity as b WITH (NOLOCK) on a.MicrobiologySID = b.MicrobiologySID
	inner join Dim.Organism as c WITH (NOLOCK) on c.OrganismSID = b.OrganismSID
	inner join Dim.Topography as t WITH (NOLOCK) on a.TopographySID = t.TopographySID
	inner join Dim.Institution as l WITH (NOLOCK) on a.InstitutionSID = l.InstitutionSID
	where c.Organism like '%STAPHYLOCOCCUS AUREUS%'
	and a.SpecimenTakenDateTime > getdate() - 365;
 
	--Cerner?


	------------------------
	--SUD specialty encounter/therapy
	------------------------
	--Again, get ChecklistID without need to use Sta3nFlag for tracking
	--Filter on above/defined cohort for past 5 years of workload encounters
	DROP TABLE IF EXISTS #VistAOPChecklistID1825
	SELECT DISTINCT c.MVIPersonSID, m.PatientICN, ck.ChecklistID, o.VisitSID, o.PrimaryStopCodeSID, o.SecondaryStopCodeSID, o.VisitDateTime, WorkloadLogicFlag, o.LocationSID
	INTO #VistAOPChecklistID1825
	FROM Outpat.Visit o WITH (NOLOCK) 
	INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi on o.PatientSID=mvi.PatientPersonSID
	INNER JOIN #Cohort c ON mvi.MVIPersonSID=c.MVIPersonSID
	INNER JOIN Common.MasterPatient m ON mvi.MVIPersonSID=m.MVIPersonSID	
	INNER JOIN Dim.Institution as i WITH (NOLOCK) ON o.InstitutionSID=i.InstitutionSID
	INNER JOIN LookUp.ChecklistID ck WITH (NOLOCK) ON i.StaPa=ck.StaPa
	WHERE o.VisitDateTime > DATEADD(DAY,-1825,CAST(GETDATE() as date))
		AND o.VisitDateTime <= GETDATE()
		AND DateOfDeath IS NULL


	--Vista encounters
	--Logic adapted from Code.ORM_RiskMitigation
	DROP TABLE IF EXISTS #VisitSSC
	SELECT DISTINCT 
		 a.MVIPersonSID 
		,b.ChecklistID
		,b.VisitDateTime
		,b.VisitSID
		,b.PrimaryStopCodeSID
	INTO #VisitSSC
	FROM #cohort a
	INNER JOIN
		(
			SELECT
				 b1.MVIPersonSID
				,b1.ChecklistID
				,b1.VisitDateTime
				,b1.VisitSID
				,b1.PrimaryStopCodeSID
			FROM #VistAOPChecklistID1825 b1 WITH (NOLOCK) --[Outpat].[Visit] b1 WITH (NOLOCK) 
			INNER JOIN [Outpat].[VDiagnosis] c WITH (NOLOCK) 
				ON c.VisitSID = b1.VisitSID
			INNER JOIN [LookUp].[ICD10] d WITH (NOLOCK) 
				ON c.ICD10SID = d.ICD10SID
			LEFT OUTER JOIN [LookUp].[StopCode] psc WITH (NOLOCK) 
				ON b1.PrimaryStopCodeSID = psc.StopCodeSID 
			LEFT OUTER JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) 
				ON b1.SecondaryStopCodeSID = ssc.StopCodeSID 
			WHERE (	    ssc.SUDTx_NoDxReq_Stop = 1 
						OR (ssc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
						OR  psc.SUDTx_NoDxReq_Stop = 1
						OR (psc.SUDTx_DxReq_Stop = 1 AND d.SUDdx_poss = 1)	--added 6/22/21
						--General MH stopcodes included as well, per JT 7/2020; we are encouraging BHIP
						--teams to offer SUD, so we are giving credit for GMH when the patient has SUD dx.
						OR (ssc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
						OR (psc.StopCode IN ('502', '534', '539', '550') AND d.SUDdx_poss = 1)
				  )
				AND b1.WorkloadLogicFlag='Y'
			) b
		ON a.MVIPersonSID = b.MVIPersonSID;

	--Get cpt code sids for < 10 minute cpt code to exclude (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptexclude
	SELECT CPTSID,CPTCode, CPTName, CPTExclude=1
	INTO #cptexclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('98966', '99441', '99211', '99212');

	--Get cpt code sids for add-on codes that can be used with excluded CPT codes (effective as of 10/1 per HRF code)
	DROP TABLE IF EXISTS #cptinclude;
	SELECT CPTSID,CPTCode, CPTInclude=1
	INTO #cptinclude
	FROM [Dim].[CPT] WITH(NOLOCK)
	WHERE CPTCode IN ('90833','90836','90838');

	--Get cpt codes for any visit from initial visit query that have phone stop code
	DROP TABLE IF EXISTS #SUD_Tx_VistA 
	SELECT
		v.*
		,CASE 
			WHEN sc.Telephone_MH_Stop=1 AND ci.CPTSID IS NOT NULL --MH_Telephone_Stop includes all MH and SUD telephone
				THEN ci.CPTCode -- if one of these CPT codes is used, the visit counts even if an excluded code is also used
			WHEN sc.Telephone_MH_Stop=1 AND ce.CPTSID IS NOT NULL 
				THEN NULL --exclude visits with these CPT codes (unless they have one of the included codes accounted for above)
			ELSE 999999 
		END AS CPTCode --999999 => that there is no procedure code requirement		
	INTO #SUD_Tx_VistA
	FROM #VisitSSC v
	INNER JOIN [Lookup].[StopCode] sc WITH (NOLOCK)
		ON v.PrimaryStopCodeSID = sc.StopCodeSID
	LEFT JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
		ON v.VisitSID = p.VisitSID 
	LEFT JOIN 
		(
			SELECT p.VisitSID, e.CPTSID, e.CPTCode 
			FROM #cptexclude e
			INNER JOIN [Outpat].[VProcedure] p WITH (NOLOCK) 
				ON e.CPTSID = p.CPTSID
		) ce 
		ON p.VisitSID = ce.VisitSID
	LEFT JOIN #cptinclude ci 
		ON ci.CPTSID = p.CPTSID

	DELETE #SUD_Tx_VistA WHERE CPTCode IS NULL;

	--SUD specialty Cerner encounters/therapy
	DROP TABLE IF EXISTS #SUD_Tx_Cerner;
	SELECT DISTINCT 
		co.MVIPersonSID
		,ck.ChecklistID
		,v.TZDerivedVisitDateTime AS VisitDateTime
		--,v.EncounterType --for validation
		--,ce.CPTCode AS CPTExclude --for validation
		--,ci.CPTCode AS CPTInclude --for validation
		,CASE WHEN v.EncounterType='Telephone' AND ci.CPTSID IS NOT NULL THEN ci.CPTCode
			WHEN v.EncounterType='Telephone' AND ce.CPTSID IS NOT NULL THEN NULL
			WHEN ce.CPTCode IN ('98966','99441') AND ci.CPTCode IS NULL THEN NULL --telephone CPT codes, may have been used in non-telephone encounter types before Telephone encounter type existed
			ELSE 999999 
			END AS CPTCode --999999 => that there is no procedure code requirement
	INTO #SUD_Tx_Cerner
	FROM [Cerner].[FactUtilizationOutpatient] AS v WITH(NOLOCK)
	INNER JOIN #cohort AS co
		ON co.MVIPersonSID=v.MVIPersonSID 
	INNER JOIN [Cerner].[FactDiagnosis] as fd WITH(NOLOCK) 
		ON v.EncounterSID = fd.EncounterSID
	INNER JOIN [LookUp].[ICD10] d WITH(NOLOCK) 
		ON fd.NomenclatureSID = d.ICD10SID
	INNER JOIN [LookUp].[ListMember] AS lm WITH(NOLOCK)
		ON v.ActivityTypeCodeValueSID=lm.ItemID
	INNER JOIN [Cerner].[FactProcedure] as p WITH(NOLOCK) 
		ON v.EncounterSID=p.EncounterSID
	INNER JOIN LookUp.ChecklistID as ck WITH (NOLOCK) 
		ON ck.StaPa=v.STAPA
	LEFT JOIN (	SELECT 
					 p.EncounterType
					,p.EncounterSID
					,CASE WHEN EncounterTypeClass = 'Recurring' OR EncounterType = 'Recurring' THEN p.TZDerivedProcedureDateTime ELSE NULL END AS TZDerivedProcedureDateTime
					,e.CPTCode
					,e.CPTSID FROM #cptexclude AS e
				INNER JOIN [Cerner].[FactProcedure] AS p WITH(NOLOCK) 
					ON e.CPTCode=p.SourceIdentifier) AS ce 
		ON   p.EncounterSID=ce.EncounterSID 
		AND (ce.TZDerivedProcedureDateTime IS NULL OR ce.TZDerivedProcedureDateTime = v.TZDerivedVisitDateTime)
	LEFT JOIN #cptinclude AS ci ON p.SourceIdentifier=ci.CPTCode
	WHERE lm.domain='ActivityType' AND (lm.List='MHOC_SUD'	OR (lm.List='MHOC_GMH' AND d.SUDdx_poss=1))
	AND (v.TZDerivedVisitDateTime >= DATEADD(DAY,-1825,CAST(GETDATE() as date)) 
	AND  v.TZDerivedVisitDateTime <= getdate())

	DELETE #SUD_Tx_Cerner WHERE CPTcode IS NULL;

	-- Union the VistA and Cerner data together
	DROP TABLE IF EXISTS #SUD_Tx
	-- VistA
	SELECT MVIPersonSID
			,ChecklistID
			,VisitDateTime
	INTO #SUD_Tx
	FROM #SUD_Tx_VistA
	UNION ALL
	-- Cerner
	SELECT MVIPersonSID
			,ChecklistID
			,VisitDateTime
	FROM #SUD_Tx_Cerner

	--Pull in first and last visit only
	DROP TABLE IF EXISTS #SUD_Treatment
	SELECT c.MVIPersonSID
		,mind.ChecklistID 
		,mind.VisitDateTime
	INTO #SUD_Treatment
	FROM #Cohort c
	LEFT JOIN  (
		SELECT * FROM (
			SELECT DISTINCT *,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY VisitDateTime ASC) RN
			FROM #SUD_Tx) a
			WHERE RN=1) mind 
		ON c.MVIPersonSID=mind.MVIPersonSID
	UNION
	SELECT c.MVIPersonSID
		,maxd.ChecklistID 
		,maxd.VisitDateTime
	FROM #Cohort c
	LEFT JOIN  (
		SELECT * FROM (
			SELECT DISTINCT *,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC) RN
			FROM #SUD_Tx) a
			WHERE RN=1) maxd 
		ON c.MVIPersonSID=maxd.MVIPersonSID;


	------------------------
	--IDU Rx
	------------------------
	--Vista Rx
	DROP TABLE IF EXISTS #Rx_Vista
	SELECT DISTINCT ChecklistID=isnull(cl.ChecklistID,a.sta3n) 
			,b.MVIPersonSID
			,ReleaseDateTime
			,MedicationType=
				CASE WHEN (a.Drugnamewithoutdose LIKE '%CONDOM%' OR a.LocalDrugNameWithDose LIKE '%CONDOM%') THEN 'Condom' 
						WHEN (a.Drugnamewithoutdose LIKE '%naloxone%' OR a.LocalDrugNameWithDose LIKE '%naloxone%') THEN 'Naloxone' 
						WHEN (a.Drugnamewithoutdose LIKE '%emtricitabine%' OR a.LocalDrugNameWithDose LIKE '%emtricitabine%') THEN 'PrEP'
						--WHEN (a.Drugnamewithoutdose LIKE '%fentanyl%' OR a.LocalDrugNameWithDose LIKE '%fentanyl%') THEN 'Fentanyl TS'
						WHEN (a.Drugnamewithoutdose LIKE '%Buprenorphine%' or a.LocalDrugNameWithDose LIKE '%Buprenorphine%' OR
							  a.Drugnamewithoutdose LIKE '%Naltrexone%' or a.LocalDrugNameWithDose LIKE '%Naltrexone%' OR
							  a.Drugnamewithoutdose LIKE '%Methadone%' or a.LocalDrugNameWithDose LIKE '%Methadone%') THEN 'MOUD'
						WHEN a.Drugnamewithoutdose LIKE '%SYRINGE%' or a.LocalDrugNameWithDose LIKE '%SYR%' THEN 'Syringe'
						ELSE 'Other Harm Reduction' END
	INTO #Rx_Vista
	FROM RxOut.RxOutpatFill as a WITH (NOLOCK) 
	INNER JOIN Common.MVIPersonSIDPatientPersonSID as b WITH (NOLOCK) 
		ON a.PatientSID=b.PatientPersonSID
	INNER JOIN #Cohort c WITH (NOLOCK) 
		ON c.MVIPersonSID=b.MVIPersonSID
	INNER JOIN RxOut.RxOutpatSig as s WITH (NOLOCK) 
		ON a.RxOutpatSID = s.RxOutpatSID
	LEFT JOIN LookUp.Sta6a as cl WITH (NOLOCK) 
		ON cl.STA6AID = a.PrescribingSta6a
	WHERE a.ReleaseDateTime >= getdate() - 1825 
	AND (   a.Drugnamewithoutdose = 'Condom' OR
			a.localdrugnamewithdose = 'Condom' OR
			a.Drugnamewithoutdose LIKE '%naloxone%' OR
			a.localdrugnamewithdose LIKE '%naloxone%' OR 
			(a.Drugnamewithoutdose LIKE 'emtricitabine/tenofovir' OR a.Drugnamewithoutdose LIKE 'tenofovir/emtricitabine') OR
			(a.localdrugnamewithdose LIKE 'emtricitabine/tenofovir' OR a.localdrugnamewithdose LIKE 'tenofovir/emtricitabine') OR
			--a.Drugnamewithoutdose LIKE 'fentanyl test%' OR
			a.localdrugnamewithdose LIKE 'fentanyl test%' OR
			(a.DrugNameWithoutDose LIKE '%Buprenorphine%' OR a.DrugNameWithoutDose LIKE '%Methadone%') OR
			a.DrugNameWithoutDose LIKE '%Naltrexone%' OR
			a.Drugnamewithoutdose LIKE '%harm%' OR
			a.localdrugnamewithdose LIKE '%harm%' OR			
			s.sig LIKE '%harm reduction%' OR
			(a.Drugnamewithoutdose LIKE '%SYRINGE%' OR a.LocalDrugNameWithDose LIKE '%SYR%')
		);

	--Cerner Rx
	DROP TABLE IF EXISTS #Rx_CernerStage
	SELECT * 
	INTO #Rx_CernerStage
	FROM (
		SELECT DISTINCT d.MVIPersonSID
			,d2.VUID 
			,STA6A = ISNULL(o.STA6A,d2.STA6A)
			,IssueDate = CAST(d.TZDerivedOrderUTCDateTime as DATE)
			,CAST(d.DerivedDispenseQuantity as int) as Qty
			,DrugStatus = CASE
				WHEN d.TZDerivedOrderUTCDateTime >= getdate() - 1825 
					AND d.RxActiveFlag=1 THEN 'ActiveRx'
				WHEN DATEADD(DAY, CAST (d.Dayssupply AS INT), d.TZDerivedCompletedUTCDateTime) >= CAST(GETDATE() AS DATE)
				THEN 'PillsOnHand'
				ELSE NULL END
		FROM [Cerner].[FactPharmacyOutpatientDispensed] as d WITH (NOLOCK)
		INNER JOIN #Cohort as c
			ON d.MVIPersonSID = c.MVIPersonSID 
		LEFT JOIN [Cerner].[FactPharmacyOutpatientOrder] as o WITH(NOLOCK) -- pharm order info
			ON d.MedMgrPersonOrderSID = o.MedMgrPersonOrderSID  
		LEFT JOIN (
			SELECT d.MedMgrPersonOrderSID
				,d.FillNumber
				,d.VUID
				,d.STA6A
				,ROW_NUMBER() OVER (PARTITION BY d.MedMgrPersonOrderSID ORDER BY d.FillNumber DESC) AS FillRowID
			FROM [Cerner].[FactPharmacyOutpatientDispensed] as d WITH (NOLOCK)
			) as d2 ON d2.FillRowID = 1
				AND d.MedMgrPersonOrderSID = d2.MedMgrPersonOrderSID    
		) m
	WHERE m.DrugStatus IS NOT NULL
	AND IssueDate >= getdate() - 1825 ;

	DROP TABLE IF EXISTS #Rx_Cerner
	SELECT l.ChecklistID
		,rxo.MVIPersonSID
		,rxo.IssueDate
		,MedicationType=
			CASE WHEN (nd.Drugnamewithoutdose LIKE '%CONDOM%' OR nd.DrugNameWithDose LIKE '%CONDOM%') THEN 'Condom' 
					WHEN (nd.Drugnamewithoutdose LIKE '%naloxone%' OR nd.DrugNameWithDose LIKE '%naloxone%') THEN 'Naloxone' 
					WHEN (nd.Drugnamewithoutdose LIKE '%emtricitabine%' OR nd.DrugNameWithDose LIKE '%emtricitabine%') THEN 'PrEP'
					--WHEN (nd.Drugnamewithoutdose LIKE '%fentanyl%' OR nd.DrugNameWithDose LIKE '%fentanyl%') THEN 'Fentanyl TS'
					WHEN (nd.Drugnamewithoutdose LIKE '%Buprenorphine%' or nd.DrugNameWithDose LIKE '%Buprenorphine%' or 
						  nd.Drugnamewithoutdose LIKE '%Naltrexone%' or nd.DrugNameWithDose LIKE '%Naltrexone%' or 
						  nd.Drugnamewithoutdose LIKE '%Methadone%' or nd.DrugNameWithDose LIKE '%Methadone%') THEN 'MOUD'
					WHEN (nd.Drugnamewithoutdose LIKE '%SYRINGE%' or nd.DrugNameWithDose LIKE '%SYR%') THEN 'Syringe'
					ELSE 'Other Harm Reduction' END
	INTO #Rx_Cerner
	FROM #Rx_CernerStage rxo
	INNER JOIN [LookUp].[Drug_VUID] as nd WITH(NOLOCK) 
		ON rxo.VUID = nd.VUID 
	LEFT JOIN [LookUp].[Sta6a] as l WITH(NOLOCK) 
		ON rxo.Sta6a = l.Sta6a
	WHERE rxo.IssueDate >= getdate() - 1825
		AND (	nd.Drugnamewithoutdose LIKE '%Condom%' OR
				nd.Drugnamewithoutdose LIKE '%naloxone%' OR
				(nd.DrugNameWithoutDose LIKE '%Buprenorphine%' OR nd.DrugNameWithoutDose LIKE '%Methadone%') OR
				nd.DrugNameWithoutDose LIKE '%Naltrexone%' OR
				(nd.Drugnamewithoutdose LIKE 'emtricitabine/tenofovir' OR nd.Drugnamewithoutdose LIKE 'tenofovir/emtricitabine') OR
				nd.Drugnamewithoutdose LIKE '%harm%' OR 
				--nd.Drugnamewithoutdose LIKE 'fentanyl test%' OR
				nd.DrugNameWithDose LIKE '%Condom%' OR
				nd.DrugNameWithDose LIKE '%naloxone%' OR 
				(nd.DrugNameWithDose LIKE 'emtricitabine/tenofovir' OR nd.DrugNameWithDose LIKE 'tenofovir/emtricitabine') OR
				nd.DrugNameWithDose LIKE '%harm%' OR
				--nd.DrugNameWithDose LIKE 'fentanyl test%' OR
				(nd.Drugnamewithoutdose LIKE '%SYRINGE%' OR nd.DrugNameWithDose LIKE '%SYR%')
			);

	--Combine VistA and Cerner Rx
	DROP TABLE IF EXISTS #IDU_Rx
	SELECT
		 ChecklistID
		,MVIPersonSID
		,ReleaseDateTime
		,MedicationType
	INTO #IDU_Rx
	FROM #Rx_Vista
	UNION
	SELECT
		 ChecklistID
		,MVIPersonSID
		,IssueDate
		,MedicationType
	FROM #Rx_Cerner


	------------------------
	-- Additional inserts based on SME rules/requests
	------------------------
	--MOUD
	--Find non-outpatient MOUD in past 5 years
	DROP TABLE IF EXISTS #MOUD
	SELECT DISTINCT cl.ChecklistID, a.MVIPersonSID, a.MOUDDate, MedicationType='MOUD'
	INTO #MOUD
	FROM Present.MOUD a
	INNER JOIN #Cohort c 
		ON a.MVIPersonSID=c.MVIPersonSID
	INNER JOIN LookUp.ChecklistID cl WITH (NOLOCK)
		ON a.StaPa=cl.StaPa
	WHERE MOUDDate >= getdate() - 1825 AND (ActiveMOUD=1 OR ActiveMOUD_Patient=1);

	/***********************************
	--Insert non-outpatient MOUD into cohort to finish the MedicationType re: MOUD
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime=MOUDDate, MedicationType
	FROM #MOUD;


	--FENTATYL
	--Find VA-SSP KIT ADD HARM RED SUPPLY FENT TEST STRIPS health factor in past 5 years
	drop table if exists #HF_Fentanyl
	select distinct HealthFactorType,a.HealthFactorTypeSID
	INTO #HF_Fentanyl
	from Dim.HealthFactorType as a WITH (NOLOCK)
	where HealthFactorType in ('VA-SSP KIT ADD HARM RED SUPPLY FENT TEST STRIPS')

	drop table if exists #HealthFactor_Fentanyl 
	select p.MVIPersonSID, ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n), ReleaseDateTime=HealthFactorDateTime,MedicationType='Fentanyl TS'
	into #HealthFactor_Fentanyl
	from HF.HealthFactor as a WITH (NOLOCK)
	inner join #HF_Fentanyl as b WITH (NOLOCK) on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on a.PatientSID = p.PatientPersonSID
	inner join #Cohort c on p.MVIPersonSID=c.MVIPersonSID
	left join #VistAOPChecklistID1825 ck on a.VisitSID=ck.VisitSID
	where healthfactordatetime > getdate() - 1825

	--Cerner Health Factor for Fentanyl?

	/***********************************
	--Insert Fentanyl health factor into cohort to finish the MedicationType re: Fentanyl
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime, MedicationType
	FROM #HealthFactor_Fentanyl


	--SYRINGE
	--Find VA-SSP KIT PHARMACY health factor in past 5 years
	drop table if exists #HFSSP_Syringe
	select distinct HealthFactorType, a.HealthFactorTypeSID
	INTO #HFSSP_Syringe
	from Dim.HealthFactorType as a WITH (NOLOCK)
	where HealthFactorType = 'VA-SSP KIT PHARMACY' OR HealthFactorType LIKE 'VA-SSP OTHER KIT%' OR HealthFactorType LIKE 'VA-SSP KIT CLINIC/LOGISTICS%';


	drop table if exists #HealthFactor_Syringe
	select ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n),p.MVIPersonSID,b.HealthFactorType,a.HealthFactorDateTime,a.Comments 
	into #HealthFactor_Syringe
	from HF.HealthFactor as a WITH (NOLOCK)
	inner join #HFSSP_Syringe as b on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on a.PatientSID = p.PatientPersonSID
	left join #VistAOPChecklistID1825 ck on a.VisitSID=ck.VisitSID
	where healthfactordatetime > getdate() - 1825
	and (HealthFactorType = 'VA-SSP KIT PHARMACY' OR (b.HealthFactorType LIKE 'VA-SSP OTHER KIT%' AND a.Comments <> '0') OR b.HealthFactorType LIKE 'VA-SSP KIT CLINIC/LOGISTICS%');


	/***********************************
	--Insert Syringe health factor into cohort to finish the MedicationType re: Syringe
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime=HealthFactorDateTime, MedicationType='Syringe'
	FROM #HealthFactor_Syringe


	--CONDOM
	--Find VA-SSP KIT ADD HARM RED SUPPLY CONDOMS in past 5 years
	drop table if exists #HFSSP_Condoms
	select distinct HealthFactorType, a.HealthFactorTypeSID
	INTO #HFSSP_Condoms
	from Dim.HealthFactorType as a WITH (NOLOCK)
	where HealthFactorType = 'VA-SSP KIT ADD HARM RED SUPPLY CONDOMS';

	drop table if exists #HealthFactor_Condom
	select ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n),p.MVIPersonSID,HealthFactorType,HealthFactorDateTime,Comments 
	into #HealthFactor_Condom
	from HF.HealthFactor as a WITH (NOLOCK)
	inner join #HFSSP_Condoms as b on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join Common.MVIPersonSIDPatientPersonSID as p WITH (NOLOCK) on a.PatientSID = p.PatientPersonSID
	left join #VistAOPChecklistID1825 ck on a.VisitSID=ck.VisitSID
	where healthfactordatetime > getdate() - 1825;

	/***********************************
	--Insert Syringe health factor into cohort to finish the MedicationType re: Syringe
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime=HealthFactorDateTime, MedicationType='Condom'
	FROM #HealthFactor_Condom


	--NAXOLONE
	--Find Naxolone HFs - logic based on OMHSP_PERC_MDS Code.Metric_OEND2
	--Get VISTA Naloxone HF
	DROP TABLE IF EXISTS #Naloxone
	SELECT Distinct p.MVIPersonSID, ChecklistID=ISNULL(ck.ChecklistID,hf.Sta3n), ReleaseDateTime=HealthFactorDateTime,MedicationType='Naloxone'
	INTO #Naloxone
	FROM [HF].[HealthFactor] as hf  WITH (NOLOCK)
	INNER JOIN [Dim].[HealthFactorType] as dim  WITH (NOLOCK) ON hf.HealthFactorTypeSID = dim.HealthFactorTypeSID
	inner JOIN Common.MVIPersonSIDPatientPersonSID  as p WITH (NOLOCK) ON hf.PatientSID = p.PatientPersonSID
	inner join #Cohort c on p.MVIPersonSID=c.MVIPersonSID
	left join #VistAOPChecklistID1825 ck on hf.VisitSID=ck.VisitSID
	WHERE dim.HealthFactorType like '%HAS NALOXONE RX%' OR dim.HealthFactorType='VA-NALOXONE RX ORDERED' 
	and healthfactordatetime > getdate() - 1825;

	--Get Cerner Naloxone HF
	DROP TABLE IF EXISTS #Naloxone_Cerner
	SELECT Distinct f.MVIPersonSID, ck.ChecklistID, ReleaseDateTime=FormDateTime,MedicationType='Naloxone'
	INTO #Naloxone_Cerner
	FROM [Cerner].[FactPowerForm] f WITH (NOLOCK)
	inner join #Cohort c on c.MVIPersonSID=f.MVIPersonSID
	inner join lookup.checklistid ck with (nolock) on f.STAPA=ck.StaPa
	WHERE DerivedDtaEvent ='Naloxone Prescription Info'  --DtaEvent
		AND DerivedDtaEventResult = 'Patient has current naloxone medication (unused, unexpired)' --DTAEventResult
		AND FormDateTime > getdate() - 1825;

	-- Combine NaloxoneHF 
	DROP TABLE IF EXISTS #NaloxoneHF
	SELECT *
	INTO #NaloxoneHF
	  FROM #Naloxone 
	UNION
	SELECT *
	  FROM #Naloxone_Cerner

	/***********************************
	--Insert Naloxone HF into cohort to continue building the MedicationType re: Naloxone
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime, MedicationType
	FROM #NaloxoneHF

	--Find non-VA orders for Naloxone - logic based on OMHSP_PERC_MDS Code.Metric_OEND2
	--VISTA Non-VA Med orderables
	DROP TABLE IF EXISTS #NaloxonePONonVA
	select distinct PharmacyOrderableItemSID 
	INTO #NaloxonePONonVA
	FROM [dim].[PharmacyOrderableItem] as a  WITH (NOLOCK)
	WHERE (pharmacyorderableitem like '%NALOXONE%' or PharmacyOrderableItem like '%EVZIO%' or PharmacyOrderableItem like '%KLOXXADO%' or PharmacyOrderableItem like '%ZIMHI%')
		and PharmacyOrderableItem not like '%BUP%' and PharmacyOrderableItem not like '%PENTAZOC%' and PharmacyOrderableItem not like '%INV%' and pharmacyorderableitem not like '%PLACEBO%'
		and PharmacyOrderableItem not like '%ENTER%NOTE%' and PharmacyOrderableItem not like '%IV NALOXONE%' and PharmacyOrderableItem not like '%HOSPITAL%USE%'
		and PharmacyOrderableItem not like '%STUDY%' and PharmacyOrderableItem not like '%QUICK ORDER%' and PharmacyOrderableItem not like '%SODIUM CHLORIDE%'
		and PharmacyOrderableItem not like '%CONTROLLED SUBSTANCE MENU%'
		and isnull(IVFlag,'Hamburger') <> 'Y' and InactiveDateTime is null;

	--Cerner Non-VA Med
	DROP TABLE IF EXISTS #NonVACerner
	SELECT DISTINCt MVIPersonSID, ChecklistID, ReleaseDateTime=TZOrderUTCDateTime, MedicationType='Naloxone'
	INTO #NonVACerner
	FROM (
		   SELECT DISTINCT a.MVIPersonSID
				,b.ChecklistID
				,EncounterSID
				,TZOrderUTCDateTime
				,OrderCatalog
				,orderedAsMnemonic
				,OrderStatus
		   FROM [Cerner].[FactPharmacyNonVAMedOrder] a WITH (NOLOCK)
		   INNER JOIN LookUp.ChecklistID b on a.STAPA=b.StaPa
		   WHERE
				  (OrderedAsMnemonic like '%NALOXONE%' or OrderedAsMnemonic like '%EVZIO%' 
					or OrderedAsMnemonic like '%KLOXXADO%' or OrderedAsMnemonic like '%ZIMHI%' or OrderedAsMnemonic like '%narcan%')
				   and OrderedAsMnemonic not like '%BUP%' 
				   and SimplifiedDisplayLine not like '%Intrav%'
				   and OrderStatus in ('Completed','Canceled','Suspended','Ordered' ,'Discontinued')
				   and (TZOrderUTCDateTime > getdate() - 1825) --adjusting time frame to look back 1825 days for consistency
		 ) AS a

	--Local DrugSId's
	DROP TABLE IF EXISTS #NaloxoneLocDrug
	SELECT DISTINCT LocalDrugSID
	INTO #NaloxoneLocDrug
	FROM [dim].[localdrug]  WITH (NOLOCK)
	WHERE 
		(LocalDrugNameWithDose like '%Naloxone%Auto%'
			or localdrugnamewithdose like '%NALOXONE%SPRAY%'
			or localdrugnamewithdose like '%NALOXONE%KIT%'
			or localdrugnamewithdose like '%NALOXONE%INTRAMUSC%'
			or localdrugnamewithdose like '%NALOXONE%2mg%0.4%'
			or localdrugnamewithdose like '%EVZIO%'
			or localdrugnamewithdose like '%KLOXXADO%'
			or LocalDrugNameWithDose like '%ZIMHI%'
			or localdrugnamewithdose like '%NALOXONE%NASAL%'
			or localdrugnamewithdose like '%NALOXONE%RESCUE%'
			or localdrugnamewithdose like '%NALOXONE%INTRAN%'
			or localdrugnamewithdose like '%NALOXONE%0.5mg%0.5ml%')
		and localdrugnamewithdose not like '%NOTE%'
		and localdrugnamewithdose not like '%DEMO%'
		and localdrugnamewithdose not like '%PLACEHOLDER%'
		and localdrugnamewithdose not like '%POINTER%';

	DROP TABLE IF EXISTS #NonVALocal
	SELECT Distinct PatientSID, Sta3n, DocumentedDateTime, LocationSID
	INTO #NonVALocal
	FROM [NonVAMed].[NonVAMed] as A  WITH (NOLOCK)
	INNER JOIN #NaloxoneLocDrug as B
	  ON A.LocalDrugSID = B.LocalDrugSID
	WHERE A.DocumentedDateTime > getdate() - 1825; --adjusting time frame to look back 1825 days for consistency

	DROP TABLE IF EXISTS #NonVAOrderable
	SELECT Distinct PatientSID, Sta3n, DocumentedDateTime, LocationSID
	INTO #NonVAOrderable
	FROM [NonVAMed].[NonVAMed] as A  WITH (NOLOCK)
	INNER JOIN #NaloxonePONonVA as B
	  ON A.PharmacyOrderableItemSID = B.PharmacyOrderableItemSID
	WHERE A.DocumentedDateTime > getdate() - 1825; --adjusting time frame to look back 1825 days for consistency

	DROP TABLE IF EXISTS #NonVA
	SELECT DISTINCT p.MVIPersonSID, ChecklistID=ISNULL(ck.ChecklistID,a.Sta3n), ReleaseDateTime=a.DocumentedDateTime, MedicationType='Naloxone'
	INTO #NonVA
	FROM (
		SELECT PatientSID, Sta3n, DocumentedDateTime, LocationSID
		FROM #NonVALocal
		UNION
		SELECT PatientSID, Sta3n, DocumentedDateTime, LocationSID
		FROM #NonVAOrderable
	) as A
	INNER JOIN [SPatient].[SPatient] as ss  WITH (NOLOCK)
	   on a.PatientSID=ss.PatientSID
	INNER JOIN Common.vwMVIPersonSIDPatientPersonSID p WITH (NOLOCK)
		ON a.PatientSID=p.PatientPersonSID
	LEFT JOIN #VistAOPChecklistID1825 ck
		ON a.LocationSID=ck.LocationSID
		AND cast(a.DocumentedDateTime as date)=cast(ck.VisitDateTime as date)
		AND p.MVIPersonSID=ck.MVIPersonSID

	-- Combine Cerner and Vista Non-VA meds
	DROP TABLE IF EXISTS #NonVAAll
	SELECT DISTINCT a.ChecklistID, c.MVIPersonSID, a.ReleaseDateTime, a.MedicationType
	INTO #NonVAAll
	FROM (
		SELECT ChecklistID, MVIPersonSID, ReleaseDateTime, MedicationType
		FROM #NonVA
		UNION
		SELECT ChecklistID, MVIPersonSID, ReleaseDateTime, MedicationType
		FROM #NonVACerner 
		) a
	INNER JOIN #Cohort c on a.MVIPersonSID=c.MVIPersonSID

	/***********************************
	--Insert non-VA Naloxone Rx into cohort to finish the MedicationType re: Naloxone
	***********************************/
	INSERT INTO #IDU_Rx
	SELECT ChecklistID, MVIPersonSID, ReleaseDateTime, MedicationType
	FROM #NonVAAll


	------------------------
	--Final step for #IDU_RxFinal
	------------------------	
	--Add in SUD contacts
	DROP TABLE IF EXISTS #IDU_RxFinal
	SELECT 
		 ChecklistID
		,MVIPersonSID
		,ReleaseDateTime
		,MedicationType
	INTO #IDU_RxFinal
	FROM #IDU_Rx
	WHERE ChecklistID IS NOT NULL
	UNION
	SELECT 
		 ChecklistID
		,MVIPersonSID	
		,VisitDateTime
		,MedicationType='SUD Engagement'
	FROM #SUD_Treatment
	WHERE ChecklistID IS NOT NULL;


/**************************************************/

--Publish first table

/**************************************************/

EXEC [Maintenance].[PublishTable] 'SUD.IDU_Rx', '#IDU_RxFinal'


	drop table if exists #IDUCohort
	select distinct  a.*,PatientName,LastFour,mp.DateOfBirth
		,case when dx.MVIPersonSID is not null then 'SUD Dx' else 'No SUD Dx' end SUDDx
		,case when b.MVIPersonSID is null then 'No' else 'Yes' end Prep
		,case when c.MVIPersonSID is null then 'No' else 'Yes' end Naloxone
		,case when d.MVIPersonSID is null then 'No' else 'Yes' end Condom
		,case when e.MVIPersonSID is null then 'No' else 'Yes' end FentanylTS
		--,case when g.MVIPersonSID is null then 'No' else 'Yes' end MOUD
		,mp.Homeless
		,case when a.ChecklistID = ap.ChecklistID then 1 else 0 end MostRecentAppointment
		,mp.WorkPhoneNumber,mp.PhoneNumber,mp.CellPhoneNumber
		,case when v.MVIPersonSID is null then 'No' else 'Yes' end ActiveHepVL
	into #IDUCohort
	from #cohort as a 
	INNER JOIN Common.MasterPatient as mp WITH (NOLOCK) on A.MVIPersonSID = mp.mvipersonsid
	left outer join Present.Diagnosis as dx WITH (NOLOCK) on A.MVIPersonSID = dx.MVIPersonSID and dx.DxCategory = 'SUDdx_poss'
	left outer join SUD.IDU_Rx as b WITH (NOLOCK) on a.mvipersonsid = b.mvipersonsid and b.ReleaseDateTime > getdate() - 180 and b.MedicationType = 'Prep'
	left outer join SUD.IDU_Rx as c WITH (NOLOCK) on a.mvipersonsid = c.mvipersonsid and c.ReleaseDateTime > getdate() - 180 and c.MedicationType = 'naloxone'
	left outer join SUD.IDU_Rx as d WITH (NOLOCK) on a.mvipersonsid = d.mvipersonsid and d.ReleaseDateTime > getdate() - 180 and d.MedicationType = 'condom'
	left outer join SUD.IDU_Rx as e WITH (NOLOCK) on a.mvipersonsid = e.mvipersonsid and e.ReleaseDateTime > getdate() - 180 and e.MedicationType = 'Fentanyl TS'
	--left outer join SUD.IDU_Rx as g on a.mvipersonsid = g.mvipersonsid and g.ReleaseDateTime > getdate() - 180 and e.MedicationType = 'MOUD'
	left outer join #ActiveHepVL v on a.MVIPersonSID=v.MVIPersonSID
	left outer join Present.AppointmentsPast as ap WITH (NOLOCK) on a.mvipersonsid = ap.MVIPersonSID and ApptCategory in ('PCRecent','MHRecent') and ap.MostRecent_ICN =1 
	WHERE DATEOFDEATH IS NULL;


	drop table if exists #WhyIDU
	select ChecklistID, MVIPersonSID,'MHA Survey' as EvidenceType,SurveyGivenDateTime as EvidenceDate
	,SurveyName as Details,SurveyChoiceText Details2,SurveyQuestionText Details3
	into #WhyIDU
	from #SurveyAnswer

	UNION 

	select ChecklistID, MVIPersonSID,'IDU Health Factor' as EvidenceType,HealthFactorDateTime as EvidenceDate
	,HealthFactorType as Details,Comments Details2,null Details3
	from #HealthFactor
	where HxCurrent = 'Current'

	UNION 

	select   ChecklistID,MVIPersonSID,'SSP Health Factor' as EvidenceType,HealthFactorDateTime as EvidenceDate
	,HealthFactorType as Details,null Details2,Comments  Details3
	from #HealthFactorSSP

	UNION 

	select   ChecklistID,MVIPersonSID,'Harm Reduction Orders' as EvidenceType
	,IssueDate as EvidenceDate
	,LocalDrugNameWithDose  as Details,null  Details2, Sig  Details3
	from #HarmReduction 

	UNION 

	select distinct ChecklistID,a.MVIPersonSID,'Drug Screen' as EvidenceType
	,LabDate  as EvidenceDate
	,case 
	when a.UDTGroup in ('Oxycodone','Hydromorphone','Fentanyl') then a.UDTGroup + '*'
	when a.UDTGroup in ('Amphetamine') then a.UDTGroup + '**'
	else a.UDTGroup 
	End + ' (' + LabChemResultNumericValue + ')' as Details
	,case when Neg > 1 then cast(Neg as Varchar(20)) + 'x more recent negatives'
	when Neg = 1 then cast(Neg as Varchar(20)) + 'x more recent negative' 
	end  as Details2
	,null Details3
	from #PosIVD2 as a 
	inner join (select MVIPersonSID,max(LabDate )as EvidenceDate
					   ,UDTGroup 
				from #PosIVD2 
				group by MVIPersonSID,UDTGroup) as b 
		on a.mvipersonsid = b.mvipersonsid 
		and EvidenceDate = LabDate 
		and a.UDTGroup=b.UDTGroup

	UNION

	select distinct CheckListID,MVIPersonSID,'ID Diagnosis' as EvidenceType
	,max(MostRecentDate) as EvidenceDate
	,'(' + ICD10Code + ') ' + ICD10Description as Details, 
	case when ICD10Code like 'm%'  or ICD10Code like 'L%' then 'Abscess/Wound'
	when ICD10Code like 'I%' then 'Endocarditis'
	when ICD10Code in ('Z21.','Z71.7', 'B20.', 'O98.72', 'B97.35', 'R75.') then 'HIV'
	when ICD10Code like 'B%' or ICD10Code like 'P%'  or ICD10Code like 'K%'  then 'Hepatitis'
	when ICD10Code like 'C%'  then 'Hepatic Cancer'
	else null end Details2,null Details3
	from #DxDetails d
	WHERE IDUDx=1 and RN=1 
	group by ChecklistID,MVIPersonSID, '(' + ICD10Code + ') ' + ICD10Description,  ICD10Code ,ICD10Description

	UNION

	select distinct CheckListID,MVIPersonSID,'SUD Diagnosis' as EvidenceType
	,max(MostRecentDate) as EvidenceDate
	,'(' + ICD10Code + ') ' + ICD10Description as Details, 
	null Details2,null Details3
	from #DxDetails
	WHERE SUDDx=1 AND RN=1
	group by ChecklistID,MVIPersonSID, '(' + ICD10Code + ') ' + ICD10Description,  ICD10Code ,ICD10Description

	UNION 

	select distinct ChecklistID, MVIPersonSID,'SUD Engagement' as EvidenceType
	,VisitDateTime as EvidenceDate,NULL Details, NULL Details2, NULL Details3 
	from #SUD_Treatment

	UNION

	select distinct ChecklistID ,MVIPersonSID,'Note Mentions' as EvidenceType
	,ReferenceDateTime as EvidenceDate
	,TIUDocumentDefinition  as Details, replace(Snippet,Term,'<b>' + Term + '</b>') Details2
	,cast(row_number() over (order by referencedatetime) as varchar(1000)) as Details3 
	from present.nlp_variables
	where concept='IDU'

	UNION 

	select distinct StaPa,MVIPersonSID,'Staph Aureus' as EvidenceType
	,SpecimenTakenDateTime as EvidenceDate
	,Topography as Details,Organism Details2
	,null as Details3 
	from #Micro

	UNION

	select a.ChecklistID,a.MVIPersonSID,'Hep C Labs',a.Date 
	,case when a.LabType = 'GT' then 'GT - ' + a.LabChemResultValue
	else a.LabType + ' - ' + a.Interpretation end ,NULL,a.LabChemResultValue
	from #MostRecentHep as a
	--inner join #ActiveHepVL as b on a.MVIPersonSID = b.MVIPersonSID (Karine Rozenberg request 11/16)

	UNION

	select ChecklistID,MVIPersonSID,'HIV Labs',LabChemCompleteDateTime 
	,CONCAT(LabType, ' - ', Interpretation) as Details,NULL,LabChemResultValue
	from #MostRecentHIV;


	delete from #WhyIDU where MVIPersonSID not in (select mvipersonsid from #IDUCohort);


	drop table if exists #IDUEvidence
	select distinct  a.* ,b.Code,Facility
	into #IDUEvidence
	from #WhyIDU as a 
	left outer join LookUp.stationcolors as b on a.ChecklistID = b.CheckListID;


/**************************************************/

--Publish final tables 

/**************************************************/


EXEC [Maintenance].[PublishTable] 'SUD.IDUCohort', '#IDUCohort';

EXEC [Maintenance].[PublishTable] 'SUD.IDUEvidence', '#IDUEvidence';

EXEC [Log].[ExecutionEnd]; 


END