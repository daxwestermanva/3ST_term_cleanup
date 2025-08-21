

/***
=============================================
Author:		<Tolessa Gurmessa>
Create date: <8/6/2018>
Initial development for NonVAMeds.
10/02/2018	SG	- Removed DROP/Create for permanent tables and cleanup the temp tables at the end
20181012	RAS - Added MVIPersonSID. Removed IF statement for truncate to outside try -- this way if the first error is thrown then nothing else is attempted.
20190105	RAS - Added Maintenance PublishTable
20200422		- RAS Removed Barbiturate_Rx, CYP3A4_inhibitors_Rx, and SOMA_Rx from final table. These no longer exist in LookUp.NationalDrug.
20200422		- RAS	Formatting. Added ChecklistID. Removed join with SPatient to get PatientICN. 
				- Changed date precision to DATE in WHERE statement so that it can be run at different times on same day, with the same result.
				- Replaced joins with Dim_LocalDrug and LookUp.NationalDrug with new view LookUp.PharmacyOrderableItem which contains fields and logic previously in this code.
20210913		- AI	Enclave Refactoring - Counts confirmed
20210917	AI: - Enclave Refactoring - Refactored comments, no testing performed
20221107	WK  - Updating the definition of opioidagonist_rx and opioidforpain_rx see "updates to opioid agonist and opioid for pain measure" below
				- Removed missing entries (sid -1) and entries relating to zzdrug (sid 1200012788) entries from [LookUp].[PharmacyOrderableItem]
				- Added logic from the pharmacyorderableitem table to label opioidforpain and opioid agonist and set them to occur before applying values from the pharmacyorderableitem table and other logic
				- Logic to Assign all prescriptions with pharmacyorderableitem LIKE '%NON-VA METHADONE%' AND poi.Sta3n = 593 to 0 was removed because it only effected 13 prescriptions
				- Logic for Opium was updated to remove accidental opium identification
20230105	WK  - Added additional logic for buprenorphine prescriptions as opioid for pain or opioid antagonists
				- Added logic for naltrexone to be incorporated into CNS_ActiveMed_Rx or AlcoholPharmacyothery_Rx
				- Moved the lookup.pharmacyorderableitem table from the 
				- To identify patients with OUD data for procedures (Jcodes) and stop codes of interest were included in the Patient OUD list
Changes from 2030105 rolled back for February deployment and reimplemented in March deployment
20230215	WK  - Updated logic for CNS_ActiveMed_Rx, AlcoholPharmacyothery_Rx, opioidagonist_rx and opioidforpain_rx to updates instead of case statements
			WK  - Updated timeframe back to a 12 month lookback period
			WK  - Included NonVAMedsid in the final table to help trouble shoot 
			WK  - Removed Naltrexone, methadone and buprenorphine in final section of opioidforpain identification
1/1/2025	SM  - Integrating with Oracle Health - non va meds are entered as orders in OH. OrderCatalogSynonymSID is mapped to VUID where feasible in Cerner.Dim.OrderCatalog
				- updating timeline to 13m to meet RV2 requirements
				- Updated defintion for Methadone for opioidagonist/opioidforpain - do not use ordername information, just if OUD present in past year (add CC OUD)
				- Updated defintion for Buprenorphrine for opioidagonist/opioidforpain - do not use ordername information, just if OUD present in past year (add CC OUD)
					-- exception - patch meds which can only be for pain
				- Nonva med variables in RV2:  20
						SELECT distinct [InstanceVariable] FROM [REACH].[Predictors] where [InstanceVariable] like '%nonva%' order by InstanceVariable
			NonVA_Atypical_Antidepressant
			NonVA_MAOI
			NonVA_NonPainSNRI
			NonVA_NonPainTCA
			NonVA_PainAdjSNRI
			NonVA_PainAdjTCA
			NonVA_RX_ALCOHOL_PHARMACOTHERAPY
			NonVA_RX_ANALGESIC_COMBINED
			NonVA_RX_ANTIPSYCHOTIC
			NonVA_RX_ANXIOLYTIC
			NonVA_RX_BARBITURATES
			NonVA_Rx_BENZODIAZEPINE
			NonVA_RX_Folic_Acid
			NonVA_RX_MOODSTABILIZER
			NonVA_Rx_OpioidForPain
			NonVA_RX_PAINADJ_ANTICONVULSANT
			NonVA_RX_SEDATIVE_ZDRUG
			NonVA_RX_STATIN
			NonVA_RX_STIMULANT
			NonVA_SSRI

2/18/2025	SM	- added CC OUD dx per Matt Boden's method - pointing to OMHSP_PERC_Core.[MDS].[Common_IVC_MHSEOC_Claim]
				- deprecated values sets from lookup.NationalDrug not used downstream
				- using SetTerms in ALEX, updated where investigation of values sets between ALEX and lookup.NationalDrug are discrepant
				- update SetTerm statements based on current truth 
2/27/25		SM	- adding Marijuana category to support STORM, 
				- updating dx extraction to include Present.Diagnosis as step1, next sprint update CC extrcation and add DoD data
				- Next Sprint: Use ORM.DoD_OUD per BK, Data in [ORM].[vwDOD_DxVertical] used in Present.Diagnosis does not have an instance date
3/31/25		SM	- Added ORM.DoD_OUD to sources of OUD dx
				- adding  XLA SetTerm 'NaloxoneKit' plus search  ordername like 'Naloxone'
				- Update SetTerm - per AR per SUD16 definition
						
						a) Setterm =MethadoneOtp or (ordername like Methadone and SetTerm IS NULL): 
							1) Update SetTerm to MOUD - OUD dx in past year 
							2) Update SetTerm to Opioidforpain - no OUD in past year
						b) Setterm =NaltrexoneInj or SetTerm=BuprenorphineMedications
							1) Update SetTerm to MOUD
						c) Ordername like '%Naltrexone%'  and SetTerm is NULL
							1) Update SetTerm to MOUD if OUD dx in past year 
						c) Ordername like '%Buprenor%'  and SetTerm is NULL
							1) Update SetTerm to MOUD if OUD dx in past year 
							2) Update SetTerm to Opioidforpain - no OUD in past year

Issues:
1) mapping of rx values in CDS may not be same as mapping for PP
1.1) [Nationaldrug].opioidagonist_rx has 59 less methadone formulations than [Lib_SetValues_CDS].setterm='Methadone'
3) DerivedOrderCatalogSID =1800007448  has a PrimaryMnemonic =miscellaneous medication , not sure this can be mapped beyond this non specific entry...
4) VISTA mapping PharmacyOrderableItemSID to nationaldrugSID in Lookup.NationalDrug: #MapPharmacyOrderableItem_NationaDrugSID
4.1) duplicates at PharmacyOrderableItemSID - 517/376,382 rows total  
=============================================
*/
CREATE PROCEDURE [Code].[Present_NonVAMed]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Present_NonVAMed','Execution of Code.Present_NonVAMed SP'

