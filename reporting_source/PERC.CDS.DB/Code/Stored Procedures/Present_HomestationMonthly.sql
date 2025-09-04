

/****** Object:  StoredProcedure [Code].[Present_HomestationMonthly]    Script Date: 9/15/2021 2:17:27 PM ******/

-- =============================================
-- Author:		<David Wright>
-- Create date: 9/1/2017
-- Description: Monthly rolling station for the previous year. Includes actives, 
-- Modifications:	
	-- 2020-09-08 RAS Create VM version and added Cerner Millenium inpatient records logic
	-- 2021-09-15 BTW: Enclave Refactoring - Counts Confirmed.
	-- 2022-03-11 SG: changed RelationshipStartDateTime to RelationshipStartDate from present.Provider
	-- 2022-09-07 RAS: Added Sta3n_EHR and PatientPersonSID (saving patient id related to station assignment
		-- so that we can track historically if patient mappings change and because this is needed in REACH VET)
	-- 2023-09-19 LM: Change to reflect new rules to prioritize location of most recent PCP over MHTC

--TEST:
	-- EXEC [Code].[Present_HomestationMonthly] @ForceUpdate=1

-- DEPENDENCIES:
	-- Common.Providers
-- =============================================

CREATE PROCEDURE [Code].[Present_HomestationMonthly]
	@ForceUpdate bit = 0
AS
BEGIN
	--	DECLARE @ForceUpdate bit = 1
	DECLARE @DescriptionText varchar(100)= 'Execution of Code.Present_HomestationMonthly (@ForceUpdate='+ cast(@ForceUpdate as varchar) +')'
EXEC [Log].[ExecutionBegin] @Name = 'Code.Present_HomestationMonthly',@Description = @DescriptionText

--Define 1 year period 
DECLARE @End_dt  DATE  = DateAdd(M, DateDiff(M, 0, GetDate()), 0)  /*first day of month*/
DECLARE @Begin_dt DATE = DateAdd(M,-12,@End_dt)                /*Year before first day*/     

--Label the Fiscal Year Month
DECLARE @FYM varchar(7) = (
	SELECT 'FY' + right(cast(FiscalYear as varchar(4)),2) + 'M' + cast(FiscalMonth as varchar(2))
	FROM [Dim].[Date] d 
	WHERE Date=@End_dt
	)
	
DECLARE @variables varchar(200) = '@FYM = ' + @FYM + ': ' + cast(@Begin_dt as varchar) + ' - ' + cast(@End_dt as varchar)
PRINT @variables

