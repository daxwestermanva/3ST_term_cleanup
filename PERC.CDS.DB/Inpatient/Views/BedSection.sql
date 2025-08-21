




/*
	20210107	RAS	Removed DispositionType per source table and code changes.
	20220427	EC	Added PlaceOfDispositionCode and cast AMA and treating specialty flags as tinyint
					for use in PDE code.
	20220517	RAS	Refactored WHERE clause to use DerivedBedSectionRecordSID instead of UniqueBedEpisode
*/

CREATE VIEW [Inpatient].[BedSection]
AS

SELECT i.MVIPersonSID
	  ,i.InpatientEncounterSID
	  ,i.PatientPersonSID
	  ,Census = CASE --mark most recent bedsection only as census record
			WHEN i.Census=1 AND i.LastRecord=1 
			THEN 1 ELSE 0 END
	  ,i.AdmitDateTime
	  ,i.DischargeDateTime
	  ,i.MedicalService
	  ,i.Accommodation
	  ,i.DerivedBedSectionRecordSID
	  ,BedSection = ts.PTFCode
	  ,BedSectionName = ts.Specialty
	  ,i.BsInDateTime
	  ,i.BsOutDateTime
	  ,i.PrincipalDiagnosisICD10SID
	  ,i.ICD10Code
	  ,i.PrincipalDiagnosisICD9SID
	  ,i.AdmitDiagnosis
	  ,i.PlaceOfDisposition
	  ,i.PlaceOfDispositionCode
	  ,AMA = CAST(i.AMA AS INT) 
	  ,i.Sta6a
	  ,i.ChecklistID
	  ,i.LastRecord
	  ,i.UpdateDate
	  ,ts.TreatingSpecialtySID
	  ,MedSurgInpatient_TreatingSpecialty = CAST(ts.MedSurgInpatient_TreatingSpecialty AS TINYINT) 
	  ,MentalHealth_TreatingSpecialty = CAST(ts.MentalHealth_TreatingSpecialty AS TINYINT) 
	  ,RRTP_TreatingSpecialty = CAST(ts.RRTP_TreatingSpecialty AS TINYINT) 
	  ,NursingHome_TreatingSpecialty = CAST(ts.NursingHome_TreatingSpecialty AS TINYINT) 
	  ,Homeless_TreatingSpecialty = CAST(ts.Homeless_TreatingSpecialty AS TINYINT) 
	  ,i.Sta3n_EHR
FROM [Common].[InpatientRecords] i WITH (NOLOCK)
INNER JOIN [LookUp].[TreatingSpecialty] ts WITH (NOLOCK) ON ts.TreatingSpecialtySID = i.TreatingSpecialtySID
WHERE i.BedSectionRecordSID = i.DerivedBedSectionRecordSID -- not showing repeating bedsection stays