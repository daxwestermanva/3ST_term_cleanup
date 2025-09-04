




/********************************************************************************************************************
DESCRIPTION: Inpatient stays with bed section transitions for past 5 years.
			 Original source code from David Wright and Aaron Dalton.
TEST:
	EXEC [Code].[Inpatient_BedSection]  --Should take about 2 Minutes
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2018-08-14		JEB		Refactored to remove DROP/CREATE of [Inpatient].[Bedsection]. 
							Proper formatting applied
							WHERE clause with dates casted to DATE where applicable
	20180827		RAS		Incorporated Jason's changes from "Inpatient_BedSection_JB20180814"
							Changed inner join with Present SPatient to Spatient.SPatient because the dependency between 
							SPatient and Bedsection tables was in both directions.  One needs to run first.
	20190618		RAS		Added ChecklistID to table and code.
	20200528		RAS		Removed specific "SAS" columns to make the table more intuitive.  Logic for BsInDay and BsOutDay
							is retained and used to fill in BSInDateTime and BsOutDateTime on each row.
							Added flags to identify  most recent record and the first record in a bed section episode 
							(essentially the same purpose as the row previously containing the SAS_MedRec).  
							Created view based on this table to simplify querying.  Keeping this table because if you need
							to get details using SpecialtyTransferSID, then you need all of the records.
	20200818		RAS		Added code for Cerner overlay 
	20201006		RAS		Added logic to get only bedsection changes from MillCDS InpatientMovemement because that source data 
							includes other types of history as well. Modeled code on original VistA data version.
	20201019		RAS		Removed logic from 20201006, this was moved to the source data sproc instead.
	20210107		RAS		Removed DispositionType from table and related view. Cerner data only has 1 field, so only keeping VistA CDW
							PlaceOfDisposition and Cerner Millenium DischargeDisposition to get the information on where the patient
							went upon discharge.  Flag for AMA is created for VistA data using DispositionType field and for Millenium
							data using the DischargeDisposition field.
	20210721		AI		Enclave Refactoring - Counts confirmed
	20210917		AI		Enclave Refactoring - Refactored comments, no testing performed
	20210920		JEB		Enclave Refactoring - Refactored comment
	20220420		EC		Adding Cerner Admit and Discharge Diagnosis data, adding ICD10Code column to table (in addition to existing ICD10SID column)
	20220517		RAS		Replacing UniqueBedEpisode flag with DerivedBedSectionSID. XLA needs an identifier across one bed section episode, with the
							ability to find the other TreatingSpecialtySIDs when there are multiple.
	20230307		LM		Added columns for Medical Service and Accomodation from Cerner
	20240614		RAS		Removed SpecialtyIEN

--Questions:
Are there additional ways we should be flagging Nursing Home stays apart from PTFCode?
What about stays that do not have a mapped PTFCode -- do we need additional code or do we need to wait for better data?
How do we determine principal diagnosis?
Do we really need AdmitDiagnosis?  Is millenium VisitReason like VistA AdmitDiagnosis?
	We display AdmitDiagnosis on PDE report when a PrincipalDiagnosis is not available
********************************************************************************************************************/

CREATE PROCEDURE [Code].[Inpatient_BedSection]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Inpatient_BedSection','Execution of Code.Inpatient_BedSection SP'

