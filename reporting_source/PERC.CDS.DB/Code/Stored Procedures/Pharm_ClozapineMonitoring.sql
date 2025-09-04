/*=============================================
Author:  <Patric Spoutz>
Create date: <1-6-17>
Description: <National Clozapine Dashboard>
MODIFICATIONS:
	2018-06-07 JB	Removed hard coded database references
	2019-02-06 SM	added publish method
	2019-08-09 JF	ANC values and calculation added to existing meds table per Ira's request
	2019-09-06 JF	added previous ANC value
	2019-12-02 RAS	Removed Name and SSN.  Added these and Age to the App report SP.
	2019-12-13 JF	update to clozapine serum labs
	2019-12-14 SM	updated sta3n rx location to ChecklistID except for CPRSorders that do not have institutionsid, divisionsid nor sta6a
	2019-12-23 JF	update to integrate ChecklistID with lab values
	2020-04-22 SM	added NPI (provider identifier)
	2020-10-20 PS	replaced references to LookUp.Lab to LookUp.Lab_VM
	2020-12-15 RAS	Replaced PatientICN with MVIPersonSID
	2021-05-18 JEB	Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
	2021-05-** MCP	Removed dependency from MPR to RxOutpat
	2021-09-09 JEB	Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
	2024-5-07 AER   Accounting for clozapine metabolite labs
	2024-11-15 LM	Update for faster run time
	Testing execution:
		EXEC [Code].[Pharm_ClozapineMonitoring]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'EXEC Code.Pharm_ClozapineMonitoring'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'ClozapineMonitoring' ORDER BY 1 DESC

===============================================*/
CREATE PROCEDURE [Code].[Pharm_ClozapineMonitoring]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Pharm_ClozapineMonitoring','Execution of Code.Pharm_ClozapineMonitoring SP'

	--Identifying most recent releasedatetime for Clozapine  in past 90 days: outpatient, inpatient, CPRS order
  
	----------------------------------------------------------------------------
	-- GET NATIONAL DRUG SIDS FOR ALL CLOZAPINE
	----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #NationalDrugSID_Cloz;
	SELECT a.NationalDrugSID,a.VUID
		,a.DrugNameWithoutDose
		,b.LocalDrugSID
	INTO #NationalDrugSID_Cloz
	FROM [LookUp].[NationalDrug] a WITH (NOLOCK)
	LEFT JOIN [Dim].[LocalDrug] b WITH (NOLOCK)
		ON a.NationalDrugSID = b.NationalDrugSID
	WHERE a.DrugNameWithDose LIKE '%clozap%'
	;
--select distinct DrugNameWithoutDose from #NationalDrugSID_Cloz
	----------------------------------------------------------------------------
	-- STEP 1:  Get all VA sources of CLOZAPINE

	------ Inpatient
	------ Outpatient Rx
	------ CPRS Orders
	----------------------------------------------------------------------------
	----------------------------------------------------------------------------
	-- Inpatient
	----------------------------------------------------------------------------
	----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #MAXDate;
	SELECT a.PatientSID
		,MAX(ActionDateTime) AS Max_ClozapineDate
	INTO  #MAXDate
	FROM [BCMA].[BCMADispensedDrug] a WITH (NOLOCK) 
	INNER JOIN [Dim].[LocalDrug] b WITH (NOLOCK) ON a.LocalDrugSID = b.LocalDrugSID
	INNER JOIN #NationalDrugSID_Cloz c ON b.NationalDrugSID = c.NationalDrugSID
	WHERE a.DosesGiven IS NOT NULL
		AND a.ActionDateTime > CAST(DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	GROUP BY a.PatientSID
	;
	
	DROP TABLE IF EXISTS #MAXDATE_ChecklistID;
	SELECT  
		a.PatientSID
		,ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,ccc.DrugNameWithoutDose
		,a.Max_ClozapineDate
		,f.ChecklistID
	INTO #MAXDATE_ChecklistID
	FROM #MAXDate a
	INNER JOIN [BCMA].[BCMADispensedDrug] b WITH (NOLOCK)
		ON a.PatientSID = b.PatientSID  
		AND a.Max_ClozapineDate = b.ActionDateTime
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #NationalDrugSID_Cloz ccc 
		ON b.LocalDrugSID = ccc.LocalDrugSID
	INNER JOIN [BCMA].[BCMAMedicationLog] d WITH (NOLOCK)
		ON b.BCMAMedicationLogSID = d.BCMAMedicationLogSID
	INNER JOIN [Dim].[Division] e WITH (NOLOCK)
		ON d.InstitutionSID = e.InstitutionSID
	INNER JOIN [LookUp].[Sta6a] f WITH (NOLOCK)
		ON e.Sta6a = f.Sta6a
		
;

drop table if exists #maxDate_Mill
SELECT  
					 ppsid.MVIPersonSID,
					l.DrugNameWithoutDose
					,s1.VUID as ObservedMatchID
					,s1.TZDispenseUTCDateTime as InstanceFromDateTime
					,s1.TZDispenseUTCDateTime as InstanceToDateTime 
					,s1.DispenseHistorySID as InstanceMatchID
					,CASE WHEN CAST(s1.STA6A AS VARCHAR) IS NULL OR CAST(s1.STA6A AS VARCHAR) IN ('0','-1','*Missing*','*Unknown at this time*')
						THEN CAST(s1.STAPA AS VARCHAR) ELSE CAST(s1.STA6A AS VARCHAR) END AS STA6A
					,s1.DispenseHistorySID as ValidationMatchID
			into #maxDate_Mill
        FROM [CERNER].[FactPharmacyInpatientDispensed] AS s1 WITH (NOLOCK)
				INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] ppsid WITH (NOLOCK) ON ppsid.PatientPersonSID = s1.PersonSID
				INNER JOIN ( 
				select * from #NationalDrugSID_Cloz
					) l ON s1.VUID = l.VUID
				WHERE s1.TZDispenseUTCDateTime > CAST(DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) AS DATETIME2(0))

 