/** PUBLISHED TABLE
DROP TABLE IF  EXISTS [Present].[NonVAMed]
CREATE TABLE [Present].[NonVAMed](
	[MVIPersonSID] [int] NULL,
	[PatientPersonSID] [int] NULL,
	[Sta3n] [int] NOT NULL,
	[Sta6a] [nvarchar](100) NULL,
	[InstanceFromDate] [date] NULL,
	[InstancetoDate] [date] NULL,
	[InstanceSID] [bigint] NOT NULL,
	[InstanceType] [varchar](14) NOT NULL,
	[OrderSID] [int] NULL,
	[OrderType] [varchar](24) NOT NULL,
	[OrderName] [varchar](100) NULL,
	[DodFlag] [int] NULL,
	[Source] [varchar](1) NOT NULL,
	[DrugNameWithoutDose_Max] [varchar](100) NULL,
	[SetTerm] [varchar] (200),
	[OUD_Methadone_BUP_PastYear] [int] NULL,
	[UpdatedPerName] [varchar](250) NULL
) ON [DefFG]
*/
;
----------------------------------------------------------------------------------------
-- ID patients with OUD in past year
-- PP code did not use workload criteria
-- will need to verify OUD dx 1 year prior to methadone as in PP code (need to extract 25m)
----------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #OUD_SID
select DISTINCT ICD10SID,ICD10Code,DxCategory 
INTO #OUD_SID
FROM [LookUp].[ICD10_VerticalSID] b 
where DxCategory like 'OUD'
;
------------------------------------------------------------------------------------------------------------------------------
--OUD DX dates in past 25 months
--PP code did not use workload criteria 
------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS  #OUD_dx --1,764,366
SELECT DISTINCT *
INTO #OUD_dx
FROM
(
		-- VISTA Outpatient Diagnosis
		SELECT   
		c.MVIPersonSID
		,InstanceDate=a.VisitDateTime
		,InstanceSID=cast (a.VisitSID as varchar (100))
		,InstanceSource='V'
		,b.DxCategory
		FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
		  INNER JOIN App.vwCDW_Outpat_Workload w WITH (NOLOCK)  -- from Present_Diagnosis code
					ON a.VisitSID=w.VisitSID
		  INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
					ON c.PatientPersonSID = a.PatientSID 
		  INNER JOIN #OUD_SID b
					ON a.[ICD10SID] = b.[ICD10SID]
			WHERE a.VisitDateTime >= DATEADD(DAY, -912, GETDATE()) -- 25M
		UNION
		-- VISTA Inpatient Diagnosis source -  using startdate=admitdate in PP code
		SELECT   
		c.MVIPersonSID
		,InstanceDate=d.AdmitDateTime
		,InstanceSID=cast (d.InpatientSID as varchar (100))
		,InstanceSource='V'
		,b.DxCategory
		  FROM Inpat.InpatientDiagnosis a WITH (NOLOCK)
		  INNER JOIN Inpat.Inpatient as d  WITH (NOLOCK)
				on a.InpatientSID = d.InpatientSID
		  INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
				ON c.PatientPersonSID = a.PatientSID 
		  INNER JOIN #OUD_SID b
			ON a.[ICD10SID] = b.[ICD10SID]
			WHERE d.AdmitDateTime >= DATEADD(DAY, -912, GETDATE()) -- 25M OR a.DischargeDateTime IS NULL
		UNION
		-- VISTA Inpatient Discharge Diagnosis source -  using startdate=admitdate in PP code
		SELECT   
		c.MVIPersonSID
		,InstanceDate=a.AdmitDateTime
		,InstanceSID=cast (a.InpatientSID as varchar (100))
		,InstanceSource='V'
		,b.DxCategory
		  FROM Inpat.InpatientDischargeDiagnosis a WITH (NOLOCK)
		  INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
				ON c.PatientPersonSID = a.PatientSID 
		  INNER JOIN #OUD_SID b
			ON a.[ICD10SID] = b.[ICD10SID]
			WHERE a.AdmitDateTime >= DATEADD(DAY, -912, GETDATE()) -- 25M OR a.DischargeDateTime IS NULL
		UNION
		-- VISTA Inpatient Specialty transfer Diagnosis source - using startdate=admitdate in PP code
		SELECT  
		c.MVIPersonSID
		,InstanceDate=d.AdmitDateTime
		,InstanceSID=cast (a.InpatientSID as varchar (100))
		,InstanceSource='V'
		,b.DxCategory
		  FROM Inpat.SpecialtyTransferDiagnosis a WITH (NOLOCK)
		  INNER JOIN Inpat.Inpatient as d  WITH (NOLOCK)
				on a.InpatientSID = d.InpatientSID
		  INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
				ON c.PatientPersonSID = a.PatientSID 
		  INNER JOIN #OUD_SID b
			ON a.[ICD10SID] = b.[ICD10SID]
			WHERE d.AdmitDateTime >= DATEADD(DAY, -912, GETDATE()) -- 25M OR a.SpecialtyTransferDateTime IS NULL
		UNION
		--Oracle Health
		SELECT  c.MVIPersonSID
			  ,InstanceDate=c.TZDerivedDiagnosisDate
			  ,InstanceSID=cast (c.EncounterSID as varchar (100))
		 	  ,InstanceSource='M'
			  ,b.DxCategory
		FROM	(
				SELECT MVIPersonSID, EncounterSID, TZDerivedDiagnosisDate= cast (TZDerivedDiagnosisDateTime as date), SourceIdentifier FROM [Cerner].[FactDiagnosis] 
				) c 
		INNER JOIN #OUD_SID b  
			ON c.SourceIdentifier=b.ICD10code
		WHERE c.TZDerivedDiagnosisDate >= DATEADD(DAY, -912, GETDATE()) -- 25M
		UNION
		-- Community Care 
		select   MVIPersonSID
		,InstanceDate=a.ServiceStartDate -- visit date or admit date
		,InstanceSID=a.ClaimSID
		,InstanceSource='CC'
		,c.DxCategory
		from [MDS].Common_IVC_MHSEOC_Claim as A    WITH (NOLOCK)
		inner join Common.MasterPatient as B WITH (NOLOCK)
			on a.PatientICN=b.PatientICN    
		inner join #OUD_SID as C 
			on a.PrimaryICD=c.ICD10Code
		WHERE a.ServiceStartDate >= DATEADD(DAY, -912, GETDATE()) -- 25M
		UNION
		--Present.Diagnosis
		SELECT DISTINCT [MVIPersonSID]
		,InstanceDate=[MostRecentDate]
		,InstanceSID='NA'
		,InstanceSource='Present_Diagnosis'
		,b.DxCategory
		FROM [Present].[DiagnosisDate] a WITH (NOLOCK)  -- no date restriction since it should be in past 12m
		inner join #OUD_SID as b 
			on a.[ICD10Code]=b.ICD10Code
		UNION
		-- DoD
		SELECT DISTINCT [MVIPersonSID]
		,InstanceDate=instance_date
		,InstanceSID='NA'
		,InstanceSource='DoD'
		,b.DxCategory
		FROM [ORM].[dod_oud] a WITH (NOLOCK)
		inner join #OUD_SID as b 
			on a.ICD10_dot=b.ICD10Code
		WHERE a.instance_date >= DATEADD(DAY, -912, GETDATE()) -- 25M
)a
;
----------------------------------------------------------------------------------------
-- Values sets used in REACH VET 2.0 and STORM (downstream dependency)
----------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #RequiredValuesets
Select distinct value
, detail
,SetTerm
INTO  #RequiredValuesets
from [XLA].[Lib_SetValues_CDS] WITH (NOLOCK) -- USE CDS definition for RV 2.0 and not CPP
where vocabulary like '%vuid%' 
and setterm in 
(
'ANXIOLYTIC'
,'OpioidforPain'
,'PainAdjSNRI'
,'PainAdjTCA'
,'AlcoholPharmacotherapy'
,'AnalgesicCombined'
,'ANTIPSYCHOTIC'
,'BARBITURATES'
,'BENZODIAZEPINE'
,'MOODSTABILIZER'
,'STATIN'
,'STIMULANT'
,'SSRI'
,'FolicAcid'
,'PainAdjAnticonvulsant'
,'SedativeZdrug'
,'ControlledSubstance'
,'BuprenorphineMedications'
,'NaltrexoneInj'
,'MethadoneOtp'
,'NaloxoneKit'
)
UNION
Select distinct value, detail, SetTerm 
from [XLA].[Lib_SetValues_ALEX] WITH (NOLOCK) -- AR just added to ALEX 2/12 for RV 2.0
where vocabulary like '%vuid%' 
and setterm in 
(
'AtypicalAntidepressant'
,'MAOI'
,'SNRINonpain'
,'TcaNonpain'
)
UNION
/** missing this VUID in ALEX  **/
Select distinct value, detail, SetTerm ='OpioidforPain'  
from [XLA].[Lib_SetValues_CDS] WITH (NOLOCK)
where vocabulary like 'vuid'  and value='4041817'  --METHADONE HCL 10MG/ML SOLN,ORAL SYRINGE 1ML (was in Lookup.NationalDrug used in STORM)
UNION
/** Using Original [lookup].[Nationaldrug]  since used in STORM and ALEX definition either are more restrictive or does not exist **/
select distinct vuid , drugnamewithdose, setterm='SedatingPainORM_Rx' -- does not exist in ALEX
from [lookup].[Nationaldrug]  WITH (NOLOCK)
where SedatingPainORM_Rx = 1 
UNION
--/**

/** Marijuana - SetTerm=Marijuana (Not in ALEX)**/
select distinct vuid , drugnamewithdose, setterm='Marijuana'   
from [lookup].[Nationaldrug]  WITH (NOLOCK)
where drugnamewithdose like '%Marijuana%'



