/*-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <7/11/2024>
-- Description:	Adopted from Scott Ragland's code to align hospice care definitions with PMOP definitions.
    Palliative Care and Oncology flags are included, in case they are needed in the future.

-- 2024/08/06: D&A PERC Support - Changed to resolve Build Warning due to original three part naming convention usage
-- =============================================*/
CREATE PROCEDURE [Code].[ORM_HospicePalliativeCare]
AS
BEGIN
   

EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_HospicePalliativeCare','Execution of SP Code.ORM_HospicePalliativeCare'


--0:00
-- find hospice and palliative care stop codes 
DROP TABLE IF EXISTS #StopCode;
select distinct
StopCode
,StopCodeName
,StopCodeSID
,case when Stopcode = '351' then 1 else 0 end as Hospice
,case when StopCode = '353' then 1 else 0 end as Palliative
,case when stopcode not in ('308', '351', '353') then 1 else 0 end as Oncology
,case when stopcode = '308' then 1 else 0 end as Hematology
INTO #StopCode
FROM dim.stopcode
where stopcode in ( '351', '353' )
	or stopcode in ( '42','93','94','149','308','316','330','431','488','903','904' )
	or
	((stopcodename like '%CHEMO%' or stopcodename like '%ONCOL%'
      or stopcodename like '%RADIAT%')
      and stopcode in ('111','451','454','465','460','469','471','472','476','484'))

;

--0:00
-- find all hospice, oncology, and palliative care locations using 1* and 2* stop codes 
DROP TABLE IF EXISTS #Locations;
select 
LocationSID
,LocationName
,PrimaryStopCode
,PSCN
,SecondaryStopCode
,SSCN
,Hospice
,Palliative
,Oncology
,OncologySC
,Hematology
,CernerSite
INTO #Locations
from
	(
	select distinct
	a.LocationSID
	,a.LocationName
	,d.StopCode as PrimaryStopCode
	,d.StopCodeName as PSCN
	,e.StopCode as SecondaryStopCOde
	,e.StopCodeName as SSCN
	,case when a.LocationName like '%HOSPICE%' then 1
		else isnull(isnull(b.Hospice,c.Hospice),0) end as Hospice
	,case when (a.LocationName like '%PALL%' or a.locationname like '%COmFORT%CARE%') 
		and a.locationname not like '%PALLY%' and a.LocationName not like '%APALLI%' then 1 else isnull(isnull(b.Palliative,c.Palliative),0) end as Palliative
	,case when a.LocationName like '%ONCOLOGY%' or a.LocationName like '%CHEMO%' or a.locationname like '%TUMOR%'
		or a.locationname like '%CANCER%' or a.locationname like '%ONC%' then 1
		else isnull(isnull(b.Oncology,c.Oncology),0) end as Oncology
	,isnull(b.Oncology,c.Oncology) as OncologySC
	,isnull(b.Hematology,c.Hematology) as Hematology
	,case when b.StopCode is not null or c.stopcode is not null then 1 else 0 end as StopCodeFlag
	,case when a.sta3n = 200 then 1 else 0 end as CernerSite
	from dim.location as a
	left join #Stopcode as b
		on a.primarystopcodesid = b.stopcodesid
	left join #Stopcode as c
		on a.secondarystopcodesid = c.stopcodesid
	left join Dim.StopCode as d
		on d.stopcodesid = a.PrimaryStopCodeSID
	left join Dim.StopCode as e
		on e.stopcodesid = a.SecondaryStopCodeSID
	where b.stopcodesid is not null or c.stopcodesid is not null
		or a.locationname like '%ONCOLOGY%' or a.locationname like '%CHEMO%' or a.locationname like '%HOSPICE%' or a.locationname like '%PALLIATIVE%'
		or a.locationname like '%TUMOR%' or a.locationname like '%CANCER%' or a.locationname like '%HEM%/ONC%' or a.locationname like '%ONC%/HEM%'
		or (a.sta3n = 200 and (a.Locationname like '% CHEMO%' or a.LocationName like '% Comfort Care%' or a.locationname like '% HEM%Onc%' or a.locationname like '% HOSPICE%'
			or a.locationname like '% ONC%' or a.locationname like '% Pall%' or a.locationname like '% RAD%ONC%'))

	) as a
