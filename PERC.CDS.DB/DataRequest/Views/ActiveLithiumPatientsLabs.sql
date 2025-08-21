CREATE VIEW [DataRequest].[ActiveLithiumPatientsLabs]
AS
	SELECT DISTINCT a.Patientsid, a.patienticn, a.drugnamewithoutdose, b.LabChemTestName, MAX(c.LabChemSpecimenDateTime) AS maxlabdate
	FROM [DataRequest].[LithiumActivePatients] a WITH (NOLOCK)
	LEFT OUTER JOIN [Chem].[LabChem] c WITH (NOLOCK)
		ON a.Patientsid = c.PatientSID 
	INNER JOIN [Dim].[LabChemTest] b WITH (NOLOCK)
		ON c.LabChemTestSID = b.LabChemTestSID
	WHERE (b.LabChemTestName LIKE '%lithium%') AND (c.LabChemSpecimenDateTime >= GETDATE() - 370)
	GROUP BY a.Patientsid, a.patienticn, a.drugnamewithoutdose, b.LabChemTestName
GO