EXEC [Log].[Message] 'Information','HomestationMonthly variables',@variables

	--------------------------------------------------------------------
	-- RPCMM Data
	--------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.HomestationMonthly RPCCM','Execution of Step 1, RPCCM Data'

	--get most recent PCP or if not, most recent MHTC
	DROP TABLE IF EXISTS #rpccm;
	SELECT MVIPersonSID	
		  ,ChecklistID
		  ,Sta3n_EHR = CASE WHEN CernerSiteFlag = 1 THEN 200 ELSE Sta3n END 
		  ,PatientSID
		  ,FYM=@FYM
	INTO #Rpccm
	FROM ( 
		SELECT MVIPersonSID,PatientICN,PatientSID,ChecklistID,Sta3n,ProviderSID,CernerSiteFlag
			,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY PCP DESC, RelationshipStartDateTime DESC,ChecklistID)
		FROM [Common].[Providers] WITH (NOLOCK)
		WHERE MHTC=1 
			OR PCP=1
		) as A
	WHERE RN=1
	
	DROP TABLE IF EXISTS #MVIPersonSID_RPCMM;
	SELECT MVIPersonSID
	INTO #MVIPersonSID_RPCMM
	FROM #Rpccm

	EXEC [Tool].[CIX_CompressTemp] '#MVIPersonSID_RPCMM', 'MVIPersonSID'
	
	EXEC [Log].[ExecutionEnd]

	--------------------------------------------------------------------
	-- Inpatient Records
	--------------------------------------------------------------------
	
	EXEC [Log].[ExecutionBegin] 'Code.HomestationMonthly Inpat','Execution of Step 2, Inpatient records'

	--Inpatient Data from VistA (CDWWork)
	DROP TABLE IF EXISTS #PTF1;
	SELECT a.MVIPersonSID
		,a.Sta3n
		,a.Sta6a
		,st.ChecklistID
		,a.PatientSID
	INTO #PTF1
	FROM (
		SELECT inp.Sta3n
			,Sta6a = CASE WHEN dl.Sta6a IS NULL OR dl.Sta6a IN ('*Unknown at this time*','*Missing*')
				THEN CONVERT(VARCHAR(6),inp.Sta3n)
				ELSE dl.Sta6a END
			,mvi.MVIPersonSID
			,inp.PatientSID
			,RN = ROW_NUMBER() OVER(PARTITION BY mvi.MVIPersonSID,CONVERT(DATE, DischargeDateTime) ORDER BY ISNULL(DischargeDateTime,'2100-12-31') DESC,AdmitDateTime DESC)
			,inp.DischargeDateTime
		FROM [Inpat].[Inpatient] as inp
		LEFT JOIN [Dim].[WardLocation] AS dw WITH (NOLOCK) ON inp.DischargeWardLocationSID = dw.WardLocationSID
		LEFT JOIN [Dim].[Division] AS dl WITH (NOLOCK) ON dl.DivisionSID = dw.DivisionSID
		LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON inp.PatientSID = mvi.PatientPersonSID
		WHERE inp.InpatientSID > 0  
			AND ((inp.DischargeDateTime >= @Begin_dt 
			and inp.DischargeDateTime < @End_dt
			) /*Non-Census*/
				or ((inp.DischargeDateTime >= @End_dt 
				or inp.DischargeDateTime IS NULL) 
				AND (Admitdatetime <@End_dt)
				)) /*Census*/
			AND MVIPersonSID > 0
		) a
	LEFT JOIN [LookUp].[Sta6a] st WITH (NOLOCK) on st.Sta6a=a.Sta6a
	WHERE RN = 1

	--SELECT * FROM #PTF1 WHERE ChecklistID IS NULL

	DROP TABLE IF EXISTS #PTF;
	SELECT p1.MVIPersonSID
		,p1.Sta6a
		,p1.ChecklistID
		,p1.PatientSID
		,p1.Sta3n
	INTO #PTF 
	FROM #PTF1 p1
	LEFT JOIN #MVIPersonSID_RPCMM as m on m.MVIPersonSID=p1.MVIPersonSID
	WHERE m.MVIPersonSID is NULL --only patients without MHTC/PCP assignment

	--Add Cerner Millenium (CDWWork2) Inpatient Data
	DROP TABLE IF EXISTS #PTF2
	SELECT inp.MVIPersonSID
		,inp.PersonSID
		,inp.STA6A
		,inp.STAPA
		,Sta3n_EHR = 200
	INTO #PTF2
	FROM [Cerner].[FactInpatient] inp WITH(NOLOCK) 
	LEFT JOIN #MVIPersonSID_RPCMM p ON p.MVIPersonSID=inp.MVIPersonSID 
	WHERE ISNULL(TZDischargeDateTime,'2100-12-31 00:00:00') >= @Begin_dt
		AND TZDerivedAdmitDateTime < @End_dt
		AND p.MVIPersonSID IS NULL --only patients without MHTC/PCP assignment
		--AND STAPA IS NOT NULL --Why are there NULL STAPAs?

	--SELECT * FROM #PTF2 WHERE STAPA IS NULL
	--SELECT * FROM #PTF2 WHERE STA6A IS NULL
	
	EXEC [Log].[ExecutionEnd]

	--------------------------------------------------------------------
	-- OUTPATIENT
	--------------------------------------------------------------------

	EXEC [Log].[ExecutionBegin] 'Code.HomestationMonthly Outpatient','Execution of HomestationMonthly Step 3, Outpatient records'
	
	/***** VistA Outpatient Data *****/
	
	DROP TABLE IF EXISTS #workload1;
	SELECT SecondaryStopCodeSID
		  ,AppointmentStatusSID
		  ,VisitDateTime
		  ,DivisionSID
		  ,VisitSID
		  ,Sta3n
		  ,MVIPersonSID
		  ,PatientSID
	INTO #workload1
	FROM [Outpat].[Visit] as wk WITH (NOLOCK)
	LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON wk.PatientSID = mvi.PatientPersonSID
	WHERE wk.VisitDateTime >= @Begin_dt 
		AND wk.VisitDateTime < @END_DT
		AND WorkloadLogicFlag='Y'
	
	DROP TABLE IF EXISTS #workload;
	SELECT SecondaryStopCodeSID
		  ,AppointmentStatusSID
		  ,VisitDateTime
		  ,DivisionSID
		  ,VisitSID
		  ,Sta3n
		  ,wk.MVIPersonSID
		  ,wk.PatientSID
	INTO #workload
	FROM #workload1 as wk
	LEFT JOIN #MVIPersonSID_RPCMM as b ON b.MVIPersonSID=wk.MVIPersonSID 
	WHERE b.MVIPersonSID is null
	
	DROP TABLE IF EXISTS #workloadf;
	SELECT ov.MVIPersonSID
		,ov.PatientSID
		,ov.Sta3n
		,da.AppointmentStatus
		,InpEnc = CASE WHEN da.AppointmentStatus = 'INPATIENT APPOINTMENT' THEN 1 
					ELSE 0 END
		,HomeFlag = CASE 
                    WHEN clc.Stopcode in (696,708,692,693,695,445,447,491,645, 647,137) THEN 1 --telehealth provider site
                    WHEN clc.stopcode in (698,648,179) THEN 2 
					ELSE 0 END
		,Sta6a=	CASE
					WHEN dd.Sta6a='673BY'  THEN '675'
					WHEN dd.Sta6a='673BU'  THEN '675BU'
					WHEN dd.Sta6a='6739AB' THEN '6759AB'
					WHEN dd.Sta6a='673GA'  THEN '675GA'
					WHEN dd.Sta6a='673GE'  THEN '675GC'
					WHEN dd.Sta6a='673GD'  THEN '675GD'
					WHEN dd.Sta6a='573GH'  THEN '675GE'
					WHEN dd.Sta6a='573BZ'  THEN '675GB'
					WHEN dd.Sta6a='671GA'  THEN '740GA'
					WHEN dd.Sta6a='671BO'  THEN '740GB'
					WHEN dd.Sta6a='671BZ'  THEN '740GC'
					WHEN dd.Sta6a='671GE'  THEN '740GD'
					WHEN dd.Sta6a='671GD'  THEN '740GE'
					WHEN dd.Sta6a='671GI'  THEN '740GF'
					WHEN dd.Sta6a='671GG'  THEN '740GG'
					WHEN dd.Sta6a='671DU'  THEN '740GT'
					WHEN dd.Sta6a='518GG'  THEN '631GF'
					WHEN dd.Sta6a='523GB'  THEN '631GE'
					WHEN dd.Sta6a like '[*]%' and ov.sta3n is not null THEN convert(varchar(50), ov.sta3n)  
					WHEN dd.Sta6a is null and ov.sta3n is not null THEN convert(varchar(50), ov.sta3n) 
				ELSE dd.sta6a END
				,StopCodeName
	INTO #workloadf
	FROM #Workload as ov
	LEFT JOIN [Dim].[Division] as dd WITH (NOLOCK) ON dd.DivisionSID = ov.Divisionsid
	LEFT JOIN [Dim].[AppointmentStatus] as da WITH (NOLOCK) ON da.AppointmentStatusSID=ov.AppointmentStatusSID
    LEFT JOIN [Dim].[StopCode] as clc WITH (NOLOCK) on clc.StopCodeSID=ov.SecondaryStopCodeSID
	WHERE --VeteranFlag='Y' AND 
		AppointmentStatus = 'CHECKED OUT' 
		OR AppointmentStatus = 'INPATIENT APPOINTMENT'

	DROP TABLE IF EXISTS #wk;
    SELECT wk.Sta6a
		,wk.Sta3n
    	,wk.MVIPersonSID
		,wk.PatientSID
    	,wk.HomeFlag
    	,wk.InpEnc 
	INTO #wk
    FROM #workloadf  as wk 
    LEFT JOIN #MVIPersonSID_RPCMM as p on p.MVIPersonSID=wk.MVIPersonSID 
	WHERE wk.HomeFlag IN (0, 2) --exclude inpatient encounters
		AND p.MVIPersonSID is null --only patients without MHTC/PCP assignment

	/***** Add Cerner Millenium Outpatient Data *****/
	DROP TABLE IF EXISTS #OutpatMill
	SELECT uxo.MVIPersonSID
		,uxo.PersonSID
		,uxo.STA6A
		,Sta3n_EHR = 200
		,HomeFlag=0 --Is there telehealth logic that needs to be added here?
		,InpEnc=0
	INTO #OutpatMill
	FROM [Cerner].[FactUtilizationOutpatient] uxo WITH (NOLOCK)
	LEFT JOIN #MVIPersonSID_RPCMM p ON p.MVIPersonSID=uxo.MVIPersonSID 
	WHERE TZDerivedVisitDateTime >= @Begin_dt 
		AND TZDerivedVisitDateTime < @END_DT
		AND p.MVIPersonSID IS NULL --only patients without MHTC/PCP assignment
	--AppointmentStatus checked out?
	-- CMH question: what is significance of 0,1,2 for HomeFlag?

	EXEC [Log].[ExecutionEnd]

	--------------------------------------------------------------------
	-- COMBINE INPATIENT AND OUTPATIENT RECORDS
	--------------------------------------------------------------------
	EXEC [Log].[ExecutionBegin] 'Code.HomestationMonthly Combine IP/OP','Execution of HomestationMonthly Step 4, Combine inpatient and outpatient records'

	DROP TABLE IF EXISTS #tmp_allpats;
	SELECT Sta6a
		  ,Sta3n
		  ,MVIPersonSID
		  ,PatientSID
		  ,HomeFlag = 0
		  ,InpEnc = 1
	INTO #tmp_allpats
	FROM #PTF --VistA Inpatient
	UNION ALL
	SELECT Sta6a
		  ,Sta3n_EHR
		  ,MVIPersonSID
		  ,PersonSID
		  ,HomeFlag = 0
		  ,InpEnc = 1
	FROM #PTF2 --Millennium Inpatient
	UNION ALL
	SELECT Sta6a
		  ,Sta3n
		  ,MVIPersonSID
		  ,PatientSID
		  ,HomeFlag
		  ,InpEnc
	FROM #wk --VistA Outpatient
	UNION ALL
	SELECT Sta6a
		  ,Sta3n_EHR
		  ,MVIPersonSID
		  ,PersonSID
		  ,HomeFlag
		  ,InpEnc
	FROM #OutpatMill --Millennium Outpatient

	PRINT 'Done with tmp_allpats'
	EXEC [Log].[ExecutionEnd]

	--------------------------------------------------------------------
	--Declare @msg_w3 varchar(max) = ( select 'Starting first row number ' + FORMAT (getdate(), 'MM/dd/yyyy hh:mm tt'))
	--RAISERROR ( @Msg_w3, 0, 1) WITH NOWAIT 	

	EXEC [Log].[ExecutionBegin] 'Code.HomestationMonthly Stations','Execution of HomestationMonthly Step 5, Assigning stations'

	--DECLARE @FYM varchar(6) ='FY17M1'
	/*Get Checklist_ID (CBO Facilities List aka Integrated Station aka Parent Station), Nepec3n      */
	/*Ignore HomeFlag =2 or Inpatient Encounter unless they are the only ones*/
	DROP TABLE IF EXISTS #tmp_allpats2;
	SELECT e.MVIPersonSID
		,e.PatientSID
		,e.Sta3n
   		,FYM = @FYM
		,ck.ChecklistID
		,TotalNepecs=CASE WHEN e.HomeFlag = 2 OR e.InpEnc = 1 THEN 0 --What if they have both of these, which one should be prioritized?
			  ELSE ROW_NUMBER() OVER(PARTITION BY e.MVIPersonSID,ck.ChecklistID ORDER BY e.MVIPersonSID,ck.ChecklistID,e.HomeFlag,e.InpEnc)
			  END
	INTO  #tmp_allpats2
	FROM #tmp_allpats AS e
	INNER JOIN [Lookup].[Sta6a] as ck WITH (NOLOCK) ON ck.Sta6a=e.Sta6a

	--DROP TABLE #tmp_allpats 

	PRINT 'Done with tmp_allpats2'

	--Declare @msg_w4 varchar(max) = ( select 'Starting reveser  row number ' + FORMAT (getdate(), 'MM/dd/yyyy hh:mm tt'))
	--RAISERROR ( @Msg_w4, 0, 1) WITH NOWAIT 	

	/* reverse numbering and pick the larger value. Get Home Visn from dim.sta3n*/
	DROP TABLE IF EXISTS #tmp_allpats3;
	SELECT MVIPersonSID,ChecklistID,FYM,PatientSID,Sta3n
	INTO #tmp_allpats3
	FROM (
		SELECT MVIPersonSID
			  ,ChecklistID,FYM,PatientSID,Sta3n
			  ,RowReverse=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY TotalNepecs DESC, ChecklistID) 
		FROM #tmp_allpats2 ) AS A
	WHERE RowReverse=1

	--Combine MHTC/PCP with most Frequent station

	--Declare @msg_w5 varchar(max) = ( select 'writing homestationmonthly file ' + FORMAT (getdate(), 'MM/dd/yyyy hh:mm tt'))
	--RAISERROR ( @Msg_w5, 0, 1) WITH NOWAIT 	

	DROP TABLE IF EXISTS #StageHomeStation
	SELECT A.MVIPersonSID
		  ,m.PatientICN
		  ,A.ChecklistID
		  ,A.FYM
		  ,A.MonthBeginDate	
		  ,PatientPersonSID = A.PatientSID 
		  ,Sta3n_EHR = A.Sta3n
	INTO #StageHomeStation
	FROM (
		SELECT MVIPersonSID,ChecklistID,FYM
			,PatientSID,Sta3n
			,@End_dt as MonthBeginDate
		FROM #tmp_allpats3
		UNION ALL
		SELECT MVIPersonSID,ChecklistID,FYM
			,PatientSID,Sta3n_EHR
			,@End_dt
		FROM #RPCCM
		) A
	INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK) on m.MVIPersonSID=A.MVIPersonSID --Brings in PatientICN, also excludes most test patients

