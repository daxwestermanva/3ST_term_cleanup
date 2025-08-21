







/*
MODIFICATIONS
	2024-06-14	RAS	Replaced SpecialtyIEN with PTFCode and removed BedSectionName alias from Specialty column.
*/

CREATE PROCEDURE [DeltaView].[Common_InpatientRecords_002_POCTestOnly]
AS
BEGIN
--TRUNCATE TABLE Stage.Common_InpatientRecords_002
--INSERT Stage.Common_InpatientRecords_002 WITH(TABLOCK)
--SELECT *
--FROM Common.InpatientRecords_002

-- select existing data into a staging table
-- then delete census data and discharge date time prior to 2 years ago

--Past 10 fiscal years (complete years + current)
DECLARE @StartDate DATETIME2(0) = (
	SELECT MIN(Date) 
	FROM Dim.Date 
	WHERE FiscalYear IN (
		SELECT FiscalYear
		FROM Dim.Date 
		WHERE Date = CAST(DATEADD(YEAR,-10,GETDATE()) AS DATE)
		)	)
--	SET @StartDate =  CAST(GETDATE() - 1875 AS DATE)
PRINT @StartDate
---- remove the data we are updating 
--DELETE Stage.Common_InpatientRecords_002
--WHERE DischargeDateTime > @StartDate

