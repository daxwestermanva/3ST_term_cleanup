CREATE TABLE [ORM].[DefinitionsReportRelevantDx] (
    [ClinicalDetailCategory] NVARCHAR (255) NULL,
    [DiseaseDisorder]        NVARCHAR (255) NULL,
    [Description]            NVARCHAR (255) NULL,
    [DiagnosisCohort]        NVARCHAR (255) NULL,
    [StopCodeCohort]         NVARCHAR (255) NULL,
    [Exclusion]              NVARCHAR (255) NULL,
    [DxMeasureID]            TINYINT        NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DefinitionsReportRelevantDx]
    ON [ORM].[DefinitionsReportRelevantDx];

