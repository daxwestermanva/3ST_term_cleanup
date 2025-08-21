

/* =============================================
-- Author:		Tolessa Gurmessa
-- Date:		4/13/2023 
-- Description:	This SP creates a dataset for Community Care Opioid Prescribers.
-- This code is borrowed from Michael Harvey (ADS)

	Modifications:
	2023-05-24	LM	Changed TerminationDate to TerminationDateTime and added join to Staff.StaffChangeMod due to upstream changes in SStaff.SStaff
	2023-05-24  TG Commented the PAIDFlag and PAIDEmployeeIEN until we figure out where we could find this information.
-- ============================================*/
CREATE PROCEDURE [Code].[ORM_NonVAProviders]



AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.ORM_NonVAProviders','Execution of SP Code.ORM_NonVAProviders'

	drop table if exists #ProviderList_1;
		select distinct
		a.sta3n
		,ProviderSID
		INTO #ProviderList_1
		FROM RxOut.RxOutPat as a
		where IssueDate >= cast(getdate() - 366 as date)

		;

		drop table if exists #ProviderList_2;
		select distinct
		a.sta3n
		,ProviderSID
		INTO #ProviderList_2
		FROM RxOut.RxOutPat as a
		where IssueDate >= cast(getdate() - 740 as date)
			and RxStatus IN (
					'active'
					, 'suspended'
					, 'hold'
					, 'provider Hold'
					)

		;

		drop table if exists #ProviderList_3;
		select distinct
		a.sta3n
		,ProviderSID
		INTO #ProviderList_3
		from rxout.rxoutpatfill as a
		where ReleaseDateTime >= cast(cast(getdate() - 366 as date) as datetime2(0))

		;

drop table if exists #Prescriber_Vista;
select
*
INTO #Prescriber_Vista
FROM
	(
	select
	*
	from #ProviderList_1
	UNION
	select
	*
	from #ProviderList_2
	UNION
	select
	*
	FROM #ProviderList_3
	) as a

		;

		drop table #ProviderList_1 ; drop table #ProviderList_2 ; drop table #ProviderList_3

		;


/*****Cerner Providers*****/
drop table if exists #PRescriber_Cerner;
SELECT DISTINCT 200 AS sta3n
	, OrderProviderPersonStaffSID AS ProviderSID
INTO #Prescriber_Cerner
FROM OrderMill.PersonOrder AS A
INNER JOIN NDimMill.CodeValue AS B
	ON A.CatalogTypeCodeValueSID = B.CodeValueSID
		AND B.CDFMeaning = 'PHARMACY'
		AND B.CodeValueSetSID = 1800000979
		AND B.ActiveIndicator = 1
INNER JOIN PharmacyMill.MedDispenseOrder AS mdo
	ON mdo.PersonOrderSID = a.PersonOrderSID
LEFT JOIN (
	SELECT DISTINCT PersonOrderSID
		, OrderProviderPersonStaffSID
	FROM .OrderMill.OrderActionDetail
	WHERE OrderProviderPersonStaffSID > 0
		AND ActionSequence = 1 -- ActionType = Order
	) AS D
	ON A.PersonOrderSID = D.PersonOrderSID
WHERE (
		(
			A.OrderDateTime >= cast(cast(getdate() - 366 as date) as datetime2(0))
			AND A.OrderDateTime <= CAST(CAST(GETDATE() + 1 AS DATE) AS DATETIME2(0))
			)
		OR (
			a.DepartmentalStatus = 'Ordered'
			AND A.OrderDateTime >= cast(cast(getdate() - 740 as date) as datetime2(0))
			)
		)

	;

drop table if exists #Prescriber_Cerner2;
SELECT distinct
200 as sta3n
,f.OrderProviderPersonStaffSID as ProviderSID
INTO #Prescriber_Cerner2
FROM PharmacyMill.DispenseHistory AS A
JOIN PharmacyMill.MedDispenseOrder AS B 
  ON A.PersonOrderSID = B.PersonOrderSID
JOIN NDimMill.CodeValue AS D
  ON A.DispenseEventTypeCodeValueSID = D.CodeValueSID
 AND D.ActiveIndicator = 1
 AND D.CDFMeaning = 'DISPENSE'
 AND D.CodeValueSetID = 4032
