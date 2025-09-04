/*****************************************************************************
*****************************************************************************/


-- View: vw_NLP_StageVariables
-- Maps concept and subclass labels to standardized reporting labels, adds count per patient/concept
CREATE VIEW vw_NLP_StageVariables AS
SELECT MVIPersonSID, ChecklistID,
  CASE WHEN TargetClass = 'LIVESALONE' THEN 'Lives Alone'
       WHEN TargetClass = 'CAPACITY' THEN 'Capacity for Suicide'
       WHEN TargetClass = 'PPAIN' THEN 'Psychological Pain'
       ELSE TargetClass END AS Concept,
  CASE WHEN SubclassLabel = 'Acquired capacity for suicide' OR SubclassLabel = 'practical' THEN 'Repeated Exposure to Painful/Provocative Events'
       WHEN SubclassLabel = 'Dispositional capacity for suicide' OR SubclassLabel = 'dispositional' THEN 'Genetic/Temperamental Risk Factors'
       WHEN SubclassLabel = 'Situational capacity for suicide' OR SubclassLabel = 'situational' THEN 'Acute/Situational Risk Factors'
       WHEN SubclassLabel = 'Practical capacity for suicide' OR SubclassLabel = 'acquired' THEN 'Access to Lethal Means'
       WHEN TargetClass = 'CAPACITY' THEN NULL
       WHEN TargetClass = 'Sleep' THEN 'Sleep issues'
       WHEN TargetClass = 'Debt' THEN 'Financial issues'
       WHEN TargetClass = 'Justice' THEN 'Legal issues'
       WHEN TargetClass = 'FoodInsecure' THEN 'Food insecurity'
       WHEN TargetClass = 'Housing' THEN 'Housing issues'
       WHEN TargetClass = 'JobInstable' THEN 'Job instability'
       WHEN TargetClass = 'Loneliness' THEN 'Loneliness'
       WHEN TargetClass = 'LivesAlone' THEN 'Lives Alone'
       WHEN TargetClass = 'XYLA' THEN 'Suspected Xylazine Exposure'
       WHEN TargetClass = 'IDU' THEN 'Suspected Injection Drug Use'
       ELSE SubclassLabel END AS SubclassLabel,
  Term, EntryDateTime, ReferenceDateTime, TIUDocumentDefinition, StaffName,
  REPLACE(Snippet, Term, Term) AS Snippet,
  ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, TargetClass, SubclassLabel ORDER BY ReferenceDateTime DESC, EntryDateTime DESC) AS CountDesc
FROM vw_NLP_OneRecordPerNote
WHERE NOT (Concept = 'Capacity for Suicide' AND SubclassLabel IS NULL);
