/*****************************************************************************
*****************************************************************************/


-- View: vw_NLP_TemplateSnippets
-- Identifies snippets that are likely templates (documented >=10 times on >=10 patients)
CREATE VIEW vw_NLP_TemplateSnippets AS
SELECT Snippet, TargetClass,
  COUNT(DISTINCT MVIPersonSID) AS PatientCount,
  COUNT(DISTINCT TIUDocumentSID) AS DocumentCount
FROM vw_NLP_Concepts
GROUP BY Snippet, TargetClass
HAVING COUNT(DISTINCT MVIPersonSID) >= 10 AND COUNT(DISTINCT TIUDocumentSID) >= 10;