;

 
SELECT  
					 ppsid.MVIPersonSID
				  ,	l.DrugNameWithoutDose
					,d1.VUID as ObservedMatchID
					,s1.TZOrderUTCDateTime as InstanceFromDateTime
					,s1.TZOrderUTCDateTime as InstanceToDateTime 
					,s1.MedAdministrationEventSID as InstanceMatchID
					,CASE WHEN CAST(s1.STA6A AS VARCHAR) IS NULL OR CAST(s1.STA6A AS VARCHAR) IN ('0','-1','*Missing*','*Unknown at this time*')
						THEN CAST(s1.STAPA AS VARCHAR) ELSE CAST(s1.STA6A AS VARCHAR) END AS STA6A
					,s1.MedAdministrationEventSID as ValidationMatchID
          into #maxDate_Mill_BCMA
        FROM cerner.FactPharmacyBCMA  AS s1 
				INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] ppsid WITH (NOLOCK) ON ppsid.PatientPersonSID = s1.PersonSID
        inner join  Cerner.DimDrug d1 WITH (NOLOCK) on s1.OrderCatalogSID = d1.OrderCatalogSID
				INNER JOIN ( 
				select * from #NationalDrugSID_Cloz
					) l ON d1.VUID = l.VUID
				WHERE s1.TZOrderUTCDateTime > CAST(DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) AS DATETIME2(0))


;

DROP TABLE IF EXISTS #Inpatient;
	SELECT DISTINCT
		a.MVIPersonSID
		,a.DrugNameWithoutDose
		,1 AS Inpatient
		,0 AS Rx
		,0 AS CPRS_Order
		,a.Max_ClozapineDate
		,a.ChecklistID
	INTO #Inpatient
	FROM #MAXDATE_ChecklistID a
	UNION 
  SELECT DISTINCT
		a.MVIPersonSID
		,a.DrugNameWithoutDose
		,1 AS Inpatient
		,0 AS Rx
		,0 AS CPRS_Order
		,a.InstanceFromDateTime
		,b.ChecklistID
  FROM #maxDate_Mill as a 
  inner join LookUp.Sta6a as b WITH (NOLOCK) on a.STA6A = b.Sta6a
	UNION 
  SELECT DISTINCT
		a.MVIPersonSID
		,a.DrugNameWithoutDose
		,1 AS Inpatient
		,0 AS Rx
		,0 AS CPRS_Order
		,a.InstanceFromDateTime
		,b.ChecklistID
  FROM #maxDate_Mill_BCMA as a 
  inner join LookUp.Sta6a as b WITH (NOLOCK) on a.STA6A = b.Sta6a

	----------------------------------------------------------------------------
	-- Outpatient Rx
	----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #MaxD;
	SELECT 
		mvi.MVIPersonSID
		, MAX(rxo.ReleaseDateTime) AS max_ReleaseDateTime
	INTO #MaxD
	FROM [RxOut].[RxOutpatFill] rxo WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON rxo.PatientSID = mvi.PatientPersonSID 
	WHERE rxo.DrugNameWithoutDose LIKE '%CLOZAPINE%' 
		AND rxo.ReleaseDateTime > DATEADD(DAY,-90,CAST(GETDATE() AS DATE))
	GROUP BY mvi.MVIPersonSID
	;

	DROP TABLE IF EXISTS #Outpatient_Rx_vista;
	SELECT 
		a.MVIPersonSID
		,0 AS Inpatient
		,1 AS Rx
		,0 AS CPRS_Order
		,a.max_ReleaseDateTime
		,c.DaysSupply
		,c.DrugNameWithoutDose
		,CASE 
			WHEN DATEADD(DAY,c.DaysSupply,a.max_ReleaseDateTime) > CAST(GETDATE() AS DATE) THEN 'Pills on hand'
			ELSE 'No pills on hand' 
		END AS PillsOnHand
		,DATEADD(d,c.DaysSupply,a.max_ReleaseDateTime) AS DateSinceLastPillsHand
		,d.ProviderSID
		,dd.NPI
		,ISNULL(e.ChecklistID,CAST(d.Sta3n AS VARCHAR)) as ChecklistID
	INTO #Outpatient_Rx_Vista
	FROM #MaxD a
	INNER JOIN 
		(
			SELECT 
				mvi.MVIPersonSID
				, c1.DaysSupply
				, c1.DrugNameWithoutDose
				, c1.ReleaseDateTime
				, c1.RxOutpatSID
				, c1.LocalDrugNameWithDose
			FROM [RxOut].[RxOutpatFill] c1 WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON c1.PatientSID = mvi.PatientPersonSID 
			WHERE c1.LocalDrugNameWithDose LIKE '%CLOZAPINE%'
		) c
		ON c.MVIPersonSID=a.MVIPersonSID 
		AND a.max_ReleaseDateTime = c.ReleaseDateTime  
	INNER JOIN [RxOut].[RxOutpat] d WITH (NOLOCK)
		ON c.RxOutpatSID = d.RxOutpatSID
	INNER JOIN [SStaff].[SStaff] dd WITH (NOLOCK)
		ON d.ProviderSID = dd.StaffSID
	LEFT JOIN [LookUp].[Sta6a] e WITH (NOLOCK)
		ON e.Sta6a = d.Sta6a
	WHERE c.LocalDrugNameWithDose LIKE '%CLOZAPINE%'
	;

