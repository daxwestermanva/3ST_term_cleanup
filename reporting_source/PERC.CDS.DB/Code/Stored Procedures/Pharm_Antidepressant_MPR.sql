
/* =============================================
	Author:		<Susana Martins>
	Create date: <05/01/2015>
	Description:	<Creates table for patient report for measure mdd43h and mdd47h>
	Updates:
	20180607 JEB: Removed hard coded database references
	20180813 RAS: Changed to truncate and removed _bk process.
	20181102 RAS: Updated getdate() to cast(getdate() as date) to remove time specificity. Formatting.
	20200415 RAS: Formatting and added logging. Updated inpatient diagnosis to correctly get admit date.
	20200415 RAS: Updated join to get provider type to use view Present.ProviderType
				  instead of Present.Provider_PCP_ICN and Present.MHActiveStaff.
				  Added ChecklistID to come from last prescribing facility instead of just joining to StationAssignments 
				  (which could result in multiple ChecklistIDs for 1 Sta3n)
	20200812 RAS: Switched join for appointments to use vertical tables.
	20201006 RAS: Added MVIPersonSID at #LastFill from RxOutpat 
	20210518 JEB: Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
	20210909 JEB: Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
				  Also, added two temp table crions to help with joining. Comments are added below to note where those changes are made.
				  Added missing close logging statement
	20220331 AER: Pointing to MPR from OIT_Rockies
	20220708 JEB: Updated Synonym references to point to Synonyms from Core

	Testing execution:
		EXEC [Code].[Pharm_Antidepressant_MPR]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'EXEC Code.Pharm_Antidepressant_MPR'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'Pharm_Antidepressant_MPR_PatientReport' ORDER BY 1 DESC

================================================ */
CREATE PROCEDURE [Code].[Pharm_Antidepressant_MPR]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Pharm_Antidepressant_MPR','Execution of SP Code.Pharm_Antidepressant_MPR'

	/** Preprocess initial PatientSID cohort **/
	--2021/09/09 JBacani created this cohort to help with filtering logic
	DROP TABLE IF EXISTS #InitialPatientSIDCohort;
	SELECT DISTINCT mvi.PatientPersonSID as PatientSID,sp.MVIPersonSID
	INTO #InitialPatientSIDCohort
	FROM [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	INNER JOIN [Present].[SPatient] sp WITH (NOLOCK)
		ON sp.MVIPersonSID = mvi.MVIPersonSID



	/**** Dx depression +/- 60 days of release date of AD ******************/
	/*******STEP 1: Create table with all diagnoses dates**/
	DROP TABLE IF EXISTS #AD_RxReleaseDate;
	SELECT DISTINCT 
		 mpr.PatientSID
		,mpr.ReleaseDateTime AS AD_RxReleaseDate
		,mpr.DaysSupply
		,mpr.DrugNameWithoutDose
		,DrugNameWithoutDoseSID
		,mpr.RxStatus
		,mpr.RxOutpatSID 
		,max(mpr.ReleaseDateTime) over (partition by patientsid,mpr.DrugNameWithoutDose ) as MostRecentADRelease
		--,DaysSinceLastFill
	INTO #AD_RxReleaseDate
	FROM [LookUp].[NationalDrug] nd WITH (NOLOCK)
	INNER JOIN 
		(
			SELECT adh.PatientSID, adh.NationalDrugSID, adh.ReleaseDateTime
				  , adh.DaysSupply, adh.DrugNameWithoutDose
				  ,adh.RxStatus, adh.RxOutpatSID
			FROM [RxOut].[RxOutpatFill] adh WITH (NOLOCK)
			--2021/09/09 JBacani Using cohort here
			INNER JOIN #InitialPatientSIDCohort coh
				ON coh.PatientSID = adh.PatientSID
			WHERE adh.sta3n > 0 and adh.ReleaseDateTime >= CAST(DATEADD(DAY, -(231+105), CAST(GETDATE() AS DATE)) AS DATETIME2(0))
		) mpr 
		ON nd.NationalDrugSID = mpr.NationalDrugSID 
	WHERE nd.Antidepressant_Rx = 1
		

	--2021/09/09 JBacani Created this TEMP table to have more efficient joins later in code
	DROP TABLE IF EXISTS #AD_RxReleaseDate_PatientSID;
	SELECT DISTINCT PatientSID 
	INTO #AD_RxReleaseDate_PatientSID
	FROM #AD_RxReleaseDate
	CREATE CLUSTERED INDEX idx_AD_RxReleaseDate_PatientSID ON #AD_RxReleaseDate_PatientSID(PatientSID);

	DROP TABLE IF EXISTS #icd9
	SELECT ICD9SID 
	INTO #icd9
	FROM [LookUp].[ICD9] WITH (NOLOCK)
	WHERE Depress = 1

	CREATE CLUSTERED INDEX CIX_icd9 ON #icd9(ICD9SID)

	DROP TABLE IF EXISTS #icd10
	SELECT ICD10SID 
	INTO #icd10
	FROM [LookUp].[ICD10] WITH (NOLOCK)
	WHERE Depress = 1

	CREATE CLUSTERED INDEX CIX_icd10 ON #icd10(ICD10SID)
	
	/*ICD9 Outpatient*/
	--2021/09/09 JBACANI changed UNION to UNION since dupes are going to be removed via DISTINCT
	DROP TABLE IF EXISTS #Dep_DiagnosisDate;
	SELECT DISTINCT 
		 dxdate.PatientSID
		,dxdate.Dep_DiagnosisDate 
	INTO #Dep_DiagnosisDate 
	FROM 
		(
			SELECT op.PatientSID
				  ,op.VisitDateTime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Outpat].[VDiagnosis] op WITH (NOLOCK)
				ON rx.PatientSID = op.PatientSID 
				AND op.VisitDateTime >= CAST(DATEADD(DAY, -430, CAST(GETDATE() AS DATE)) AS DATETIME2(0))  --370 + 60 for those who received meds at exactly the 370 day mark
			INNER JOIN #icd9 d 
				ON op.ICD9SID=d.ICD9SID

			UNION

			/*ICD10 Outpatient*/
			SELECT op.PatientSID
				  ,op.VisitDateTime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Outpat].[VDiagnosis] op WITH (NOLOCK)
				ON rx.PatientSID = op.PatientSID 
				AND op.VisitDateTime >= CAST(DATEADD(DAY, -430, CAST(GETDATE() AS DATE)) AS DATETIME2(0))
			INNER JOIN #icd10 d 
				ON op.ICD10SID=d.ICD10SID

			UNION

			/*ICD9 Inpatient*/ --Ask Ilse
			SELECT id.PatientSID
				  ,ii.AdmitDateTime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Inpat].[InpatientDiagnosis] id WITH (NOLOCK)
				ON rx.PatientSID = id.PatientSID 
				AND 
					(
						(id.DischargeDateTime BETWEEN CAST(DATEADD(DAY, -430, CAST(GETDATE() AS DATE)) AS DATETIME2(0)) AND CAST(GETDATE() AS DATE)) 
						OR id.DischargeDateTime IS NULL
					)
			INNER JOIN #icd9 d 
				ON d.ICD9SID = id.ICD9SID
			INNER JOIN [Inpat].[Inpatient] ii WITH (NOLOCK)
				ON ii.InpatientSID = id.InpatientSID --RAS changed from PatientSID to InpatientSID to get correct admit date for the diagnosis

			UNION

			/*ICD10 Inpatient*/ --Ask Ilse
			SELECT id.PatientSID
				  ,ii.AdmitDateTime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Inpat].[InpatientDiagnosis] id WITH (NOLOCK)
				ON rx.PatientSID = id.PatientSID 
				AND 
					(
						(id.DischargeDateTime BETWEEN CAST(DATEADD(DAY, -430, cast(GETDATE() AS DATE)) AS DATETIME2(0)) AND CAST(GETDATE() AS DATE)) 
						OR id.DischargeDateTime IS NULL
					)
			INNER JOIN #icd10 d 
				ON d.ICD10SID = id.ICD10SID
			INNER JOIN [Inpat].[Inpatient] ii WITH (NOLOCK)
				ON ii.InpatientSID = id.InpatientSID --RAS changed from PatientSID to InpatientSID to get correct admit date for the diagnosis

			UNION

			/*ICD9 Problem List*/
			SELECT pl.PatientSID
				  ,pl.LastModifiedDatetime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Outpat].[ProblemList] pl WITH (NOLOCK)
				ON pl.PatientSID = rx.PatientSID
			INNER JOIN #icd9 d 
				ON d.ICD9SID = pl.ICD9SID
			WHERE pl.ActiveFlag = 'A' 
				AND pl.ProblemListCondition NOT LIKE '%H%'

			UNION

			/*ICD10 Problem List*/
			SELECT pl.PatientSID
				  ,pl.LastModifiedDatetime AS Dep_DiagnosisDate
			FROM #AD_RxReleaseDate_PatientSID rx
			INNER JOIN [Outpat].[ProblemList] pl WITH (NOLOCK)
				ON pl.PatientSID = rx.PatientSID
			INNER JOIN #icd10 d 
				ON d.ICD10SID = pl.ICD10SID
			WHERE pl.ActiveFlag = 'A' 
				AND pl.ProblemListCondition NOT LIKE '%H%' 
		) dxdate
	CREATE NONCLUSTERED INDEX II_Dep_DiagnosisDate ON #Dep_DiagnosisDate (PatientSID);

	/*************STEP 2: Create Table with antidepressant release dates for each patient *********/
	--replaced with active meds query 

	/****STEP 3: Create Final Key for  Depression diagnosis 60 days before or after antideppressant release date**********/ 
	DROP TABLE IF EXISTS #Dep_Dx_PlusMinus60day;
	SELECT DISTINCT 
		 dd.PatientSID
		,rx.AD_RxReleaseDate
		,1 AS Dep_Dx_PlusMinus60day 
	INTO #Dep_Dx_PlusMinus60day
	FROM #Dep_DiagnosisDate AS dd
	INNER JOIN #AD_RxReleaseDate rx 
		ON rx.PatientSID=dd.PatientSID
	WHERE (dd.Dep_DiagnosisDate >= DATEADD(DAY, -61, rx.AD_RxReleaseDate)) 
	  AND (dd.Dep_DiagnosisDate <= DATEADD(DAY,  61, rx.AD_RxReleaseDate))
	CREATE NONCLUSTERED INDEX II_Dep_Dx_PlusMinus60day ON #Dep_Dx_PlusMinus60day (PatientSID);

	DROP TABLE IF EXISTS #Index;
	SELECT 
		 ix.PatientSID
		,ix.AD_RxReleaseDate
		,ix.Dep_Dx_PlusMinus60day
		,ix.LastFillBeforeIndex
		,ix.DaysBetweenFills 
	INTO #Index
	FROM 
		(
			SELECT DISTINCT 
				subquery.PatientSID
				,subquery.AD_RxReleaseDate
				,subquery.Dep_Dx_PlusMinus60day
				,subquery.LastFillBeforeIndex
				,ISNULL(DATEDIFF(D,LastFillBeforeIndex,AD_RxReleaseDate),1000) AS DaysBetweenFills
			FROM 
				(
					SELECT 
						 d60.PatientSID
						,d60.Dep_Dx_PlusMinus60day
						,d60.AD_RxReleaseDate
						,Max(rx.AD_RxReleaseDate) OVER(PARTITION BY d60.PatientSID,d60.AD_RxReleaseDate) AS LastFillBeforeIndex
					FROM #Dep_Dx_PlusMinus60day d60
					LEFT OUTER JOIN #AD_RxReleaseDate rx 
						ON d60.PatientSID = rx.PatientSID 
						AND rx.AD_RxReleaseDate < d60.AD_RxReleaseDate
				) subquery 
		) ix
	WHERE ix.DaysBetweenFills > 105

	DROP TABLE IF EXISTS #MeasureType;  
	SELECT 
		 a.PatientSID
		,a.IndexDate
		,CASE 
			WHEN a.IndexDate >= CAST(DATEADD(DAY, -115, cast(GETDATE() AS date)) AS DATETIME2(0)) THEN 'MDD43h'
			WHEN a.IndexDate < CAST(DATEADD(DAY, -115, cast(GETDATE() AS date)) AS DATETIME2(0))	
			 AND a.IndexDate >= CAST(DATEADD(DAY, -231, cast(GETDATE() AS date)) AS DATETIME2(0)) THEN 'MDD47h'
		END AS MeasureType
		,b.LastFillBeforeIndex
  INTO #MeasureType
	FROM 
		(
			SELECT PatientSID, MIN(AD_RxReleaseDate) AS IndexDate
			FROM #Index 
			GROUP BY PatientSID
		) a 
	INNER JOIN #Index b 
		ON a.PatientSID = b.PatientSID 
		AND IndexDate = b.AD_RxReleaseDate
 

	DROP TABLE IF EXISTS #Fills;
	SELECT 
		 fills.PatientSID
		,fills.LastFillBeforeIndex
		,fills.IndexDate
		,fills.LastRelease
		,fills.MeasureType
		,fills.AD_RxReleaseDate
		,fills.NextRelease
		,DATEDIFF(d, fills.AD_RxReleaseDate, fills.NextRelease) AS DaysBetweenFills 
		,fills.DaysSupply
		,fills.DrugNamewithoutdose 
		,DATEDIFF(d, fills.IndexDate, CAST(GETDATE() AS DATE)) AS TotalDayElapsed
		,fills.LastDaysSupply
	INTO #Fills
	FROM 
		( 
			SELECT 
				 a.PatientSID
				,a.LastFillBeforeIndex
				,a.IndexDate
				,a.MeasureType
				,a.AD_RxReleaseDate
				,ISNULL(a.NextRelease,CAST(GETDATE() AS DATE)) AS NextRelease 
				,a.DaysSupply
				,a.DrugNamewithoutdose 
				,a.LastRelease
				,a.LastDaysSupply
			FROM 
				(
					SELECT 
						 m.PatientSID 
						,m.LastFillBeforeIndex
						,m.IndexDate
						,m.MeasureType
						,b.AD_RxReleaseDate
						,LEAD(b.AD_RxReleaseDate,1) OVER (PARTITION BY m.PatientSID ORDER BY b.AD_RxReleaseDate) AS NextRelease
						,b.DaysSupply
						,b.DrugNameWithoutDose
						,MAX(b.AD_RxReleaseDate) OVER (PARTITION BY m.PatientSID) AS LastRelease
						,FIRST_VALUE(b.DaysSupply) OVER (PARTITION BY m.PatientSID ORDER BY b.AD_RxReleaseDate DESC) AS LastDaysSupply
					FROM #MeasureType m 
					INNER JOIN #AD_RxReleaseDate b 
						ON m.PatientSID = b.PatientSID 
						AND m.IndexDate <= AD_RxReleaseDate
				) a 
		) fills

	DROP TABLE IF EXISTS #Calc;
	SELECT 
		 PatientSID
		,LastFillBeforeIndex
		,IndexDate
		,LastRelease
		,DATEDIFF(d,LastRelease,CAST(GETDATE() AS DATE)) AS DaysSinceLastFill
		,MeasureType
		,(SUM(DaysSupply) )-TotalDayElapsed AS NonPossessionDays
		,TotalDayElapsed
		,SUM(DaysSupply) AS TotalDaysSupply
		,LastDaysSupply
	INTO #Calc
	FROM #Fills
	WHERE AD_RxReleaseDate > = IndexDate
	GROUP BY 
		 PatientSID
		,LastFillBeforeIndex
		,IndexDate
		,LastRelease
		,MeasureType
		,TotalDayElapsed
		,LastDaysSupply
	;

	DROP TABLE IF EXISTS #LastFill;
	SELECT 
		 a.PatientSID
		,a.AD_RxReleaseDate
		,DrugNameWithoutDoseSID
		,a.DrugNameWithoutDose
		,a.DaysSupply
		,a.RxOutpatSID
		,a.RxStatus
		,mvi.MVIPersonSID
		,c.StaffName AS Prescriber
		,c.StaffSID
		,CASE WHEN Schedule like '%PRN%' THEN 'PRN' END RxType
		,ISNULL(f.ChecklistID,CAST(b.Sta3n AS varchar)) ChecklistID
	INTO #LastFill
	FROM 
		(
			SELECT * 
			FROM #AD_RxReleaseDate 
			WHERE AD_RxReleaseDate = MostRecentADRelease
		) a 
	INNER JOIN [RxOut].[RxOutpat] b WITH (NOLOCK)
		ON a.RxOutpatSID = b.RxOutpatSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON b.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [SStaff].[SStaff] c WITH (NOLOCK)
		ON b.ProviderSID = c.StaffSID
	INNER JOIN [RxOut].[RxOutpatMedInstructions] d WITH (NOLOCK)
		ON a.RxOutpatSID = d.RxOutpatSID	
	LEFT JOIN [LookUp].[Sta6a] f WITH (NOLOCK)
		ON f.Sta6a=b.Sta6a
   
   
   
	DROP TABLE IF EXISTS #appointments
	SELECT 
		 lf.PatientSID
		,pcf.AppointmentDateTime AS PCFutureAppointmentDateTime
		,pcf.PrimaryStopCodeName AS PCFutureStopCodeName
		,mhf.AppointmentDateTime AS MHFutureAppointmentDateTime
		,mhf.PrimaryStopCodeName AS MHFutureStopCodeName
		,mhr.VisitDateTime AS MHRecentVisitDate
		,mhr.PrimaryStopCodeName AS MHRecentStopCodeName
		,pcr.VisitDateTime AS PCRecentVisitDate 
		,pcr.PrimaryStopCodeName AS PCRecentStopCodeName
	INTO #appointments
	FROM #LastFill lf 
	LEFT JOIN 
		(
			SELECT PatientSID,AppointmentDateTime,PrimaryStopCodeName
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_SID = 1 AND ApptCategory = 'PCFuture'
		) pcf 
		ON lf.PatientSID = pcf.PatientSID
	LEFT JOIN 
		(
			SELECT PatientSID,AppointmentDateTime,PrimaryStopCodeName, ROW_NUMBER() OVER (PARTITION BY PatientSID ORDER BY AppointmentDateTime) AS RN1
			FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
			WHERE NextAppt_SID = 1 AND ApptCategory IN ('MHFuture','HomelessFuture')
		) mhf 
		ON lf.PatientSID = mhf.PatientSID AND (RN1=1 OR RN1 IS NULL)
	LEFT JOIN 
		(
			SELECT PatientSID,VisitDateTime,PrimaryStopCodeName, ROW_NUMBER() OVER (PARTITION BY PatientSID ORDER BY VisitDateTime DESC) AS RN2
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_SID = 1 AND ApptCategory IN ('MHRecent','HomelessRecent')
		) mhr 
		ON lf.PatientSID = mhr.PatientSID AND (RN2=1 OR RN2 IS NULL)
	LEFT JOIN 
		(
			SELECT PatientSID,VisitDateTime,PrimaryStopCodeName
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_SID = 1 AND ApptCategory = 'PCRecent'
		) pcr ON lf.PatientSID=pcr.PatientSID
	WHERE pcf.PatientSID IS NOT NULL
		OR mhf.PatientSID IS NOT NULL
		OR pcr.PatientSID IS NOT NULL
		OR mhr.PatientSID IS NOT NULL

	/**** Dx depression +/- 60 days of release date of AD ******************/
	/*******STEP 1: Create table with all diagnoses dates**/
	DROP TABLE IF EXISTS #alltogether;
	SELECT DISTINCT
		 --Patient Info
		a.PatientSID	
		,lf.MVIPersonSID
		--Measure Info
		,MeasureType
		,LastFillBeforeIndex
		,IndexDate
		,DATEDIFF(d,IndexDate,CAST(GETDATE() AS DATE)) AS DaysSinceIndex
		,CASE 
			WHEN MeasureType = 'MDD43h' THEN DATEADD(DAY, 115, IndexDate) 
			WHEN MeasureType = 'MDD47h' THEN DATEADD(DAY, 231, IndexDate)
		END AS MeasureEndDate
		,TotalDaysSupply
		,CASE 
			WHEN MeasureType = 'MDD43h' and TotalDaysSupply >= 84   then 1
			WHEN MeasureType = 'MDD47h' and TotalDaysSupply >= 180  then 1                                              
			WHEN MeasureType = 'MDD43h' and TotalDaysSupply <  84  and DATEADD(DAY, 114, IndexDate) <= cast(GETDATE() AS date) then 0
			WHEN MeasureType = 'MDD47h' and TotalDaysSupply <  180 and DATEADD(DAY, 231, IndexDate) <=cast(GETDATE() AS date)  then 0
			WHEN MeasureType = 'MDD43h' and (datediff(d, cast(GETDATE() AS date), DATEADD(DAY, 115, IndexDate)) +TotalDaysSupply) <84 then 0
			WHEN MeasureType = 'MDD43h' and (datediff(d, cast(GETDATE() AS date), DATEADD(DAY, 115, IndexDate)) +TotalDaysSupply) >=84 then -1
			WHEN MeasureType = 'MDD47h' and (datediff(d, cast(GETDATE() AS date), DATEADD(DAY, 231, IndexDate)) +TotalDaysSupply) <180 then 0
			WHEN MeasureType = 'MDD47h' and (datediff(d, cast(GETDATE() AS date), DATEADD(DAY, 231, IndexDate)) +TotalDaysSupply) >=180 then -1
			ELSE -1
		END AS PassedMeasure 
		--Drug Info
		,DrugNameWithoutDoseSID
		,lf.DrugNameWithoutDose
		,lf.ChecklistID
		,lf.Prescriber
		,lf.StaffSID AS PrescriberSID
		,lf.AD_RxReleaseDate AS LastRelease 
		,DATEDIFF(d,AD_RxReleaseDate,CAST(GETDATE() AS DATE)) AS DaysSinceLastFill
		,lf.RxType
		,lf.DaysSupply AS LastDaysSupply
		,app.PCFutureAppointmentDateTime
		,app.PCFutureStopCodeName
		,app.MHRecentVisitDate
		,app.MHRecentStopCodeName
		,app.PCRecentVisitDate 
		,app.PCRecentStopCodeName
		,app.MHFutureAppointmentDateTime
		,app.MHFutureStopCodeName
		,CASE WHEN RxStatus LIKE 'Discontinued%' THEN 'DISCONTINUED' ELSE RxStatus END AS RxStatus
		,CASE
			WHEN pt.PCP=1 THEN lf.Prescriber + ' (PCP)' 
			WHEN pt.MH=1  THEN lf.Prescriber + ' (MH)'
			ELSE lf.Prescriber
		END AS PrescriberName_Type
		,CASE
			WHEN pt.PCP=1 THEN 'PCP' 
			WHEN pt.MH=1  THEN 'MH'
			ELSE 'Not Defined'
		END AS PrescriberType
	INTO #alltogether
 	FROM #calc a
	INNER JOIN #LastFill lf 
		ON a.PatientSID = lf.PatientSID 
		AND lf.AD_RxReleaseDate >= IndexDate
	LEFT JOIN #appointments app 
		ON a.PatientSID = app.PatientSID
	LEFT JOIN [Present].[ProviderType] pt WITH (NOLOCK)
		on pt.StaffSID = lf.StaffSID
	WHERE a.MeasureType IN ('MDD47H','MDD43h')


