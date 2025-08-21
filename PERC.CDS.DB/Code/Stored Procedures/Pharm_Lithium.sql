
/* =============================================
Author:		<Susana Martins>
Create date: <07/13/2016>
Description:	<Creates table for patient report for patients with active lithum rx and lab tracking>
Modifications: --
	12/21/2016	GS Added table compression
	2/15/2017	GS added DoBackup
	3/14/2017	GS Repointed Present objects to PERC
	20180607	JEB - Removed hard coded database references
	20190206	RAS	Formatted and added maintenance publish table.
	20200414	RAS	Removed #mhtc query and replace with join to Present.Provider_MHTC. Only need to check impact of no space in StaffName.	
	20200812	RAS Pointed appointment join to vertical tables.
	20201210	RAS Reverted join to StationAssignments (now VM) to join on PatientSID instead of MVIPersonSID
	20210518	JEB - Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
	20210809	SM - Updated active Lithium computation to use Rockies MPR instead of CDS MPR.
	20210913	JEB	- Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Moved Publish tables to the very end; Added logging.
    20220322    EC - Incorporating Health Factors about outside/community labs into Lithium lab data and ranking of most recent lab date.
	20220630	RAS - Replaced PDSI PatientReport join with Present.Provider_PCP to get PCP information in final table.
	20220708	JEB - Updated Synonym references to point to Synonyms from Core
	20230911	AER - Cerner Integration
	20230913	RAS - Changed reference from omhsp_perc_cds.Cerner.FactLabResult to Cerner.FactLabResult
	20240617	LM	- Remove HealthFactorCategory reference due to change in CDW table structure; move hard-coded health factors to Lookup.ListMember
	20240815	LM - Removed hard-coded corrections for checklistID in Lexington (596) and NorCal (612A4)

	Testing execution:
		EXEC [Code].[Pharm_Lithium]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'Code.Pharm_Lithium'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE SchemaName = 'Pharm' AND TableName = 'LithiumPatientReport' ORDER BY 1 DESC

============================================== */
CREATE PROCEDURE [Code].[Pharm_Lithium]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	EXEC [Log].[ExecutionBegin] @Name = 'Code.Pharm_Lithium', @Description = 'Execution of Code.Pharm_Lithium SP'


drop table if exists #ActiveLith
select mv.*, m1.PatientPersonSID as PatientSID
into #ActiveLith
from Present.Medications mv WITH (NOLOCK)
left outer join Common.MVIPersonSIDPatientPersonSID m1 WITH (NOLOCK) on mv.MVIPersonSID = m1.MVIPersonSID and left(checklistid,3) = m1.Sta3n
where mv.DrugNameWithoutDose LIKE '%lithium%' and mv.DrugStatus='ActiveRx'
and mv.ChecklistID is not null --removed scripts order by DoD


	-------------------------------------------------------------
	--Active rx lithium -  8/9/21 - Updated to use Rockies MPR-------------------------------------------------------------
	DROP TABLE IF EXISTS #LithiumPatient;
	SELECT DISTINCT 
		rx.Sta3n
    ,Rx.CheckListID
		,rx.MVIPersonSID
    ,rx.PatientSID as PatientSID
		,rx.DrugNameWithoutDose
		,rx.DrugNameWithDose
		,CAST(mpr.MonthsInTreatment AS INT) AS MonthsInTreatment
		,rx.LastReleaseDateTime AS PresentReleaseTime
		,mpr.LastActiveRxOutpatSID AS RxOutpatSID
		,rx.PrescriberSID as ProviderSID 
    ,rx.PrescriberName
		,rx.Sta6a
		,CASE	
			WHEN rx.Sta6a='537' THEN 'VA CHG. HLTH. CARE SYSTEM'
			WHEN rx.Sta6a='564' THEN '564'
			WHEN rx.Sta6a='663' THEN 'VA PUGET SOUND HEALTH CARE SYSTEM' 
			ELSE div.DivisionName  
		END AS DivisionName
	INTO #LithiumPatient
	FROM #ActiveLith rx WITH (NOLOCK)
  left outer join [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] mpr WITH (NOLOCK) on mpr.LastActiveRxOutpatSID=rx.RxOutpatSID and mpr.MostRecentTrialFlag = 'True'
	left outer JOIN (
		SELECT Sta6a, DivisionName 
		FROM [Dim].[Division] WITH (NOLOCK) 
		WHERE DivisionName NOT LIKE 'zz%'
		) div ON rx.Sta6a = div.Sta6a