--Check if the data already exists		
	--DECLARE @ForceUpdate BIT=1
IF (
	SELECT count(*)
	FROM [Present].[HomestationMonthly]
	WHERE MonthBeginDate=@End_dt 
	)>0
	AND @ForceUpdate=0
	BEGIN 
		DECLARE @MsgTxt varchar = 'HomestationMonthly already has data for ' + @FYM
		EXEC [Log].[Message] 'Warning','Avoid Duplication',@MsgTxt
		PRINT 'Already completed for the month'
		EXEC [Log].[ExecutionEnd] 
		RETURN
	END
--ELSE PRINT 'This will run'
ELSE 	

		DECLARE @NewTotal varchar(25) = (SELECT count(*) FROM #StageHomeStation)
		DECLARE @OldTOtal varchar(25) = (SELECT count(*) FROM [Present].[HomeStationMonthly])
	 EXEC [Log].[Message] 'Information','#StageHomeStation New Row Count',@NewTotal 
	 EXEC [Log].[Message] 'Information','HomeStationMonthly Old Row Count',@OldTotal 

	PRINT 'Done with staging, beginning insert...'
	EXEC [Log].[ExecutionEnd]
		
	EXEC [Maintenance].[PublishTable] 'Present.HomeStationMonthly','#StageHomeStation'
  
PRINT 'Table update completed' 

	------------------------------------------------------------------------------------
	--ADD TO QUARTERYLY TABLE AT THE START OF EACH QUARTER (Months 10,1,4,7)
	EXEC [Log].[ExecutionBegin] 'Code.HomeStationMonthly Quarterly','Execution of HomestationMonthly step to add data to quarterly table'

	DECLARE @StartQ int
	SET @StartQ=(Select max(SUBSTRING(FYM,6,2)) from [Present].[HomeStationMonthly])

	IF @StartQ in (1,4,7,10) --If it is the beginning of a quarter, then insert new data and delete old data
	BEGIN
		--Delete data for same quarter (FY doesn't matter because only keep 2 quarters)
		DELETE [Present].[HomeStationQuarterly]
		WHERE SUBSTRING(FYM,6,2)=@StartQ

		;
		--Add new data
		INSERT INTO [Present].[HomeStationQuarterly] (MVIPersonSID,ChecklistID,Sta3n_EHR,PatientPersonSID,FYM,FYQ,UpdateDate)
		SELECT MVIPersonSID,ChecklistID,Sta3n_EHR,PatientPersonSID
			  ,FYM,FYQ=Left(FYM,4)+'Q'+CASE WHEN @StartQ=1 THEN '1' WHEN @StartQ=4 THEN '2'
				 WHEN @StartQ=7 THEN '3' WHEN @StartQ=10 THEN '4' END
			  ,UpdateDate=getdate() 
		FROM [Present].[HomestationMonthly]
		
		--Delete data older than 2 quarters
		DELETE [Present].[HomestationQuarterly]
		WHERE FYQ NOT IN (SELECT DISTINCT Top 2 FYQ FROM [Present].[HomestationQuarterly] ORDER BY FYQ DESC)

		--Log info
		PRINT 'HomestationQuarterly updated'
			DECLARE @msg varchar(200)= 'New data added to homestation quarterly (' + (SELECT Top 1 FYM +', '+FYQ FROM [Present].[HomeStationQuarterly] ORDER BY FYM DESC,FYQ DESC) +')'
			DECLARE @RowCount INT=(SELECT count(*) FROM [Present].[HomestationMonthly])
		EXEC [Log].[Message] 'Information','HomestationMonthly Quarterly Update', @msg
		EXEC [Log].[PublishTable] 'Present','HomeStationQuarterly','Present.HomestationMonthly','Append',@RowCount
	END
	ELSE --If it is NOT the beginning of a quarter, log message and do NOT insert or delete data
	BEGIN
		DECLARE @msg2 varchar(200) = 'No new data for HomestationQuarterly. Most recent = ' + 
			(SELECT Top 1 FYQ FROM [Present].[HomeStationQuarterly] ORDER BY FYQ DESC) + 
			' updated ' + (SELECT cast(max(UpdateDate) as varchar(25)) FROM [Present].[HomeStationQuarterly]) 
		EXEC [Log].[Message] 'Information','HomestationMonthly Quarterly Update','No new data for HomestationQuarterly'
	END

	EXEC [Log].[ExecutionEnd]

EXEC [Log].[ExecutionEnd]

END