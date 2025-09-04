
SELECT a.MVIPersonSID
	,e.StaPa AS ChecklistID
	,a.TargetClass
	,a.SubclassLabel
	,a.Term
	,a.ReferenceDateTime
	,b.EntryDateTime
	,a.TIUStandardTitle
	,c.TIUDocumentDefinition
	,a.TIUDocumentSID
	,a.NoteAndSnipOffset
	,a.Snippet
	,s.StaffName
FROM #GetConcepts a WITH (NOLOCK)  -- pipeline_source\Code\Stored Procedures\tmp_table_GetConcepts.sql
INNER JOIN TIU.TIUDocument b WITH (NOLOCK)
	ON a.TIUDocumentSID=b.TIUDocumentSID
INNER JOIN #TIU c WITH (NOLOCK)
	ON b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
INNER JOIN Dim.Institution e WITH (NOLOCK)
	ON b.InstitutionSID = e.InstitutionSID
LEFT JOIN SStaff.SStaff s WITH (NOLOCK)
	ON b.SignedByStaffSID=s.StaffSID
WHERE ((a.Category='3ST' AND SubclassLabel IS NOT NULL AND c.TIU_3ST = 1)
	OR a.TargetClass IN ('LIVESALONE','LONELINESS','IDU','DETOX', 'XYLA'))


DELETE FROM #AddTIU
WHERE (
--IVDU Concepts
(TargetClass='IDU' AND 
	(TIUstandardTitle = 'Gastroenterology Nursing Note'
		OR TIUstandardTitle like '%ACCOUNT%DISCLOSURE%'
		OR TIUstandardTitle like '%GROUP%NOTE%'
		OR TIUDocumentDefinition IN ('CCC: CLINICAL TRIAGE','EDUCATION NOTE','EMERGENCY DEPARTMENT DISCHARGE INSTRUCTIONS','SUICIDE PREVENTION LETTER','PATIENT LETTER (AUTO-MAIL)','STORM DATA-BASED OPIOID RISK REVIEW','CARDIOLOGY DEVICE IMPLANTATION REPORT')
		OR TIUDocumentDefinition LIKE 'VISN 4 RN%' 
		OR TIUDocumentDefinition LIKE 'OAKLAND CLINIC%'
		OR (Snippet like '%ssp%' AND NOT (Snippet like '%needle%' OR Snippet LIKE '%syringe%'))
		OR Snippet like '%(-) IVDU%'
		OR Snippet like '%(MSM, ivdu, liver dz, travel):%'
	))
--Detox Concepts
OR (TargetClass='DETOX' AND 
	(TIUDocumentDefinition IN ('ACUITY SCALE')
		OR TIUDocumentDefinition LIKE '%discharge instruction%'
		OR TIUDocumentDefinition LIKE '%acupuncture%'
	))
--Xylazine Concepts
OR (TargetClass='XYLA' AND 
	(Snippet LIKE '%provided%education%provided%'
	))
)