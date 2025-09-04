
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Dataset for information related to inpatient admissions and discharges in the Suicide
--				Behavior and Overdose Summary Report. One to Many relationship with 
--				[App].[SBOSR_SDVDetails] in the report. To be used in PowerBI visuals (Clinical/Case 
--				Factors).
--
--				No row duplication expected in this dataset.		
--				
-- Modifications:
-- 07-13-2023  CW  Adding in most recent discharge date per conversation with Field Ops.
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SBOSR_Inpatient_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	--SBOSR cohort
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID, PatientKey
	INTO #Cohort
	FROM SBOSR.SDVDetails_PBI

	-----------------------------------------------------------------------------
	--Inpatient information
	-----------------------------------------------------------------------------
	--Get the location of Veterans who are currently admitted
	DROP TABLE IF EXISTS #CurrentlyAdmitted
	SELECT
		 MVIPersonSID
		,CONCAT(InpatientType, ' (',BedSectionName,')') AS InpatientLocation
		,CurrentlyAdmitted
	INTO #CurrentlyAdmitted
	FROM (
			SELECT DISTINCT 
				 a.MVIPersonSID
				,CurrentlyAdmitted=1
				,CASE WHEN a.MentalHealth_TreatingSpecialty = 1 THEN 'Acute MH Inpatient'
					  WHEN a.RRTP_TreatingSpecialty=1 THEN 'MH Residential'
					  WHEN a.MedSurgInpatient_TreatingSpecialty = 1 THEN 'Inpatient Medical/Surgical'
					  WHEN a.NursingHome_TreatingSpecialty=1 THEN 'Nursing Home'
				 END AS InpatientType
				,CASE WHEN a.BedSectionName IN ('HIGH INTENSITY GEN INPT','High Intensity Gen Mental Health Inpat','HIGH INTENSITY GEN PSYCH INPAT') THEN 'HIGH INTENSITY GEN PSYCH'
					  WHEN a.BedSectionName IN ('GEN INTERMEDIATE PSYCH') THEN 'INTERMEDIATE GEN PSYCH'
					  WHEN a.BedSectionName IN ('CARDIAC-STEP DOWN UNIT') THEN 'CARDIAC STEP DOWN UNIT'
					  WHEN a.BedSectionName IN ('EAR, NOSE, THROAT (ENT)') THEN 'EAR, NOSE, THROAT'
					  WHEN a.BedSectionName IN ('GEN MEDICINE (ACUTE)','General (Acute Medicine)','GENERAL(ACUTE MEDICINE)') THEN 'GENERAL (ACUTE MEDICINE)'
					  WHEN a.BedSectionName IN ('General Domiciliary','DOMICILIARY GENERAL') THEN 'DOMICILIARY'
				 ELSE UPPER(a.BedSectionName) END AS BedSectionName
			FROM [Inpatient].[Bedsection] a WITH (NOLOCK)
			INNER JOIN #Cohort p 
				ON p.MVIPersonSID=a.MVIPersonSID
			WHERE (a.MentalHealth_TreatingSpecialty = 1 OR 
				   a.RRTP_TreatingSpecialty=1 OR 
				   a.MedSurgInpatient_TreatingSpecialty = 1 OR
				   a.NursingHome_TreatingSpecialty=1) AND
				   a.Census=1
		   ) Src;

	--Get the location of Veterans most recent discharge
	DROP TABLE IF EXISTS #DischargeLocation
	SELECT *
	INTO #DischargeLocation
	FROM (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY MostRecentDischargeDate, InpatientLocation) RN --In case they were discharged from more than one location in a given day
		FROM (
			SELECT *, CONCAT(InpatientType, ' (',BedSectionName,')') AS InpatientLocation
			FROM (
				SELECT DISTINCT 
					 a.MVIPersonSID
					,MAX(CAST(a.DischargeDateTime AS DATE)) MostRecentDischargeDate
					,DischargePastYr=1
					,CASE WHEN a.MentalHealth_TreatingSpecialty = 1 THEN 'Acute MH Inpatient'
							WHEN a.RRTP_TreatingSpecialty=1 THEN 'MH Residential'
							WHEN a.MedSurgInpatient_TreatingSpecialty = 1 THEN 'Inpatient Medical/Surgical'
							WHEN a.NursingHome_TreatingSpecialty=1 THEN 'Nursing Home'
						END AS InpatientType
					,CASE WHEN a.BedSectionName IN ('HIGH INTENSITY GEN INPT','High Intensity Gen Mental Health Inpat','HIGH INTENSITY GEN PSYCH INPAT') THEN 'HIGH INTENSITY GEN PSYCH'
							WHEN a.BedSectionName IN ('GEN INTERMEDIATE PSYCH') THEN 'INTERMEDIATE GEN PSYCH'
							WHEN a.BedSectionName IN ('CARDIAC-STEP DOWN UNIT') THEN 'CARDIAC STEP DOWN UNIT'
							WHEN a.BedSectionName IN ('EAR, NOSE, THROAT (ENT)') THEN 'EAR, NOSE, THROAT'
							WHEN a.BedSectionName IN ('GEN MEDICINE (ACUTE)','General (Acute Medicine)','GENERAL(ACUTE MEDICINE)') THEN 'GENERAL (ACUTE MEDICINE)'
							WHEN a.BedSectionName IN ('General Domiciliary','DOMICILIARY GENERAL') THEN 'DOMICILIARY'
						ELSE UPPER(a.BedSectionName) END AS BedSectionName
				FROM [Inpatient].[Bedsection] a WITH (NOLOCK)
				INNER JOIN #Cohort p 
					ON p.MVIPersonSID=a.MVIPersonSID
				WHERE (a.MentalHealth_TreatingSpecialty = 1 OR 
						a.RRTP_TreatingSpecialty=1 OR 
						a.MedSurgInpatient_TreatingSpecialty = 1 OR
						a.NursingHome_TreatingSpecialty=1) AND
						a.Census=0 AND
						CAST(a.DischargeDateTime AS DATE) >= DATEADD(DAY, -366, GETDATE()) --Most recent discharge within past year
				GROUP BY a.MVIPersonSID,a.DischargeDateTime,a.MentalHealth_TreatingSpecialty,a.RRTP_TreatingSpecialty,a.MedSurgInpatient_TreatingSpecialty,a.NursingHome_TreatingSpecialty,a.BedSectionName
					) Src
				) Src2
			) Src3
	WHERE RN=1;

	-----------------------------------------------------------------------------
	--Combine for final table
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #InpatientDetails
	SELECT DISTINCT
		 c.PatientKey
		,c.MVIPersonSID
		,d.MostRecentDischargeDate
		,CASE WHEN a.CurrentlyAdmitted=1 THEN 1 ELSE 0 END CurrentlyAdmitted
		,a.InpatientLocation AdmitLocation
		,CASE WHEN d.DischargePastYr=1 THEN 1 ELSE 0 END DischargePastYr
		,d.InpatientLocation as DischargeLocation
	INTO #InpatientDetails
	FROM #Cohort c
	LEFT JOIN #CurrentlyAdmitted a ON c.MVIPersonSID=a.MVIPersonSID
	LEFT JOIN #DischargeLocation d ON c.MVIPersonSID=d.MVIPersonSID

	SELECT *
	FROM #InpatientDetails

	END