----------------------------------------------------------------------------------------
-- Mapping PharmacyOrderableItemSID to VUID 0,0013 duplicates
--Excludes supplies and other non relevant items ro reduce noise ( exclusion applied in MPR computation) VUID with dose granularity
----------------------------------------------------------------------------------------

--STEP 1 - maxing out drugnamewithdose when multiple values for drugnamewithdose
DROP TABLE  IF EXISTS  #PharmacyOrderableItemSID_DrugNameWithoutDose_Max
SELECT 
		poi.PharmacyOrderableItemSID
		,poi.PharmacyOrderableItem
		,poi.InactiveDateTime
		,DrugNameWithoutDose_Max=max (DrugNameWithoutDose) 
INTO #PharmacyOrderableItemSID_DrugNameWithoutDose_Max
FROM
		(
				select PharmacyOrderableItemSID,PharmacyOrderableItem,InactiveDateTime
				from [Dim].[PharmacyOrderableItem] 
				where pharmacyorderableitemsid > 0 
				and  pharmacyorderableitemsid != 1200012788 
				and pharmacyorderableitemsid !=1200117328 
				and  PharmacyOrderableItem NOT LIKE 'ZZ%'-- Per JT -> Exclude ZZ Drugs
		) poi
LEFT JOIN [Dim].[LocalDrug] ld  WITH (NOLOCK) ON poi.PharmacyOrderableItemSID = ld.PharmacyOrderableItemSID 
LEFT JOIN [LookUp].[NationalDrug] as nd WITH (NOLOCK) on nd.NationalDrugSID=ld.NationalDrugSID 
WHERE 1=1 -- excluding supplies and such as done in MPR
AND nd.[PrimaryDrugClassCode] NOT LIKE 'AA%' -- Introduction 
AND nd.[PrimaryDrugClassCode] NOT LIKE 'AS%' -- Antiseptics 
AND nd.[PrimaryDrugClassCode] NOT LIKE 'HA%' -- Herbs/alternative therapies 
AND nd.[PrimaryDrugClassCode] NOT LIKE 'IP%' -- INTRAPLEURAL AGENTS 
AND nd.[PrimaryDrugClassCode] NOT LIKE 'PH%' -- PHARMACEUTICAL AIDS/REAGENTS 
AND nd.[PrimaryDrugClassCode] NOT LIKE 'X%' -- Supply Items 
GROUP BY poi.PharmacyOrderableItemSID
,poi.PharmacyOrderableItem
,poi.InactiveDateTime
;


