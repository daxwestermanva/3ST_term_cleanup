/*****************************************************************************
*****************************************************************************/


-- View: vw_NLP_OneRecordPerNote
-- For each note and concept, keeps only the first relevant record
CREATE VIEW vw_NLP_OneRecordPerNote AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY TIUDocumentSID, TargetClass ORDER BY NoteAndSnipOffset) AS rn
  FROM vw_NLP_FinalConcepts
) t
WHERE rn = 1;