where
	(Hospice = 1 and (1 in (CernerSite, StopCodeFlag) or (StopCodeFlag = 0 and a.lOcationname not like '%CONSULT%' and a.locationname not like '%CNSLT%')))
	or
	(Palliative = 1 and (1 in (CernerSite, StopCodeFlag) or (StopCodeFlag = 0 and a.locationname not like '%CONSULT%' and a.locationname not like '%CNSLT%')))
	or
	(Oncology = 1 and (1 in (CernerSite, StopCodeFlag) or (StopCodeFlag = 0 and PSCN not like '%DERM%' and SSCN not like '%DERM%' 
		and PSCN not in ('HEMATOLOGY','CARDIOLOGY') and SSCN not in ('HEMATOLOGY','CARDIOLOGY') and a.locationname not like '%SCREEN%' and a.locationname not like '%SCRN%'
		and a.locationname not like '%CONSULT%' and a.locationname not like '%CNSLT%' and a.locationname not like '%REGIST%'
		and a.locationname not like '%AWARENESS%' and a.locationname not like '%CONFERENCE%' and a.locationname not like '%REHAB%' and a.locationname not like '%TRANS%'
		and a.locationname not like '%SKIN%' and a.locationname not like '%YOU%NOT%ALONE%' and a.locationname not like '%SURVIVOR%' and a.locationname not like '%SUPPORT%'
		and a.locationname not like '%SPRT%' and a.locationname not like '%LAB%' and a.locationname not like '%GRP%' and a.locationname not like '%TUMOR%BOARD%'))
		and isnull(PrimaryStopCode,9999) not in ('104','108','109','111','697','674','704') and isnull(SecondaryStopCode,9999) not in ('697','719'))

;

--0:00
DROP TABLE IF EXISTS #WardLocations;
select
a.WardLocationSID
,WardLocationName
,a.DivisionSID
,case when sc.stopcodesid is null and sc2.stopcodesid is null
	and (a.specialty like '%HOSPICE%' or a.medicalservice like '%HOSPICE%') then 1
	when a.WardLocationName like '%HOSPICE%' then 1
	else isnull(isnull(sc.Hospice,sc2.Hospice),0) end as Hospice
,case when sc.stopcodesid is null and sc2.stopcodesid is null
	and (a.specialty like '%pallia%' or a.medicalservice like '%pallia%') then 1
	when a.WardLocationName like '%PALL%' then 1
	else isnull(isnull(sc.Palliative,sc2.Palliative),0) end as Palliative
,case when sc.stopcodesid is null and sc2.stopcodesid is null
	and (a.specialty like '%ONCO%' or a.specialty like '%CHEMO%'
             or a.medicalservice like '%ONCO%' or a.medicalservice like '%CHEMO%'
	         or a.specialty like '%RADIA%' or a.medicalservice like '%RADIA%') then 1
	when a.WardLocationName like '%ONC%' or a.wardlocationname like '%CHEMO%'
         then 1
	else isnull(isnull(sc.Oncology,sc2.Oncology),0) end as Oncology
INTO #WardLocations
from dim.wardlocation as a
left join dim.location as l
	on l.locationsid = a.locationsid
left join #StopCode as sc
	on sc.stopcodesid = l.primarystopcodesid
left join #StopCode as sc2
	on sc2.stopcodesid = l.secondarystopcodesid