drop table if exists #Outpatient_Rx_Mill
SELECT  
					ppsid.MVIPersonSID,
					l.DrugNameWithoutDose
					,s1.VUID as ObservedMatchID
					,s1.TZDerivedCompletedUTCDateTime as InstanceFromDateTime
					,s1.TZDerivedCompletedUTCDateTime as InstanceToDateTime 
					,s1.DispenseHistorySID as InstanceMatchID
					,CASE WHEN CAST(s1.STA6A AS VARCHAR) IS NULL OR CAST(s1.STA6A AS VARCHAR) IN ('0','-1','*Missing*','*Unknown at this time*')
						THEN CAST(s1.StaPA AS VARCHAR) ELSE CAST(s1.STA6A AS VARCHAR) END AS STA6A
					,s1.DispenseHistorySID as ValidationMatchID
          ,DATEADD(DAY,s1.DaysSupply,s1.TZDerivedCompletedUTCDateTime) as  DateSinceLastPillsHand
          ,DaysSupply
          ,case when getdate() between TZDerivedCompletedUTCDateTime and DATEADD(DAY,s1.DaysSupply,s1.TZDerivedCompletedUTCDateTime) 
                        then 'Pills on hand'
              else 'No pills on hand' end PillsOnHand
          ,s1.DerivedOrderProviderPersonStaffSID
          into #Outpatient_Rx_Mill
				FROM [CERNER].[FactPharmacyOutpatientDispensed] s1 WITH (NOLOCK)
				INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] ppsid WITH (NOLOCK) ON ppsid.PatientPersonSID = s1.PersonSID
				INNER JOIN ( 
				select * from #NationalDrugSID_Cloz
						) l ON s1.VUID = l.VUID
				WHERE TZDerivedCompletedUTCDateTime > CAST(DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) AS DATETIME2(0)) 
				 AND s1.DoDFlag = 0

;

drop table if exists #Outpatient_Rx
	SELECT DISTINCT
		MVIPersonSID
		,0 AS Inpatient
		,1 AS Rx
		,0 AS CPRS_Order
		, max_ReleaseDateTime
		,DaysSupply
		,DrugNameWithoutDose
		,PillsOnHand
		,DateSinceLastPillsHand
		,ProviderSID
		,NPI
		, ChecklistID
    into #Outpatient_Rx
	FROM #Outpatient_Rx_vista
UNION ALL
	SELECT DISTINCT
		a.MVIPersonSID
		,0 AS Inpatient
		,1 AS Rx
		,0 AS CPRS_Order
		,InstanceFromDateTime as max_ReleaseDateTime
		,DaysSupply
		,DrugNameWithoutDose
		,PillsOnHand
		,DateSinceLastPillsHand
		,DerivedOrderProviderPersonStaffSID as ProviderSID
    ,f1.NPI
		, ChecklistID
	FROM #Outpatient_Rx_mill as a 
  inner  join Cerner.FactStaffDemographic f1 WITH (NOLOCK) on f1.PersonStaffSID = DerivedOrderProviderPersonStaffSID
