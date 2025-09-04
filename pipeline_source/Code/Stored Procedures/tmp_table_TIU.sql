with
    cte_TIUStandardTitle
    as
    (
        SELECT [TIUStandardTitleSID]
            , [TIUStandardTitleIEN]
            , [Sta3n]
            , [TIUStandardTitle]
            , [TIUSubjectMatterDomainSID]
            , [TIURoleSID]
            , [TIUSettingSID]
            , [TIUServiceSID]
            , [TIUDocumentTypeSID]
            , [MasterEntryForVUIDFlag]
            , [VUID]
        FROM [CDWWork].Dim.TIUStandardTitle with (nolock)
    )
,
    cte_TIUStandardTitle
    as
    (
        SELECT [TIUStandardTitleSID]
            , [TIUStandardTitleIEN]
            , [Sta3n]
            , [TIUStandardTitle]
            , [TIUSubjectMatterDomainSID]
            , [TIURoleSID]
            , [TIUSettingSID]
            , [TIUServiceSID]
            , [TIUDocumentTypeSID]
            , [MasterEntryForVUIDFlag]
            , [VUID]
        FROM [CDWWork].Dim.TIUDocumentDefinition with (nolock)
    )
,
    cte_NLP_3ST_TIUStandardTitle
    as
    (
        SELECT TIUStandardTitle
        FROM Config.NLP_3ST_TIUStandardTitle with (nolock)
        -- TODO - where is this defined
    )
SELECT s.TIUStandardTitle
        , s.TIUStandardTitleSID
        , c.TIUDocumentDefinition
        , c.TIUDocumentDefinitionSID
        , CASE 
            WHEN t.TIUStandardTitle IS NOT NULL
        AND TIUDocumentDefinition NOT IN ('MH TMS NURSE NOTE')
		    THEN 1 
            ELSE 0 
            END AS TIU_3ST
FROM cte_TIUStandardTitle s
    INNER JOIN cte_TIUStandardTitle c
    ON s.TIUStandardTitleSID = c.TIUStandardTitleSID
    LEFT JOIN cte_NLP_3ST_TIUStandardTitle t
    ON t.TIUStandardTitle=s.TIUStandardTitle