/*******************************************************************
VISTA
*******************************************************************/
	EXEC [Log].[ExecutionBegin] 'EXEC Code.Inpatient_BedSection CDW','Execution of Code.Inpatient_BedSection SP - VistA CDW data'
	-----------------------------------------------------------------
	/*STEP 1: GET CDW ADMISSION RECORDS*/
	-----------------------------------------------------------------
	--Past 5 years (1875 days): Get CDW Admission records to calculate Discharge Date and sta6a for the admission
	DROP TABLE IF EXISTS #Main;
	SELECT 
		mvi.MVIPersonSID
		,i.InpatientSID
		,i.DischargeDateTime
		,i.AdmitDateTime
		,i.PlaceOfDispositionSID
		,i.PatientSID
		,i.PrincipalDiagnosisICD10SID
		,icd.ICD10Code
		,i.PrincipalDiagnosisICD9SID
		--,DispositionType = --Values from CDW Metadata report (no dim table)
		--	CASE WHEN i.DispositionType = '1' THEN 'REGULAR'
		--		WHEN i.DispositionType = '2' THEN 'NBC OR WHILE ASIH'
		--		WHEN i.DispositionType = '3' THEN 'EXPIRATION 6 MONTH LIMIT'
		--		WHEN i.DispositionType = '4' THEN 'IRREGULAR'
		--		WHEN i.DispositionType = '5' THEN 'TRANSFER'
		--		WHEN i.DispositionType = '6' THEN 'DEATH WITH AUTOPSY'
		--		WHEN i.DispositionType = '7' THEN 'DEATH WITHOUT AUTOPSY'
		--		ELSE i.DispositionType END
		,i.AdmitDiagnosis
		,i.Sta3n
		,i.Census 
		,i.DischargeWardLocationSID
		,i.AdmitWardLocationSID
		,ISNULL(dw.Sta6a, aw.Sta6a) AS Sta6a
		,i.DischargeFromSpecialtySID
		,pd.PlaceOfDisposition
		,pd.PlaceOfDispositionCode
		,IIF(i.DispositionType = '4', 1, 0) AS AMA
	INTO #Main
	FROM (
		SELECT
			*
			,IIF((DischargeDateTime IS NULL OR CAST(DischargeDateTime AS DATE) > CAST(GETDATE() AS DATE)) 
					AND (CAST(AdmitDateTime AS DATE) < CAST(GETDATE() AS DATE)), 1, 0) AS Census					
		FROM [Inpat].[Inpatient] WITH (NOLOCK)
		WHERE InpatientSID > 0) i
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON i.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
		ON mvi.MVIPersonSID = mp.MVIPersonSID -- gets rid of test patient data
	LEFT JOIN [Dim].[WardLocation] dw WITH (NOLOCK)
		ON i.DischargeWardLocationSID = dw.WardLocationSID
	LEFT JOIN [Dim].[WardLocation] aw WITH (NOLOCK)
		ON i.AdmitWardLocationSID = aw.WardLocationSID
	LEFT JOIN [Dim].[PlaceOfDisposition] pd WITH (NOLOCK)
		ON i.PlaceOfDispositionSID = pd.PlaceOfDispositionSID
	LEFT JOIN [Lookup].[ICD10] icd WITH (NOLOCK)
		ON i.PrincipalDiagnosisICD10SID=icd.ICD10SID
	WHERE (CAST(i.DischargeDateTime AS DATE) >= CAST(GETDATE() - 1875 AS DATE)) /*Non-Census*/
		OR i.Census = 1

	----------------------------------------------------------------
	/*STEP 2: GET Sta6a AND Bedsecn/Specialty IN AND OUT DATES FOR THE ADMISSION*/
	-----------------------------------------------------------------
	/* CDW 'TreatingSpecialty' from dim.TreatingSpecialty as specialtyIEN is was SASMED calls the 'bedsection' or bedsecn */
	/* CDW 'Specialty' from dim.TreatingSpecialty is what SASMED has for the name of the bedsection */

	DROP TABLE IF EXISTS #specialty;
	SELECT
		mn.MVIPersonSID
		,st.InpatientSID
		,st.PatientSID
   		,st.SpecialtyTransferDateTime
		,st.SpecialtyTransferSID
	    ,mn.AdmitDateTime
		,mn.DischargeDateTime
		,st.TreatingSpecialtySID
		,ds.PTFCode
		,ds.Specialty
		--,dt.Sta3n --Removed because the only cases where mn.Sta3n<>st.Sta3n are those where st.Sta3n=-1, so just keep Sta3n from #Main
	INTO #specialty
	FROM [Inpat].[SpecialtyTransfer] st WITH (NOLOCK)
	INNER JOIN #Main mn WITH (NOLOCK)
		ON st.InpatientSID = mn.InpatientSID
	INNER JOIN [Dim].[TreatingSpecialty] dt WITH (NOLOCK)
		ON dt.TreatingSpecialtySID = st.TreatingSpecialtySID
	INNER JOIN [Dim].[Specialty] ds WITH (NOLOCK) ON ds.SpecialtySID = dt.SpecialtySID
	WHERE st.SpecialtyTransferSID > 0 

	-----------------------------------------------------------------
	/*STEP 3: CLEAN UP INPATIENT STAY INFORMATION
	  The following steps aggregate contiguous bedsection stays, keeping the first bedsection date (like SASMED datasets)*/
	-----------------------------------------------------------------
	--1. Count BSinDays for each InpatientSID
	DROP TABLE IF EXISTS #SasMed1;
	SELECT *
		  ,BsInDayCount = ROW_NUMBER() OVER(PARTITION BY InpatientSID,AdmitDateTime ORDER BY SpecialtyTransferDateTime)
	INTO #SasMed1
	FROM #specialty;

		-- SELECT TOP 100 BsInDayCount,* FROM #SasMed1 ORDER BY InpatientSID,AdmitDateTime,SpecialtyTransferDateTime

	--2.Count BSinDay for each InpatientSID/Bedsecn combination (duplicate bedsecn have BedCount>1)
	DROP TABLE IF EXISTS #SasMed2;
	SELECT *
		  ,BedCount = ROW_NUMBER() OVER(PARTITION BY InpatientSID,AdmitDateTime,PTFCode ORDER BY BsInDayCount)
	INTO #SasMed2
	FROM #SasMed1;
 
		----For testing: view how contiguous bed section stays are numbered to be grouped in next step:
			-- SELECT TOP 100 BsInDayCount,BedCount,(BsInDayCount - BedCount),* FROM #SasMed2 ORDER BY InpatientSID,AdmitDateTime,SpecialtyTransferDateTime

	--3.Group duplicate bedsecn within InpatientSID
	/*select first bedsection to replicate sas medical dataset record count*/
	DROP TABLE IF EXISTS #SasMed3;
	SELECT InpatientSID
		  ,MVIPersonSID
		  ,AdmitDateTime
		  ,DischargeDateTIme
		  ,PTFCode
		  ,(BsInDayCount - BedCount) AS DistinctBedStay
		  ,MIN(SpecialtyTransferSID) AS SpecialtyTransferSID_Min --Previously SasMedRecord
		  ,MIN(SpecialtyTransferDateTime) AS BsInDateTime
	INTO #SasMed3
	FROM #SasMed2
	GROUP BY InpatientSID
		,MVIPersonSID
		,AdmitDateTime
		,DischargeDateTIme
		,PTFCode
		,(BsInDayCount - BedCount) --duplicate bedsections with contiguous in/out dates get rolled into 1 bedsection record

		-- SELECT TOP 100 * FROM #SasMed3 ORDER BY InpatientSID,AdmitDateTime,BsInDateTime

	--4.For each InpatientSID group, assign BSOut as subsequent bedsection BSinDay 
	----(the date they leave one bedsection is the same date they go into another).
	----Last BedSecn will have BSOut as null, which will be filled in during the following step
	DROP TABLE IF EXISTS #SASMed4;
	SELECT  InpatientSID
		,MVIPersonSID
		,DischargeDateTime
		,PTFCode
		,DistinctBedStay
		,SpecialtyTransferSID_Min
		,BSInDateTime
		,BsOutDateTime=LEAD(BSInDateTime) OVER (PARTITION BY InpatientSID ORDER BY InpatientSID,AdmitDateTime,BSInDateTime)
	INTO #SasMed4
	FROM #SASMed3;

		-- SELECT TOP 100 * FROM #SASMed4 ORDER BY InpatientSID,BsInDateTime

	--5.Fill in last BsOutDateTime from above by selecting the last dischargedatetime
	DROP TABLE IF EXISTS #inpat5;
	SELECT InpatientSID
		  ,DischargeDateTime
		  ,PTFCode
		  ,DistinctBedStay
		  ,SpecialtyTransferSID_Min
		  ,BsInDateTime
		  ,BsOutDateTime= --accounts for dates past end date, which are census records
			CASE WHEN BSOutDateTime IS NULL 
				OR CAST(BSOutDateTime AS DATE) > CAST(GETDATE() AS DATE) 
			THEN DischargeDateTime 
			ELSE BSOutDateTime END
	INTO #inpat5
	FROM #SasMed4

		-- SELECT TOP 100 * FROM #inpat5 ORDER BY InpatientSID,BsInDateTime

  -------------------------------------------------------
  -- Final VistA Inpatient Data
  -------------------------------------------------------
	DROP TABLE IF EXISTS #BedSectionFinal;
	SELECT DISTINCT
		i1.InpatientSID
		,i1.MVIPersonSID
		,i1.PatientSID
		,i1.AdmitDateTime
		,i1.DischargeDateTime
		,i1.SpecialtyTransferSID
		,i1.PTFCode
		,i1.Specialty
		,i1.SpecialtyTransferDateTime
		,i1.TreatingSpecialtySID
		,i5.BsInDateTime
		,i5.BsOutDateTime
		-- RAS Refactored to use FIRST SpecialtyTransfer record as UniqueBedEpisode in repeated stay instead of last.
		,DerivedBedSectionRecordSID = FIRST_VALUE(SpecialtyTransferSID) OVER(PARTITION BY i1.InpatientSID,i5.PTFCode,i5.DistinctBedStay 
				ORDER BY i1.SpecialtyTransferDateTime DESC) 
	INTO #BedSectionFinal
	FROM #SasMed2 AS i1 
	LEFT JOIN #inpat5 AS i5 ON 
		i1.InpatientSID=i5.InpatientSID 
		AND i1.PTFCode=i5.PTFCode
		AND (i1.BsInDayCount - i1.BedCount)=i5.DistinctBedStay 

	DROP TABLE IF EXISTS #VInpat
	SELECT 
		 m.Census
		,m.InpatientSID
		,m.MVIPersonSID
		,m.PatientSID
		,m.AdmitDateTime
		,m.DischargeDateTime
		,s.SpecialtyTransferSID
		,s.TreatingSpecialtySID
		-- 2024-06-14 - RAS updated below logic because previous "isnull" logic never would
			-- have impacted results since the bedsection is never null
			-- however, we need to make sure the results are what we want here
		,PTFCode = IIF(s.TreatingSpecialtySID <= 0,ds.PTFCode,s.PTFCode)
		,Specialty = IIF(s.TreatingSpecialtySID <= 0,ds.Specialty,s.Specialty)
		,m.DischargeFromSpecialtySID	--not used in final table, just included here for troubleshooting
		,m.Sta3n 
		,m.Sta6a
		,m.PlaceOfDisposition
		,m.PlaceOfDispositionCode
		,m.PrincipalDiagnosisICD10SID
		,m.ICD10Code
		,m.PrincipalDiagnosisICD9SID
		,m.AMA
		,m.AdmitDiagnosis
		,s.SpecialtyTransferDateTime
		,BsInDateTime =  ISNULL(s.BsInDateTime,m.AdmitDateTime)
		,BsOutDateTime = ISNULL(s.BsOutDateTime,ISNULL(m.DischargeDateTime,'2100-12-31 00:00:00'))
		,DerivedBedSectionRecordSID = ISNULL(s.DerivedBedSectionRecordSID,SpecialtyTransferSID)
	INTO #VInpat
	FROM #Main m
	INNER JOIN #BedSectionFinal s on s.InpatientSID=m.InpatientSID
	LEFT JOIN [Dim].[Specialty] ds WITH (NOLOCK) on ds.SpecialtySID=m.DischargeFromSpecialtySID
	LEFT JOIN (
		SELECT TOP 1 WITH TIES
			PTFCode
			,Specialty
		FROM [LookUp].[TreatingSpecialty] WITH (NOLOCK)
		ORDER BY ROW_NUMBER() OVER(PARTITION BY PTFCode ORDER BY Specialty)
		) ts on ts.PTFCode=ds.PTFCode

		--SELECT count(DISTINCT InpatientSID) FROM #Main a
		--SELECT count(DISTINCT InpatientSID) FROM #StageInpatientBedSection a
		--SELECT TOP 100 * FROM #StageInpatientBedsection ORDER BY InpatientSID,SpecialtyTransferDateTime

	DROP TABLE IF EXISTS #VInpatFinal
	SELECT s.*
		  ,ChecklistID = ISNULL(d.ChecklistID,convert(varchar,s.Sta3n))
	INTO #VInpatFinal
	FROM #VInpat s
	LEFT JOIN [LookUp].[Sta6a] d WITH (NOLOCK) on d.Sta6a=s.Sta6a
		 	
	--Clean up temp table usages
	DROP TABLE IF EXISTS #Main;
	DROP TABLE IF EXISTS #specialty;
	DROP TABLE IF EXISTS #SASMed1;
	DROP TABLE IF EXISTS #SASMed2;
	DROP TABLE IF EXISTS #SASMed3;
	DROP TABLE IF EXISTS #SASMed4;
	DROP TABLE IF EXISTS #inpat5;

	EXEC [Log].[ExecutionEnd] --VistA

