/*****************************************************************************
*
* View: vw_NLP_FinalConcepts
* 
* Joins cleaned concepts to TIU metadata and staff, applies additional exclusions
*
* Performance Optimizations:
*   - Restructured WHERE clause for better optimization
*   - Improved readability of exclusion logic
*   - Proper formatting for maintainability
*
*****************************************************************************/

CREATE VIEW vw_NLP_FinalConcepts 
AS
  SELECT a.*
    , e.StaPa AS ChecklistID
    , b.EntryDateTime
    , c.TIUDocumentDefinition
    , c.TIUDocumentDefinitionSID
    , s.StaffName
  FROM vw_NLP_CleanedConcepts a
    INNER JOIN TIU.TIUDocument b WITH (NOLOCK)
      ON a.TIUDocumentSID = b.TIUDocumentSID
    INNER JOIN vw_3ST_TIUStandardTitle c
      ON b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
    INNER JOIN Dim.Institution e WITH (NOLOCK)
      ON b.InstitutionSID = e.InstitutionSID
    LEFT JOIN SStaff.SStaff s WITH (NOLOCK)
      ON b.SignedByStaffSID = s.StaffSID
  WHERE ((a.Category = '3ST' AND a.SubclassLabel IS NOT NULL AND c.TIU_3ST = 1)
         OR a.TargetClass IN ('LIVESALONE','LONELINESS','IDU','DETOX','XYLA'))
    -- Exclude IDU false positives based on TIU criteria
    AND NOT (a.TargetClass = 'IDU' AND (
      a.TIUStandardTitle = 'Gastroenterology Nursing Note'
      OR a.TIUStandardTitle LIKE '%ACCOUNT%DISCLOSURE%'
      OR a.TIUStandardTitle LIKE '%GROUP%NOTE%'
      OR c.TIUDocumentDefinition IN ('CCC: CLINICAL TRIAGE','EDUCATION NOTE',
                                     'EMERGENCY DEPARTMENT DISCHARGE INSTRUCTIONS',
                                     'SUICIDE PREVENTION LETTER','PATIENT LETTER (AUTO-MAIL)',
                                     'STORM DATA-BASED OPIOID RISK REVIEW',
                                     'CARDIOLOGY DEVICE IMPLANTATION REPORT')
      OR c.TIUDocumentDefinition LIKE 'VISN 4 RN%'
      OR c.TIUDocumentDefinition LIKE 'OAKLAND CLINIC%'
      OR (a.Snippet LIKE '%ssp%' AND a.Snippet NOT LIKE '%needle%' AND a.Snippet NOT LIKE '%syringe%')
      OR a.Snippet LIKE '%(-) IVDU%'
      OR a.Snippet LIKE '%(MSM, ivdu, liver dz, travel):%'
    ))
    -- Exclude DETOX false positives based on TIU criteria
    AND NOT (a.TargetClass = 'DETOX' AND (
      c.TIUDocumentDefinition = 'ACUITY SCALE'
      OR c.TIUDocumentDefinition LIKE '%discharge instruction%'
      OR c.TIUDocumentDefinition LIKE '%acupuncture%'
    ))
    -- Exclude XYLA false positives
    AND NOT (a.TargetClass = 'XYLA' AND a.Snippet LIKE '%provided%education%provided%');