Join OrderMill.OrderActionDetail as f
	on a.PersonOrderSID = f.PersonOrderSID and f.ActionSequence = 1 and OrderProviderPersonStaffSID > 0
WHERE A.DispenseDateTime >= cast(cast(getdate() - 366 as date) as datetime2(0))
	AND A.DispenseDateTime <= CAST(CAST(GETDATE() AS DATE) AS DATETIME2(0))

	;

	drop table if exists #ProviderList;
	SELECT DISTINCT 
	a.sta3n
	,a.ProviderSID
	,cast(ch.LastSignOnDateTime as date) as LastSignOnDate
	INTO #ProviderList
	FROM (
		select
		*
		from #Prescriber_VistA
		UNION
		SELECT *
		FROM #Prescriber_Cerner
		UNION
		select
		*
		from #Prescriber_Cerner2
		) AS a
	left join sstaff.sstaff as ss
		on ss.staffsid = a.providersid
	LEFT JOIN Staff.StaffChangeMod ch WITH (NOLOCK)
		ON ss.StaffSID = ch.StaffSID
	where a.providersid > 0

	; 

		drop table #Prescriber_VistA ; drop table #Prescriber_Cerner ; drop table #Prescriber_Cerner2

		;

	drop table if exists #ChoicePart1;
	SELECT ProviderSID
		, ChoiceFlag
		, TimeFrameFlag
		, Count(DISTINCT RxOutpatSID) AS ChoiceCounts
		, count(DISTINCT CASE 
				WHEN IssueDate >= MostRecentIssue
					THEN rxoutpatsid
				END) AS MostRecentRxCounts
	, count(DISTINCT CASE 
				WHEN IssueDate > DateAdd(d,14,LastSignOnDate)
					THEN rxoutpatsid
				END) AS AfterLastSignOnCounts
	INTO #ChoicePart1
	FROM (
		SELECT rxoutpatsid
			, a.IssueDate
			, a.ProviderSID
			,LastSignOnDate
			, CASE 
				WHEN IssueDate >= cast(DateAdd(Month,-1,getdate()) AS DATE)
					THEN 1
				WHEN IssueDate >= cast(DateAdd(month,-6,getdate()) AS DATE)
					THEN 0
				ELSE - 1
				END AS TimeFrameFlag
			, DateAdd(d, - 30, Max(IssueDate) OVER (PARTITION BY a.providerSID)) AS MostRecentIssue
			, CASE 
				WHEN (
						FillRemarks LIKE '%CH[IO][IO]CE%'
						AND LoginDate < cast('10/01/2019 00:00:00' AS DATE)
						)
					OR (
						FillRemarks LIKE '%CCNRX%'
						AND A.LoginDate >= CONVERT(DATE, '6/1/19')
						)
					THEN 1
				WHEN A.LoginDate >= CONVERT(DATE, '6/1/19')
					AND (
						A.FillRemarks LIKE '%CNRX%'
						OR A.FillRemarks LIKE '%CCRX%'
						OR A.FillRemarks LIKE '%CCN%'
						OR A.FillRemarks LIKE '%CNN%'
						OR A.FillRemarks LIKE '%CRN%'
						)
					AND a.fillremarks NOT LIKE '%CCNRX%'
					THEN 1
				ELSE 0
				END AS ChoiceFlag
		FROM rxout.rxoutpatfill AS a
		INNER JOIN #ProviderList AS c
			ON c.providersid = a.providersid
		WHERE ReleaseDateTime >= cast(cast(getdate() - 366 as date) as datetime2(0))
			AND ReleaseDateTime < cast(cast(getdate() AS DATE) AS DATETIME2(0))
		) AS a
	GROUP BY ProviderSID
		, TimeFrameFlag
		, ChoiceFlag;

	
	drop table if exists #ChoicePart2;
	SELECT ProviderSID
		, MAX(CASE 
				WHEN ChoiceFlag = 1
					THEN ChoiceCounts
				ELSE 0
				END) AS ChoiceFlag
		, MAX(CASE 
				WHEN ChoiceFlag = 0
					THEN ChoiceCounts
				ELSE 0
				END) AS VARxFlag
		, SUM(ChoiceCounts) AS TotalRxCount
		, MAX(CASE 
				WHEN ChoiceFlag = 1
					THEN MostRecentRxCounts
				ELSE 0
				END) AS MostRecentRxChoice
		, MAX(CASE 
				WHEN ChoiceFlag = 0
					THEN MostRecentRxCounts
				ELSE 0
				END) AS MostRecentRxVA
		, SUM(MostRecentRxCounts) AS TotalMostRecentCount
		, MAX(CASE 
				WHEN ChoiceFlag = 1
					THEN AfterLastSignOnCounts
				ELSE 0
				END) AS AfterLastSignOnRxChoice
		, MAX(CASE 
				WHEN ChoiceFlag = 0
					THEN AfterLastSignOnCounts
				ELSE 0
				END) AS AfterLastSignOnRxVA
		, SUM(AfterLastSignOnCounts) AS TotalAfterLastSignOnCount
	INTO #ChoicePart2
	FROM #ChoicePart1 a 
	GROUP BY ProviderSID;



	DROP TABLE #ChoicePart1;



	drop table if exists #FinalChoice;
	SELECT DISTINCT a.*
		, CASE 
			WHEN ChoicePercent = 0
				AND a.CernerFlag = 0
				THEN 0
			WHEN ChoicePercent = 1
				THEN 1
			WHEN MostRecentChoicePercent = 1
				AND MostRecentRxChoice >= 2
				THEN 1
			WHEN MostRecentChoicePercent >= 0.20
				AND MostRecentRxChoice > 5
				THEN 1
			WHEN ChoicePercent >= 0.20
				THEN 1
			WHEN ChoiceCount > NonChoiceCount
				AND ChoiceCount > 5
				THEN 1
			WHEN MostRecentRxChoice > 0.5
				AND NonVAPrescriberFlag = 'Y'
				THEN 1
			WHEN ChoiceCount > NonChoiceCount
				AND NonVAPrescriberFlag = 'Y'
				THEN 1
			WHEN CernerFlag = 1
				THEN - 1
			ELSE 0
			END AS ChoiceFlag
		, CASE 
			WHEN ChoicePercent >= 0.20
				THEN 1
			ELSE 0
			END AS ChoicePercentFlag
	--,case when NonVAPrescriberFlag = 'Y' then 1 else 0 end as SStaffNVAPrescriberFlag
	INTO #FinalChoice
	FROM (
		SELECT DISTINCT ProviderSID
			, StaffName
			, NonVaPrescriberFlag
			, TotalRxCount - ChoiceFlag AS NonChoiceCount
			, ChoiceFlag AS ChoiceCount
			, TotalRxCount AS Total
			, cast((ChoiceFlag) AS DECIMAL(10, 3)) / cast(TotalRxCount AS DECIMAL(10, 3)) AS ChoicePercent
			, MostRecentRxChoice
			, cast((MostRecentRxChoice) AS DECIMAL(10, 3)) / cast(TotalMostRecentCount AS DECIMAL(10, 3)) AS MostRecentChoicePercent
			, AfterLastSignOnRxChoice
			, case when TotalAfterLastSignOnCount = 0 then 0
				else
				cast((AfterLastSignOnRxChoice) AS DECIMAL(10, 3)) / cast(TotalAfterLastSignOnCount AS DECIMAL(10, 3)) end AS AfterLastSignOnChoicePercent
			,TotalAfterLastSignOnCount
			, CASE 
				WHEN ss.sta3n = 200
					THEN 1
				ELSE 0
				END AS CernerFlag
		FROM #ChoicePart2 AS a 
		INNER JOIN sstaff.sstaff AS ss --where is this located and why do we need it?
			ON ss.staffsid = a.providersid
		
		) AS a;