-- STEP 2 - Adding VUID
DROP TABLE  IF EXISTS  #MapPharmacyOrderableItem_VUIDwithdose 
SELECT DISTINCT
poi.DrugNameWithoutDose_Max
,poi.PharmacyOrderableItemSID
,poi.PharmacyOrderableItem
,poi.InactiveDatetime
,VUIDwithdose=nd.VUID
,rv.SetTerm
INTO  #MapPharmacyOrderableItem_VUIDwithdose 
FROM #PharmacyOrderableItemSID_DrugNameWithoutDose_Max poi
LEFT JOIN [Dim].[LocalDrug] ld WITH (NOLOCK) ON poi.PharmacyOrderableItemSID = ld.PharmacyOrderableItemSID 
LEFT JOIN [LookUp].[NationalDrug] as nd WITH (NOLOCK) on nd.NationalDrugSID=ld.NationalDrugSID 
INNER JOIN  #RequiredValuesets as rv on rv.value=nd.VUID
WHERE rv.value IS NOT NULL

;
----------------------------------------------------------------------------------------
-- OH mapping --OrderCatalogSynonymSID to [LookUp].[NationalDrug]- VUIDwithdose 
--Excludes supplies and other non relevant items ro reduce noise ( exclusion applied in MPR computation) VUID with dose granularity
----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS  #Map_OrderCatalogSynonymSID 
SELECT DISTINCT
c.DrugNameWithoutDose_Max
,a.OrderCatalogSynonymSID
,a.PrimaryMnemonic
,a.VUIDwithDose
,rv.SetTerm
INTO  #Map_OrderCatalogSynonymSID
FROM [Cerner].[DimOrderCatalog] a  WITH (NOLOCK)
LEFT JOIN #RequiredValuesets as rv on rv.value=a.VUIDwithDose
LEFT JOIN ( -- Max drugnamewithoutdose
			select OrderCatalogSynonymSID,DrugNameWithoutDose_max=max (DrugNamewithoutDose ) 
			from [Cerner].[DimOrderCatalog] WITH (NOLOCK)
			group by OrderCatalogSynonymSID
			)c on a.OrderCatalogSynonymSID=c.OrderCatalogSynonymSID