---Find all antidepressants
drop table if exists #Antidepressant
select m.Sta3n,m.DrugICN,DrugNameWithoutDoseSID
into #Antidepressant
from [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_NationalDrugLookup]  as m 
inner join  [LookUp].[NationalDrug] nd on nd.NationalDrugSID = m.NationalDrugSID
where nd.Antidepressant_Rx = 1


drop table if exists #mpr
SELECT distinct PatientSID, m.DrugNameWithoutDoseSID, adh.TrialEndDateTime,TrialStartDateTime
    --, adh.PreviousReleaseTime,adh.DaysSinceLastFill, adh.DaysSupply,adh.RxStatus, adh.DaysTillNextFill
	, adh.DrugNameWithoutDose, adh.MPR_Trial, adh.MPRToday
	, adh.LastRxOutpatSID
	into #mpr
FROM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] AS adh WITH (NOLOCK)
INNER JOIN #InitialPatientSIDCohort coh ON coh.MVIPersonSID = adh.MVIPersonSID
inner join  #Antidepressant  as m 
					on adh.LastRxOutpatSID_Sta3n = m.Sta3n and adh.DrugNameWithoutDoseICN = m.DrugICN
where MostRecentTrialFlag = 'true'


drop table if exists #Final
		select distinct   a.[PatientSID]
      ,[MeasureType]
      ,[LastFillBeforeIndex]
      ,[IndexDate]
      ,[DaysSinceIndex]
      ,[MeasureEndDate]
      ,[TotalDaysSupply]
      ,[PassedMeasure]
      ,a.[DrugNameWithoutDose]
      , CASE 
			WHEN DateDiff(d,[LastRelease],cast(GETDATE() AS date)) >= [LastDaysSupply] 
				AND RxStatus in ('Active','Suspended') 
				AND Rxtype is null and MPRToday <1 
				THEN 'Refill Required'  
		END AS RefillRequired
      ,[Prescriber]
      ,[PrescriberSID]
      ,[LastRelease]
      ,[DaysSinceLastFill]
      ,[RxType]
      ,[LastDaysSupply]
      ,[MPRToday]
      ,[PCFutureAppointmentDateTime]
      ,[PCFutureStopCodeName]
      ,[MHRecentVisitDate]
      ,[MHRecentStopCodeName]
      ,[PCRecentVisitDate]
      ,[PCRecentStopCodeName]
      ,[MHFutureAppointmentDateTime]
      ,[MHFutureStopCodeName]
      ,[RxStatus]
      ,[PrescriberName_Type]
      ,[PrescriberType]
      ,[ChecklistID]
      ,[MVIPersonSID] 
	  into #Final
		from #alltogether as a 
		left outer join #mpr as mpr on a.PatientSID = mpr.PatientSID and a.DrugNameWithoutDoseSID = mpr.DrugNameWithoutDoseSID



	--FINAL TABLE
	EXEC [Maintenance].[PublishTable] 'Pharm.AntiDepressant_MPR_PatientReport','#final'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