drop table #ChoicePart2 

;

drop table if exists #Visits1;
select distinct
a.sta3n
,a.ProviderSID
INTO #Visits1
from outpat.VProvider as a
left join #ProviderList as b
	on a.providersid = b.providersid
where visitdatetime >= cast(getdate() - 366 as datetime2(0))
	and b.providersid is null

;

drop table if exists #Visits2;
select distinct
200 as sta3n
,PersonStaffSID
INTO #Visits2
from encmill.encounter as a
join EncMill.EncounterStaff as b
	on a.encountersid = b.encountersid
--join pbm_ad.staging.OrganizationName_CDW2 as o
--	on o.OrganizationNameSID = a.OrganizationNameSID
where a.ActiveIndicator = 1 and RegistrationDateTime >= cast(getdate() - 366 as datetime2(0))
	and a.EncounterType not in ('Care Not Rendered','Outside Documentation Only')

	;

drop table if exists #ProviderList2;
select distinct
*
INTO #ProviderList2
FROM
	(
	select
	*
	,0 as PrescriberFlag
	from #Visits1
	UNION
	select
	*
	,0 as PrescriberFlag
	FROM #Visits2
	UNION
	select
	sta3n
	,ProviderSID
	,1 as PrescriberFlag
	from #ProviderList
	) as a

