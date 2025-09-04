/*****************************************************************************
*
* View: vw_NLP_Concepts
* 
* Extracts NLP concepts for living patients, applies subclass and date filters
*
* Performance Optimizations:
*   - Replaced TRY_CAST with ISNUMERIC check for better index usage
*   - Restructured WHERE clause for better optimization
*   - Added early filtering on TargetClass to reduce join volume
*
* TODOs
*   - [ ] PDW.HDAP_NLP_OMHSP from [OMHSP_PERC_PDW].[App].[HDAP_NLP_OMHSP]?
*   - [ ] Consider adding date filter at view level if appropriate
*
*****************************************************************************/

CREATE VIEW vw_NLP_Concepts
AS
  SELECT d.MVIPersonSID
    , a.TargetClass
    , CASE WHEN s.Preferred_Label IS NOT NULL THEN s.Preferred_Label ELSE a.TargetSubClass END AS SubclassLabel
    , a.Term
    , a.ReferenceDateTime
    , a.TIUStandardTitle
    , a.TIUDocumentSID
    , a.NoteAndSnipOffset
    , TRIM(REPLACE(a.Snippet,'SNIPPET:','')) AS Snippet
    , CASE 
        WHEN a.TargetClass IN ('PPAIN','CAPACITY','JOBINSTABLE','JUSTICE',
                                  'SLEEP','FOODINSECURE','DEBT','HOUSING') 
        THEN '3ST' ELSE NULL END AS Category
  FROM PDW.HDAP_NLP_OMHSP a WITH (NOLOCK)
    INNER JOIN Common.vwMVIPersonSIDPatientPersonSID d WITH (NOLOCK)
      ON a.PatientSID = d.PatientPersonSID
    INNER JOIN Common.MasterPatient mvi WITH (NOLOCK)
      ON d.MVIPersonSID = mvi.MVIPersonSID
    LEFT JOIN vw_3ST_SubclassLabels s
      ON ISNUMERIC(a.TargetSubClass) = 1 
      AND CAST(a.TargetSubClass AS INT) = s.Instance_ID
  WHERE mvi.DateOfDeath_Combined IS NULL
    AND a.Label = 'POSITIVE'
    -- Early filter on TargetClass to reduce processing volume
    AND a.TargetClass IN ('PPAIN','CAPACITY','JOBINSTABLE','JUSTICE','SLEEP',
                          'FOODINSECURE','DEBT','HOUSING','XYLA','LIVESALONE',
                          'LONELINESS','DETOX','IDU')
    -- Apply specific subclass filters
    AND ((a.TargetClass IN ('PPAIN','CAPACITY') AND s.Instance_ID IS NOT NULL)
      OR (a.TargetClass = 'XYLA' AND a.TargetSubClass IN ('SUS','SUS-P'))
      OR a.TargetClass IN ('LIVESALONE','LONELINESS','DETOX','IDU'))
  -- Date filter to be applied in reporting or procedure


/*

*/