where a.specialty like '%HOSPICE%' or a.medicalservice like '%HOSPICE%'
    or sc.StopCode is not null  or sc2.StopCode is not null
	or a.specialty like '%ONCO%' or a.specialty like '%CHEMO%'
    or a.medicalservice like '%ONCO%' or a.medicalservice like '%CHEMO%'
	or a.specialty like '%RADIA%' or a.medicalservice like '%RADIA%' or
	(a.sta3n = 200 and (a.WardLocationname like '% CHEMO%'
       or a.WardLocationName like '% Comfort Care%'
       or a.wardlocationname like '% HEM%Onc%'
       or a.Wardlocationname like '% HOSPICE%'
	   or a.Wardlocationname like '% ONC%' or a.Wardlocationname like '% Pall%'
       or a.Wardlocationname like '% RAD%ONC%'))

;

DROP TABLE IF EXISTS #Visits1;
SELECT 
mvi.MVIPersonSID
,VisitDateTime as VisitDate
,Hospice
,Palliative
,Oncology
INTO #Visits1
from outpat.visit as a WITH (NOLOCK) 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
INNER JOIN #Locations as b
	on a.locationsid = b.LocationSID
where visitdatetime >= DATEADD(DAY,-366,GETDATE())
	and visitdatetime <= getdate()

;

/*** Adding Cerner data here. We may need to explore adding inpatient data for the cerner sites if exists any.***/
INSERT INTO #Visits1 (MVIPersonSID, VisitDate, Hospice, Palliative, Oncology)
SELECT MVIPersonSID
       ,TZDerivedVisitDateTime AS VisitDate
	   ,1 AS Hospice
	   ,0 AS Palliative
	   ,0 AS Oncology
	FROM [Cerner].[FactUtilizationOutpatient] as o WITH(NOLOCK) 
	WHERE (o.HospiceCareFlag = 1 OR o.MedicalService = 'Hospice')
		AND o.TZDerivedVisitDateTime >= cast(dateadd(day,-366,GETDATE())as datetime2(0))


DROP TABLE IF EXISTS #Inpat1;
SELECT
mvi.MVIPersonSID
,isnull(DischargeDateTime,AdmitDateTime) AS InpatDate
,Hospice
,Palliative
,Oncology
INTO #Inpat1
from inpat.inpatient as a WITH (NOLOCK) 
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
INNER JOIN #WardLocations as wl
	on wl.wardlocationsid = a.admitwardlocationsid
where (AdmitDateTime >= DateAdd(year,-1,getdate()) or
	 DischargeDateTime >= DateAdd(year,-1,getdate()))

;


DROP TABLE IF EXISTS #Inpat2;
SELECT
mvi.MVIPersonSID
,isnull(DischargeDateTime,AdmitDateTime) as InpatDate
,Hospice
,Palliative
,Oncology
INTO #Inpat2
from inpat.inpatient as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
INNER JOIN #WardLocations as wl
	on wl.wardlocationsid = a.dischargewardlocationsid
where (AdmitDateTime >= DateAdd(year,-1,getdate()) or
	 DischargeDateTime >= DateAdd(year,-1,getdate()))
	

;


DROP TABLE IF EXISTS #Exclusion1;
SELECT 
MVIPersonSID
,VisitDate
,Hospice
,Palliative
,Oncology
INTO #Exclusion1
FROM
	(
	SELECT
	MVIPersonSID
	,InpatDate as VisitDate
	,Hospice
	,Palliative
	,Oncology
	FROM #Inpat1
	where InpatDate >= DateAdd(year,-1,getdate())
	UNION
	SELECT
	MVIPersonSID
	,InpatDate as VisitDate
	,Hospice
	,Palliative
	,Oncology
	FROM #Inpat2
	where InpatDate >= DateAdd(year,-1,getdate())
	UNION
	SELECT
	MVIPersonSID
	,VisitDate
	,Hospice
	,Palliative
	,Oncology
	FROM #Visits1
	) as A

;

DROP TABLE IF EXISTS #Exclusion2;
SELECT
*
INTO #Exclusion2
FROM
	(
	select 
	MVIPersonSID
	,Hospice 
	,0 as Palliative
	,0 as Oncology
	,count(distinct VisitDate) as Visits
	from #Exclusion1
	where Hospice = 1
	group by MVIPersonSID, Hospice

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,Palliative
	,0 as Oncology
	,count(distinct VisitDate) as Visits
	from #Exclusion1
	where Palliative = 1
	group by MVIPersonSID, Palliative

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,0 as Palliative
	,Oncology
	,count(distinct VisitDate) as Visits
	from #Exclusion1
	where Oncology = 1
	group by MVIPersonSID, Oncology
	) as a

