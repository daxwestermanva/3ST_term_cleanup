CREATE TABLE [ORM].[DefinitionsReportRx] (
    [MedicationCategory]     NVARCHAR (255) NULL,
    [Description]            NVARCHAR (255) NULL,
    [NationalDrug_PrintName] NVARCHAR (255) NULL,
    [Exclusions]             NVARCHAR (255) NULL,
    [RxMeasureID]            TINYINT        NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DefinitionsReportRx]
    ON [ORM].[DefinitionsReportRx];