WHERE a.VUIDwithDose IS NOT NULL

----------------------------------------------------------------------------------------
-- NON VA MEDS
----------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------
-- VISTA NonVaMeds
------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #VISTA 
SELECT  DISTINCT
	ISNULL(mvi.MVIPersonSID, 0) AS MVIPersonSID
	,PatientPersonSID=nvm.PatientSID
	,nvm.Sta3n
	,df.Sta6a
	,InstanceFromDate=cast (nvm.DocumentedDateTime as date)
	,InstancetoDate= cast (nvm.DiscontinuedDateTime as date)
	,InstanceSID=nvm.NonVAMedSID
	,InstanceType='NonVAMedSID'
	,OrderSID=nvm.PharmacyOrderableItemSID
	,OrderType='PharmacyOrderableItemSID'
	,OrderName=poi.PharmacyOrderableItem
	,[DodFlag]=0
	,Source='V'
	,poi.DrugNameWithoutDose_Max
	,poi.SetTerm
INTO #VISTA
FROM [NonVAMed].[NonVAMed] nvm WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	ON nvm.PatientSID = mvi.PatientPersonSID
LEFT JOIN #MapPharmacyOrderableItem_VUIDwithdose  poi
	ON nvm.PharmacyOrderableItemSID = poi.PharmacyOrderableItemSID
LEFT JOIN [Dim].[Location] l WITH (NOLOCK)
	ON l.LocationSID = nvm.LocationSID
LEFT JOIN [LookUp].[DivisionFacility] df WITH (NOLOCK)
	ON df.DivisionSID = l.DivisionSID
WHERE 1=1
AND ( MVIPERSONSID>0 )
AND poi.PharmacyOrderableItem not like 'ZZ%'
AND
---TIMFRAME = past 13 m------------------------------		
			(			-- started in timeframe
						nvm.DocumentedDateTime  BETWEEN DATEADD(month, -13, CAST(GETDATE() AS DATE)) AND CAST (GETDATE() as date) 
				OR 
					(	-- started before end of timeframe and not discontinued
						nvm.DocumentedDateTime < DATEADD(month, -13, CAST(GETDATE() AS DATE)) and nvm.DiscontinuedDateTime  is null
					)
				OR 
					(-- started before timeframe and discontinued during timeframe
					nvm.DocumentedDateTime < DATEADD(month, -13, CAST(GETDATE() AS DATE)) AND nvm.DiscontinuedDateTime  >= DATEADD(month, -13, CAST(GETDATE() AS DATE))
					)
			)
;
------------------------------------------------------------------------------------------------------------------------------
--ORACLE HEALTH NonVaMeds
------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #OH 
SELECT DISTINCT a.[MVIPersonSID]
,PatientPersonSID=a.PersonSID
,Sta3n=200
,a.STA6A
,InstanceFromDate=cast (a.[TZOrderUTCDateTime] as date)
,InstancetoDate= cast (a.TZProjectedStopUTCDateTime as date)
,InstanceSID=a.PersonOrderSID
,InstanceType='PersonOrderSID'
,OrderSID=a.[OrderCatalogSynonymSID]
,OrderType='OrderCatalogSynonymSID'
,OrderName=a.[OrderCatalog]
,a.[DodFlag]
,Source='M'
,b.DrugNameWithoutDose_Max
,b.SetTerm
INTO #OH
FROM [Cerner].[FactPharmacyNonVAMedOrder] a WITH (NOLOCK)
LEFT JOIN   #Map_OrderCatalogSynonymSID b on a.OrderCatalogSynonymSID=b.OrderCatalogSynonymSID
WHERE 1=1
	AND ( MVIPERSONSID>0  )
	AND [ContributorSystem]  in ('PowerChart') -- excluding historic data ingested from VA
	AND a.OrderCatalog not like 'ZZ%'
	AND
---TIMFRAME = past 13 m------------------------------		
			(			-- started in timeframe
						TZOrderUTCDateTime   BETWEEN DATEADD(month, -13, CAST(GETDATE() AS DATE)) AND CAST (GETDATE() as date) 
				OR 
					(	-- started before end of timeframe and not discontinued
						TZOrderUTCDateTime < DATEADD(month, -13, CAST(GETDATE() AS DATE)) and TZProjectedStopUTCDateTime is null
					)
				OR 
					(-- started before timeframe and discontinued during timeframe
					TZOrderUTCDateTime < DATEADD(month, -13, CAST(GETDATE() AS DATE)) AND TZProjectedStopUTCDateTime >= DATEADD(month, -13, CAST(GETDATE() AS DATE))
					)
			);

