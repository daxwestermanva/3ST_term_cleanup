
CREATE VIEW [App].[vwCDW_Chem_PatientLabChem]
AS  -- View: Chem.PatientLabChem_v005, Table: Chem.LabChem_v081
/*-------------------------------------------------------------------------------------------------------
2021/09/15	JEB		Enclave Refactoring 
-------------------------------------------------------------------------------------------------------*/
SELECT 
	a.LabChemSID AS LabChemSID
	--, a.LRDFN AS LRDFN
	--, a.LabSubjectSID AS LabSubjectSID
	, a.Sta3n AS Sta3n
	--, a.LabPanelIEN AS LabPanelIEN
	--, a.LabPanelSID AS LabPanelSID
	--, a.LabChemFieldNumber AS LabChemFieldNumber
	--, a.ShortAccessionNumber AS ShortAccessionNumber
	--, a.LongAccessionNumberUID AS LongAccessionNumberUID
	--, a.HostLongAccessionNumberUID AS HostLongAccessionNumberUID
	--, a.CollectingLongAccessionNumberUID AS CollectingLongAccessionNumberUID
	, a.LabChemTestSID AS LabChemTestSID
	, a.PatientSID AS PatientSID
	, a.LabChemSpecimenDateTime AS LabChemSpecimenDateTime
	--, a.LabChemSpecimenVistaErrorDate AS LabChemSpecimenVistaErrorDate
	--, a.LabChemSpecimenDateTimeTransformSID AS LabChemSpecimenDateTimeTransformSID
	--, a.LabChemSpecimenDateSID AS LabChemSpecimenDateSID
	--, a.SpecimenDateInexactFlag AS SpecimenDateInexactFlag
	, a.LabChemCompleteDateTime AS LabChemCompleteDateTime
	--, a.LabChemCompleteVistaErrorDate AS LabChemCompleteVistaErrorDate
	--, a.LabChemCompleteDateTimeTransformSID AS LabChemCompleteDateTimeTransformSID
	--, a.LabChemCompleteDateSID AS LabChemCompleteDateSID
	, a.LabChemResultValue AS LabChemResultValue
	, a.LabChemResultNumericValue AS LabChemResultNumericValue
	, a.TopographySID AS TopographySID
	--, a.RequestingStaffSID AS RequestingStaffSID
	--, a.RequestingLocationSID AS RequestingLocationSID
	--, a.RequestingInstitutionSID AS RequestingInstitutionSID
	--, a.OrderingInstitutionSID AS OrderingInstitutionSID
	--, a.CollectingInstitutionSID AS CollectingInstitutionSID
	--, a.AccessionInstitutionSID AS AccessionInstitutionSID
	, a.LOINCSID AS LOINCSID
	, a.Units AS Units
	, a.Abnormal AS Abnormal
	--, a.RefHigh AS RefHigh
	--, a.RefLow AS RefLow
FROM [Chem].[LabChem] a WITH (NOLOCK)
WHERE 1=1 AND PatientSID NOT IN (0, -1)
	-- Automatic filtering:
	--AND a.OpCode <> 'X' -- Always filter out OpCode = X 
	--AND a.OpCode <> 'D' -- Filter for Work and PDWNext views