; drop table #ProviderList  ; drop table #Visits1 ; drop table #Visits2 ;

drop table if exists #Entered;
select
EnteredByStaffSID
,MAX(EntryDateTime) as LastNote
INTO #Entered
FROM tiu.tiudocument AS a
join #ProviderList2 as b
	on a.EnteredByStaffSID = b.providersid
WHERE EntryDateTime >= cast(cast(getdate() - 366 AS DATE) AS DATETIME2)
	and EntryDateTime <= cast(cast(getdate() AS DATE) AS DATETIME2)
	and EnteredByStaffSID > 0
GROUP BY EnteredbyStaffSID;


drop table if exists #Signed;
select
SignedbyStaffSID
,MAX(EntryDateTime) as LastNote
INTO #Signed
FROM tiu.tiudocument AS a
join #ProviderList2 as b
	on a.SignedByStaffSID = b.providersid
WHERE EpisodeBeginDateTime >= cast(cast(getdate() - 366 AS DATE) AS DATETIME2)
	and EpisodeBeginDateTime <= cast(cast(getdate() AS DATE) AS DATETIME2)
	and SignedByStaffSID > 0
GROUP BY SignedbyStaffSID;


drop table if exists #CoSigned;
select
CosignedByStaffSID
,MAX(EntryDateTime) as LastNote
INTO #CoSigned
FROM tiu.tiudocument AS a
join #ProviderList2 as b
	on a.CosignedByStaffSID = b.providersid
WHERE EpisodeBeginDateTime >= cast(cast(getdate() - 366 AS DATE) AS DATETIME2)
	and EpisodeBeginDateTime <= cast(cast(getdate() AS DATE) AS DATETIME2)
	and CoSignedByStaffSID > 0
GROUP BY CoSignedbyStaffSID;

	
	drop table if exists #Notes;
	SELECT DISTINCT EnteredByStaffSID
		, cast(cast(MAX(LastNote) AS DATE) AS DATETIME2(0)) AS LastNote
	INTO #Notes
	FROM (
		SELECT *
		FROM #Entered
		
		UNION
		
		SELECT *
		FROM #Signed
		
		UNION
		
		SELECT *
		FROM #CoSigned
		) AS a
	GROUP BY EnteredByStaffSID;


/**********CPRS Tab Permissions************/
drop table if exists #CPRSAccess;
select
StaffSID
,MAX(case when CPRSTabKey = 'COR' then 1 else 0 end) as CPRSAccess
,MAX(case when CPRSTabKey = 'NVA' then 1 else 0 end) as NVACPRSTab
INTO #CPRSAccess
from StaffSub.CPRSTabPermission as a --do we need this, or can we do without it?
join #ProviderList2 as b
	on a.staffsid = b.providersid
join dim.cprstabkey as c
	on c.cprstabkeysid = a.cprstabkeysid
where StaffSID > 0 and CPRSTabKey in ('COR','NVA')
	and (ExpirationDateTime is null or ExpirationDateTime >= cast(cast(getdate() as date) as datetime2(0)))
group by StaffSID

;

/***Can't include pharmacy/lab orders since these are sometimes placed in the name of outside providers****/
drop table if exists #OrderEntry;
SELECT  
	a.EnteredByStaffSID
	, MAX(EnteredDateTime) AS MostRecentOrder