------------------------------------------------------------------------------------------------------------------------------
--- Staging Table  - defining if OUD dx in previous year for methadone /buprenorphrine/ naltrexone instance 
------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #METHADONE_BUPRENORPHINE_Naltrexone_OUDPastYear
SELECT
MVIPersonSID
,InstanceSID
,InstanceFromDate
,InstancetoDate
,OUD_Methadone_BUP_PastYear=Max (OUD_Methadone_BUP_PastYear)
,MinSource=Min (Source_OUD_Methadone_BUP_PastYear)
,MaxSource=Max (Source_OUD_Methadone_BUP_PastYear)
INTO #METHADONE_BUPRENORPHINE_Naltrexone_OUDPastYear
FROM (
	SELECT a.MVIPersonSID
	,a.InstanceSID
	,a.InstanceFromDate
	,a.InstancetoDate
	,OUD_InstanceDate=b.InstanceDate
	,OUD_Methadone_BUP_PastYear= CASE	WHEN  (b.Instancedate>=DATEADD (YEAR,-1,a.InstanceFromDate) AND b.Instancedate<=a.InstancetoDate) THEN 1 -- stopped methadone in past year
										WHEN  b.Instancedate>=DATEADD (YEAR,-1,GETDATE()) AND a.InstanceToDate IS NULL THEN 1 -- stopdate is NULL
										ELSE 0 END
	,Source_OUD_Methadone_BUP_PastYear= CASE	WHEN  b.Instancedate>=DATEADD (YEAR,-1,a.InstanceToDate) THEN b.InstanceSource -- stopped methadone in past year
										WHEN  b.Instancedate>=DATEADD (YEAR,-1,GETDATE()) AND a.InstanceToDate IS NULL THEN b.InstanceSource -- stopdate is NULL
										ELSE NULL END
	FROM -- Methadone/BUP cohort
			(
			SELECT  MVIPersonSID, InstanceSID,InstanceFromDate,InstanceToDate  FROM #VISTA WHERE (OrderName like '%METHADONE%' OR  OrderName like '%BUPREN%' OR  OrderName like '%NALTREX%') 
			UNION
			SELECT  MVIPersonSID, InstanceSID,InstanceFromDate, InstanceToDate  FROM #OH WHERE (OrderName like '%METHADONE%' OR  OrderName like '%BUPREN%'OR  OrderName like '%NALTREX%') 
			)a
	LEFT JOIN #OUD_dx b on a.MVIPersonSID=b.MVIPersonSID
)a
GROUP BY MVIPersonSID
,InstanceSID
,InstanceFromDate
,InstancetoDate
;

----------------------------------------------------------------------------------------
-- Adding OUD dx per NONVA methadone /buprenorphrine/ naltrexone instance
----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Staging_Present_NonVAMed_OUD; --8,117,298
SELECT DISTINCT c.*
,UpdatedPerName=cast ('No' as varchar(250))
INTO #Staging_Present_NonVAMed_OUD
FROM
(
SELECT a.*,OUD_Methadone_BUP_PastYear=ISNULL (b.OUD_Methadone_BUP_PastYear,0) FROM #VISTA a
LEFT JOIN #METHADONE_BUPRENORPHINE_Naltrexone_OUDPastYear b 
	on a.MVIPersonSID=b.MVIPersonSID and a.Instancesid=b.InstanceSID and a.InstanceFromDate=b.InstanceFromDate
UNION
SELECT  a.*,OUD_Methadone_BUP_PastYear=ISNULL (b.OUD_Methadone_BUP_PastYear,0) FROM #OH  a
LEFT JOIN #METHADONE_BUPRENORPHINE_Naltrexone_OUDPastYear b 
	on a.MVIPersonSID=b.MVIPersonSID and a.Instancesid=b.InstanceSID and a.InstanceFromDate=b.InstanceFromDate
)c
;

----------------------------------------------------------------------------------------
-- Distinct Records ready to receive updates
----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Staging_Present_NonVAMed_update  --8,117,298
SELECT DISTINCT *
INTO #Staging_Present_NonVAMed_update
FROM #Staging_Present_NonVAMed_OUD

----------------------------------------------------------------------------------------
-- Updating PER OrderName and Setterm
-- select distinct setterm, count (*) from #Staging_Present_NonVAMed_update group by setterm order by setterm
----------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
--Update SetTerm to AlcoholPharmacotherapy_Rx
-------------------------------------------------------------------------------------------------------
UPDATE #Staging_Present_NonVAMed_update
SET SetTerm = 'AlcoholPharmacotherapy', UpdatedPerName='AlcoholPharmacotherapy-SetTerm per OrderName like naltrexone (SetTerm= NULL)'
 WHERE 1=1
AND (
	 OrderName like 'NALTREXONE' -- only impacting OH (2025)
	)
AND SetTerm is null -- (undefined)
AND UpdatedPerName='No';