;


--0:00
DROP TABLE IF EXISTS #CPT;
select
CPTCode
,CPTName
,CPTSID
,case when cptname like '%HOSPICE%' then 1 else 0 end as Hospice
,0 as Palliative
,case when cptname not like '%HOSPICE%' then 1 else 0 end as Oncology
INTO #CPT
from dim.cpt
where 
	(cptname like '%HOSPICE%' and 
		(
		CPTCode in ('99377','99378','G0065','G0182','G9687','G9718','G9720','G9857','G9858','G9861','S0271','S9126','T2042','T2043')
		or (CPTCode like 'G94%' and CPTName like '%HOSPICE%')
		or (CPTCode like 'M102%' and CPTName like '%HOSPICE%')
		or (CPTCode like 'Q50%' and CPTName like '%HOSPICE%' and CPTCode not in ('Q5001','Q5002','Q5009'))
		)
	)
	or
	(cptcode like '964%' or (cptcode like '965[0-4]%' and cptname like '%CHEMO%'))
	or
	(cptname like '%radiation%therapy%' or cptname like '%RADIATION%DOSIMETRY%'
	or cptname like '%RADIATION%TX%' or cptname like '%RADIATION%MANAG%' or cptname like 'APPLY%RADIAT%')

;

--0:58

DROP TABLE IF EXISTS #CPTVisits1;
select 
mvi.MVIPersonSID
,cast(vproceduredatetime as date) as VisitDate
,Hospice
,Palliative
,Oncology
INTO #CPTVisits1
from outpat.VProcedure as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
INNER JOIN #CPT as c
	on a.cptsid = c.cptsid
where a.vproceduredatetime >= DateAdd(year,-1,getdate())
	and a.vproceduredatetime <= getdate()
	

;

DROP TABLE IF EXISTS #CPTInpat1;
select 
mvi.MVIPersonSID
,cptproceduredatetime as VisitDate
,Hospice
,Palliative
,Oncology
INTO #CPTInpat1
from inpat.inpatientcptprocedure a
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
INNER JOIN #CPT as c
	on a.cptsid = c.cptsid
join [$(CDWWork3)].[SPatient].[SPatient_EHR] as b	--2024/08/06: D&A PERC Support - Changed to resolve Build Warning due to original three part naming convention usage
	on b.patientsid = a.patientsid
where a.CPTProcedureDateTime >= getdate() - 365 
	and a.CPTproceduredatetime <= getdate()

;


DROP TABLE IF EXISTS #CPTExclusion;
SELECT DISTINCT
MVIPersonSID
,VisitDate
,Hospice
,Palliative
,Oncology
INTO #CPTExclusion
FROM
	(
	SELECT
	*
	FROM #CPTVisits1
	UNION
	SELECT
	*
	FROM #CPTInpat1
	) as A

;

DROP TABLE IF EXISTS #CPTExclusion2;
SELECT
*
INTO #CPTExclusion2
FROM
	(
	select 
	MVIPersonSID
	,Hospice 
	,0 as Palliative
	,0 as Oncology
	,count(distinct VisitDate) as Visits
	from #CPTExclusion
	where Hospice = 1
	group by MVIPersonSID, Hospice

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,Palliative
	,0 as Oncology
	,count(distinct VisitDate) as Visits
	from #CPTExclusion
	where Palliative = 1
	group by MVIPersonSID, Palliative

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,0 as Palliative
	,Oncology
	,count(distinct VisitDate) as Visits
	from #CPTExclusion
	where Oncology = 1
	group by MVIPersonSID, Oncology
	) as a

;


