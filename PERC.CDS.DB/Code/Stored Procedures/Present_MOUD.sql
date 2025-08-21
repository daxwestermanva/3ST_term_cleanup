/********************************************************************************************************************
DESCRIPTION: This stored procedure creates the Present.MOUD table, which is all Medication for Opioid Use Disorder 
	(MOUD) visits or prescriptions in the last 3 months. MOUD consists of Opioid Agonist (Buprenorphine and Methadone) 
	and Opioid Antagonist (Naltrexone injectable) medications, and can be dispensed on an inpatient basis, outpatient 
	basis, through Opioid Treatment Program (OTP) clinic visits, or from a non-VA provider. 
	Discontinued MOUD is flagged with a 0 in the ActiveMOUD column. If all MOUD has been discontinued, ActiveMOUD_Patient 
	has a value of 0 for all patient encounters to flag a recent discontinuation. 
AUTHOR:		 Sohoni, Pooja
CREATED:	 2018/10/25
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2019-11-13		CLB		changed DrugNameWithoutDose to DrugNameWithDose/PharmacyOrderableItem where applicable;
							decreased run time on #523_Visits with code reformulation; aggregated duplicate rows 
							when there are multiple providers for one CPT encounter.
	2019-11-29		CLB		dropped Code.Present_MAT_Discontinuation and combined SPs to produce one, combined table, 
							Present.MAT, with flag for discontinuation.
	2019-12-10		CLB		added facility name; changed "recently" discontinued inclusion criterion from 1 year to 3 months. 
							Because of integrated sites giving duplicate encounters, we are sometimes using sta3n and 
							sometimes Facility for Location. We should be more consistent in what we display.
	2020-01-14		CLB		extended Non-VA Med history from 3 mo. back to to 1 year due to field request.
	2020-03-16		MP		added buprenorphine inj (sublocade) to CPRS orders 
	2020-11-03		PS		Cerner overlay, also renaming procedure to MOUD, per current clinical guidance
	2020-02-09		SM		Replaced PrescriptionPersonOrderSID with DerivedPersonOrderSID and DispensedDateTime with CompletedDateTime
	2020-02-10		SM		Replaced ResponsiblePhysicianPersonStaffSID with DerivedPersonStaffSID for consistency with naming convention of computed fields
	2020-02-16		SG		Roll Back DerivedPersonStaffSID to ResponsiblePhysicianPersonStaffSID, for HotFix
	2020-02-17		SG		Updateing back ResponsiblePhysicianPersonStaffSID with DerivedPersonStaffSID 	
	2020-02-18		SA		Made adjustment to code for TFS update; Updated back ResponsiblePhysicianPersonStaffSID with DerivedPersonStaffSID 		
	2021-05-18      JEB     Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
	2021-08-24		AMN		updated cerner outpat dispensing pull with removal of TZ from datetimes and join to mill rather than fact table as many corresponding orders are filtered out in fact table					
	2021-09-13		AI		Enclave Refactoring - Counts confirmed
	2022-05-02		RAS		Refactored CPT Procedures (Naltrexone Only) section to use LookUp ListMember
	2022-05-04		RAS		Changed references from NationalDrug to LookUp.Drug_VUID for Cerner Mill data.
	2022-05-28		RAS		Refactored to use StaPa instead of "Location" which varied (sometimes Sta3n, sometimes Facility name)
							Implemented date variables for consistency, other clean up.
	2022-06-17		LM		Pointed to Lookup.StopCode_VM
	2022-06-22		AMN		updated cerner field CompletedDateTime to use TZCompletedDateTime to match latest code
	2022-08-15		SAA_JJR Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data
	2023-01-09      TG  pulling HCPCS data for Methadone, Naltrexone and Buprenorphine
	2024-02-06		MCP		Updating inpatient to match with metric definitions for MOUD (see SUD16)
********************************************************************************************************************/
CREATE PROCEDURE [Code].[Present_MOUD]
AS
BEGIN

--Discontinuation criteria for:
--1) NonVA - no longer an active status 
--2) Inpatient - > 90 days 
--3) Outpatient Rx - > 90 days
--4) OTP 523 Visits - > 90 days
--5) CPRS - > 90 days
--6) CPT - > 90 days
--To align with the MOUD recommendations on STORM, we will consider any MOUD
--in the past 90 days to be active, with the exception of non-VA meds, which
--are complicated (per JT as of 2020-03-31).