/*******************************************************************
CERNER
*******************************************************************/
	EXEC [Log].[ExecutionBegin] 'EXEC Code.Inpatient_BedSection CDW2','Execution of Code.Inpatient_BedSection SP - Cerner/Millenium CDW2 data'

	DROP TABLE IF EXISTS #MillIP
	SELECT Census = CASE WHEN i.TZDischargeDateTime IS NULL THEN 1 ELSE 0 END --Not using EncounterStatus per Cerner call
		  ,i.MVIPersonSID
		  ,i.EncounterSID					as InpatientEncounterSID
		  ,i.PersonSID						as PatientPersonSID
		  ,i.TZDerivedAdmitDateTime			as AdmitDateTime 
		  ,i.TZDischargeDateTime			as DischargeDateTime
		  ,i.STAPA							as ChecklistID
		  ,i.DischargeDisposition			as PlaceOfDisposition
		  ,LEFT(admitdx.SourceIdentifier + ' ' + admitdx.SourceString,50) as AdmitDiagnosis
          ,prindx.SourceIdentifier			as ICD10Code
		  ,im.MedicalService
		  ,im.DerivedAccommodation as Accommodation
		  ,im.EncounterLocationHistorySID	as BedSectionRecordSID
		  ,im.DerivedCodeValueSID			as TreatingSpecialtySID
		  ,im.PTFCode
		  ,im.Specialty
		  ,im.Sta6a							as Sta6a
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
	WHERE i.DoDFlag=0 or i.Derived_VHA_Eligibility_Flag = 'Yes'

	EXEC [Log].[ExecutionEnd] --Cerner/Millenium