/********************************************************************************
Intentions: Identify Hospice patients based on SNOMED Codes
Limitations: SNOMED Codes are not always mapped to ICD9/10 codes properly 
    so this is limited to only ICD9/10 codes that have yet to be mapped.
    - SPV data is used. Need to validate the CDWWork3 ProblemList table 
      before transitioning.

Results: 18649 rows returned on 2022-05-02 in 25.056 sec.
*********************************************************************************/
DROP TABLE IF EXISTS #SNOMED_PL;
SELECT
*
into #SNOMED_PL 
FROM
	(
	select distinct 
	mvi.MVIPersonSID
	,MAX(case when b.ICD10Code <> 'Z51.5' then 1 else 0 end) over(partition by mvi.MVIPersonSID) as Hospice
	,MAX(case when b.ICD10Code = 'Z51.5' and a.ActiveFlag = 'A' then 1 else 0 end) over(partition by mvi.MVIPersonSID) as Palliative
	, 0 as Oncology

	from Outpat.ProblemList as a
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
	left join Dim.ICD10 as b 
		on a.ICD10SID = b.ICD10SID
			and b.ICD10Code = 'R69.' or b.ICD10Code = 'Z51.5' -- Generic unmapped diagnosis for ICD10
	left join Dim.ICD9 as c 
		on a.ICD9SID = c.ICD9SID
			and c.ICD9Code = '799.9' -- Generic unmapped diagnosis for ICD9
	where a.SNOMEDCTConceptCode in (
		'170935008'
		, '111947009'
		, '446260003'
		, '767503006'
		, '305911006'
		, '170936009'
		, '64703005'
		, '162607003'
		, '162608008'
		, '300936002'
		, '1891000124102'
		, '1921000124108'
		, '1971000124109'
		, '1951000124104'
		, '448451000124101'
		, '452531000124108'
		, '452591000124109'
		)
		and (
			b.ICD10Code is not null
			or c.ICD9Code is not null
		)
		and mvi.MVIPersonSID is not null 
		and a.EnteredDateTime >= DateAdd(year,-5,getdate())
		and ProblemListCondition = 'P' 
		and (a.ActiveFlag = 'A' or EnteredDateTime >= DateAdd(year,-1,getdate()))
	) as A
Where 1 in (Palliative, Hospice)

;

/********************************************************************************
Intentions: Remove Hospice patients identified by health factors such as 
      the National Clinical Reminder within the past 1 year
    - Aims to pull the following:
        Hospice
        Terminal Illness
        Limited Life Expectancy < 6 Months
            - Note: Hospice upper limit defined as 6 months
Limitations: 
    - Unvalidated

Results: ### rows returned on 2022-05-02 in XXX sec.
*********************************************************************************/
DROP TABLE IF EXISTS #LLE_HFs;
with a as (
	select HealthFactorTypeSID
	from Dim.HealthFactorType 
	where (
		HealthFactorType like '%hospice%'
		OR HealthFactorType like '%terminal%'
		OR (
			HealthFactorType like '%life%'
				and (
						(
						HealthFactorType like '%limited%' 
						OR HealthFactorType like '%exp%' 
						)
					OR HealthFactorType like '%<%'
					)
				and (
					HealthFactorType like '%6%'
					OR HealthFactorType like '%six%'
					)
			)
		)
		and HealthFactorType not like '%NO%'
		and HealthFactorType not like '%Refer%'
		and HealthFactorType not like '%fund%'
		and HealthFactorType not like '%>%'
		and HealthFactorType not like 'ALS HOSPICE INFORMATION PROVIDED'
)

select mvi.MVIPersonSID
	, 1 as Hospice
	, 0 as Palliative
	, 0 as Oncology
into #LLE_HFs
from HF.HealthFactor as b 
join a 
	on a.HealthFactorTypeSID = b.HealthFactorTypeSID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON b.PatientSID = mvi.PatientPersonSID 
where b.HealthFactorDateTime >= getdate() - 180
	
;

DROP TABLE IF EXISTS #HospiceOI;
SELECT a.[OrderableItemSID]
    , a.[OrderableItemName]