inner join LookUp.Sta6a as b WITH (NOLOCK) on a.STA6A = b.Sta6a




	------------------------------------------------------
	----------------------
	-- CPRS Orders
	----------------------------------------------------------------------------
	-- Get list of qualifying CPRS orders
	DROP TABLE IF EXISTS #Orderable;
	SELECT oi.OrderableItemSID
		,oi.OrderableItemName
		,dg.DisplayGroupName
		,oi.InpatientMedCode
		,oi.OutpatientMedFlag
		,oi.NonFormularyFlag
		,oi.NonVAMedsFlag
	INTO #Orderable
	FROM [Dim].[OrderableItem] oi WITH (NOLOCK)
	INNER JOIN [Dim].[DisplayGroup] dg WITH (NOLOCK) ON dg.DisplayGroupSID = oi.DisplayGroupSID
	WHERE oi.OrderableItemName LIKE '%clozapine%'
		AND dg.DisplayGroupName LIKE 'pharmacy'
	;

	-- Narrow down the orders to past 90 days
	DROP TABLE IF EXISTS #Recent_Orders;
	SELECT DISTINCT
		a.CPRSOrderSID
		,b.Max_OrderStartDateTime
		,b.OrderableItemSID
	INTO #Recent_Orders
	FROM [CPRSOrder].[OrderedItem] a WITH (NOLOCK)
	INNER JOIN 
		(
			SELECT 
				MAX(a.OrderStartDateTime) AS Max_OrderStartDateTime
				,a.OrderableItemSID
			FROM [CPRSOrder].[OrderedItem] a WITH (NOLOCK)
			WHERE a.OrderStartDateTime >= CAST(DATEADD(DAY,-90,CAST(GETDATE() AS DATE)) AS DATETIME2(0))
			AND a.OrderStartDateTime < CAST(CAST(GETDATE() + 1 AS DATE) AS DATETIME2(0))
			GROUP BY a.OrderableItemSID
		) B 
		ON a.OrderableItemSID = b.OrderableItemSID
		AND a.OrderStartDateTime = b.Max_OrderStartDateTime
	;

	-- Qualifying orders
	DROP TABLE IF EXISTS #Qualifying_Orders;
	SELECT DISTINCT
		mvi.MVIPersonSID
		,a.PatientSID
		,a.Sta3n
		,b.Max_OrderStartDateTime
		,e.OrderableItemName
	INTO #Qualifying_Orders
	FROM [CPRSOrder].[CPRSOrder] a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #Recent_Orders b 
		ON a.CPRSOrderSID = b.CPRSOrderSID
	INNER JOIN #Orderable e 
		ON e.OrderableItemSID = b.OrderableItemSID
	LEFT JOIN [Dim].[VistaPackage] d WITH (NOLOCK)
		ON a.VistaPackageSID = d.VistaPackageSID
	WHERE d.VistaPackage <> 'Outpatient Pharmacy'
		AND d.VistaPackage NOT LIKE '%Non-VA%'
		;

	-- Final table
	DROP TABLE IF EXISTS #CPRSOrder;
	SELECT  
		 a.MVIPersonSID
		,OrderableItemName
		,0 AS Inpatient
		,0 AS Rx
		,1 AS CPRS_Order
		,a.Max_OrderStartDateTime
		,cast(b.Sta3n as nvarchar (10)) as Sta3n
	INTO #CPRSOrder
	FROM (
		SELECT MVIPersonSID
			,Max_OrderStartDateTime
		FROM #Qualifying_Orders
		) a
	INNER JOIN #Qualifying_Orders b 
		ON a.Max_OrderStartDateTime = b.Max_OrderStartDateTime
		AND a.MVIPersonSID = b.MVIPersonSID
	;

	----------------------------------------------------------------------------
	-- STEP 3:  All together: Inpat + outpat RX + CPRS Order
	----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Staging;
	SELECT 
		a.MVIPersonSID
		,a.DrugNameWithoutDose
		,a.Inpatient
		,a.Rx AS OutPat_Rx
		,a.CPRS_Order
		,a.Max_ClozapineDate AS ClozapineDate
		,a.ChecklistID
	INTO #Staging
	FROM (
		SELECT DISTINCT MVIPersonSID,DrugNameWithoutDose,Inpatient,Rx,CPRS_Order,Max_ClozapineDate,ChecklistID
		FROM #Inpatient
		UNION ALL
		SELECT DISTINCT MVIPersonSID,DrugNameWithoutDose,Inpatient,Rx,CPRS_Order,max_ReleaseDateTime,ChecklistID
		FROM #Outpatient_Rx
		UNION ALL
		SELECT MVIPersonSID,OrderableItemName,Inpatient,Rx,CPRS_Order,Max_OrderStartDateTime,sta3n
		FROM #CPRSOrder
		) as A

	;

	-- GETTING MAX RELEASE ( 1 per patient per drugnamewithoutdose)
	DROP TABLE IF EXISTS #CLOZAPINE;
	SELECT DISTINCT A.*
	INTO #CLOZAPINE
	FROM #Staging A
	INNER JOIN 
		(
			SELECT MVIPersonSID
				,MAX(ClozapineDate) AS MaxClozapineDate
			FROM #Staging
			GROUP BY MVIPersonSID
		) B 
		ON a.MVIPersonSID = B.MVIPersonSID
		AND A.ClozapineDate = B.MaxClozapineDate
	;

	--- GETTING SIDS
	DROP TABLE IF EXISTS #PatientSID_Cloz;
	SELECT DISTINCT a.MVIPersonSID
		,ps.PatientICN
		,ps.PatientPersonSID as PatientSID
		,a.OutPat_Rx
	INTO #PatientSID_Cloz
	FROM #Staging a
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] ps WITH (NOLOCK)
		ON ps.MVIPersonSID=a.MVIPersonSID
	;

	/*---------------------------------------------------------------------------------
	-- Labs: <Rank 1>  max dates for ANC, ANC-Calcualtion, Clozapine/Norclozapine blood level 
			 <Rank 2>  lowest previous ANC value within past 30 days
	----------------------------------------------------------------------------------*/