INTO #OrderEntry
FROM CPRSOrder.CPRSOrder AS a
INNER JOIN #ProviderList2 AS b
	ON a.EnteredByStaffSID = b.ProviderSID
JOIN dim.VistaPackage AS v
	ON v.VistaPackageSID = a.VistaPackageSID
WHERE EnteredDateTime >= cast(cast(getdate() - 366 AS DATE) AS DATETIME2(0))
	and EnteredDateTime <= cast(cast(getdate() as date) as datetime2(0))
	AND (
		a.sta3n = 200
		OR 
		v.Vistapackage in ('INPATIENT MEDICATIONS','ORDER ENTRY/RESULTS REPORTING','SCHEDULING','CONSULT/REQUEST TRACKING')
		)
GROUP BY EnteredByStaffSID;

drop table if exists #MostRecentRx;
select
a.ProviderSID
,MAX(IssueDate) as MostRecentRxIssue 
,MAX(case when enteredbystaffsid = a.providersid then IssueDate end) as MostRecentIssue_EnteredbyStaff
INTO #MostRecentRx
FROM rxout.rxoutpat as a
join #ProviderList2 as b
	on a.providersid = b.providersid
where issuedate >= cast(getdate() - 740 as date) and Issuedate <= cast(getdate() as date)
group by a.ProviderSID

