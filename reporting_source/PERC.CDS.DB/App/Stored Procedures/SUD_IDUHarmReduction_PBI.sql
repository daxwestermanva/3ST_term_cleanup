-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <2/13/23>
-- Description:	SUD PowerBI - Prescriptions for IVDU patients
--
-- 9/16/2024    CW  Adding testing for Hep C and HIV (includes non positive/non reactive test results)
-- 12/30/2024   CW  Adding in Demo patients
--
-- =============================================
CREATE   PROCEDURE [App].[SUD_IDUHarmReduction_PBI]

AS
BEGIN
	SET NOCOUNT ON;
 
	DROP TABLE IF EXISTS #IDVUCohort
	SELECT DISTINCT MVIPersonSID
	INTO #IDVUCohort
	FROM SUD.IDUCohort WITH (NOLOCK);

	DROP TABLE IF EXISTS #HepC	
	SELECT DISTINCT b.MVIPersonSID
		,s.CheckListID
		,MedicationType='Hep C Test' --maintaining MedicationType naming convention to keep report intact
		,ReleaseDateTime=d.Date --maintaining ReleaseDateTime naming convention to keep report intact
	INTO #HepC
	FROM PDW.SCS_HLIRC_DOEx_HepCLabAllPtAllTime a WITH (NOLOCK)
	INNER JOIN Common.MasterPatient b WITH (NOLOCK) on a.PatientICN=b.PatientICN
	INNER JOIN #IDVUCohort c on b.MVIPersonSID=c.MVIPersonSID
	INNER JOIN Dim.Date d WITH (NOLOCK) on a.LabChemSpecimenDateSID=d.DateSID
	INNER JOIN Lookup.StationColors as s WITH (NOLOCK) on cast(a.sta3n as varchar(5)) = s.CheckListID
	WHERE d.Date >= getdate() - 1825;

	DROP TABLE IF EXISTS #HIV
	SELECT DISTINCT c.MVIPersonSID
		,d.ChecklistID
		,MedicationType='HIV Test' --maintaining MedicationType naming convention to keep report intact
		,ReleaseDateTime=LabChemCompleteDateTime --maintaining ReleaseDateTime naming convention to keep report intact
	INTO #HIV
	FROM PDW.PCS_LABMed_DOEx_HIV a WITH (NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID b WITH (NOLOCK) on a.PatientSID=b.PatientPersonSID
	INNER JOIN #IDVUCohort c on b.MVIPersonSID=c.MVIPersonSID
	INNER JOIN LookUp.DivisionFacility d WITH (NOLOCK) on a.Sta6a=d.Sta6a
	WHERE LabChemCompleteDateTime >= getdate() - 1825;


	--Final table
	SELECT a.MVIPersonSID, ChecklistID, MedicationType, ReleaseDateTime
	FROM #IDVUCohort a
	INNER JOIN SUD.IDU_Rx b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE MedicationType <> 'Other Harm Reduction' --not being used in PowerBI report at this time, so removing
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, MedicationType, ReleaseDateTime
	FROM #HepC
	
	UNION
	
	SELECT MVIPersonSID, ChecklistID, MedicationType, ReleaseDateTime
	FROM #HIV

	UNION

	SELECT MVIPersonSID, ChecklistID, MedicationType=
		CASE WHEN mv.MVIPersonSID=13066049 THEN 'MOUD' --Needs Review (demo)
			 WHEN mv.MVIPersonSID=9279280 THEN 'Naloxone' --Confirmed IDU (demo)
			 WHEN mv.MVIPersonSID=9415243 THEN 'Syringe' --Removed (demo)
			 END
		,ReleaseDateTime=CAST('8/22/1864' as date)
	FROM Common.MasterPatient mv  WITH (NOLOCK)
	INNER JOIN LookUp.ChecklistID c1 WITH (NOLOCK) 
		ON 1=1 and len(c1.ChecklistID) >=3
	WHERE mv.mvipersonsid IN (13066049, 9279280, 9415243);
	
 
END