INTO #HospiceOI
FROM [Dim].[OrderableItem] AS a
LEFT OUTER JOIN [Dim].[DisplayGroup] AS b
	ON a.[DisplayGroupSID] = b.[DisplayGroupSID]
WHERE a.[OrderableItemName] LIKE '%HOSPICE%'
    AND a.[OrderableItemName] NOT LIKE '%CONSULT%'
    AND a.[OrderableItemName] NOT LIKE '%ANTICIPATED%'
    AND ISNULL( b.[DisplayGroupName], 'Hamburger' ) NOT LIKE '%PHARMACY%'
    AND a.[OrderableItemName] NOT LIKE '%ASSESSMENT%'
    AND a.[OrderableItemName] NOT LIKE '%REFERRAL%'
    AND a.[OrderableItemName] NOT LIKE '%PALLIATIVE%'

;

DROP TABLE IF EXISTS #HospiceOI2;
select
mvi.MVIPersonSID
INTO #HospiceOI2
from cprsorder.ordereditem as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
join #HospiceOI as c
	on a.orderableitemsid = c.orderableitemsid

where orderstartdatetime >= DateAdd(year,-1,getdate())

;

DROP TABLE IF EXISTS #OncologyICDCodes;
select 
a.ICD10SID
,ICD10Code
,ICD10Description
INTO #OncologyICDCodes
from dim.ICD10 as a
left join dim.ICD10DescriptionVersion as b
	on a.icd10sid = b.icd10sid
where (icd10code like 'C%' or icd10code = 'G89.3') and icd10code not like 'C44%' and ICD10Code not like 'C43%' and ICD10Description not like '%IN Remiss%'
	--or (Icd10code like 'Z8[5-6]%' and ICD10Description like '%PERSONAL%MALIGNANT%')

;


DROP TABLE IF EXISTS #OncologyDx;
select 
mvi.MVIPersonSID
,0 as Hospice
,0 as Palliative
,1 as Oncology
,count(distinct cast(VisitDateTime as date)) as Visits
INTO #OncologyDx
from outpat.VDiagnosis as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
join #OncologyICDCodes as b
	on a.icd10sid = b.icd10sid
where VisitDateTime >= DateAdd(year,-1,getdate())
	and VisitDateTime <= getdate()
group by MVIPersonSID

;

DROP TABLE IF EXISTS #InpatOnc;
select
mvi.MVIPersonSID
,0 as Hospice
,0 as Palliative
,1 as Oncology
INTO #InpatOnc
from inpat.InpatientDiagnosis as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
join #OncologyICDCodes as b
	on a.icd10sid = b.icd10sid
where DischargeDateTime >= DateAdd(year,-1,getdate())

;

DROP TABLE IF EXISTS #OncPL
SELECT 
mvi.MVIPersonSID
,0 as Hospice
,0 as Palliative
,1 as Oncology
INTO #OncPL
from outpat.ProblemList as a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
Join #OncologyICDCodes as B
	on a.icd10sid = b.ICD10SID
where ActiveFlag = 'A' and ProblemListCondition = 'P' and EnteredDateTime >= DateAdd(year,-3,getdate())

;

DROP TABLE IF EXISTS #Cerner1
select 
mvi.MVIPersonSID
,cast(ActivityDateTime as date) as ActivityDate
,case when MedService like '%HOSPICE%' or PerformingLocation like '%HOSPICE%' or ChargeDescription like '%HOSPICE%' then 1 else 0 end as Hospice
,case when medservice like '%PALLIATIVE%' or performinglocation like '%PALLIATIVE%' or ChargeDescription like '%PALLIATIVE%' then 1 else 0 end as Palliative
,case when medservice like '%ONCOLOGY%' or PerformingLocation like '%ONCOLOGY%' or ChargeDescription like '%ONCOLOGY%'
	or medservice like '%chemotherapy%' or PerformingLocation like '%chemotherapy%' or ChargeDescription like '%chemotherapy%' then 1 else 0 end as Oncology