EXEC [Log].[ExecutionBegin] 'Code.Present_MOUD','EXEC Code.Present_MOUD'





----------------------------------------------------------------------------
-- GET NATIONAL DRUG SIDS FOR ALL MOUD
----------------------------------------------------------------------------
-- NOTE: USE LOOKUP.VUID FOR CERNER MILLENNIUM DATA
	-- Only 1 query currently (2022-05-04), so I did not create temp table
DROP TABLE IF EXISTS #MOUD_SIDs;
SELECT NationalDrugSID
	  ,OpioidAgonist_Rx
	  ,NaltrexoneINJ_Rx
	  ,DrugNameWithDose
	  ,DrugNameWithoutDose
INTO #MOUD_SIDs
FROM [LookUp].[NationalDrug] WITH (NOLOCK)
WHERE OpioidAgonist_Rx = 1	-- Buprenorphine and Methadone are Opioid Agonists
	OR NaltrexoneINJ_Rx = 1	-- Naltrexone is an Opioid Antagonist

----------------------------------------------------------------------------
-- CREATE STAGING TABLE
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #MOUD_Stage 
CREATE TABLE #MOUD_Stage (
	PatientPersonSID INT
	,Sta3n	SMALLINT
	,MOUD	VARCHAR(500)
	,MOUDDate	DATE
	,Prescriber	VARCHAR(500)
	,Discontinued	BIT
	,StaPa	VARCHAR(50)
	,MOUDType	VARCHAR(50)
	)



----------------------------------------------------------------------------
-- STEP 0:  Find patients with documented OUD
-- Note: Looking for an OTP StopCode or CPT code in the last 2 years as the inital cohort - will join with prescription data to ensure it occured within 6 months
----------------------------------------------------------------------------
drop table if exists #DayTreat 
select A.STA3N,
 m.mvipersonsid 
,A.VISITDATETIME,a.VisitSID
into #DayTreat
from outpat.visit as a
left outer join Outpat.VProcedure v1 WITH (NOLOCK) on a.VisitSID = v1.VisitSID --since not all visits have procedures this needs to be an outer join
inner join Common.MVIPersonSIDPatientPersonSID as m WITH (NOLOCK) on a.PatientSID = m.PatientPersonSID
left outer join LookUp.CPT cv WITH (NOLOCK) on v1.CPTSID = cv.CPTSID
left outer join LookUp.stopcode as b WITH (NOLOCK) on a.PrimaryStopCodeSID = b.StopCodeSID
left outer join LookUp.stopcode as c WITH (NOLOCK) on a.SecondaryStopCodeSID = c.StopCodeSID
where ((b.StopCode = '523' or c.stopcode = '523') OR cv.OTP_HCPCS = 1)
and a.visitdatetime > getdate()-730


DROP TABLE IF EXISTS #Dates
SELECT EndDate =	CAST(GETDATE() + 1 AS DATE) 
	,BeginDate1Y =	CAST(DATEADD(DAY,-366,CAST(GETDATE() + 1 AS DATE)) AS DATETIME2(0))
	,BeginDate90D = CAST(DATEADD(DAY,-91,CAST(GETDATE() + 1 AS DATE)) AS DATETIME2(0))
INTO #Dates

----------------------------------------------------------------------------
-- STEP 1:  Get all non-VA sources of MOUD
-- Note: Finding non-VA meds through Cerner is low priority for now (JT 2020-11-02)
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #NonVA_MOUD_Dosage_Staging;
SELECT DISTINCT 
	a.PatientSID
	,a.Sta3n
	,CASE --from Code.Present_NonVAMed
		WHEN c.PharmacyOrderableItem LIKE '%METHADONE%' AND c.PharmacyOrderableItem NOT LIKE '%PAIN%' THEN c.PharmacyOrderableItem
		ELSE m.DrugNameWithDose 
	 END AS DrugNameWithDose 
	,CAST(DocumentedDateTime AS DATE) AS MOUDDate
	,CASE 
		WHEN a.DiscontinuedDateTime is NOT NULL THEN 1
		ELSE 0
	 END AS Discontinued
	,CASE  --from Code.Present_NonVAMed
		WHEN c.PharmacyOrderableItem LIKE '%METHADONE%' AND c.PharmacyOrderableItem NOT LIKE '%PAIN%' THEN 1
		ELSE m.OpioidAgonist_Rx
	 END AS OpioidAgonist_Rx
	,m.NaltrexoneINJ_Rx
	,ck.StaPa