/*******************************************************************
COMBINE VISTA AND CERNER
*******************************************************************/
DROP TABLE IF EXISTS #InpatientUnion
SELECT *
	,LastRecord = CASE 
					WHEN ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY BsOutDateTime DESC,SpecialtyTransferDateTime DESC) = 1 
					THEN 1 ELSE 0 END	  
	,GETDATE() AS UpdateDate
INTO #InpatientUnion
FROM (
	SELECT MVIPersonSID
		  ,InpatientEncounterSID
		  ,PatientPersonSID
		  ,Census
		  ,AdmitDateTime
		  ,DischargeDateTime
		  ,MedicalService
		  ,Accommodation
		  ,TreatingSpecialtySID
		  ,PTFCode
		  ,Specialty
		  ,BSInDateTime
		  ,BSOutDateTime
		  ,BedSectionRecordSID
		  ,PlaceOfDisposition
		  ,PlaceOfDispositionCode		= NULL
		  ,AMA
		  ,AdmitDiagnosis
		  ,PrincipalDiagnosisICD10SID	= NULL
		  ,ICD10Code
		  ,PrincipalDiagnosisICD9SID	= NULL
		  ,SpecialtyTransferDateTime	
		  ,Sta6a
		  ,ChecklistID
		  ,DerivedBedSectionRecordSID = BedSectionRecordSID
		  ,Sta3n_EHR=200
	FROM #MillIP
	WHERE MVIPersonSID>0 --needed for SQL53 data referenced in OMHSP_PERC_CDSSbx
	UNION ALL
	SELECT MVIPersonSID
		  ,InpatientSID
		  ,PatientSID
		  ,Census
		  ,AdmitDateTime
		  ,DischargeDateTime
		  ,MedicalService = NULL
		  ,Accommodation = NULL
		  ,TreatingSpecialtySID
		  ,PTFCode
		  ,Specialty
		  ,BSInDateTime
		  ,BSOutDateTime
		  ,SpecialtyTransferSID
		  ,PlaceOfDisposition
		  ,PlaceOfDispositionCode
		  ,AMA
		  ,AdmitDiagnosis
		  ,PrincipalDiagnosisICD10SID
		  ,ICD10Code
		  ,PrincipalDiagnosisICD9SID
		  ,SpecialtyTransferDateTime
		  ,Sta6a
		  ,ChecklistID
		  ,DerivedBedSectionRecordSID
		  ,Sta3n
	FROM #VInpatFinal
	) u

	