/*******************************************************************
PULL INPATIENT DATA AND RELATED BEDSECTION/SPECIALTY DATA
--*******************************************************************/
	--DROP TABLE IF EXISTS #test 
	--SELECT DISTINCT mvi.MVIPersonSID,InpatientSID= COALESCE(i.InpatientSID,st.InpatientSID)
	--INTO #test
	--FROM [Inpat].[Inpatient] i WITH (NOLOCK)
	--INNER JOIN [Inpat].[SpecialtyTransfer] st WITH (NOLOCK) ON i.InpatientSID = st.InpatientSID
	--INNER JOIN [OMHSP_PERC_CDSTest].[Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	--	ON i.PatientSID = mvi.PatientPersonSID
	--INNER JOIN [OMHSP_PERC_CDSTest].[Common].[MasterPatient] mp
	--	ON mvi.MVIPersonSID = mp.MVIPersonSID -- gets rid of test patient data
	--WHERE i.InpatientSID > 0
	--	AND i.AdmitDateTime IS NOT NULL
	--	AND (st.SpecialtyTransferDateTime >= @StartDate
	--		OR ((i.DischargeDateTime >= @StartDate 
	--		OR i.DischargeDateTime IS NULL)	)	)
	
	
--	DELETE ir--SELECT ir.*
--	FROM [Stage].[Common_InpatientRecords_002] ir
--	INNER JOIN #test t ON t.InpatientSID = ir.InpatientSID
	
--SELECT DISTINCT DischargeDateTime,AdmitDateTime,SpecialtyTransferDateTime FROM 	[Stage].[Common_InpatientRecords_002] ir
--ORDER BY 3
	
	
	--DROP TABLE IF EXISTS #test2
	--SELECT DISTINCT mvi.MVIPersonSID,InpatientSID= COALESCE(i.InpatientSID,st.InpatientSID)
	--INTO #test2
	--FROM [Inpat].[Inpatient] i WITH (NOLOCK)
	--INNER JOIN [Inpat].[SpecialtyTransfer] st WITH (NOLOCK) ON i.InpatientSID = st.InpatientSID
	--INNER JOIN [OMHSP_PERC_CDSTest].[Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	--	ON i.PatientSID = mvi.PatientPersonSID
	--INNER JOIN [OMHSP_PERC_CDSTest].[Common].[MasterPatient] mp
	--	ON mvi.MVIPersonSID = mp.MVIPersonSID -- gets rid of test patient data
	--WHERE i.InpatientSID > 0
	--	AND i.AdmitDateTime IS NOT NULL
	--	AND (i.DischargeDateTime >= @StartDate 
	--		OR i.DischargeDateTime IS NULL)		

	-------------------------------------------------------------------------
	-- VISTA
	-------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Main;
	SELECT 
		mvi.MVIPersonSID
		,i.InpatientSID
		,DischargeDateTime = ISNULL(i.DischargeDateTime,'2100-12-31')
		,i.AdmitDateTime
		,i.PlaceOfDispositionSID
		,i.PatientSID
		,PrincipalDiagnosisSID = COALESCE(i.PrincipalDiagnosisICD10SID,i.PrincipalDiagnosisICD9SID)
		,PrincipalDiagnosisType = CASE WHEN PrincipalDiagnosisICD10SID > 0 THEN 'ICD10CM' ELSE 'ICD9CM' END
		,i.AdmitDiagnosis
		,i.Sta3n
		--,i.Census 
		,i.DischargeWardLocationSID
		,i.AdmitWardLocationSID
		,COALESCE(dw.Sta6a,aw.Sta6a) AS Sta6a
		,i.DischargeFromSpecialtySID
		,pd.PlaceOfDisposition
		,pd.PlaceOfDispositionCode
		,IIF(i.DispositionType = '4', 1, 0) AS AMA -- 4 = IRREGULAR according to CDW Metadata report (no dim table)
	INTO #Main
	FROM [Inpat].[Inpatient] i WITH (NOLOCK)
	/*<Vista>INNER JOIN $DeltaKeyTable VDK WITH (NOLOCK) ON VDK.InpatientSID = i.InpatientSID</Vista>*/
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON i.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] mp
		ON mvi.MVIPersonSID = mp.MVIPersonSID -- gets rid of test patient data
	LEFT JOIN [Dim].[WardLocation] dw WITH (NOLOCK)
		ON i.DischargeWardLocationSID = dw.WardLocationSID
	LEFT JOIN [Dim].[WardLocation] aw WITH (NOLOCK)
		ON i.AdmitWardLocationSID = aw.WardLocationSID
	LEFT JOIN [Dim].[PlaceOfDisposition] pd WITH (NOLOCK)
		ON i.PlaceOfDispositionSID = pd.PlaceOfDispositionSID
	WHERE i.InpatientSID > 0
		AND i.AdmitDateTime IS NOT NULL
		AND (i.DischargeDateTime >= @StartDate 
			OR i.DischargeDateTime IS NULL
			)
	
	UPDATE #Main
	SET Sta6a = Sta3n
	WHERE Sta6a IS NULL OR Sta6a IN ('*Missing*','*Unknown at this time*')

	-- SELECT * FROM #Main WHERE Sta6a IS NULL OR Sta6a IN ('*Missing*','*Unknown at this time*')

	/* CDW 'TreatingSpecialty' from dim.TreatingSpecialty as specialtyIEN is was SASMED calls the 'bedsection' or bedsecn */
	/* CDW 'Specialty' from dim.TreatingSpecialty is what SASMED has for the name of the bedsection */
	DROP TABLE IF EXISTS #specialty;
	SELECT
		mn.MVIPersonSID
		,st.InpatientSID
		,st.PatientSID
   		,st.SpecialtyTransferDateTime
		,st.SpecialtyTransferSID
		,mn.Sta3n
	    ,mn.AdmitDateTime
		,mn.DischargeDateTime
		,st.TreatingSpecialtySID
		,s.PTFCode
		,dt.Specialty
		--,dt.Sta3n --Removed because the only cases where mn.Sta3n<>st.Sta3n are those where st.Sta3n=-1, so just keep Sta3n from #Main
		,BsInDate = CASE WHEN SpecialtyTransferDateTime > DischargeDateTime AND DATEDIFF(DAY,DischargeDateTIme,SpecialtyTransferDateTime)=0 
						THEN DischargeDateTime ELSE SpecialtyTransferDateTime
						END
	INTO #specialty
	FROM [Inpat].[SpecialtyTransfer] st WITH (NOLOCK)
	INNER JOIN #Main mn WITH (NOLOCK)
		ON st.InpatientSID = mn.InpatientSID
	INNER JOIN [Dim].[TreatingSpecialty] dt WITH (NOLOCK)
		ON dt.TreatingSpecialtySID = st.TreatingSpecialtySID
	INNER JOIN [Dim].[Specialty] s ON s.SpecialtySID = dt.SpecialtySID
	WHERE st.SpecialtyTransferSID > 0 

	-------------------------------------------------------------------------
	-- CERNER
	-------------------------------------------------------------------------
	---------EXEC [Log].[ExecutionBegin] 'EXEC Code.Inpatient_BedSection CDW2','Execution of Code.Inpatient_BedSection SP - Cerner/Millenium CDW2 data'

	DROP TABLE IF EXISTS #MillIP
	SELECT DISTINCT
		Census = CASE WHEN i.TZDischargeDateTime IS NULL THEN 1 ELSE 0 END --Not using EncounterStatus per Cerner call
		  ,i.MVIPersonSID
		  ,i.EncounterSID					as InpatientEncounterSID
		  ,i.PersonSID						as PatientPersonSID
		  ,i.TZDerivedAdmitDateTime			as AdmitDateTime 
		  ,ISNULL(i.TZDischargeDateTime,'2100-12-31')	as DischargeDateTime
		  ,i.DischargeDisposition			as PlaceOfDisposition
		  ,LEFT(admitdx.SourceIdentifier + ' ' + admitdx.SourceString,50) as AdmitDiagnosis
          ,prindx.NomenclatureSID			as PrincipalDiagnosisSID
		  ,PrincipalDiagnosisType = 'ICD10CM'
		  ,im.MedicalService
		  ,im.DerivedAccommodation	as Accommodation
		  ,im.EncounterLocationHistorySID	as BedSectionRecordSID
		  ,im.DerivedCodeValueSID			as TreatingSpecialtySID
		  ,im.PTFCode
		  ,im.Specialty
		  ,im.Sta6a							as Sta6a
		  ,im.STAPA
		  ,CAST(LEFT(im.STAPA,3) AS INT)	as Sta3n
		  ,im.TZDerivedBeginEffectiveDateTime		as SpecialtyTransferDateTime
		  ,im.TZDerivedBeginEffectiveDateTime		as BSInDateTime
		  ,im.TZDerivedEndEffectiveDateTime		as BSOutDateTime
		  ,CASE 
			WHEN i.DischargeDisposition = 'Left Against Medical Advice' THEN 1 
			ELSE 0 END as AMA
	INTO #MillIP
	FROM [Cerner].[FactInpatient] i WITH (NOLOCK)
	INNER JOIN [Cerner].[FactInpatientSpecialtyTransfer] im WITH (NOLOCK) ON im.EncounterSID=i.EncounterSID
	LEFT JOIN [Cerner].[FactDiagnosis] admitdx WITH (NOLOCK) ON i.EncounterSID = admitdx.EncounterSID AND admitdx.PrimaryAdmitDxFlag = 1
    LEFT JOIN [Cerner].[FactDiagnosis] prindx WITH (NOLOCK) ON i.EncounterSID = prindx.EncounterSID AND prindx.PrimaryDischargeDxFlag = 1

	DELETE #MillIP WHERE PTFCode IS NULL OR STAPA IS NULL
	-- 250 records on 2023-05-12. It's impossible to make a rule that works for 
	-- every scenario and keeping them makes it impossible to sort bed transitions correctly

	-------------------------------------------------------------------------
	-- UNION 
	-------------------------------------------------------------------------
	DROP TABLE IF EXISTS #StageIP_1
	SELECT s.MVIPersonSID							
		--,s.StayId									
		--,DerivedBedSectionRecordSID = s.DerivedSID						
		--,s.BSInDateTime								
		--,s.BsOutDateTime							
		--,DerivedInpatientRecordSID = s.InpatientEncounterSID
		--,s.KeepFlag									
		,s.PatientPersonSID							
		,s.PTFCode								
		,s.Specialty
		,s.MedicalService
		,s.Accommodation
		,s.BedSectionRecordSID						
		,s.SpecialtyTransferDateTime
		,OutDate = s.DischargeDateTime
		,s.TreatingSpecialtySID						
		,s.InpatientEncounterSID					
		,s.Sta6a									
		,s.STAPA								
		,Sta3n = LEFT(STAPA,3)
		,Sta3n_EHR	= 200		
		,s.AdmitDateTime							
		,s.DischargeDateTime						
		,s.PlaceOfDisposition						
		,s.AMA										
		,s.AdmitDiagnosis							
		,s.PrincipalDiagnosisSID 
		,s.PrincipalDiagnosisType
		,PlaceOfDispositionCode	= CAST(NULL AS VARCHAR)
		--,BatchDate 
		--,BatchStart
	INTO #StageIP_1
	FROM #MillIP s 

	INSERT #StageIP_1
	SELECT s.MVIPersonSID							
		--,s.StayId									
		--,DerivedBedSectionRecordSID = s.DerivedSID						
		--,s.BSInDateTime								
		--,s.BsOutDateTime							
		--,DerivedInpatientRecordSID = s.InpatientSID
		--,s.KeepFlag									
		,s.PatientSID
		,s.PTFCode
		,s.Specialty
		,MedicalService = NULL
		,Accommodation  = NULL
		,s.SpecialtyTransferSID
		,s.SpecialtyTransferDateTime
		,OutDate = CASE WHEN s.SpecialtyTransferDateTime > s.DischargeDateTime THEN s.SpecialtyTransferDateTime ELSE s.DischargeDateTime END
		,s.TreatingSpecialtySID
		,m.InpatientSID
		,m.Sta6a
		,st.STAPA
		,m.Sta3n
		,m.Sta3n
		,m.AdmitDateTime
		,m.DischargeDateTime
		,m.PlaceOfDisposition
		,m.AMA
		,m.AdmitDiagnosis
		,PrincipalDiagnosisSID 
		,PrincipalDiagnosisType
		,m.PlaceOfDispositionCode
		--,BatchDate 
		--,BatchStart
	FROM #specialty s 
	INNER JOIN #Main m ON m.InpatientSID = s.InpatientSID
	INNER JOIN [LookUp].[Sta6a] st ON st.Sta6a  = m.Sta6a 
	
	DROP TABLE #Main,#MillIP,#specialty
	
	-------------------------------------------------------------------------
	-- CLEAN AND ASSIGN IN/OUT DATES 
	-------------------------------------------------------------------------
	-- Create a flag to identify every time a new bed section stay begins, then use cumulative sum to number each group of stays
	
	DROP TABLE IF EXISTS #DerivedStay;
	WITH RangeAll AS (
		SELECT --MVIPersonSID,InpatientEncounterSID,BedSection,SpecialtyTransferDateTime,OutDate,AdmitDateTime,DischargeDateTime
			--,StartNew
			*,StayId = SUM(StartNew) OVER (PARTITION BY MVIPersonSID ORDER BY InpatientEncounterSID,SpecialtyTransferDateTime ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
		FROM (
			SELECT *
				,StartNew = CASE 
					-- when the bed section changes, it's definitely the start of a bedsection stay
					WHEN LAG(PTFCode) OVER(PARTITION BY MVIPersonSID ORDER BY InpatientEncounterSID,SpecialtyTransferDateTime) <> PTFCode THEN 1
					-- when the inpatientsid changes, mark as start of new stay
					WHEN LAG(InpatientEncounterSID) OVER(PARTITION BY MVIPersonSID ORDER BY InpatientEncounterSID,SpecialtyTransferDateTime) <> InpatientEncounterSID THEN 1
					-- when the bed section and inpatientsid stays the same, it's the same stay if the outdate from the previous overlaps
					WHEN LAG(OutDate) OVER(PARTITION BY MVIPersonSID ORDER BY InpatientEncounterSID,SpecialtyTransferDateTime) > SpecialtyTransferDateTime 
						OR LAG(InpatientEncounterSID) OVER(PARTITION BY MVIPersonSID ORDER BY InpatientEncounterSID,SpecialtyTransferDateTime) = InpatientEncounterSID
					THEN 0
					ELSE 1 END

			FROM #StageIP_1
			) a --WHERE MVIPersonSID = 6243334
		)
	--	SELECT TOP 1000 StayId,* FROM RangeAll ORDER BY MVIPersonSID,SpecialtyTransferDateTime
	SELECT DerivedSID = FIRST_VALUE(BedSectionRecordSID) OVER(PARTITION BY MVIPersonSID,StayId ORDER BY SpecialtyTransferDateTime)
		,BSInDateTime = MIN(CASE WHEN SpecialtyTransferDateTime > DischargeDateTime THEN DischargeDateTime ELSE SpecialtyTransferDateTime END) OVER(PARTITION BY MVIPersonSID,StayId)
		,BSOutDateTime = MAX(CASE WHEN OutDate > DischargeDateTime THEN DischargeDateTime ELSE OutDate END) OVER(PARTITION BY MVIPersonSID,StayId)
		,*
	INTO #DerivedStay
	FROM RangeAll
	
	
	-- Update stays within the same inpatientsid to have an outdate = following in date
	;WITH UpdateOut AS (
		SELECT MVIPersonSID,StayId,BSInDateTime
			,OutDateTime = LEAD(BsInDateTime) OVER(PARTITION BY MVIPersonSID,InpatientEncounterSID ORDER BY BsInDateTime)
		FROM (SELECT DISTINCT MVIPersonSID,StayId,InpatientEncounterSID,BSInDateTime,BSOutDateTime FROM #DerivedStay) a
		)
	UPDATE ds
	SET BSOutDateTime = u.OutDateTime
	FROM #DerivedStay ds
	LEFT JOIN UpdateOut u ON u.MVIPersonSID = ds.MVIPersonSID AND u.StayId = ds.StayId
	WHERE u.OutDateTime IS NOT NULL

	-- update overlapping stays, if the end of a stay runs into the beginning of another, changing the outdate to earlier
	-- which might be < dischargedatetime
	;WITH UpdateOut AS (
		SELECT MVIPersonSID,StayId,BSInDateTime
			,OutDateTime = 
				CASE 
					WHEN LEAD(BsInDateTime) OVER(PARTITION BY MVIPersonSID ORDER BY BsInDateTime) < BSOutDateTime 
						AND LEAD(BSOutDateTime) OVER(PARTITION BY MVIPersonSID ORDER BY BsInDateTime) >= BSOutDateTime
					THEN LEAD(BSInDateTime) OVER(PARTITION BY MVIPersonSID ORDER BY BsInDateTime)
					ELSE NULL END

		FROM (SELECT DISTINCT MVIPersonSID,StayId,BSInDateTime,BSOutDateTime FROM #DerivedStay) a
		)
	UPDATE ds
	SET BSOutDateTime = u.OutDateTime
	FROM #DerivedStay ds
	LEFT JOIN UpdateOut u ON u.MVIPersonSID = ds.MVIPersonSID AND u.StayId = ds.StayId
	WHERE u.OutDateTime IS NOT NULL

	-- so now the overlaps that are left are where a stay starts AND ends within another. 

	-- find "nested" stays and split to containing stay record
	-- It only makes sense to do this for stays where the in and out date are different, if they are
	-- equal because of weird admin data, then it isn't meaningful or practical to create
	-- records of movement in and out at the same time.
	DROP TABLE IF EXISTS #DistinctStay 
	SELECT DISTINCT MVIPersonSID,DerivedSID,InpatientEncounterSID,BSInDateTime,BSOutDateTime,Split = 0
	INTO #DistinctStay	
	FROM #DerivedStay
	WHERE BSInDateTime < BSOutDateTime
	--WHERE MVIPersonSID = 6243334

	DROP TABLE IF EXISTS #DistinctAdmit
	SELECT MVIPersonSID,InpatientEncounterSID,MinIn = MIN(BSInDateTime),MaxOut = MAX(BSOutDateTime)
	INTO #DistinctAdmit	
	FROM #DerivedStay
	--WHERE MVIPersonSID = 6243334
	GROUP BY MVIPersonSID,InpatientEncounterSID
	HAVING MIN(BSInDateTime) < MAX(BSOutDateTime)
	
	DECLARE @LoopID INT = 1
	DECLARE @RowCount INT = 1
	WHILE @RowCount > 0 
	BEGIN

	
	DROP TABLE IF EXISTS #Update
	SELECT TOP 1 WITH TIES
		a.MVIPersonSID,a.DerivedSID,a.InpatientEncounterSID
		,a.BSInDateTime,a.BSOutDateTime
		,b.MinIn AS ChildInDate
		,b.MaxOut AS ChildOutDate
		,b.InpatientEncounterSID AS ChildStay
		--,RN = ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID,a.DerivedSID,a.BSInDateTime,a.BSOutDateTime ORDER BY b.MinIn)
	INTO #Update
	FROM #DistinctStay a
	LEFT JOIN #DistinctAdmit b ON b.MVIPersonSID = a.MVIPersonSID
		AND b.InpatientEncounterSID <> a.InpatientEncounterSID-- not the same record
		AND b.MinIn >= a.BSInDateTime
		AND b.MaxOut <= a.BSOutDateTime
	WHERE b.InpatientEncounterSID IS NOT NULL
	ORDER BY ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID,a.DerivedSID,a.BSInDateTime,a.BSOutDateTime ORDER BY b.MinIn)

	DELETE d
	FROM #DistinctStay d
	INNER JOIN #Update u ON u.DerivedSID = d.DerivedSID
		AND u.BSInDateTime = d.BSInDateTime
		AND u.BSOutDateTime = d.BSOutDateTime

	-- one where they leave to go to the nested stay
	INSERT #DistinctStay
	SELECT MVIPersonSID,DerivedSID,InpatientEncounterSID,BSInDateTime,ChildInDate,1
	FROM #Update
	-- one where they return to the "parent"
	INSERT #DistinctStay
	SELECT MVIPersonSID,DerivedSID,InpatientEncounterSID,ChildOutDate,BSOutDateTime,1
	FROM #Update

	SET @RowCount = @@ROWCOUNT

	PRINT @LoopID
	SET @LoopID = @LoopID + 1

	END

	
	DROP TABLE IF EXISTS #StageIP
	SELECT uBSInDateTime = u.BSInDateTime
		,uBSOutDateTime = u.BSOutDateTime
		,d.* 
		,DerivedBedSectionRecordSID = d.DerivedSID
		,KeepFlag = CASE WHEN d.DerivedSID = BedSectionRecordSID THEN 1 ELSE 0 END
	INTO #StageIP
	FROM #DerivedStay d
	LEFT JOIN #DistinctStay u ON d.DerivedSID = u.DerivedSID


 ---EXEC [Maintenance].[PublishTable] 'DeltaView.CommonInpatientRecords_002_POCTestOnly','#StageIP'


	BEGIN TRY

		BEGIN TRAN
		
		IF( SELECT COUNT([MVIPersonSID]) FROM DeltaView.CommonInpatientRecords_002_POCTestOnly) > 0
		BEGIN
			
			DELETE T
			FROM 
				DeltaView.CommonInpatientRecords_002_POCTestOnly T
				INNER JOIN #StageIP S
					ON S.MVIPersonSID = T.MVIPersonSID
					AND S.BedSectionRecordSID = T.BedSectionRecordSID
					AND S.SpecialtyTransferDateTime = T.SpecialtyTransferDateTime
					AND ISNULL(S.uBSInDateTime, '1900-01-01') = ISNULL(T.uBSInDateTime, '1900-01-01');

			
			DELETE T
			FROM 
				DeltaView.CommonInpatientRecords_002_POCTestOnly T
				INNER JOIN #StageIP S
					ON S.MVIPersonSID = T.MVIPersonSID
					AND S.BedSectionRecordSID = T.BedSectionRecordSID
					AND S.SpecialtyTransferDateTime = T.SpecialtyTransferDateTime
					AND S.uBSInDateTime IS NOT NULL 
					AND T.uBSInDateTime IS NULL;
			

			
			--For Vista, delete all records that no longer exist (soft deleted) in the root entity table

			/*<Vista>DELETE T
			FROM 
				DeltaView.CommonInpatientRecords_002_POCTestOnly T
			WHERE 
				T.MVIPersonSID IN (

					SELECT 
						mvi.MVIPersonSID
					FROM 
						CDW14.Inpat.Inpatient_v392 i
						INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH(NOLOCK)
							ON i.PatientSID = mvi.PatientPersonSID
					WHERE InpatientSID IN 
					(

						SELECT InpatientSID  FROM $DeltaKeyTable

						EXCEPT

						SELECT InpatientSID FROM [Inpat].[Inpatient] i WITH(NOLOCK)

					)
			
				)</Vista>*/


		END

		
		INSERT INTO [DeltaView].[CommonInpatientRecords_002_POCTestOnly]
           ([MVIPersonSID]
           ,[StayId]
           ,[DerivedBedSectionRecordSID]
           ,[BSInDateTime]
           ,[BsOutDateTime]
           ,[uBSInDateTime]
           ,[uBsOutDateTime]
           ,[KeepFlag]
           ,[PatientPersonSID]
           ,[PTFCode]
           ,[Specialty]
           ,[MedicalService]
           ,[Accommodation]
           ,[BedSectionRecordSID]
           ,[SpecialtyTransferDateTime]
           ,[TreatingSpecialtySID]
           ,[InpatientEncounterSID]
           ,[Sta6a]
           ,[StaPa]
           ,[Sta3n_EHR]
           ,[AdmitDateTime]
           ,[DischargeDateTime]
           ,[PlaceOfDisposition]
           ,[AMA]
           ,[AdmitDiagnosis]
           ,[PrincipalDiagnosisSID]
           ,[PrincipalDiagnosisType]
           ,[PlaceOfDispositionCode])
		SELECT DISTINCT
			[MVIPersonSID]
           ,[StayId]
           ,[DerivedBedSectionRecordSID]
           ,[BSInDateTime]
           ,[BsOutDateTime]
           ,[uBSInDateTime]
           ,[uBsOutDateTime]
           ,[KeepFlag]
           ,[PatientPersonSID]
           ,[PTFCode]
           ,[Specialty]
           ,[MedicalService]
           ,[Accommodation]
           ,[BedSectionRecordSID]
           ,[SpecialtyTransferDateTime]
           ,[TreatingSpecialtySID]
           ,[InpatientEncounterSID]
           ,[Sta6a]
           ,[StaPa]
           ,[Sta3n_EHR]
           ,[AdmitDateTime]
           ,[DischargeDateTime]
           ,[PlaceOfDisposition]
           ,[AMA]
           ,[AdmitDiagnosis]
           ,[PrincipalDiagnosisSID]
           ,[PrincipalDiagnosisType]
           ,[PlaceOfDispositionCode]
		FROM
			#StageIP;


		COMMIT

	END TRY
	BEGIN CATCH

		ROLLBACK

	END CATCH


END