INTO #Cerner1
from BillingMill.ChargeItem as a
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PersonSID = mvi.PatientPersonSID 
left join [NDimMill].[BillItem] as b
	on b.BillItemSID = a.BillItemSID
where (MedService like '%HOSPICE%' or PerformingLocation like '%HOSPICE%' or ChargeDescription like '%HOSPICE%'
	or medservice like '%PALLIATIVE%' or performinglocation like '%PALLIATIVE%' or ChargeDescription like '%PALLIATIVE%'
	or medservice like '%ONCOLOGY%' or PerformingLocation like '%ONCOLOGY%' or ChargeDescription like '%ONCOLOGY%'
	or medservice like '%chemotherapy%' or PerformingLocation like '%chemotherapy%' or ChargeDescription like '%chemotherapy%')
	and (ActivityType like '%OFFICE%VISIT%' or activitytype like '%PALLIATIVE%' or activitytype like '%CHEMOTHERAPY%'
		or ActivityType like '%CODInG%CHAGE%' or activitytype like '%CODING%CHANG%' or activitytype like '%CODING%CHAR%' 
		or activitytype like '%PASTORAL%MONITOR%' or activitytype like '%ONCOLOGY%' 
		or activitytype like '%PERSON%MANAGEMENT%' or activitytype like '%SPECIAL%SERV%'
		or activitytype like '%HCBC%' or activitytype like '%CLINICAL%CONTACT%' or activitytype like '%NURSING%'
		or activitytype like '%PATIENT%CARE%' or activitytype like '%MENTAL%HEALTH%' or activitytype like '%SURGERY%'
		or activitytype like '%ADMIT%' or ActivityType like '%PHARMACY%')
	and activitytype not like '%CONSULT%'
	 and mvi.MVIPersonSID is not null
	and ActivityDateTime >= DateAdd(year,-1,getdate())
	and ActivityDateTime <= getdate()

;


DROP TABLE IF EXISTS #Cerner;
SELECT
*
INTO #Cerner
FROM
	(
	select 
	MVIPersonSID
	,Hospice 
	,0 as Palliative
	,0 as Oncology
	,count(distinct ActivityDate) as Activities
	from #Cerner1
	where Hospice = 1
	group by MVIPersonSID, Hospice

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,Palliative
	,0 as Oncology
	,count(distinct ActivityDate) as Activities
	from #Cerner1
	where Palliative = 1
	group by MVIPersonSID, Palliative

	UNION

	select 
	MVIPersonSID
	,0 as Hospice 
	,0 as Palliative
	,Oncology
	,count(distinct ActivityDate) as Activities
	from #Cerner1
	where Oncology = 1
	group by MVIPersonSID, Oncology
	) as a

;


DROP TABLE IF EXISTS #ExclusionFinal;
select DISTINCT
MVIPersonSID
,MAX(Hospice) over(partition by MVIPersonSID) as Hospice
,MAX(Palliative) over(partition by MVIPersonSID) as Palliative
,MAX(Oncology) over(partition by MVIPersonSID) as Oncology
INTO #ExclusionFinal
FROM
	(
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #Exclusion2
	where 1 in (Hospice,palliative) or visits >= 5
	UNION
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #CPTExclusion2
	where 1 in (Hospice,Palliative) or visits >= 3
	UNION
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #SNOMED_PL
	UNION
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #LLE_HFs
	UNION
	select 
	*
	,1 as Hospice
	,0 as Palliative
	,0 as #Oncology
	FROM #HospiceOI2
	UNION
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	FROM #OncologyDx
	where 1 in (Hospice,Palliative) or Visits >= 2
	UNION
	select 
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #InpatOnc
	UNION
	select
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	from #OncPL
	UNION
	select
	MVIPersonSID
	,Hospice
	,Palliative
	,Oncology
	FROM #Cerner
	where 1 in (Hospice,Palliative) or Activities >= 2
	) as a

;

EXEC Maintenance.PublishTable 'ORM.HospicePalliativeCare', '#ExclusionFinal'

EXEC [Log].[ExecutionEnd]

END