--select * from #LithiumPatient where mvipersonsid = 11424746
--select * from [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug]  where MVIPersonSID = 11424746
	-------------------------------------------------------------
	--Lithium labs: first select all relevant labs then identify most recent lab for each patient
	-------------------------------------------------------------
	DROP TABLE IF EXISTS #LithiumLabsinpastyear;
	SELECT DISTINCT 
		c.PatientSID
		,mvi.MVIPersonSID		
		,LabChemSpecimenDateTime AS MaxLabDate
		,LabChemTestName
		,LabChemResultNumericValue
		,LabChemResultValue
	INTO #LithiumLabsinpastyear
	FROM  [Chem].[LabChem] c WITH (NOLOCK) 
  	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) --keep this join to get lithium labs for patients at ALL facilities, not just the facility at which the lithium is prescribed
		ON c.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Dim].[LabChemTest] b WITH (NOLOCK)
		ON c.LabChemTestSID = b.LabChemTestSID 
		AND c.LabChemSpecimenDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0))
	INNER JOIN [Dim].[LOINC] d WITH (NOLOCK)
		ON c.LOINCSID = d.LOINCSID
	WHERE 
		( b.LabChemTestName LIKE '%lithium%' 
		  AND b.LabChemTestName NOT LIKE '%LITHIUM DOSE DATE%'
		  AND b.LabChemTestName NOT LIKE '%LITHIUM DOSE TIME%'
		)
		OR d.LOINC IN 
			('13455-1',--LITHIUM.PLASMA/LITHIUM.RBC
			 '14334-7',
			 '15369-2',--LITHIUM.SALIVA/LITHIUM.SERUM
			 '17086-0',
			 '18238-6',
			 '25461-5',
			 '25462-3',
			 '25463-1',
			 '34331-9',--LITHIUM/CREATININE
			 '3718-4',
			 '3719-2',
			 '3720-0',
			 '3721-8',
			 '3723-4',
			 '4300-0',
			 '9358-3',
			 '9815-2'
			)
	;
	
  DROP TABLE IF EXISTS #LithiumLabsinpastyearCerner;
	SELECT DISTINCT 
		a.PatientSID
		,a.MVIPersonSID
		,CollectDateTime AS MaxLabDate
		,SourceString as LabChemTestName
		,case when isnumeric(ResultValue) = 1 then ResultValue else null end  LabChemResultNumericValue
		,ResultValue LabChemResultValue
	INTO #LithiumLabsinpastyearCerner
  FROM #LithiumPatient as a 
  INNER JOIN [Cerner].[FactLabResult] as b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID 
  WHERE 
		( b.SourceString LIKE '%lithium%' 
		  AND b.SourceString NOT LIKE '%LITHIUM DOSE DATE%'
		  AND b.SourceString NOT LIKE '%LITHIUM DOSE TIME%'
		)
		OR SourceIdentifier IN 
			('13455-1',--LITHIUM.PLASMA/LITHIUM.RBC
			 '14334-7',
			 '15369-2',--LITHIUM.SALIVA/LITHIUM.SERUM
			 '17086-0',
			 '18238-6',
			 '25461-5',
			 '25462-3',
			 '25463-1',
			 '34331-9',--LITHIUM/CREATININE
			 '3718-4',
			 '3719-2',
			 '3720-0',
			 '3721-8',
			 '3723-4',
			 '4300-0',
			 '9358-3',
			 '9815-2'
			)
  
  
  insert into #LithiumLabsinpastyear
  select  * from #LithiumLabsinpastyearCerner
  
	/*--========================================================================================================= */
	--Types of items
	DROP TABLE IF EXISTS #SelectedLabItems;
	SELECT DISTINCT 
		 oi.Sta3n
		,oi.OrderableItemCode
		,oi.OrderableItemCodeSource
		,oi.OrderableItemName
		,oi.OrderableItemSID
		,oi.InactivatedDateTime
		,dg.DisplayGroupName
		,oi.OrderableItemCost
	INTO #SelectedLabItems
	FROM [Dim].[OrderableItem] oi WITH (NOLOCK)
	INNER JOIN [Dim].[DisplayGroup] dg WITH (NOLOCK) ON dg.DisplayGroupSID = oi.DisplayGroupSID
	WHERE dg.DisplayGroupName LIKE '%lab%'
		AND oi.OrderableItemName LIKE '%lithium%'      
	;
	CREATE NONCLUSTERED INDEX [idx_Sta3nOrderItemSid] ON #SelectedLabItems ([Sta3n] ASC,OrderableItemSID)
		WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF, FILLFACTOR = 90, DATA_COMPRESSION = PAGE)
	;

	/*--========================================================================================================= */
	DROP TABLE IF EXISTS #CprsPendingLabItems;
	SELECT 
		mvi.MVIPersonSID
		,a.PatientSID
		,a.CPRSOrderSID
		,a.CPRSOrderIEN
		,a.OrderStartDateTime
		--,i.FYQTR
		--,i.MonthYear
		--,i.MonthYearSID
		,c.EnteredDateTime
		,d.OrderableItemName
		,d.OrderableItemCode
		,d.OrderableItemCodeSource
		,d.OrderableItemSID
		,e.OrderStatusSID
		,e.OrderStatus
		,a.AbnormalResultsFlag
		,a.Findings
		,CAST(GETDATE() AS DATE) AS AOD
	INTO #CprsPendingLabItems
	FROM [CPRSOrder].[CPRSOrder] a WITH (NOLOCK)
	INNER JOIN #LithiumPatient AA 
		ON a.PatientSID = AA.patientsid
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON AA.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [CPRSOrder].[OrderedItem] c WITH (NOLOCK) 
		ON a.CPRSOrderSID = c.CPRSOrderSID 
		AND c.OrderStartDateTime >= CAST(DATEADD(dd,-366, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	INNER JOIN #SelectedLabItems AS d on c.OrderableItemSID=d.OrderableItemSID 
	INNER JOIN 
		(
			SELECT DISTINCT 
				OrderStatus,OrderStatusSID 
			FROM [Dim].[OrderStatus] WITH (NOLOCK)
			WHERE OrderStatus IN ('LAPSED','PENDING')
		) e 
		ON a.OrderStatusSID = e.OrderStatusSID
	WHERE  a.OrderStartDateTime >= CAST(DATEADD(dd,-366, CAST(GETDATE() AS DATE)) AS datetime2(0))
	;


	DROP TABLE IF EXISTS #MaxDateLithiumLabsOrderedPendinginpastyear;
	SELECT b.* 
	INTO #MaxDateLithiumLabsOrderedPendinginpastyear 
	FROM 
		(
			SELECT DISTINCT 
				a.MVIPersonSID
				,a.OrderStartDateTime
				,a.OrderStatus
				,ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID ORDER BY a.OrderStartDateTime DESC) AS MostRecentRank  
			FROM #CprsPendingLabItems a
		) b
	WHERE b.MostRecentRank = 1
	;
	-------------------------------------------------------------
	--Pull health factors used to indicate lithium labs from outside of the VA (community labs)
	-------------------------------------------------------------
	DROP TABLE IF EXISTS #LithiumHFs;
	SELECT DISTINCT 
		a.AttributeValue AS HealthFactorType
		,mvi.MVIPersonSID
		,b.PatientSID
		,b.HealthFactorDateTime
		,b.Comments
	INTO #LithiumHFs
	FROM [Lookup].[ListMember] a WITH (NOLOCK)
	INNER JOIN [HF].[HealthFactor] b WITH (NOLOCK)
		ON a.ItemID = b.HealthFactorTypeSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON b.PatientSID = mvi.PatientPersonSID 
	WHERE a.List = 'Lithium_HF' 
		AND b.HealthFactorDateTime >= CAST(DATEADD(DAY, -366, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
	;
-------------------------------------------------------------
	--Combine VA Lab Tests and HF Lab Tests and Rank
	-------------------------------------------------------------

	DROP TABLE IF EXISTS #MaxDateLithiumLabsinpastyear;  
	SELECT MVIPersonSID
		  ,PatientSID
		  ,LabChemResultNumericValue
		  ,LabChemResultValue
		  ,LabChemTestName
		  ,maxlabdate
		  ,MostRecentRank
	INTO #MaxDateLithiumLabsinpastyear 
	FROM (
		SELECT DISTINCT a.*
			,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY MaxLabDate desc) AS MostRecentRank  
		FROM #LithiumLabsinpastyear AS a
		) AS b
	WHERE MostRecentRank=1
	;

	DROP TABLE IF EXISTS #AllLabDates;
	SELECT MVIPersonSID
		,MaxLabDate
		,LabChemTestName
		,LabChemResultNumericValue
		,LabChemResultValue
	INTO #AllLabDates
	FROM #MaxDateLithiumLabsinpastyear 
	UNION
	SELECT MVIPersonSID
		,MaxLabDate = HealthFactorDateTime 
		,LabChemTestName = CONCAT('Health Factor: ', HealthFactorType)
		,'LabChemResultNumericValue' = NULL
		,LabChemResultValue = Comments
	FROM #LithiumHFs
	;

	DROP TABLE IF EXISTS #MaxLabDate; 
	SELECT MVIPersonSID
		  ,LabChemResultNumericValue
		  ,LabChemResultValue
		  ,LabChemTestName
		  ,MaxLabDate
		  ,MostRecentRank
	INTO #MaxLabDate
	FROM (
		SELECT DISTINCT a.*
			,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY MaxLabDate desc) AS MostRecentRank  
		FROM #AllLabDates AS a
		) AS b
	WHERE MostRecentRank=1
	;
		-------------------------------------------------------------
	--Active lithium rx and max lithium lab date at icn level
	-------------------------------------------------------------
	DROP TABLE IF EXISTS #LithiumActiveRx_Labs; 
	SELECT DISTINCT 
		 a.ChecklistID
     ,a.MVIPersonSID
		,a.PatientSID
		,b.MaxLabDate
		,a.MonthsInTreatment
		,a.RxOutpatSID
		,a.ProviderSID
    ,a.PrescriberName
		,a.Sta6a
		,a.DivisionName
		,a.DrugNameWithoutDose
		,a.DrugNameWithDose AS LocalDrugNameWithDose
		,a.PresentReleaseTime
		,b.LabChemTestName
		,b.LabChemResultNumericValue
		,b.LabChemResultValue
		,c.OrderStartDateTime
		,c.OrderStatus
	INTO #LithiumActiveRx_Labs
	FROM #LithiumPatient a
	LEFT JOIN #MaxLabDate b 
		ON a.MVIPersonSID = b.MVIPersonSID
	LEFT JOIN 
		(
			SELECT DISTINCT 
				MVIPersonSID
				,OrderStartDateTime
				,OrderStatus 
			FROM #MaxDateLithiumLabsOrderedPendinginpastyear
		) c 
		ON a.MVIPersonSID = c.MVIPersonSID 
		AND ((c.OrderStartDateTime > b.MaxLabDate) OR b.MaxLabDate IS NULL)
	;

	--GET APPOINTMENTS
	DROP TABLE IF EXISTS #appointments;
	SELECT 
		l.MVIPersonSID
		,pcf.AppointmentDateTime AS PCFutureAppointmentDateTime_ICN
		,pcf.PrimaryStopCode AS PCFuturePrimaryStopCode_ICN		
		,pcf.PrimaryStopCodeName AS PCFutureStopCodeName_ICN			
		,pcf.AppointmentLocationName AS PCFutureAppLocationName_ICN		
		,mhf.AppointmentDateTime AS MHFutureAppointmentDateTime_ICN
		,mhf.PrimaryStopCode AS MHFuturePrimaryStopCode_ICN	
		,mhf.PrimaryStopCodeName AS MHFutureStopCodeName_ICN				
		,mhf.AppointmentLocationName AS MHFutureAppointmentLocationName_ICN	
		,oth.AppointmentDateTime AS OtherFutureAppointmentDateTime_ICN	
		,oth.PrimaryStopCode AS OtherFuturePrimaryStopCode_ICN		
		,oth.PrimaryStopCodeName AS OtherFutureStopCodeName_ICN			
	 INTO #appointments
	 FROM #LithiumActiveRx_Labs l
	 LEFT JOIN 
		(
			SELECT MVIPersonSID,AppointmentDateTime,PrimaryStopCode,PrimaryStopCodeName,AppointmentLocationName
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN = 1 AND ApptCategory = 'PCFuture'
		) pcf 
		ON pcf.MVIPersonSID = l.MVIPersonSID
	 LEFT JOIN 
		(
			SELECT MVIPersonSID,AppointmentDateTime,PrimaryStopCode,PrimaryStopCodeName,AppointmentLocationName
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN = 1 AND ApptCategory = 'MHFuture'
		) mhf 
		ON mhf.MVIPersonSID=l.MVIPersonSID
	 LEFT JOIN 
		(
			SELECT MVIPersonSID,AppointmentDateTime,PrimaryStopCode,PrimaryStopCodeName
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_ICN = 1 AND ApptCategory = 'OtherFuture'
		) oth 
		ON oth.MVIPersonSID = l.MVIPersonSID
	;
	-------------------------------------------------------------
	--Creating Patient Report
	-------------------------------------------------------------
	DROP TABLE IF EXISTS #final;
	SELECT DISTINCT
		LEFT(a.ChecklistID, 3) AS Sta3n
		,a.MVIPersonSID
		,a.PatientSID
		,a.MaxLabDate
		,a.ProviderSID AS PrescriberSID
		,mp.PatientICN
		,mp.PatientName
		,mp.PatientSSN
		,mp.LastFour
		,mp.Age
		,mp.Gender
		,a.PrescriberName
		,a.Sta6a
		,a.DivisionName
		,a.ChecklistID AS IntegratedSta3n -- based on where prescription was ordered
		,a.ChecklistID
		,CASE 
			WHEN DATEDIFF(DAY, MaxLabDate, GETDATE()) <= 90 THEN 0 -- less than 3m
			WHEN DATEDIFF(DAY, MaxLabDate, GETDATE()) > 90 AND DATEDIFF(day,MaxLabDate, GETDATE()) <= 180 THEN 1 --3-6m
			WHEN DATEDIFF(DAY, MaxLabDate, GETDATE()) > 180 AND DATEDIFF(day,MaxLabDate, GETDATE()) <= 370 THEN 2  --6-12m
			ELSE 3 
		END AS FollowUpKey --more than 12m
		,g.PCFutureAppointmentDateTime_ICN AS PCFutureAppointmentDateTime
		,g.PCFuturePrimaryStopCode_ICN AS PCFuturePrimaryStopCode
		,g.PCFutureStopCodeName_ICN AS PCFutureStopCodeName
		,g.PCFutureAppLocationName_ICN AS PCFutureAppLocationName
		,g.MHFutureAppointmentDateTime_ICN AS MHFutureAppointmentDateTime
		,g.MHFuturePrimaryStopCode_ICN AS MHFuturePrimaryStopCode
		,g.MHFutureStopCodeName_ICN AS MHFutureStopCodeName
		,g.MHFutureAppointmentLocationName_ICN AS MHFutureAppLocationName
		,g.OtherFutureAppointmentDateTime_ICN AS OtherFutureAppointmentDateTime
		,g.OtherFuturePrimaryStopCode_ICN AS OtherFuturePrimaryStopCode
		,g.OtherFutureStopCodeName_ICN AS OtherFutureStopCodeName
		,mp.LastFour as LookUpLastFour
		--,c.TeamSID
		--,c.Team
		,c.StaffName AS PrimaryCareProvider
		,c.ProviderSID AS PrimaryProviderSID
		,c.ChecklistID AS PrimaryProviderInstitution
		,c.DivisionName AS PrimaryProviderDivision
		,h.StaffName AS MHTC
		,h.TeamRole AS MHTCType
		,h.Sta6a AS MHTCInstitutionCode
		,h.DivisionName AS MHTCInstitutionName 
		,ISNULL(a.LocalDrugNameWithDose, a.DrugNameWithoutDose) AS Drug
		,a.MonthsInTreatment
		,a.PresentReleaseTime
		,f.HealthFactorType
		,f.HealthFactorDateTime
		,a.LabChemTestName
		,a.LabChemResultNumericValue
		,a.LabChemResultValue 
		,CASE 
			WHEN a.LabChemResultValue LIKE '%1%'
			  OR a.LabChemResultValue LIKE '%2%'
			  OR a.LabChemResultValue LIKE '%3%'
			  OR a.LabChemResultValue LIKE '%4%'
			  OR a.LabChemResultValue LIKE '%5%'
			  OR a.LabChemResultValue LIKE '%6%'
			  OR a.LabChemResultValue LIKE '%7%'
			  OR a.LabChemResultValue LIKE '%8%'
			  OR a.LabChemResultValue LIKE '%9%' 
			THEN LTRIM(REPLACE(a.LabChemResultValue, '<', '')) 
			ELSE NULL 
		END AS LabChemResultValue_Numeric
		,a.OrderStartDateTime 
		,a.OrderStatus
	INTO #final
  FROM #LithiumActiveRx_Labs a
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
		ON a.MVIPersonSID = mp.MVIPersonSID
	LEFT JOIN [Present].[Provider_PCP] c WITH (NOLOCK)
		ON a.Mvipersonsid = c.mvipersonsid and c.ChecklistID = a.checklistid
	LEFT JOIN [LookUp].[Sta6a] e WITH (NOLOCK)
		ON a.Sta6a=e.Sta6a
	LEFT JOIN #LithiumHFs f 
		ON a.PatientSID = f.PatientSID
	LEFT JOIN #appointments g 
		ON a.MVIPersonSID = g.MVIPersonSID
	--LEFT JOIN [Present].[Appointments] g WITH (NOLOCK) ON a.MVIPersonSID=g.MVIPersonSID
	LEFT JOIN [Present].[Provider_MHTC] h WITH (NOLOCK)
		ON a.Mvipersonsid = h.mvipersonsid and h.ChecklistID = a.checklistid
	;

  
  
--select * from #final
	EXEC [Maintenance].[PublishTable] 'Pharm.LithiumPatientReport','#final'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