-------------------------------------------------------------------------------------------------
--Update SetTerm to MOUD
-------------------------------------------------------------------------------------------------------

-- CASE 1 OrderName like 'NALTREXONE'  and  SetTerm= NULL AND OUD in past year  
-- creating new rows for UpdatedPerName='AlcoholPharmacotherapy' 

INSERT INTO #Staging_Present_NonVAMed_update
SELECT
MVIPersonSID	
,PatientPersonSID	
,Sta3n	
,Sta6a	
,InstanceFromDate	
,InstancetoDate	
,InstanceSID	
,InstanceType	
,OrderSID	
,OrderType	
,OrderName	
,DodFlag	
,Source	
,DrugNameWithoutDose_Max	
,SetTerm ='MOUD'	
,OUD_Methadone_BUP_PastYear	
,UpdatedPerName='MOUD SetTerm - ordername like Naltrexone (SetTerm= NULL) and OUD past year'
FROM #Staging_Present_NonVAMed_update
WHERE 1=1
AND SetTerm = 'AlcoholPharmacotherapy' 
AND  UpdatedPerName='AlcoholPharmacotherapy' 
AND  OrderName like 'NALTREXONE'  
AND OUD_Methadone_BUP_PastYear=1

-- CASE 2 SetTerm= NaltrexoneInj 

UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'MOUD', UpdatedPerName='MOUD-SetTerm= NaltrexoneInj'
WHERE  1=1
AND SetTerm in ('NaltrexoneInj')
AND UpdatedPerName='No'

-- CASE 3 SetTerm=  BuprenorphineMedications

UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'MOUD', UpdatedPerName='MOUD-SetTerm= BuprenorphineMedications'
WHERE  1=1
AND SetTerm in ('BuprenorphineMedications')
AND UpdatedPerName='No'

-- CASE 4 SetTerm= MethadoneOtp

UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'MOUD', UpdatedPerName='MOUD-SetTerm= MethadoneOtp and OUD past year'
WHERE  1=1
AND OUD_Methadone_BUP_PastYear=1
AND SetTerm in ('MethadoneOtp') 
AND UpdatedPerName='No'

--Case 5 OrderName like '%METHADONE%'  and SetTerm IS NULL

UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'MOUD', UpdatedPerName='MOUD-Methadone (SetTerm= NULL) and OUD past year'
WHERE  1=1
AND OrderName like '%METHADONE%' 
AND OUD_Methadone_BUP_PastYear=1
AND SetTerm is null
AND UpdatedPerName='No'

-------------------------------------------------------------------------------------------------
--Update SetTerm to OpioidforPain
-------------------------------------------------------------------------------------------------------

-- CASE 1 SetTerm= MethadoneOtp and no OUD dx past year

UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'OpioidforPain', UpdatedPerName='MOUD-SetTerm = MethadoneOtp and No OUD past year'
WHERE  1=1
AND OUD_Methadone_BUP_PastYear=0
AND SetTerm in ('MethadoneOtp') 
AND UpdatedPerName='No'

--Case 2 OrderName like '%METHADONE%'  and SetTerm IS NULL and no OUD dx past year
UPDATE #Staging_Present_NonVAMed_update 
SET SetTerm = 'OpioidforPain', UpdatedPerName='OpioidforPain- -Ordername like Methadone (SetTerm= NULL) and No OUD past year'
WHERE  1=1
AND OrderName like '%METHADONE%' 
AND OUD_Methadone_BUP_PastYear=0
AND SetTerm is null
AND UpdatedPerName='No'
;
-- Case 3  OrderName  has 'pain'

UPDATE #Staging_Present_NonVAMed_update
SET SetTerm = 'OpioidforPain', UpdatedPerName='OpioidforPain-SetTerm=MOUD and pain in ordername'
WHERE 1=1
AND OrderName like '%pain%'
AND SetTerm like 'MOUD'


--/****Update SetTerm to MOUD
--OrderName like '%SUBOXONE%' 
--((SetTerm in ('MOUD_poss') or SetTerm is null))
--*/
--UPDATE #Staging_Present_NonVAMed_update
--SET SetTerm = 'MOUD', UpdatedPerName='MOUD-SUBOXONE'
--WHERE	1=1
--AND	OrderName like '%SUBOXONE%' 
--AND ((SetTerm in ('MOUD_poss') or SetTerm is null))
--AND  UpdatedPerName='No'

--/****Update SetTerm to OpioidforPain
--OrderName like '%BUPRENORP%' 
--ABSENCE OUD in year prior */
--UPDATE #Staging_Present_NonVAMed_update
--SET SetTerm = 'OpioidForPain', UpdatedPerName='opioidforpain-Buprenorphrine (SetTerm=MOUD_poss or NULL) and no OUDdxpastyear'
--WHERE 1=1
--AND (OrderName like '%BUPRENORP%'  and OUD_Methadone_BUP_PastYear=0) 
--AND  (SetTerm like 'MOUD_poss' or SetTerm is null)
--AND  UpdatedPerName='No'

-------------------------------------------------------------------------------------------------
--Update SetTerm to Marijuana
-------------------------------------------------------------------------------------------------------