INTO #NonVA_MOUD_Dosage_Staging
FROM [NonVAMed].[NonVAMed] a WITH (NOLOCK)
INNER JOIN [Dim].[LocalDrug] b WITH (NOLOCK)
	ON a.PharmacyOrderableItemSID = b.PharmacyOrderableItemSID
LEFT JOIN [Dim].[PharmacyOrderableItem] c WITH (NOLOCK)
	ON a.PharmacyOrderableItemSID = c.PharmacyOrderableItemSID
LEFT JOIN #MOUD_SIDs m -- not all NonVA MOUD is captured in #MOUD_SIDs so use LEFT JOIN
	ON b.NationalDrugSID = m.NationalDrugSID
INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON ck.Sta3n = a.Sta3n AND ck.Sta3nFlag = 1
INNER JOIN #Dates d ON a.DocumentedDateTime BETWEEN d.BeginDate1Y AND d.EndDate

-- Make one row per unique patient and MOUDDateTime. This will either expose clinician coding error
-- (e.g., small typos in dosage formulations) or accurately display all MOUD dosages dispensed at 
-- that encounter.
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT PatientSID
	  ,Sta3n
      ,MAX(DrugNameWithDose) AS MOUD
	  ,MOUDDate
	  ,'Non-VA Prescriber' AS Prescriber 
	  ,Discontinued 
	  ,StaPa
	  ,'NonVA'
FROM #NonVA_MOUD_Dosage_Staging
WHERE OpioidAgonist_Rx = 1 OR NaltrexoneINJ_Rx = 1  --because we use LEFT JOIN in #NonVA_MOUD_Dosage_Staging
--select only for MOUD here
GROUP BY PatientSID,Sta3n,MOUDDate,Discontinued,StaPa

DROP TABLE IF EXISTS #NonVA_MOUD_Dosage_Staging
----------------------------------------------------------------------------
-- STEP 2:  Get all VA sources of MOUD
------ Inpatient 
------ Outpatient Rx
------ OTP 523 Visits
------ CPRS Orders
------ CPT Procedure Codes
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Inpatient (from PDSI)
----------------------------------------------------------------------------

-- VistA
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT DISTINCT 
	bcma.PatientSID
	,bcma.Sta3n
	,c.DrugNameWithoutDose AS MOUD
	,CAST(bcma.ActionDateTime AS DATE) AS MOUDDate
	,'Inpatient' AS Prescriber
	,CASE
		WHEN bcma.ActionDateTime < d.BeginDate90D
		THEN 1
		ELSE 0
	 END AS Discontinued 
	,ck.StaPa
	,'Inpatient'
FROM [BCMA].[BCMADispensedDrug] bcma WITH (NOLOCK)
INNER JOIN [Dim].[LocalDrug] b WITH (NOLOCK)
	ON bcma.LocalDrugSID = b.LocalDrugSID
INNER JOIN #MOUD_SIDs c
	ON b.NationalDrugSID = c.NationalDrugSID
INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) 
	ON ck.Sta3n = bcma.Sta3n 
	AND ck.Sta3nFlag = 1
INNER JOIN #Dates d
	ON bcma.ActionDateTime BETWEEN d.BeginDate1Y AND d.EndDate
WHERE bcma.DosesGiven IS NOT NULL
	AND (c.NaltrexoneINJ_Rx = 1 or c.OpioidAgonist_Rx = 1)



-- Cerner
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT DISTINCT 
	o.PersonSID AS PatientSID
	,200 as Sta3n
	,o.PrimaryMnemonic as MOUD
	,CAST(o.TZDispenseUTCDateTime as DATE) as MOUDDate
	,'Inpatient' as Prescriber
	,CASE WHEN 
		o.TZDispenseUTCDateTime < d.BeginDate90D
	 THEN 1
	 ELSE 0
	 END AS Discontinued 
	,l.StaPa
	,'Inpatient'
FROM [Cerner].[FactPharmacyInpatientDispensed] o WITH (NOLOCK) 
INNER JOIN [Cerner].[DimLocations] l WITH (NOLOCK) on o.OrganizationNameSID = l.OrganizationNameSID
INNER JOIN #Dates d ON o.TZDispenseUTCDateTime BETWEEN d.BeginDate1Y AND d.EndDate
WHERE ((o.PrimaryMnemonic = 'Naltrexone' and (DosageForm is Null or  DosageForm NOT LIKE '%Patch%'))
	OR (PrimaryMnemonic	LIKE '%SUBLOCADE%'  and (DosageForm is Null or  DosageForm NOT LIKE '%Patch%'))
	OR (PrimaryMnemonic	LIKE '%NALTREXONE%' and (DosageForm NOT LIKE '%Patch%' and DosageForm NOT LIKE '%Tab%')))

