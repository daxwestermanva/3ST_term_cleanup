/*****************************************************************************
 * View: vw_3ST_TIUStandardTitle
 * 
 * Identifies TIU Standard Titles and Document Definitions relevant for
 *  3ST concepts
 * 
 * TODOs:
 *  - [ ] In Dim.TIUDocumentDefinition in CDWWork or elsewhere?
 *  - [ ] In Dim.TIUStandardTitle in CDWWork or elsewhere?
 *  - [ ] Where is Config.NLP_3ST_TIUStandardTitle defined?
 *****************************************************************************/
CREATE VIEW vw_3ST_TIUStandardTitle
AS
  SELECT s.TIUStandardTitle
    ,s.TIUStandardTitleSID
    ,c.TIUDocumentDefinition
    ,c.TIUDocumentDefinitionSID
    ,CASE
    WHEN t.TIUStandardTitle IS NOT NULL
      AND c.TIUDocumentDefinition NOT IN ('MH TMS NURSE NOTE') THEN 1
    ELSE 0
  END AS TIU_3ST
  FROM Dim.TIUStandardTitle s WITH (NOLOCK)
    INNER JOIN Dim.TIUDocumentDefinition c WITH (NOLOCK)
      ON s.TIUStandardTitleSID = c.TIUStandardTitleSID
    LEFT JOIN Config.NLP_3ST_TIUStandardTitle t WITH (NOLOCK)
      ON t.TIUStandardTitle = s.TIUStandardTitle;