UPDATE #Staging_Present_NonVAMed_update
SET SetTerm = 'Marijuana', UpdatedPerName='Marijuana- when ordername like cannab'
WHERE 1=1
AND OrderName like '%cannab%'
AND  UpdatedPerName='No'

-------------------------------------------------------------------------------------------------
--Update SetTerm to NaloxoneKit
-------------------------------------------------------------------------------------------------------

UPDATE #Staging_Present_NonVAMed_update
SET SetTerm = 'NaloxoneKit', UpdatedPerName='NaloxoneKit- when ordername like naloxone (SetTerm= NULL)'
WHERE 1=1
AND OrderName like 'Naloxone'
AND SetTerm is null
AND  UpdatedPerName='No'

-------------------------------------------------------------------------------------------------
--Update SetTerm to OpioidForPain - pain in ordername and SetTerm=MOUD
-------------------------------------------------------------------------------------------------------

UPDATE #Staging_Present_NonVAMed_update
SET SetTerm = 'OpioidForPain', UpdatedPerName='Opioidforpain- ordername like opioid names'
WHERE	1=1
AND
	(
			(
			OrderName like '%ALFENTANIL' or
			OrderName like '%ALPHAPRODINE%' or
			OrderName like '%BUTORPHANOL%' or
			OrderName like '%CODEINE%' or
			OrderName like '%DEZOCINE%' or
			OrderName like '%DIHYDROCODEINE%' or
			OrderName like '%FENTANYL%' or
			OrderName like '%HYDROCODONE%' or
			OrderName like '%HYDROMORPHONE%' or
			OrderName like '%LEVORPHANOL%' or
			OrderName like '%MEPERIDINE%' or
			OrderName like '%MORPHINE%' or
			OrderName like '%NALBUPHINE%' or
			OrderName like '%OLICERIDINE%' or
			OrderName like '%OPIUM%' or
			OrderName like '%OXYCODONE%' or
			OrderName like '%OXYMORPHONE%' or
			OrderName like '%PENTAZOCINE%' or
			OrderName like '%PROPOXYPHENE%' or
			OrderName like '%REMIFENTANIL%' or
			OrderName like '%SUFENTANIL%' or
			OrderName like '%TAPENTADOL%' or
			OrderName like '%TRAMADOL%' 
			) 
	AND
			(
			OrderName not like '%TIOTROPIUM%'  -- excluding non opioids
			and OrderName not like '%apomorphine%' -- for parkinson's
			and OrderName not like '%IPRATROPIUM%'  -- excluding non opioids
			and OrderName not like '%promethazine%codein%'  -- excluding codeine for cough
			and OrderName not like '%guaifenesin%'  -- excluding codeine for cough
			and OrderName not like '%dexchlorpheniramin%'  -- excluding codeine for cough
			)
	)
AND  (SetTerm IS NULL)
AND UpdatedPerName LIKE 'NO'

----------------------------------------------------------------------------------------------
-- STAGING TABLE: Aggregating update info to remove duplicates
---------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Staging_Present_NonVAMed	
SELECT
MVIPersonSID
,PatientPersonSID
,Sta3n
,Sta6a
,InstanceFromDate
,InstancetoDate
,InstanceSID
,InstanceType
,OrderSID
,OrderType
,OrderName
,DodFlag	
,[Source]
,DrugNameWithoutDose_Max
,SetTerm
,OUD_Methadone_BUP_PastYear
,UpdatedPerName=STRING_AGG (UpdatedPerName,',')
INTO #Staging_Present_NonVAMed
FROM (SELECT DISTINCT * FROM #Staging_Present_NonVAMed_update) a -- necessary to do a distinct here because there are now duplicates for drugs codes into different setterms
GROUP BY 
MVIPersonSID
,PatientPersonSID
,Sta3n
,Sta6a
,InstanceFromDate
,InstancetoDate
,InstanceSID
,InstanceType
,OrderSID
,OrderType
,OrderName
,DodFlag	
,[Source]
,DrugNameWithoutDose_Max
,SetTerm
,OUD_Methadone_BUP_PastYear

-----------------------------------------------------------------------------------
-- Final table 
EXEC [Maintenance].[PublishTable] '[Present].[NonVAMed]','#Staging_Present_NonVAMed'


	--Clean up temp table usages
	DROP TABLE IF EXISTS #OUD_SID
	DROP TABLE IF EXISTS #OUD_dx
	DROP TABLE IF EXISTS #RequiredValuesets
	DROP TABLE IF EXISTS #MapPharmacyOrderableItem_VUIDwithdose
	DROP TABLE IF EXISTS #METHADONE_BUPRENORPHINE_Naltrexone_OUDPastYear
	DROP TABLE IF EXISTS  #PharmacyOrderableItemSID_DrugNameWithoutDose_Max
	DROP TABLE IF EXISTS #VISTA
	DROP TABLE IF EXISTS #OH
	DROP TABLE IF EXISTS #Staging_Present_NonVAMed_OUD
	DROP TABLE IF EXISTS #Staging_Present_NonVAMed_update
	DROP TABLE IF EXISTS #Staging_Present_NonVAMed
	DROP TABLE IF EXISTS #Map_OrderCatalogSynonymSID

;
EXEC [Log].[ExecutionEnd]

END