----------------------------------------------------------------------------
-- Outpatient Rx
----------------------------------------------------------------------------
-- VistA prep table
DROP TABLE IF EXISTS #Outpatient_Rx_Dosage_Staging1;
SELECT DISTINCT 
	a.PatientSID
	,b.DrugNameWithoutDose 
	,CAST(c.ReleaseDateTime AS DATE) as MOUDDate
	,s.StaffName AS Prescriber 
	,CASE
		WHEN c.ReleaseDateTime < d.BeginDate90D
		THEN 1
		ELSE 0
	 END AS Discontinued
	,a.Sta6a
	,a.Sta3n
	 -- ,CASE WHEN f.STA6AID is NOT NULL THEN f.Facility  --we want to use sta6aid to give us facility
		--ELSE CAST(a.sta3n AS NVARCHAR(max)) --but we default to sta3n if sta6a is too granular
		--END AS Location
INTO #Outpatient_Rx_Dosage_Staging1
FROM [RxOut].[RxOutpat] a WITH (NOLOCK)
INNER JOIN #MOUD_SIDs b ON a.NationalDrugSID = b.NationalDrugSID
INNER JOIN [RxOut].[RxOutpatFill] c WITH (NOLOCK)
	ON a.RxOutpatSID=c.RxOutpatSID
INNER JOIN [SStaff].[SStaff] s WITH (NOLOCK)
	ON a.ProviderSID = s.StaffSID
INNER JOIN #Dates d ON c.ReleaseDateTime BETWEEN d.BeginDate90D AND d.EndDate
WHERE c.ReleaseDateTime IS NOT NULL

DROP TABLE IF EXISTS #MOUD_SIDs

-- VistA
DROP TABLE IF EXISTS #Outpatient_Rx_Dosage_Staging;
SELECT PatientSID
	,rx.Sta3n
	,DrugNameWithoutDose
	,MOUDDate
	,Prescriber
	,Discontinued
	,ISNULL(fac.StaPa,ck.StaPa) StaPa
INTO #Outpatient_Rx_Dosage_Staging
FROM #Outpatient_Rx_Dosage_Staging1 rx
LEFT JOIN [LookUp].[Sta6a] fac WITH (NOLOCK) ON fac.Sta6a = rx.Sta6a
LEFT JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON 
	ck.Sta3n=rx.Sta3n 
	AND ck.Sta3nFlag = 1

UNION ALL

-- Cerner
SELECT DISTINCT
	 ph.PersonSID as PatientSID
	,Sta3n = 200
	,m.DrugNameWithoutDose
	,CAST(ph.TZDerivedCompletedUTCDateTime as DATE) as MOUDDate
	,s.NameFullFormatted as Prescriber
	,CASE WHEN ph.TZDerivedCompletedUTCDateTime < d.BeginDate90D
	 THEN 1
	 ELSE 0
	 END AS Discontinued
	,ph.StaPA
FROM [Cerner].[FactPharmacyOutpatientDispensed] ph WITH (NOLOCK)
INNER JOIN [LookUp].[Drug_VUID] m WITH (NOLOCK) on ph.VUID = m.VUID 
--INNER JOIN [LookUp].NationalDrug m on ph.ParentItemSID = m.NationalDrugSID -- Remove after validation for 4.16 release
INNER JOIN #Dates d ON ph.TZDerivedCompletedUTCDateTime BETWEEN d.BeginDate1Y AND d.EndDate
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH(NOLOCK) ON ph.DerivedOrderProviderPersonStaffSID = s.PersonStaffSID
WHERE 	m.OpioidAgonist_Rx = 1	-- Buprenorphine and Methadone are Opioid Agonists
		OR m.NaltrexoneINJ_Rx = 1	-- Naltrexone is an Opioid Antagonist

