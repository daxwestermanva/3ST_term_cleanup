

CREATE PROCEDURE [Code].[SMI_PatientReport]
AS
/* ========================================================================
Author:		Claire Hannemann
Create date: 7/16/2021
Description:	Pulls in variables for display on SMI Loss to Care dashboard
Cohort definition: All living Veterans (excluding non-Veterans) with SMI (schizophrenia, bipolar or other psychoses) OP or IP diagnosis in prior 2 years. 
					  Do not include diagnoses from problem list.

MODIFICATIONS
	20210913	JEB	- Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Moved Publish tables to the very end; 
					  Added logging; Anchored dates within WHERE clauses so that results in a given day are repeatable
							   
	Testing execution:
		EXEC [Code].[SMI_PatientReport]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'Code.SMI_PatientReport'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE SchemaName = 'SMI' AND TableName = 'PatientReport' ORDER BY 1 DESC

  ======================================================================== */
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.SMI_PatientReport', @Description = 'Execution of Code.SMI_PatientReport SP'

	-- ==========================================================
	-- Pull in SMI cohort for dashboard
	-- ==========================================================
	--Cohort is created in Code.Present_ActivePatient under RequirementID='50'
	--Grab demographic and contact info from Common.MasterPatient
	DROP TABLE IF EXISTS #cohort
	SELECT 
		a.MVIPersonSID,
		b.PatientICN,
		b.LastName, 
		b.FirstName,
		b.PatientName,
		b.LastFour,
		b.Age,
		b.DisplayGender as Gender,
		b.Veteran,
		b.PossibleTestPatient,
		b.TestPatient,
		b.PhoneNumber,
		b.StreetAddress1,
		b.StreetAddress2,
		b.City,
		b.State,
		b.Zip,
		b.PercentServiceConnect,
		b.Homeless,
		ISNULL(c.ChecklistID,a.ChecklistID) AS Homestation_ChecklistID, --if homestation is null, fill in with ChecklistID of most recent SMI dx
		ISNULL(c.Sta3n_Loc,a.Sta3n_Loc) AS Sta3n
	INTO #cohort
	FROM 
		(
			SELECT MVIPersonSID, ChecklistID, Sta3n_Loc 
			FROM [Present].[ActivePatient] WITH (NOLOCK)
			WHERE RequirementID = 50
		) a --SMI cohort
	INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) 
		ON a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * 
			FROM [Present].[ActivePatient] WITH (NOLOCK)
			WHERE RequirementID = 1
		) c 
		ON a.MVIPersonSID = c.MVIPersonSID --homestation

	-- ==========================================================
	-- Qualifying diagnosis (schiz, bipolar, other psychoses)
	-- ==========================================================
	DROP TABLE IF EXISTS #Diagnosis 
	SELECT  
		mvi.MVIPersonSID
		,b.ICD10Description
		,CASE WHEN Schiz = 1 THEN 1 ELSE 0 END AS Schiz_dx
		,CASE WHEN Bipolar = 1 THEN 1 ELSE 0 END AS Bipolar_dx
		,CASE WHEN Schiz = 0 AND Bipolar = 0 THEN 1 ELSE 0 END AS OtherPsychoses_dx
		,a.VisitDateTime as Dx_date
	INTO #Diagnosis 
	FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.ICD10SID = b.ICD10SID
	WHERE (a.VisitDateTime >= DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND a.VisitDateTime < CAST(GETDATE() AS DATE))
		AND a.WorkloadLogicFlag = 'Y'
		AND b.SMI = 1

	UNION ALL
	SELECT  
		mvi.MVIPersonSID
		,b.ICD10Description
		,CASE WHEN Schiz = 1 THEN 1 ELSE 0 END AS Schiz_dx
		,CASE WHEN Bipolar = 1 THEN 1 ELSE 0 END AS Bipolar_dx
		,CASE WHEN Schiz = 0 AND Bipolar = 0 THEN 1 ELSE 0 END AS OtherPsychoses_dx
		,i.DischargeDateTime as Dx_date
	FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
	LEFT JOIN [Inpat].[Inpatient] i WITH (NOLOCK)
		ON a.InpatientSID=i.InpatientSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.ICD10SID = b.ICD10SID
	WHERE ((a.DischargeDateTime >= DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND a.DischargeDateTime < CAST(GETDATE() AS DATE)) OR a.DischargeDateTime IS NULL) 
		AND SMI = 1

	UNION ALL
	SELECT  
		mvi.MVIPersonSID
		,b.ICD10Description
		,CASE WHEN Schiz=1 THEN 1 ELSE 0 END AS Schiz_dx
		,CASE WHEN Bipolar=1 THEN 1 ELSE 0 END AS Bipolar_dx
		,CASE WHEN Schiz=0 AND Bipolar=0 THEN 1 ELSE 0 END AS OtherPsychoses_dx
		,i.DischargeDateTime as Dx_date
	FROM [Inpat].[InpatientDischargeDiagnosis] a WITH (NOLOCK)
	LEFT JOIN [Inpat].[Inpatient] i WITH (NOLOCK)
		ON a.InpatientSID=i.InpatientSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.[ICD10SID] = b.[ICD10SID]
	WHERE ((a.DischargeDateTime >= DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND a.DischargeDateTime < CAST(GETDATE() AS DATE)) OR a.DischargeDateTime IS NULL) 
		AND SMI=1

	UNION ALL
	SELECT  
		mvi.MVIPersonSID
		,b.ICD10Description
		,CASE WHEN Schiz=1 THEN 1 ELSE 0 END AS Schiz_dx
		,CASE WHEN Bipolar=1 THEN 1 ELSE 0 END AS Bipolar_dx
		,CASE WHEN Schiz=0 AND Bipolar=0 THEN 1 ELSE 0 END AS OtherPsychoses_dx
		,a.SpecialtyTransferDateTime as Dx_date
	FROM [Inpat].[SpecialtyTransferDiagnosis] a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.ICD10SID = b.ICD10SID
	WHERE ((a.SpecialtyTransferDateTime >= DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND a.SpecialtyTransferDateTime < CAST(GETDATE() AS DATE)) OR a.SpecialtyTransferDateTime IS NULL) 
	AND SMI = 1

	UNION ALL
	SELECT 
		a.MVIPersonSID
		,b.ICD10Description
		,CASE WHEN Schiz=1 THEN 1 ELSE 0 END AS Schiz_dx
		,CASE WHEN Bipolar=1 THEN 1 ELSE 0 END AS Bipolar_dx
		,CASE WHEN Schiz=0 AND Bipolar=0 THEN 1 ELSE 0 END AS OtherPsychoses_dx
		,a.TZDerivedDiagnosisDateTime as Dx_date
	FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
	INNER JOIN [LookUp].[ICD10] b WITH (NOLOCK) 
		ON a.NomenclatureSID = b.ICD10SID
	WHERE a.SourceVocabulary = 'ICD-10-CM' 
		AND a.MVIPersonSID>0
		AND (a.TZDerivedDiagnosisDateTime >= DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND a.TZDerivedDiagnosisDateTime < CAST(GETDATE() AS DATE))
		AND SMI = 1


	DROP TABLE IF EXISTS #Diagnosis_unique
	SELECT a.MVIPersonSID,
		b.Schiz_dx,
		case when b.Schiz_dx=1 and (b.Schiz_dx_date is NULL or b.Schiz_dx_date > getdate())  then cast(getdate() as date) else cast(b.Schiz_dx_date as date) end as Schiz_dx_date,
		c.Bipolar_dx,
		case when c.Bipolar_dx=1 and (c.Bipolar_dx_date is NULL or c.Bipolar_dx_date > getdate()) then cast(getdate() as date) else cast(c.Bipolar_dx_date as date) end as Bipolar_dx_date,
		d.OtherPsychoses_dx,
		case when d.OtherPsychoses_dx=1 and (d.OtherPsychoses_dx_date is NULL or d.OtherPsychoses_dx_date > getdate()) then cast(getdate() as date) else cast(d.OtherPsychoses_dx_date as date) end as OtherPsychoses_dx_date
	INTO #Diagnosis_unique
	FROM #cohort a
	LEFT JOIN (
				SELECT 
					MVIPersonSID
					,Schiz_dx
					,MAX(Dx_date) AS Schiz_dx_date
				FROM #Diagnosis 
				WHERE Schiz_dx=1
				GROUP BY MVIPersonSID, Schiz_dx
			 ) b
			 ON a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN (
				SELECT 
					MVIPersonSID
					,Bipolar_dx
					,MAX(Dx_date) AS Bipolar_dx_date
				FROM #Diagnosis 
				WHERE Bipolar_dx=1
				GROUP BY MVIPersonSID, Bipolar_dx
			 ) c 
			 ON a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN (
				SELECT 
					MVIPersonSID
					,OtherPsychoses_dx
					,MAX(Dx_date) AS OtherPsychoses_dx_date
				FROM #Diagnosis 
				WHERE OtherPsychoses_dx=1
				GROUP BY MVIPersonSID, OtherPsychoses_dx
			 ) d
			 ON a.MVIPersonSID=d.MVIPersonSID


	-- =========================================================================
	-- Upcoming appointments (PC, MH, Other)
	-- =========================================================================
	--Future appointments 
	DROP TABLE IF EXISTS #nextappt_any
	SELECT *
	,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY AppointmentDateTime) AS NextAppt_Any
	INTO #nextappt_any
	FROM SMI.AppointmentsFuture WITH (NOLOCK)

	DROP TABLE IF EXISTS #appointments
	SELECT 
		c.MVIPersonSID
		,pcf.AppointmentDateTime			AS PCFutureAppt_DateTime
		,pcf.PrimaryStopCode				AS PCFutureAppt_PrimaryStopCode
		,pcf.PrimaryStopCodeName			AS PCFutureAppt_PrimaryStopCodeName
		,pcf.ChecklistID					AS PCFutureAppt_ChecklistID
		,pcf.Facility						AS PCFutureAppt_Facility
		,pcf.ClinicName						AS PCFutureAppt_ClinicName
		,mhf.AppointmentDateTime			AS MHFutureAppt_DateTime
		,mhf.PrimaryStopCode				AS MHFutureAppt_PrimaryStopCode
		,mhf.PrimaryStopCodeName			AS MHFutureAppt_PrimaryStopCodeName
		,mhf.SecondaryStopCode				AS MHFutureAppt_SecondaryStopCode
		,mhf.SecondaryStopCodeName			AS MHFutureAppt_SecondaryStopCodeName
		,mhf.ChecklistID					AS MHFutureAppt_ChecklistID
		,mhf.Facility						AS MHFutureAppt_Facility
		,mhf.ClinicName						AS MHFutureAppt_ClinicName
		,oth.AppointmentDateTime			AS OtherFutureAppt_DateTime
		,oth.PrimaryStopCode				AS OtherFutureAppt_PrimaryStopCode
		,oth.PrimaryStopCodeName			AS OtherFutureAppt_PrimaryStopCodeName
		,oth.ChecklistID					AS OtherFutureAppt_ChecklistID
		,oth.Facility						AS OtherFutureAppt_Facility
		,oth.ClinicName						AS OtherFutureAppt_ClinicName
		,oth.MH_under10min					AS OtherFutureAppt_MH_under10min		
		,anyf.AppointmentDateTime			AS AnyFutureAppt_DateTime
		,anyf.PrimaryStopCode				AS AnyFutureAppt_PrimaryStopCode
		,anyf.PrimaryStopCodeName			AS AnyFutureAppt_PrimaryStopCodeName
		,anyf.SecondaryStopCode				AS AnyFutureAppt_SecondaryStopCode
		,anyf.SecondaryStopCodeName			AS AnyFutureAppt_SecondaryStopCodeName
		,anyf.ChecklistID					AS AnyFutureAppt_ChecklistID
		,anyf.Facility						AS AnyFutureAppt_Facility
		,anyf.ClinicName					AS AnyFutureAppt_ClinicName
	INTO #appointments
	FROM #cohort c
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsFuture] WITH (NOLOCK)
			WHERE ApptCategory = 'PCFuture'
		) pcf 
		ON pcf.MVIPersonSID = c.MVIPersonSID 
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsFuture] WITH (NOLOCK)
			WHERE ApptCategory = 'MHFuture' 
		) mhf 
		ON mhf.MVIPersonSID  =c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsFuture] WITH (NOLOCK)
			WHERE ApptCategory = 'OtherFuture' 
		) oth 
		ON oth.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM #nextappt_any
			WHERE NextAppt_Any = 1
		) anyf 
		ON anyf.MVIPersonSID = c.MVIPersonSID
	WHERE pcf.MVIPersonSID IS NOT NULL
		OR mhf.MVIPersonSID IS NOT NULL
		OR oth.MVIPersonSID IS NOT NULL
		OR anyf.MVIPersonSID IS NOT NULL

	-- =========================================================================
	-- Past encounters (PC, MH ,ED/urgent care, other), looking back one year 
	-- =========================================================================	
	--Outpatient encounters, ED visits and inpatient discharges in past year
	DROP TABLE IF EXISTS #mostrecent_any
	SELECT *
		,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC) AS MostRecent_Any
	INTO #mostrecent_any
	FROM SMI.AppointmentsPast WITH (NOLOCK)

	DROP TABLE IF EXISTS #cohort_visits
	SELECT 
		c.MVIPersonSID
		,pcv.VisitDateTime			AS PCRecentEnc_VisitDate
		,pcv.PrimaryStopCode		AS PCRecentEnc_PrimaryStopCode
		,pcv.PrimaryStopCodeName	AS PCRecentEnc_PrimaryStopCodeName
		,pcv.ChecklistID			AS PCRecentEnc_ChecklistID
		,pcv.Facility				AS PCRecentEnc_Facility
		,pcv.ClinicName				AS PCRecentEnc_ClinicName
		,pcv.Provider				As PCRecentEnc_Provider		
		,mhv.VisitDateTime			AS MHRecentEnc_VisitDate
		,mhv.PrimaryStopCode		AS MHRecentEnc_PrimaryStopCode
		,mhv.PrimaryStopCodeName	AS MHRecentEnc_PrimaryStopCodeName
		,mhv.SecondaryStopCode		AS MHRecentEnc_SecondaryStopCode
		,mhv.SecondaryStopCodeName	AS MHRecentEnc_SecondaryStopCodeName
		,mhv.ChecklistID			AS MHRecentEnc_ChecklistID
		,mhv.Facility				AS MHRecentEnc_Facility
		,mhv.ClinicName				AS MHRecentEnc_ClinicName
		,mhv.Provider				As MHRecentEnc_Provider	
		,ed.VisitDateTime			AS EDRecentEnc_VisitDate
		,ed.PrimaryStopCode			AS EDRecentEnc_PrimaryStopCode
		,ed.PrimaryStopCodeName		AS EDRecentEnc_PrimaryStopCodeName
		,ed.ChecklistID				AS EDRecentEnc_ChecklistID
		,ed.Facility				AS EDRecentEnc_Facility
		,ed.ClinicName				AS EDRecentEnc_ClinicName
		,ed.Provider				As EDRecentEnc_Provider	
		,oth.VisitDateTime			AS OtherRecentEnc_VisitDate
		,oth.PrimaryStopCode		AS OtherRecentEnc_PrimaryStopCode
		,oth.PrimaryStopCodeName	AS OtherRecentEnc_PrimaryStopCodeName
		,oth.ChecklistID			AS OtherRecentEnc_ChecklistID
		,oth.Facility				AS OtherRecentEnc_Facility
		,oth.ClinicName				AS OtherRecentEnc_ClinicName
		,oth.Provider				As OtherRecentEnc_Provider	
		,oth.MH_under10min			AS OtherRecentEnc_MH_under10min
		,anyv.VisitDateTime			AS AnyRecentEnc_VisitDate
		,anyv.PrimaryStopCode		AS AnyRecentEnc_PrimaryStopCode
		,anyv.PrimaryStopCodeName	AS AnyRecentEnc_PrimaryStopCodeName
		,anyv.SecondaryStopCode		AS AnyRecentEnc_SecondaryStopCode
		,anyv.SecondaryStopCodeName	AS AnyRecentEnc_SecondaryStopCodeName
		,anyv.ChecklistID			AS AnyRecentEnc_ChecklistID
		,anyv.Facility				AS AnyRecentEnc_Facility
		,anyv.ClinicName			AS AnyRecentEnc_ClinicName
		,anyv.Provider				As AnyRecentEnc_Provider	
		,inp.AdmitDateTime			AS IPAdmit_Date
		,inp.DischargeDateTime		AS IPDischarge_Date
		,inp.Census					AS CurrentlyAdmitted
		,inp.ChecklistID			AS IPDischarge_ChecklistID
		,inp.Facility				AS IPDischarge_Facility
		,inp.BedSectionName			AS IPDischarge_Bedsection
	INTO #cohort_visits
	FROM #cohort c
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsPast] WITH (NOLOCK)
			WHERE ApptCategory = 'PCRecent' 
		) pcv 
		ON pcv.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsPast] WITH (NOLOCK)
			WHERE ApptCategory = 'MHRecent' 
		) mhv 
		ON mhv.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsPast] WITH (NOLOCK)
			WHERE ApptCategory = 'EDRecent' 
		) ed 
		ON ed.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM [SMI].[AppointmentsPast] WITH (NOLOCK)
			WHERE ApptCategory = 'OtherRecent' 
		) oth 
		ON oth.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT * FROM #mostrecent_any
			WHERE MostRecent_Any = 1
		) anyv 
		ON anyv.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN 
		(
			SELECT MVIPersonSID,AdmitDateTime,DischargeDateTime,BedSectionName,Census,a.ChecklistID,b.Facility
			FROM [Inpatient].[BedSection] a WITH (NOLOCK)
			LEFT JOIN [LookUp].[ChecklistID] b WITH (NOLOCK)
				ON a.ChecklistID=b.ChecklistID
			WHERE a.LastRecord = 1
		) inp 
		ON inp.MVIPersonSID = c.MVIPersonSID

	--Create indicators for PC/MH/Other engagement parameter: months since last encounter (0-3, 3-6, 6-9, 9-12, 12+)
	-- 1: Most recent encounter was 0-3 months prior
	-- 2: Most recent encounter was 3-6 months prior
	-- 3: Most recent encounter was 6-9 months prior
	-- 4: Most recent encounter was 9-12 months prior
	-- 5: Most recent encounter was more than 12 months prior

	DROP TABLE IF EXISTS #cohort_visits2
	SELECT *
		--Primary care
		,CASE WHEN PCRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-3,GETDATE()) AND GETDATE() THEN 1
			  WHEN PCRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-6,GETDATE()) AND DATEADD(MONTH,-3,GETDATE()) THEN 2
			  WHEN PCRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-9,GETDATE()) AND DATEADD(MONTH,-6,GETDATE()) THEN 3
			  WHEN PCRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-12,GETDATE()) AND DATEADD(MONTH,-9,GETDATE()) THEN 4
			  ELSE 5 
			  END AS PC_Engagement
		--Mental Health
		,CASE WHEN MHRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-3,GETDATE()) AND GETDATE() THEN 1
			  WHEN MHRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-6,GETDATE()) AND DATEADD(MONTH,-3,GETDATE()) THEN 2
			  WHEN MHRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-9,GETDATE()) AND DATEADD(MONTH,-6,GETDATE()) THEN 3
			  WHEN MHRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-12,GETDATE()) AND DATEADD(MONTH,-9,GETDATE()) THEN 4
			  ELSE 5 
			  END AS MH_Engagement
		--Other
		,CASE WHEN OtherRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-3,GETDATE()) AND GETDATE() THEN 1
			  WHEN OtherRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-6,GETDATE()) AND DATEADD(MONTH,-3,GETDATE()) THEN 2
			  WHEN OtherRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-9,GETDATE()) AND DATEADD(MONTH,-6,GETDATE()) THEN 3
			  WHEN OtherRecentEnc_VisitDate BETWEEN DATEADD(MONTH,-12,GETDATE()) AND DATEADD(MONTH,-9,GETDATE()) THEN 4
			  ELSE 5 
			  END AS Other_Engagement
	INTO #cohort_visits2
	FROM #cohort_visits


	-- =====================================================================
	--Pull in ED, MH and ICMHR counts from SMI.AppointmentsPast 
	-- =====================================================================
	DROP TABLE IF EXISTS #counts
	SELECT DISTINCT MVIPersonSID,ED_counts_pastyear,MH_counts_pastyear,ICMHR_counts_90day 
	into #counts 
	FROM [SMI].[AppointmentsPast] WITH (NOLOCK)

	-- =====================================================================
	--Calculate number of unique mental health inpatient stays in past year
	-- =====================================================================
	DROP TABLE IF EXISTS #MH_IP
	SELECT DISTINCT 
		a.MVIPersonSID,InpatientEncounterSID,BsInDateTime,BsOutDateTime--, next_admitdate=LAG(BsInDateTime) OVER (PARTITION BY MVIPersonSID ORDER BY BsInDateTime desc) 
	INTO #MH_IP
	FROM [Inpatient].[BedSection] a WITH (NOLOCK)
	INNER JOIN [LookUp].[TreatingSpecialty] b WITH (NOLOCK)
		ON a.TreatingSpecialtySID = b.TreatingSpecialtySID
	WHERE (a.DischargeDateTime > DATEADD(MONTH,-12,CAST(GETDATE() AS DATE)) OR a.DischargeDateTime IS NULL) 
		AND (b.MentalHealth_TreatingSpecialty = 1 OR b.RRTP_TreatingSpecialty = 1)

	--Get rid of extra rows where a patient was transfered to a separate bedsection within the same IP stay
	DROP TABLE IF EXISTS #MH_IP2
	SELECT 
		*
		, LAG(BsInDateTime) OVER (PARTITION BY MVIPersonSID ORDER BY BsInDateTime DESC) AS Next_BsInDateTime
	INTO #MH_IP2
	FROM #MH_IP

	DELETE FROM #MH_IP2 WHERE CAST(BsOutDateTime AS DATE) = CAST(Next_BsInDateTime AS DATE)

	DROP TABLE IF EXISTS #MH_IP_Count
	SELECT MVIPersonSID, COUNT(MVIPersonSID) AS IP_MH_counts_pastyear
	INTO #MH_IP_Count
	FROM #MH_IP2
	GROUP BY MVIPersonSID

	-- ===========================
	-- PCP and MHTC providers
	-- ===========================	
	--for people with more than one provider (about 5%), first prioritize the provider at their homestation. If none exists then choose randomly which provider to display based on name.
	DROP TABLE IF EXISTS #PCP
	SELECT 
		a.*
		,ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID ORDER BY a.ChecklistID_match DESC, PCP_name) AS RN
	INTO #PCP
	FROM  
		(
			SELECT 
				a.MVIPersonSID
				,a.Homestation_ChecklistID
				,b.StaffName AS PCP_Name
				,b.ChecklistID AS PCP_ChecklistID
				,c.Facility AS PCP_Facility
				,CASE WHEN a.Homestation_ChecklistID = b.ChecklistID THEN 1 ELSE 0 END AS ChecklistID_match
			from #cohort a
			INNER JOIN [Present].[Provider_PCP] b WITH (NOLOCK)
				ON a.MVIPersonSID=b.MVIPersonSID
			INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK)
				ON b.ChecklistID=c.ChecklistID
		) a

	DROP TABLE IF EXISTS #MHTC
	SELECT 
		a.*
		,ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID ORDER BY a.ChecklistID_match desc, a.MHTC_name) AS RN
	INTO #MHTC
	FROM  
		(
			SELECT 
				a.MVIPersonSID
				,a.Homestation_ChecklistID
				,b.StaffName AS MHTC_Name
				,b.ChecklistID AS MHTC_ChecklistID
				,c.Facility AS MHTC_Facility
				,CASE WHEN a.Homestation_ChecklistID=b.ChecklistID THEN 1 ELSE 0 END AS ChecklistID_match
			FROM #cohort a
			INNER JOIN [Present].[Provider_MHTC] b WITH (NOLOCK)
				ON a.MVIPersonSID = b.MVIPersonSID
			INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK)
				ON b.ChecklistID=c.ChecklistID
		) a

	DROP TABLE IF EXISTS #providers
	SELECT 
		a.MVIPersonSID,
		b.PCP_Name,
		b.PCP_ChecklistID,
		b.PCP_Facility,
		c.MHTC_Name,
		c.MHTC_ChecklistID,
		c.MHTC_Facility
	INTO #providers
	FROM #cohort a
	LEFT JOIN (SELECT * FROM #PCP WHERE RN = 1) b ON a.MVIPersonSID = b.MVIPersonSID
	LEFT JOIN (SELECT * FROM #MHTC WHERE RN = 1) c ON a.MVIPersonSID = c.MVIPersonSID


	-- ===================================================
	-- High Risk Flag for suicide - active in past year
	-- ===================================================
	DROP TABLE IF EXISTS #hrf
	SELECT 
		c.MVIPersonSID 
		,a.OwnerChecklistID AS HRF_ChecklistID
		,b.Facility AS HRF_Facility
		,a.LastActionDateTime AS HRF_Date
		,a.LastActionDescription AS HRF_Status
	INTO #hrf 
	FROM #cohort c
	LEFT JOIN [PRF_HRS].[PatientReport_v02] a WITH (NOLOCK) 
		ON c.MVIPersonSID = a.MVIPersonSID--this table contains most recent HRF status for patients in past year
	LEFT JOIN [LookUp].[ChecklistID] b WITH (NOLOCK) 
		ON a.OwnerChecklistID = b.ChecklistID


	-- =================================================================================================
	--  Psychotropics and controlled substances with no pills on hand ("recently discontinued")
	-- =================================================================================================
	--Include the minimum days without pills on hand in each category and overall for easier sorting in the report.
	
	DROP TABLE IF EXISTS #RxTransitions1
	SELECT MVIPersonSID
			,RxCategory
			,PrescriberName
			,DaysWithNoPoH AS MinDaysWithNoPoH
	INTO #RxTransitions1
	FROM	(
			SELECT *
			,row_number() OVER(PARTITION BY MVIPersonSID, RxCategory ORDER BY DaysWithNoPOH) AS RN
			FROM [Present].[RxTransitionsMH] WITH (NOLOCK)
			WHERE NoPoH = 1 and DaysWithNoPoH >=0
			) a
	WHERE RN=1

	DROP TABLE IF EXISTS #RxTransitions2
	SELECT a.MVIPersonSID,
		   b.MinDaysWithNoPoH as RxTransitions_Antidepressant,
		   b.PrescriberName as RxTransitions_Antidepressant_Pr,
		   c.MinDaysWithNoPoH as RxTransitions_Antipsychotic,
		   c.PrescriberName as RxTransitions_Antipsychotic_Pr,
		   d.MinDaysWithNoPoH as RxTransitions_Benzodiazepine,
		   d.PrescriberName as RxTransitions_Benzodiazepine_Pr, 
		   e.MinDaysWithNoPoH as RxTransitions_Stimulant,
		   e.PrescriberName as RxTransitions_Stimulant_Pr,
		   f.MinDaysWithNoPoH as RxTransitions_MoodStabilizer,
		   f.PrescriberName as RxTransitions_MoodStabilizer_Pr,
		   g.MinDaysWithNoPoH as RxTransitions_Sedative_zdrug,
		   g.PrescriberName as RxTransitions_Sedative_zdrug_Pr,
		   h.MinDaysWithNoPoH as RxTransitions_OpioidAgonist,
		   h.PrescriberName as RxTransitions_OpioidAgonist_Pr,
		   i.MinDaysWithNoPoH as RxTransitions_OpioidForPain,
		   i.PrescriberName as RxTransitions_OpioidForPain_Pr,
		   j.MinDaysWithNoPoH as RxTransitions_OtherControlledSub,
		   j.PrescriberName as RxTransitions_OtherControlledSub_Pr,
		   a.MinDays AS RxTransitions_MinDaysForSorting
	INTO #RxTransitions2
	FROM 
			  (
				SELECT MVIPersonSID
					,MIN(MinDaysWithNoPoH) AS MinDays
				FROM #RxTransitions1 WITH (NOLOCK)
				GROUP BY MVIPersonSID
			  )  a
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='Antidepressant_Rx'
			  ) b 
			   ON a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='Antipsychotic_Rx'
			  ) c
			   ON a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='Benzodiazepine_Rx'
			  ) d
			   ON a.MVIPersonSID=d.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='Stimulant_Rx'
			  ) e
			   ON a.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='MoodStabilizer_Rx'
			  ) f
			   ON a.MVIPersonSID=f.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='Sedative_zdrug_Rx'
			  ) g
			   ON a.MVIPersonSID=g.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='OpioidAgonist_Rx'
			  ) h
			   ON a.MVIPersonSID=h.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='OpioidForPain_Rx'
			  ) i
			   ON a.MVIPersonSID=i.MVIPersonSID
	LEFT JOIN (
				SELECT *
				FROM #RxTransitions1 
				WHERE RxCategory='OtherControlledSub_Rx'
			  ) j
			   ON a.MVIPersonSID=j.MVIPersonSID



	-- ===================================================
	-- Combine all
	-- ===================================================
	DROP TABLE IF EXISTS #SMI_PatientReport
	SELECT 
		co.MVIPersonSID
		,co.PatientICN
		,co.LastName 
		,co.FirstName
		,co.PatientName
		,co.LastFour
		,co.Age
		,co.Gender
		,co.Veteran
		,co.PossibleTestPatient
		,co.TestPatient
		,co.PhoneNumber
		,co.StreetAddress1
		,co.StreetAddress2
		,co.City
		,co.State
		,co.Zip
		,co.PercentServiceConnect
		,co.Homeless
		,co.Homestation_ChecklistID
		,co.Sta3n
		,dx.Schiz_dx
		,dx.Schiz_dx_date
		,dx.Bipolar_dx
		,dx.Bipolar_dx_date
		,dx.OtherPsychoses_dx
		,dx.OtherPsychoses_dx_date
		,app.PCFutureAppt_DateTime
		,app.PCFutureAppt_PrimaryStopCode
		,app.PCFutureAppt_PrimaryStopCodeName
		,app.PCFutureAppt_ChecklistID
		,app.PCFutureAppt_Facility
		,app.PCFutureAppt_ClinicName
		,app.MHFutureAppt_DateTime
		,app.MHFutureAppt_PrimaryStopCode
		,app.MHFutureAppt_PrimaryStopCodeName
		,app.MHFutureAppt_SecondaryStopCode
		,app.MHFutureAppt_SecondaryStopCodeName
		,app.MHFutureAppt_ChecklistID
		,app.MHFutureAppt_Facility
		,app.MHFutureAppt_ClinicName
		,CASE WHEN app.MHFutureAppt_PrimaryStopCode NOT BETWEEN '500' AND '599' AND app.MHFutureAppt_PrimaryStopCode NOT IN ('156','157') 
			AND (app.MHFutureAppt_SecondaryStopCode BETWEEN '500' AND '599' OR app.MHFutureAppt_SecondaryStopCode IN ('156','157')) THEN 1 END AS MHFutureAppt_SecondaryOnly
		,app.OtherFutureAppt_DateTime
		,app.OtherFutureAppt_PrimaryStopCode
		,app.OtherFutureAppt_PrimaryStopCodeName
		,app.OtherFutureAppt_ChecklistID
		,app.OtherFutureAppt_Facility
		,app.OtherFutureAppt_ClinicName
		,app.OtherFutureAppt_MH_under10min
		,app.AnyFutureAppt_DateTime
		,app.AnyFutureAppt_PrimaryStopCode
		,app.AnyFutureAppt_PrimaryStopCodeName
		,app.AnyFutureAppt_SecondaryStopCode
		,app.AnyFutureAppt_SecondaryStopCodeName
		,app.AnyFutureAppt_ChecklistID
		,app.AnyFutureAppt_Facility
		,app.AnyFutureAppt_ClinicName
		,v.PCRecentEnc_VisitDate
		,v.PCRecentEnc_PrimaryStopCode
		,v.PCRecentEnc_PrimaryStopCodeName
		,v.PCRecentEnc_ChecklistID
		,v.PCRecentEnc_Facility
		,v.PCRecentEnc_ClinicName
		,v.PCRecentEnc_Provider
		,v.MHRecentEnc_VisitDate
		,v.MHRecentEnc_PrimaryStopCode
		,v.MHRecentEnc_PrimaryStopCodeName
		,v.MHRecentEnc_SecondaryStopCode
		,v.MHRecentEnc_SecondaryStopCodeName
		,v.MHRecentEnc_ChecklistID
		,v.MHRecentEnc_Facility
		,v.MHRecentEnc_ClinicName
		,v.MHRecentEnc_Provider
		,CASE WHEN v.MHRecentEnc_PrimaryStopCode NOT BETWEEN '500' AND '599' AND v.MHRecentEnc_PrimaryStopCode NOT IN ('156','157') 
			AND (v.MHRecentEnc_SecondaryStopCode BETWEEN '500' AND '599' OR v.MHRecentEnc_SecondaryStopCode IN ('156','157')) THEN 1 END AS MHRecentEnc_SecondaryOnly
		,v.EDRecentEnc_VisitDate
		,v.EDRecentEnc_PrimaryStopCode
		,v.EDRecentEnc_PrimaryStopCodeName
		,v.EDRecentEnc_ChecklistID
		,v.EDRecentEnc_Facility
		,v.EDRecentEnc_ClinicName
		,v.EDRecentEnc_Provider
		,v.OtherRecentEnc_VisitDate
		,v.OtherRecentEnc_PrimaryStopCode
		,v.OtherRecentEnc_PrimaryStopCodeName
		,v.OtherRecentEnc_ChecklistID
		,v.OtherRecentEnc_Facility
		,v.OtherRecentEnc_ClinicName
		,v.OtherRecentEnc_Provider
		,v.OtherRecentEnc_MH_under10min
		,v.AnyRecentEnc_VisitDate
		,v.AnyRecentEnc_PrimaryStopCode
		,v.AnyRecentEnc_PrimaryStopCodeName
		,v.AnyRecentEnc_SecondaryStopCode
		,v.AnyRecentEnc_SecondaryStopCodeName
		,v.AnyRecentEnc_ChecklistID
		,v.AnyRecentEnc_Facility
		,v.AnyRecentEnc_ClinicName
		,v.AnyRecentEnc_Provider
		,v.PC_Engagement
		,v.MH_Engagement
		,v.Other_Engagement
		,CASE WHEN v.PC_Engagement =5 or v.MH_Engagement >= 3 then 2 --red
			  WHEN v.PC_Engagement =4 or v.MH_Engagement =2 then 1 --orange, have this set to come up first for sorting
			  ELSE 3 END AS Color_Coding --white
		,v.IPAdmit_Date
		,v.IPDischarge_Date
		,v.CurrentlyAdmitted
		,v.IPDischarge_ChecklistID
		,v.IPDischarge_Facility
		,v.IPDischarge_Bedsection
		,cnt.ED_counts_pastyear
		,cnt.MH_counts_pastyear
		,cnt.ICMHR_counts_90day
		,mh_ip.IP_MH_counts_pastyear
		,p.PCP_Name
		,p.PCP_ChecklistID
		,p.PCP_Facility
		,p.MHTC_Name
		,p.MHTC_ChecklistID
		,p.MHTC_Facility
		,hrf.HRF_ChecklistID
		,hrf.HRF_Facility
		,hrf.HRF_Date
		,hrf.HRF_Status
		,rx.RxTransitions_Antidepressant
		,rx.RxTransitions_Antipsychotic
		,rx.RxTransitions_Benzodiazepine
		,rx.RxTransitions_MoodStabilizer
		,rx.RxTransitions_OpioidAgonist
		,rx.RxTransitions_OpioidForPain
		,rx.RxTransitions_OtherControlledSub
		,rx.RxTransitions_Sedative_zdrug
		,rx.RxTransitions_Stimulant
		,rx.RxTransitions_Antidepressant_Pr
		,rx.RxTransitions_Antipsychotic_Pr
		,rx.RxTransitions_Benzodiazepine_Pr
		,rx.RxTransitions_MoodStabilizer_Pr
		,rx.RxTransitions_OpioidAgonist_Pr
		,rx.RxTransitions_OpioidForPain_Pr
		,rx.RxTransitions_OtherControlledSub_Pr
		,rx.RxTransitions_Sedative_zdrug_Pr
		,rx.RxTransitions_Stimulant_Pr
		,rx.RxTransitions_MinDaysForSorting
	INTO #SMI_PatientReport
	FROM #cohort co
	LEFT JOIN #Diagnosis_unique dx ON co.MVIPersonSID = dx.MVIPersonSID
	LEFT JOIN #appointments app ON co.MVIPersonSID = app.MVIPersonSID
	LEFT JOIN #cohort_visits2 v ON co.MVIPersonSID = v.MVIPersonSID
	LEFT JOIN #counts cnt ON co.MVIPersonSID = cnt.MVIPersonSID
	LEFT JOIN #MH_IP_Count mh_ip ON co.MVIPersonSID = mh_ip.MVIPersonSID
	LEFT JOIN #providers p ON co.MVIPersonSID = p.MVIPersonSID
	LEFT JOIN #hrf hrf ON co.MVIPersonSID = hrf.MVIPersonSID
	LEFT JOIN #RxTransitions2 rx ON co.MVIPersonSID = rx.MVIPersonSID

	EXEC [Maintenance].[PublishTable] 'SMI.PatientReport','#SMI_PatientReport'
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END