;

	drop table if exists #ProviderList4;
	SELECT DISTINCT 
		a.sta3n
		, ProviderSID
		, StaffName AS ProviderName
		, PositionTitle
		, ServiceSection
		, ProviderClass
		, ProviderScheduleType
		, LastSignonDateTime
		, CASE 
			WHEN NonVAPrescriberFlag = 'Y'
				THEN 1
			ELSE 0
			END AS SStaffNVAPrescriberFlag
		, CASE 
			WHEN (
					ProviderScheduleType LIKE '%FEE%BASIS%'
					OR ProviderScheduleType LIKE '%FEE%SERVICE%'
					OR providerscheduletype LIKE '%COMMUNITY%CARE%'
					OR providerscheduletype LIKE '%NON%VA%CARE%'
					OR ServiceSection LIKE '%FEE BASIS%'
					OR ProviderScheduleType LIKE '%FEE BASIS%'
					OR servicesection LIKE '%NON%VA%CARE%'
					OR servicesection LIKE '%COMMUNITY CARE%'
					OR servicesection LIKE 'FEE SERVICES%'
					OR PositionTitle LIKE '%FEE%BASIS%'
					OR PositionTitle LIKE '%NON%VA%PROV%'
					OR positiontitle LIKE '%COMMUNITY%CARE%'
					OR servicesection LIKE '%PURCHASED%CARE%'
					OR servicesection LIKE '%FEE%SVS%'
					OR ss.NonVAPrescriberFlag = 'Y'
					)
				THEN 1
			ELSE 0
			END AS NVASstaffIndicator
		, ss.StaffIEN
		--, CASE 
		--	WHEN ss.PAIDEmployeeIEN IS NOT NULL
		--		THEN 1
		--	ELSE 0
		--	END AS PaidFlag
		,case when ss.StaffIEN is not null and ss.TerminationDateTime is not null then 1
				else 0 end as SeparatedFlag 
		,isnull(cprs.CPRSAccess,0) as CPRSAccess
		,isnull(cprs.NVACPRSTab,0) as NVACPRSAccess
	INTO #ProviderList4
	FROM #ProviderList2 AS a
	left join #CPRSAccess as CPRS
		on a.providersid = cprs.staffsid
	INNER JOIN sstaff.sstaff AS ss
		ON ss.staffsid = a.providersid
	LEFT JOIN Staff.StaffChangeMod ch WITH (NOLOCK)
		ON ss.StaffSID = ch.StaffSID
			;
	
	drop table if exists #ProviderInfo;
	SELECT DISTINCT a.*
		, b.NonChoiceCount
		, LastNote
		, MostRecentOrder
		,MostRecentRxIssue
		,MostRecentIssue_EnteredbyStaff
		,AfterLastSignOnRxChoice
		,TotalAfterLastSignOnCount
		,AfterLastSignOnChoicePercent
		, CASE 
			WHEN ChoiceFlag = -1
				THEN NULL
			WHEN b.providersid IS NULL
				AND a.sta3n = 200
				THEN NULL
			ELSE isnull(ChoicePercent, 0.00)
			END AS ChoicePercent
		, CASE 
			WHEN b.providersid IS NULL
				AND a.sta3n = 200
				THEN - 1
			ELSE isnull(ChoiceFlag, 0)
			END AS ChoiceFlag
		, isnull(ChoicePercentFlag, 0) AS ChoicePercentFlag
		,Total
		----*****This is the case statement that matters most*****
		--Unfortunately there's no easy filter that works here since this data is messy and nonstandardized.  So this is kind of a long case statement that flags providers in a relatively important descending order
		-- since doing it in a different order can cause providers to be flagged incorrectly.
		, CASE 
			when sta3n = 200 then -1
			--When a significant % of Rxs are choice and they've had at least 10 Rxs, probably a CCNRx provider
			WHEN ChoiceFlag = 1
				AND Total > 10
				THEN 1
			--When a significant % of their Rxs are Choice and they've not had a note, order, sign on, or are in PAID and have no CPRS Access then probably choice
			WHEN ChoiceFlag = 1
				AND LastNote IS NULL
				AND oe.MostRecentOrder IS NULL
				AND LastSignOnDateTime IS NULL
				--AND PaidFlag = 0
				AND CPRSAccess = 0
				THEN 1
			--No sign ons, no notes, no recent orders, not in paid, no CPRS access or CPRS access is only NVA view
			WHEN LastSignOnDateTime IS NULL
				AND LastNote IS NULL
				AND MostRecentOrder IS NULL
				--AND PaidFlag = 0
				AND CPRSAccess = 0
				AND (
					NVASstaffIndicator = 1
					OR ChoiceFlag = 1
					OR NVACPRSAccess = 1 
					--OR a.stapa IS NULL
					)
				THEN 1
			---VA Provider: signed on/had orders recently and has CPRS access and is in PAID and has no NVA SStaff Indicators 
			WHEN  (
					lastSignOnDateTime >= cast(cast(getdate() - 180 AS DATE) AS DATETIME2(0))
					OR lastnote >= cast(cast(getdate() - 180 AS DATE) AS DATETIME2(0))
					OR MostRecentOrder >= cast(cast(getdate() - 180 AS DATE) AS DATETIME2(0))
					)
				and 1 in (CPRSAccess) --(PAIDFlag, CPRSAccess) --PAIDFlag is temporarily removed until we find this information
				and 1 not in (NVASStaffIndicator, SStaffNVAPrescriberFlag)
				THEN 0
			--No sign ons (at VistA sites) in the past 2 years and an indicator in SStaff they are non VA and no PAID data entry
			when isnull(LastSignOnDateTime,cast('01/01/1900' as datetime2(0))) < cast(cast(getdate() - 740 as date) as datetime2(0))
				and 1 in (NVASstaffIndicator) and (SeparatedFlag = 1) then 1 --(PaidFlag = 0 or SeparatedFlag = 1)
			--VA Provider - recent sign on and in PAID and recent notes and has CPRS access.  Some providers are flagged as a Non VA Provider because they are contract/fee but work at the facility
			--	which for our purposes we still treat as VA providers so this helps differentiate those.
			when LastSignOnDateTime >= cast(cast(DateAdd(month,-1,getdate()) as date) as datetime2(0))
				and LastNote >= cast(cast(DateAdd(month,-1,getdate()) as date) as datetime2(0))
				and 1 in (CPRSAccess) then 0 --(CPRSAccess,PAIDFlag)
			--Default to VA provider when there's nothing that indicates it's a Non VA Provider at all but there's also no sign ons or activity.
			when LastSignonDateTime is null and LastNote is null and isnull(ChoiceFlag,0) = 0 and NVASstaffIndicator = 0 and NVACPRSAccess = 0 then 0
			--Default to VA provider when there's a sign on in the past but nothing indicates it's a non VA provider
			when isnull(ChoiceFlag,0) = 0 and LastSignOnDateTime is not null and NVASstaffIndicator = 0 and NVACPRSAccess = 0 then 0
			--Non VA Provider: Flag in SStaff = Y, not in PAID, no CPRS Access, Choice % > 50% of Rxs, last sign on more than 90 days ago, no notes ever
			when SStaffNVAPRescriberFlag = 1 --and PAIDFlag = 0 --Removed until we discover PAIDEmployeeIEN
			and (CPRSAccess = 0 or NVACPRSAccess = 1) and ChoicePercent > 0.5	
				and LastSignOnDateTime < cast(cast(getdate() - 90 as date) as datetime2(0)) and LastNote is null then 0
			--VA provider: Staff w/ no Rxs (e.g. Total Rxs is null or 0) means they are in this list b/c they have visits only, which should primarily be VA staff at this point (after all the other filters applied)
			when isnull(total,0) = 0 then 0
			--Non VA Provider: Staff has not signed into VistA in over 2 years, and has another indicator for possibly being a Choice Provider
			when LastSignonDateTime < cast(cast(getdate() - 740 as date) as datetime2(0))
				and (ChoiceFlag = 1 or NVACPRSAccess = 1 or SStaffNVAPrescriberFlag = 1) then 1
			--Non VA Provider: Issuing Rxs at least 1 pay period beyond last sign on date, last signed on more than 90 days ago, Choice Rx comments or SStaff NVA Provider Flag indicates NVA provider, and has never entered a CPRS Note
			when MostRecentRxIssue > cast(DateAdd(d,14,lastSignOnDateTime) as date)
				and LastSignOnDateTime < cast(cast(getdate() - 90 as date) as datetime2(0))
				and 1 in (ChoiceFlag, SStaffNVAPrescriberFlag)
				and LastNote is null then 1
			--VA Providers: A lot of residents and VA providers doing work from a different location are also tagged as being NVA providers in SStaff.  This catches people who have signed on recently and may have indicators
			--  that they are NVA providers but in actuality are probably VA providers.  Most could be found in the GAL when verifying the data.
			when LastSignonDateTime >= cast(cast(getdate() - 30 as date) as datetime2(0))
				and (SStaffNVAPrescriberFlag = 0 or isnull(ChoiceFlag,0) = 0 --or PAIDFlag = 1 --Temporarily removed.
				or CPRSAccess = 1 or (ChoiceFlag = 1 and MostRecentRxIssue < cast(lastsignondatetime as date))) then 0
			--VA Provider: Almost everyone who has logged in recently is a VA provider; and especially if their most recent Rx was issued before/on last sign in day
			when LastSignOnDateTime >= cast(cast(getdate() - 90 as date) as datetime2(0)) and MostRecentRxIssue <= cast(LastSignOnDateTime as date)
				and (isnull(ChoiceFlag,0) = 0 or (ChoiceFlag = 1 and Total < 15)) then 0
			--VA Provider: never issued an Rx after they last signed on in VA
			when cast(DateAdd(d,14,LastSignOnDateTime) as date) >= MostRecentRxIssue then 0
			--VA Provider: SStaff NonVAPrescriberFlag <> Y and access to CPRS exists
			when SStaffNVAPrescriberFlag = 0 and CPRSAccess = 1 then 0
			when LastSignonDateTime >= cast(cast(getdate() - 30 as date) as datetime2(0)) then 0
			-- Non VA Provider: significant % of Choice Rxs = Choice in fill remarks, some Rxs issued after their last sign on, significant % of those also indicated as Choice
			when ChoiceFlag = 1 and TotalAfterLastSignOnCount > 0 and AfterLastSignOnChoicePercent >= 0.5 then 1
			--Non VA Provider: Often times former staff become non VA providers and their data is not really updated.  This tries to capture that - they are issuing Rxs after their last sign on date,
				--the SStaff File flags them as non VA providers, and the Rx issue date is more than a month after their last sign on date.  Also sometimes weird stuff happens w/ notes - so if they never wrote/signed a note
				-- or their last note also coincided w/ the last sign on date then they are included in this.
			when 
				TotalAfterLastSignOnCount > 0
				and SStaffNVAPrescriberFlag = 1
				and (TotalAfterLastSignOnCount > 5 or DateDiff(d,LastSignOnDatetime,MostRecentRxIssue) > 30)
				and (LastNote is null or cast(LastNote as date) <= cast(LastSignOnDateTime as date)) then 1
			when
				NVASStaffIndicator = 1
				and (
					(DateDiff(d,LastSignOnDateTime,MostRecentRxIssue) > 90)
					or
					NVACPRSAccess = 1
					or
					LastSignonDateTime is null
					) then 1
			--VA Provider: Guessing game at this point - NVA PRescriber flag is off in SStaff, no Choice Rxs in fill remarks, flag as VA Provider
			when SStaffNVAPrescriberFlag = 0 and isnull(ChoiceFlag,0) = 0 and MostRecentIssue_EnteredByStaff <= cast(lastsignondatetime as date) then 0
			when CPRSAccess = 1 and MostRecentRxIssue <= cast(DateAdd(d,30,LastNote) as date) then 0
			when SStaffNVAPrescriberFlag = 0 and MostRecentIssue_EnteredbyStaff is not null then 0
			when MostRecentIssue_EnteredbyStaff is not null then 0
			when SStaffNVAPrescriberFlag = 0 then 0
			when SStaffNVAPrescriberFlag = 1 then 1
			ELSE NULL
			END AS NonVAPrescriberFlag_VA
			,UserName
			,Email
			,PositionTask
			---Cerner Flags		
		,case
			when sta3n <> 200 then -1
			when UserName is not null and (Email like '%@va.gov%' or (PositionTask like 'VA %' and PositionTask not like '%View only%')) then 0
			when UserName is null and (EMail is null or Email not like '%@VA.gov%') and PositionTask not like 'VA %' then 1
			when UserName is not null and Email like '%.mil%' then 1
			when Email like 'EXTERNAL%' then 1
			when Email like '%@va.gov%' then 0
			when UserName is null and PositionTask like '%View Only%' then 1
			when PositionTask like 'VA %' and PositionTask not like '%VA View Only%' then 0
			when Email like '%@Cerner%' or PositionTask like '%CERNER%' or ProviderName like '%CERNER Consult%' then 0
			when LastNote is null and MostRecentOrder is null and PositionTask not like 'VA %' then 1
			when PositionTask like '%VA View Only%' then 1
			when Email is null and PositionTask not like 'VA %' and MostRecentRxIssue > MostRecentOrder then 1
			when Email is null and PositionTask not like 'VA %' and LastNote is null and MostRecentOrder is null then 1
			when Email is null and PositionTask not like 'VA %' then 1
				else null end as NonVAPrescriberFlag_Cerner
	INTO #ProviderInfo
	FROM #ProviderList4 AS a
	LEFT JOIN #FinalChoice AS b
		ON a.providersid = b.providersid
	LEFT JOIN #Notes AS n
		ON n.EnteredByStaffSID = a.providersid
	LEFT JOIN #OrderEntry AS oe
		ON oe.EnteredByStaffSID = a.ProviderSID
	LEFT JOIN [SStaffMill].[SPersonStaff] AS sp
		ON sp.personstaffsid = a.providersid
	LEFT JOIN #MostRecentRx as mrrx
		on mrrx.providersid = a.providersid
	WHERE a.ProviderName NOT LIKE 'CERNER%CERNER%' and a.ProviderName not like '%Test,Test%' and a.providername not like '%Test, Test%'
		and a.ProviderName not like '%ZZ,ZZ%' and a.ProviderName not like '%ZZ, ZZ%'
		and a.providersid > 0

		;
	/****
CREATE TABLE ORM.NonVAProviders
	(
	sta3n int
	,ProviderSID int
	,ProviderName varchar(100)
	,PositionTitle varchar(100)
	,ServiceSection varchar(250)
	,ChoicePercent decimal(10,4)
	,ChoiceFlag smallint
	,ChoicePercentFlag smallint
	,SStaffNVAPrescriberFlag smallint
	,NonVAPrescriberFlag_VA smallint
	) ON DefFG WITH (DATA_COMPRESSION = PAGE)
	;
**********************/
EXEC [Maintenance].[PublishTable] 'ORM.NonVAProviders', '#ProviderInfo'

EXEC [Log].[ExecutionEnd] 

END