-- Make one row per unique patient, prescriber, discontinued status, and MOUDDate. This will 
-- either expose clinician coding error (e.g., small typos in dosage formulations) or accurately 
-- display all MOUD dosages dispensed at that encounter.
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT PatientSID
	  ,Sta3n
      ,MAX([DrugNameWithoutDose]) AS MOUD
	  ,MOUDDate
	  ,Prescriber 
	  ,Discontinued 
	  ,StaPa
	  ,'Rx'
FROM #Outpatient_Rx_Dosage_Staging
GROUP BY PatientSID,Sta3n,MOUDDate,Prescriber,Discontinued,StaPa 

DROP TABLE IF EXISTS #Outpatient_Rx_Dosage_Staging1,#Outpatient_Rx_Dosage_Staging
----------------------------------------------------------------------------
-- OTP (Stop Code 523) Visits
----------------------------------------------------------------------------

-- VistA
DROP TABLE IF EXISTS #Visits;
SELECT DISTINCT
	a.VisitSID
	,CAST(a.VisitDateTime AS date) AS VisitDate
	,a.PatientSID
	,a.Sta3n
	,b.StaPa
	,dt.BeginDate90D
INTO #Visits
FROM [Outpat].[Visit] a WITH (NOLOCK)
INNER JOIN [LookUp].[DivisionFacility] b WITH (NOLOCK) ON a.DivisionSID = b.DivisionSID
INNER JOIN #Dates dt ON a.VisitDateTime BETWEEN dt.BeginDate1Y AND dt.EndDate
LEFT JOIN (SELECT StopCodeSID FROM [LookUp].[StopCode] WITH (NOLOCK) WHERE OAT_Stop = 1) c
	ON a.PrimaryStopCodeSID = c.StopCodeSID
LEFT JOIN (SELECT StopCodeSID FROM [LookUp].[StopCode] WITH (NOLOCK) WHERE OAT_Stop = 1) d
	ON a.SecondaryStopCodeSID = d.StopCodeSID
WHERE c.StopCodeSID IS NOT NULL OR d.StopCodeSID IS NOT NULL

UNION ALL

-- Cerner
SELECT DISTINCT EncounterSID as VisitSID
	  ,CAST(TZDerivedVisitDateTime as DATE) as VisitDate
	  ,o.PersonSID as PatientSID
	  ,200 as Sta3n
	  ,o.StaPA
	  ,d.BeginDate90D
FROM [Cerner].[FactUtilizationOutpatient] o WITH (NOLOCK)
INNER JOIN #Dates d ON TZDerivedVisitDateTime BETWEEN d.BeginDate1Y AND d.EndDate
WHERE ActivityType LIKE '%VA Opioid Substitution%'

--Fields of interest into staging table
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT DISTINCT
	a.PatientSID
	,Sta3n
	,'OUD Treatment Program Visit' AS MOUD
	,a.VisitDate AS MOUDDate
	,'Unknown' as Prescriber
	,CASE WHEN a.VisitDate < a.BeginDate90D
		THEN 1
		ELSE 0
		END AS Discontinued 
	,a.StaPa
	,'OTP'
FROM #Visits a

DROP TABLE IF EXISTS #Visits

----------------------------------------------------------------------------
-- CPT Procedures - Naltrexone Inj, Methadone HCPCS, Buprenorphine HCPCS, Naltrexone HCPCS
----------------------------------------------------------------------------
-- VistA
DROP TABLE IF EXISTS #Methadone_Buprenorphine_Naltrexone_Provider_Staging;
SELECT DISTINCT
	a.PatientSID
	,a.Sta3n
	,MOUD=CASE WHEN List='Rx_NaltrexoneDepot' THEN 'NALTREXONE INJ'
		WHEN List='Methadone_OTP_HCPCS' THEN 'METHADONE HCPCS'
		WHEN List='Buprenorphine_OTP_HCPCS' THEN 'BUPRENORPHINE HCPCS'
		WHEN List='Naltrexone_OTP_HCPCS' THEN 'NALTREXONE HCPCS'
		END
	,CAST(a.VisitDateTime AS DATE) AS MOUDDate
	,e.StaffName 
	,ck.StaPa
	,dt.BeginDate90D