EXEC [Maintenance].[PublishTable] 'Common.InpatientRecords','#InpatientUnion'
		
EXEC [Log].[ExecutionEnd]

END

/* DISPOSITIONS

SELECT DISTINCT DispositionType FROM [Inpat].[Inpatient] ORDER BY 1 

	--1:REGULAR
	--2:NBC OR WHILE ASIH (Absent Sick In Hospital)
	--3:EXPIRATION 6 MONTH LIMIT
	--4:IRREGULAR (Against Medical Advice)
	--5:TRANSFER
	--6:DEATH WITH AUTOPSY
	--7:DEATH WITHOUT AUTOPSY

SELECT DISTINCT PlaceOfDisposition,PlaceOfDispositionCode FROM Dim.PlaceOfDisposition WHERE PlaceOfDispositionCode IS NOT NULL and PlaceOfDispositionCode NOT LIKE '%*%' ORDER BY 1

SELECT DISTINCT DischargeDisposition,DischargeDispositionCD FROM App.CDW2_EncMill_Encounter  ORDER BY 1
SELECT DISTINCT DischargeToLocation,DischargeToLocationCD FROM App.CDW2_EncMill_Encounter  ORDER BY 1

*/

--SELECT * FROM Log.ExecutionLog ORDER BY 1 DESC