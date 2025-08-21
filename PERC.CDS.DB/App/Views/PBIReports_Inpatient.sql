


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Inpatient]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Inpatient] AS

	WITH InpatientPrep AS (
	SELECT DISTINCT a.MVIPersonSID
		,a.AMA AS AMADischarge
		,Census=CAST(a.Census as int)
		,DischargeDate=CAST(a.DischargeDateTime as date)
		,AdmitDate=CAST(a.AdmitDateTime as date)
		,InpatientType=
			CASE WHEN a.MentalHealth_TreatingSpecialty = 1 THEN 'Acute MH Inpatient'
		 		 WHEN a.RRTP_TreatingSpecialty=1 THEN 'MH Residential'
				 WHEN a.MedSurgInpatient_TreatingSpecialty = 1 THEN 'Inpatient Medical/Surgical'
				 WHEN a.NursingHome_TreatingSpecialty=1 THEN 'Nursing Home'
			END
		,a.BedSectionName
		,AdmitDx=CONCAT('(',a.ICD10Code,') ',i.ICD10Description)
		,a.ChecklistID AS ChecklistID_Discharge
		,l.Facility
		,l.Code
		,a.PlaceOfDisposition
	FROM [Inpatient].[Bedsection] a WITH (NOLOCK)
	INNER JOIN [Common].[PBIReportsCohort] c WITH (NOLOCK)
		ON c.MVIPersonSID=a.MVIPersonSID
	INNER JOIN [Lookup].StationColors as l WITH (NOLOCK) 
		ON a.ChecklistID = l.ChecklistID
	LEFT JOIN LookUp.ICD10 i WITH (NOLOCK)
		ON a.PrincipalDiagnosisICD10SID=i.ICD10SID
	WHERE a.Census=1 OR (a.DischargeDateTime > DATEADD(year,-5,cast(getdate() as date)))
	),
	Inpatient AS (
	SELECT TOP (1) WITH TIES *, InptDates=CONCAT(FORMAT(AdmitDate, 'M/d/yyyy'), ' - ', FORMAT(DischargeDate,'M/d/yyyy'))
	FROM InpatientPrep
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, InpatientType ORDER BY Census DESC, DischargeDate DESC)
	)
	SELECT MVIPersonSID
		,AMADischarge
		,Census
		,DischargeDate
		,AdmitDate
		,InpatientType
		,BedSectionName
		,AdmitDx
		,ChecklistID_Discharge
		,Facility
		,Code
		,PlaceOfDisposition
		,InptDates
	FROM Inpatient

	UNION

	SELECT MVIPersonSID
		,AMADischarge
		,Census
		,DischargeDate
		,AdmitDate
		,InpatientType
		,BedSectionName
		,AdmitDx
		,ChecklistID
		,Facility
		,Code
		,PlaceOfDisposition
		,InptDates
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)