INTO #Methadone_Buprenorphine_Naltrexone_Provider_Staging
FROM [Outpat].[VProcedure] a WITH (NOLOCK)
INNER JOIN [LookUp].[ListMember] lm WITH (NOLOCK) ON lm.ItemID = a.CPTSID
LEFT JOIN [Outpat].[VProvider] d WITH (NOLOCK) ON d.VisitSID = a.VisitSID
LEFT JOIN [SStaff].[SStaff] e WITH (NOLOCK) ON e.StaffSID = d.ProviderSID
INNER JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK) ON ck.Sta3n = a.Sta3n AND ck.Sta3nFlag = 1
INNER JOIN #Dates dt ON a.VisitDateTime BETWEEN dt.BeginDate1Y AND dt.EndDate
WHERE lm.Domain = 'CPT'
	AND lm.List IN ('Rx_NaltrexoneDepot','Methadone_OTP_HCPCS','Buprenorphine_OTP_HCPCS','Naltrexone_OTP_HCPCS')

UNION ALL

-- Cerner
SELECT p.PersonSID
	  ,200 as Sta3n
	  ,MOUD=CASE WHEN List='Rx_NaltrexoneDepot' THEN 'NALTREXONE INJ'
		WHEN List='Methadone_OTP_HCPCS' THEN 'METHADONE HCPCS'
		WHEN List='Buprenorphine_OTP_HCPCS' THEN 'BUPRENORPHINE HCPCS'
		WHEN List='Naltrexone_OTP_HCPCS' THEN 'NALTREXONE HCPCS'
		END
	  ,CAST(p.TZDerivedProcedureDateTime as DATE) as MOUDDate
	  ,MAX(s.NameFullFormatted) as StaffName
	  ,p.STAPA
	  ,dt.BeginDate90D
FROM [Cerner].[FactProcedure] p WITH (NOLOCK)
LEFT JOIN [Cerner].[FactUtilizationOutpatient] o WITH (NOLOCK) on p.EncounterSID = o.EncounterSID
LEFT JOIN [Cerner].[FactStaffDemographic] s WITH (NOLOCK) on o.DerivedPersonStaffSID = s.PersonStaffSID
INNER JOIN [LookUp].[ListMember] lm WITH (NOLOCK) ON lm.ItemID = p.NomenclatureSID
INNER JOIN #Dates dt ON p.TZDerivedProcedureDateTime BETWEEN dt.BeginDate1Y AND dt.EndDate
WHERE lm.Domain = 'CPT'
	AND lm.List IN ('Rx_NaltrexoneDepot','Methadone_OTP_HCPCS','Buprenorphine_OTP_HCPCS','Naltrexone_OTP_HCPCS')
GROUP BY p.MVIPersonSID
	,p.PersonSID
	,p.TZDerivedProcedureDateTime
	,p.StaPA
	,lm.List
	,dt.BeginDate90D


-- Final table aggregates all providers for the same visit into one row 
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT PatientSID
	,Sta3n
	,MOUD
	,MOUDDate
	,Prescriber
	,CASE WHEN 
	MOUDDate < BeginDate90D
	THEN 1
	ELSE 0
	END AS Discontinued 
	,StaPa
	,'CPT'
FROM (
	SELECT PatientSID
		,Sta3n
		,MOUD
		,MOUDDate
		,BeginDate90D
		,StaPa
		,MAX([StaffName]) AS Prescriber
	FROM #Methadone_Buprenorphine_Naltrexone_Provider_Staging
	GROUP BY PatientSID,Sta3n,MOUDDate,StaPa,MOUD, BeginDate90D
	) a

DROP TABLE IF EXISTS #Methadone_Buprenorphine_Naltrexone_Provider_Staging

----------------------------------------------------------------------------
-- CPRS Orders (Naltrexone and Buprenorphine (sublocade) injection only) 
---- JT finding out whether there is any equivalent in Cerner, we can proceed for now
----------------------------------------------------------------------------
-- Get list of qualifying CPRS orders
DROP TABLE IF EXISTS #Orderable;
SELECT oi.OrderableItemSID
      ,oi.OrderableItemName
      ,dg.DisplayGroupName
INTO #Orderable
FROM [Dim].[OrderableItem] oi WITH (NOLOCK)
INNER JOIN [Dim].[DisplayGroup] dg WITH (NOLOCK) ON dg.DisplayGroupSID = oi.DisplayGroupSID
WHERE (
	(oi.OrderableItemName LIKE '%NALTREXONE%' AND oi.OrderableItemName NOT LIKE '%methyl%')
	OR oi.OrderableItemName LIKE '%BUPRENORPHINE%'
	)
	AND dg.DisplayGroupName = 'Pharmacy'
	AND oi.OrderableItemName LIKE '%INJ%'
	AND oi.OrderableItemName NOT LIKE '%STUDY%' 
	AND oi.OrderableItemName NOT LIKE '%INV%'