-----------Find all the labs needed in the last 7 months (6 months +30 days to find lowest value) and flag most recent 
-----------VISTA
drop table if exists #Labs
SELECT DISTINCT *
into #Labs
FROM 
	(
	SELECT 
		a.Sta3n
		,d.MVIPersonSID
		,CAST(a.ShortAccessionNumber AS VARCHAR(15)) AS [Accession#-anc] 
		,c.LabChemPrintTestName
		,c.LabChemTestName
		,a.LabChemSpecimenDateTime
		,LabChemResultValue
		,a.LabChemResultNumericValue
		,a.Units
		,cast(a.RefLow as varchar(15)) AS RefLow
		,cast(a.RefHigh as varchar(15)) AS RefHigh
		,0 AS OutsideLabFlag
		,CASE 
			WHEN C.AbsoluteNeutrophilCount_Blood = 1 and Units like '%\%%' ESCAPE '\' THEN 'Poly' --Neutrophil %
			WHEN C.AbsoluteNeutrophilCount_Blood = 1 and Units not like '%\%%' ESCAPE '\' THEN 'ANC' --AbsoluteNeutrophilCount
			WHEN C.WhiteBloodCell_Blood = 1 THEN 'WBC'
			WHEN C.PolysNeutrophils_Blood = 1 THEN 'Poly'
			WHEN C.Clozapine_Blood = 1 and labchemtestname like '%nor%' THEN 'NorCloz'
			WHEN C.Clozapine_Blood = 1 and labchemtestname not like '%nor%' THEN 'Cloz'
			END AS LabType
		, C.LOINC,'N' as Calc_value_used
	FROM [Chem].[LabChem] a WITH (NOLOCK)
	INNER JOIN #PatientSID_Cloz d 
		ON a.PatientSID = d.PatientSID
	INNER JOIN [LookUp].[Lab] C WITH (NOLOCK)
		ON A.LabChemTestSID=C.LabChemTestSID
	WHERE (((C.AbsoluteNeutrophilCount_Blood=1 or C.WhiteBloodCell_Blood = 1 or C.PolysNeutrophils_Blood = 1)
				AND a.LabChemCompleteDateTime > DATEADD(DAY,-210,CAST(GETDATE() AS DATE))  )
			or (C.Clozapine_Blood = 1))
		AND a.LabChemCompleteDateTime > DATEADD(DAY,-360,CAST(GETDATE() AS DATE))
		AND a.LabChemResultValue NOT LIKE '%comment%'
		AND a.LabChemResultValue NOT LIKE '%canc%'
	) a1

----------CERNER
insert into #labs
SELECT DISTINCT 
	Sta3n=200 
	,b.MVIPersonSID
	,null as [Accession#-anc]
	,[Event] 
	, DiscreteTaskAssay
	,CollectDateTime  
	,case when isnumeric(ResultValue) = 1 then ResultValue else null end  LabChemResultNumericValue
	,ResultValue AS LabChemResultValue
	,ResultUnits
	,RefLow=null 
	,RefHigh=null 
	,OutsideLabFlag=0 
	,CASE WHEN C.AbsoluteNeutrophilCount_Blood = 1 and ResultUnits like '%\%%' ESCAPE '\' THEN 'Poly' 
		WHEN C.AbsoluteNeutrophilCount_Blood = 1 and ResultUnits not like '%\%%' ESCAPE '\' THEN 'ANC' 
		WHEN C.WhiteBloodCell_Blood = 1 THEN 'WBC'
		WHEN C.PolysNeutrophils_Blood = 1 THEN 'Poly'
		WHEN C.Clozapine_Blood = 1 and labchemtestname like '%nor%' THEN 'NorCloz'
		WHEN C.Clozapine_Blood = 1 and labchemtestname not like '%nor%' THEN 'Cloz'
		END AS LabType
	,SourceIdentifier 
	,'N' as Calc_value_used
FROM  #PatientSID_Cloz as a 
inner join  [Cerner].[FactLabResult] as b WITH (NOLOCK) on a.mvipersonsid = b.mvipersonsid 
inner join  [LookUp].[Lab] C WITH (NOLOCK)
	ON  b.DiscreteTaskAssaySID = C.LabChemTestSID  and c.sta3n = 200
where isnumeric(ResultValue) = 1 and ((b.CollectDateTime > getdate() - 210 
		and (C.AbsoluteNeutrophilCount_Blood=1 or C.WhiteBloodCell_Blood = 1 or C.PolysNeutrophils_Blood = 1))
	or (C.Clozapine_Blood = 1 ) )
AND b.CollectDateTime > getdate() - 360 

;

drop table if exists #ANC_Calc
select a.Sta3n, a.MVIPersonSID,a.[Accession#-anc],a.LabChemPrintTestName,a.LabChemTestName,a.LabChemResultValue, 'ANC' as  LabType
,a.Units
,a.LabChemSpecimenDateTime
,a.LabChemResultNumericValue as Poly
, b.LabChemResultNumericValue as WBC ,b.Units as WBC_Units
,(a.LabChemResultNumericValue/100)*b.LabChemResultNumericValue as LabChemResultNumericValue
,'Y' as Calc_value_used,a.RefLow,a.RefHigh,a.OutsideLabFlag,a.LOINC
into #ANC_Calc
from 
(select * from #labs where LabType = 'poly') as a
left outer join 
(select * from #labs where LabType = 'WBC') as b on a.mvipersonsid = b.mvipersonsid and cast(a.LabChemSpecimenDateTime as date) = cast(b.LabChemSpecimenDateTime as date)



insert into  #Labs
select a.Sta3n,a.MVIPersonSID,a.[Accession#-anc],a.LabChemPrintTestName,a.LabChemTestName
,a.LabChemSpecimenDateTime,a.LabChemResultNumericValue as LabChemResultValue,cast(a.LabChemResultNumericValue as decimal(18,2))
,a.WBC_Units +' /  %' as Units,a.RefLow,a.RefHigh,a.OutsideLabFlag,a.LabType,a.LOINC,'Y' as Calc_value_used
--,b.MVIPersonSID
from #ANC_Calc as a
left outer join #Labs as b on a.MVIPersonSID = b.Mvipersonsid 
          and a.LabChemSpecimenDateTime = b.LabChemSpecimenDateTime and b.labtype = 'anc'
--only insert a calculated ANC is there isn't already one on that date
where b.mvipersonsid is null


--select * from #labs 
--where mvipersonsid in (select mvipersonsid from Pharm.ClozapineMonitoring c1 where c1.[MostRecentANC_D&T] is null)

----Tease out the Cloz/NorCloz levels from the Total/Cloz/NorCloz which was done on a given day
drop table if exists #labs_CLoz
select a.Sta3n,a.MVIPersonSID,a.LabChemSpecimenDateTime,
case when NorResultNumeric is null and TotalResultNumeric is not null then cast(TotalResultNumeric - ClozResultNumeric as varchar)
      else isnull(cast(NorResultNumeric as varchar),NorResult) end NorResult
,isnull(NorUnits,TotalUnits) as NorUnits
,case when ClozResultNumeric is null and TotalResultNumeric is not null then cast(TotalResultNumeric - NorResultNumeric as varchar)
      else isnull(cast(ClozResultNumeric as varchar),ClozResult) end ClozResult
,isnull(isnull(ClozUnits,TotalUnits),NorUnits) as ClozUnits
into #labs_CLoz
from (
select a.Sta3n,a.MVIPersonSID,a.LabChemSpecimenDateTime
,cast(b.LabChemResultNumericValue as int) as TotalResultNumeric,b.Units as TotalUnits
,c.LabChemResultValue as NorResult,cast(c.LabChemResultNumericValue as int) as NorResultNumeric,c.Units as NorUnits
,d.LabChemResultValue as ClozResult,cast(d.LabChemResultNumericValue as int) as ClozResultNumeric,d.Units as ClozUnits
from ( 
select * --any clozapine for data setting
from #labs where labtype like '%cloz%') as a 
left outer join (
select * --total clozapine
from #labs where labtype like '%cloz%' and (labchemtestname like '%tot%' or labchemtestname like '%met%')
											AND LabChemTestName NOT LIKE '%OXIDE%'  ) as b    
        on a.mvipersonsid = b.mvipersonsid and a.LabChemSpecimenDateTime = b.LabChemSpecimenDateTime
left outer join (
select * --nor clozapine
from #labs  where labtype like '%cloz%' and labchemtestname like '%nor%' and labchemtestname not like '%tot%' and labchemtestname not like '%met%' 
  AND LabChemTestName NOT LIKE '%OXIDE%' ) as c
        on a.mvipersonsid = c.mvipersonsid and a.LabChemSpecimenDateTime = c.LabChemSpecimenDateTime
left outer join (
select * --clozapine
from #labs where labtype like '%cloz%' and labchemtestname not like '%nor%' 
  and labchemtestname not like '%tot%' and labchemtestname not like '%met%' AND LabChemTestName NOT LIKE '%OXIDE%' ) as d
        on a.mvipersonsid = d.mvipersonsid and a.LabChemSpecimenDateTime = d.LabChemSpecimenDateTime
) as a

drop table if exists #Labs_MostRecentANC
select * 
into #Labs_MostRecentANC
from (
select *,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID, LabType ORDER BY LabChemSpecimenDateTime DESC,Calc_value_used,units) AS LabRank --find the most recent for each lab type - using calc value = N when there is a tie
from #Labs
where labtype in ('ANC' )
) as a 
where LabRank = 1


drop table if exists #Labs_MostRecentCloz
select * 
into #Labs_MostRecentCloz
from (
select *,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY LabChemSpecimenDateTime DESC) AS LabRank --find the most recent for each lab type - using calc value = N when there is a tie
from #labs_CLoz
) as a 
where LabRank = 1


-----------Find the lowest of each tab within 30days of the most recent 
drop table if exists #lab_final
select * 
into #lab_final
from (
select distinct a.Sta3n as Sta3n,a.MVIPersonSID,a.LabType,a.[Accession#-anc]
,a.LabChemSpecimenDateTime as [MostRecentANC_D&T] 
,a.LabChemResultValue 
,a.LabChemResultNumericValue as Result_Value ,a.Units
,a.Calc_value_used
,b.LabChemSpecimenDateTime as [<30d_LowestPrev_LabChemSpecDateTime], b.LabChemResultNumericValue as [<30d_LowestPrev_ANC_Value]
,b.Units as Previous_Units
,b.Calc_value_used as Previous_Calc_value_used
,row_number() over(partition by a.mvipersonsid,a.labtype order by b.LabChemResultNumericValue,b.LabChemSpecimenDateTime desc,b.Calc_value_used) as LabRankByValue
from #Labs_MostRecentANC as a 
left outer join #labs as b on a.mvipersonsid = b.mvipersonsid and a.labtype = b.labtype
      and b.LabChemSpecimenDateTime between dateadd(d,-31,a.LabChemSpecimenDateTime) and b.LabChemSpecimenDateTime
      and a.LabChemSpecimenDateTime <> b.LabChemSpecimenDateTime
where a.labtype in ('ANC' ) 
) as a 
where LabRankByValue = 1

;--select * from #labs where mvipersonsid = 1420904
	------------------------------------------------------------------------
	-- last visit (past 180 days else null) clozapine prescriber for outpatient rx
	--------------------------------------------------------------------------
	DROP TABLE IF EXISTS #LastVisitClozPrescriber;
	SELECT 
		a1.MVIPersonSID, a1.VisitDateTime, a1.ProviderSID, a1.StaffName, a1.LocationName, a1.NPI
	INTO #LastVisitClozPrescriber
	FROM 
		(
			SELECT 
				 g.ProviderSID
				,a.VisitDateTime
				,d.MVIPersonSID
				,e.StaffName
				,e.NPI
				,f.LocationName
				,ROW_NUMBER() OVER(PARTITION BY d.MVIPersonSID ORDER BY a.VisitDateTime Desc) AS LastApptRank
			FROM [Outpat].[VProvider] a WITH (NOLOCK)
			INNER JOIN #PatientSID_Cloz d 
				ON a.PatientSID = d.PatientSID
			INNER JOIN #Outpatient_Rx g 
				ON a.ProviderSID=g.ProviderSID
			INNER JOIN [Outpat].[Visit] c WITH (NOLOCK)
				ON a.VisitSID = c.VisitSID
			INNER JOIN [Dim].[Location] f WITH (NOLOCK)
				ON f.LocationSID = c.LocationSID
			INNER JOIN [SStaff].[SStaff] e WITH (NOLOCK)
				ON e.StaffSID = a.ProviderSID
			WHERE a.VisitDateTime > DATEADD(DAY,-180, CAST(GETDATE() AS DATE))
				AND c.WorkloadLogicFlag = 'Y'
		) a1
	WHERE a1.LastApptRank = 1
	;

insert into #LastVisitClozPrescriber
SELECT MVIPersonSID
     ,VisitDateTime, ProviderSID, NameFullFormatted ,LocationName
     ,  NPI
FROM (
	SELECT 
		 c.MVIPersonSID
     ,c.TZDerivedVisitDateTime AS VisitDateTime, DerivedPersonStaffSID AS ProviderSID, f1.NameFullFormatted ,c.Location AS LocationName
     , NULL NPI
	,ROW_NUMBER() OVER(PARTITION BY d.MVIPersonSID ORDER BY TZDerivedVisitDateTime Desc) AS LastApptRank
	FROM #Outpatient_Rx d 
  INNER JOIN [Cerner].[FactUtilizationOutpatient] c WITH(NOLOCK) ON d.MVIPersonSID = c.MVIPersonSID AND d.ProviderSID = c.DerivedPersonStaffSID
  INNER JOIN Cerner.FactStaffDemographic f1 WITH (NOLOCK) ON c.DerivedPersonStaffSID = f1.PersonStaffSID
	WHERE c.TZDerivedVisitDateTime   > DATEADD(DAY,-180, CAST(GETDATE() AS DATE))
	AND c.MVIPersonSID>0) AS A 
		WHERE a.LastApptRank = 1


 ----------------------------------------------------------------------------
-- Staging Final Table (Meds, Labs AND LastVisit with prescriber)
 ----------------------------------------------------------------------------
DROP TABLE IF EXISTS #StageClozapineMonitoring;

		SELECT a.ChecklistID
			,mp.MVIPersonSID
			,a.DrugNameWithoutDose
			,a.Inpatient
			,a.OutPat_Rx
			,a.CPRS_Order
			,a.CLOZAPINEDate AS max_releasedatetime
			,e.Dayssupply
			,e.PillsOnHand
			,e.DateSinceLastPillsHand
			,lfa.[MostRecentANC_D&T] 
			,lfa.[Accession#-anc]
			,case when  lfa.Calc_value_used = 'Y' then  lfa.[Accession#-anc] else null end as [Accession#-c]
			,TRY_CONVERT(float,lfa.Result_Value) AS ANC_Value
			,lfa.Units as ANC_Units
      ,isnull(lfa.Calc_value_used,'N') Calc_value_used
			,lfc.LabChemSpecimenDateTime as [MostRecentClozapine_D&T]
			,ClozResult  as Clozapine_Lvl
			,ClozUnits as Cloz_Units
			,case when NorResult is not null then lfc.LabChemSpecimenDateTime else null end   as [MostRecentNorclozapine_D&T] 
			,NorResult as Norclozapine_Lvl
			,lfa.[<30d_LowestPrev_LabChemSpecDateTime] as [<30d_LowestPrev_LabChemSpecDateTime]  
			,TRY_CONVERT(float,lfa.[<30d_LowestPrev_ANC_Value]) AS [<30d_LowestPrev_ANC_Value]
			,lfa.Previous_Units as Previous_ANC_Units
      ,isnull(lfa.Previous_Calc_value_used,'N') as Prev_Calc_value_used
			,NorUnits as Nor_Units
			,c.VisitDateTime
			,c.StaffName AS VisitStaff
			,c.LocationName AS Visit_Location
			,IsNULL(e.NPI,c.NPI) AS NPI
			,isnull(f.StaffName,f1.NameFullFormatted) AS Prescriber
    INTO #StageClozapineMonitoring
		FROM #CLOZAPINE a
		INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
			ON mp.MVIPersonSID = a.MVIPersonSID
		LEFT JOIN  #lab_final lfa 
			ON mp.MVIPersonSID = lfa.MVIPersonSID and lfa.labtype = 'ANC'
    	LEFT JOIN #Labs_MostRecentCloz lfc 
			ON mp.MVIPersonSID = lfc.MVIPersonSID

		LEFT JOIN #LastVisitClozPrescriber c 
			ON a.MVIPersonSID = c.MVIPersonSID
		LEFT JOIN #Outpatient_Rx e 
			ON e.max_ReleaseDateTime = a.ClozapineDate
			AND a.MVIPersonSID = e.MVIPersonSID 
			AND OutPat_Rx = 1
		LEFT JOIN [SStaff].[SStaff] f WITH (NOLOCK) 
			ON e.ProviderSID = f.StaffSID
    left JOIN Cerner.FactStaffDemographic f1 ON e.ProviderSID = f1.PersonStaffSID  
      
	EXEC [Maintenance].[PublishTable] 'Pharm.ClozapineMonitoring','#StageClozapineMonitoring'
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END
GO