-- Qualifying orders
INSERT INTO #MOUD_Stage(PatientPersonSID,Sta3n,MOUD,MOUDDate,Prescriber,Discontinued,StaPa,MOUDType)
SELECT DISTINCT 
	a.PatientSID
	,a.Sta3n
	,e.OrderableItemName AS MOUD
	,CAST(oi.OrderStartDateTime as DATE) AS MOUDDate
	,'CPRS Order' AS Prescriber
	,CASE
		WHEN oi.OrderStartDateTime < dt.BeginDate90D
		THEN 1
		ELSE 0
	 END AS Discontinued 
	,ck.StaPa
	,'CPRS_Order'
FROM [CPRSOrder].[CPRSOrder] a WITH (NOLOCK)
INNER JOIN [CPRSOrder].[OrderedItem] oi WITH (NOLOCK) ON oi.CPRSOrderSID = a.CPRSOrderSID
INNER JOIN #Orderable e ON e.OrderableItemSID = oi.OrderableItemSID
INNER JOIN [Dim].[VistaPackage] d WITH (NOLOCK) ON a.VistaPackageSID = d.VistaPackageSID
INNER JOIN [LookUp].[ChecklistID] ck ON ck.STA3N = a.Sta3n AND ck.Sta3nFlag = 1
INNER JOIN #Dates dt ON oi.OrderStartDateTime BETWEEN dt.BeginDate1Y AND dt.EndDate
WHERE d.VistaPackage <> 'Outpatient Pharmacy'
	AND d.VistaPackage NOT LIKE '%Non-VA%' 

DROP TABLE IF EXISTS #Orderable
----------------------------------------------------------------------------
-- STEP 3:  Assemble the final cohort, which includes an active/discontinued and only pulls in Methadone where the patient has evidence of day treatment
-- flag for each MOUD source.
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Staging1
SELECT distinct mvi.MVIPersonSID
	,a.PatientPersonSID
	,a.Sta3n
	,a.StaPa
	,a.MOUD
	,a.MOUDDate
	,a.Prescriber
	,a.Discontinued
	,a.MOUDType
INTO #Staging1
FROM #MOUD_Stage a
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON mvi.PatientPersonSID = a.PatientPersonSID
LEFT OUTER JOIN #DayTreat as d on mvi.MVIPersonSID = d.mvipersonsid and VISITDATETIME between dateadd(d,-180,MOUDDate) and dateadd(d,180,MOUDDate)
WHERE mvi.MVIPersonSID > 0 and ((MOUD like '%Methadone%' and (d.mvipersonsid is not null or a.MOUDType like 'NonVA')) or MOUD not like '%Methadone%')
	-- there were a few records in the previous version with 0 value in the PatientSID column

DROP TABLE IF EXISTS #MOUD_Stage

DROP TABLE IF EXISTS #MOUD_Cohort
SELECT DISTINCT
	  p.MVIPersonSID
	  ,p.PatientPersonSID AS PatientSID
	  ,p.Sta3n
	  ,p.MOUD
	  ,ISNULL(p.NonVA,0) AS NonVA
	  ,ISNULL(p.Inpatient,0) AS Inpatient
	  ,ISNULL(p.Rx,0) AS Rx
	  ,ISNULL(p.OTP,0) AS OTP
	  ,ISNULL(p.CPT,0) AS CPT
	  ,ISNULL(p.CPRS_Order,0) AS CPRS_Order
	  ,MOUDDate
	  ,Prescriber
	  ,StaPa
	  ,CASE WHEN p.Discontinued = 0 THEN 1 ELSE 0 END AS ActiveMOUD 
	  ,CASE WHEN MIN(CAST(p.Discontinued AS INT)) OVER(PARTITION BY p.MVIPersonSID) = 0 
		THEN 1 ELSE 0 
		END ActiveMOUD_Patient
INTO #MOUD_Cohort
FROM (
	SELECT *,Flag=1 FROM #Staging1
	) u
PIVOT (MAX(FLag) FOR MOUDType IN (
	Inpatient,OTP,CPT,CPRS_Order,Rx,NonVA
	)	) p

DROP TABLE IF EXISTS #Staging1


EXEC [Maintenance].[PublishTable] 'Present.MOUD', '#MOUD_Cohort'

EXEC [Log].[ExecutionEnd]

END