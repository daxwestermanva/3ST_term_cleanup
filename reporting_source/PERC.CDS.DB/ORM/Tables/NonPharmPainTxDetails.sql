CREATE TABLE [ORM].[NonPharmPainTxDetails] (
    [Non-Pharmacological Pain Treatment] NVARCHAR (255) NULL,
    [Description]                        NVARCHAR (255) NULL,
    [Rationale]                          NVARCHAR (255) NULL,
    [CPTCohort]                          NVARCHAR (255) NULL,
    [StopCodeCohort]                     NVARCHAR (255) NULL,
    [ICD9Proc]                           NVARCHAR (255) NULL,
    [ICD10Proc]                          NVARCHAR (255) NULL,
    [Exclusion]                          NVARCHAR (255) NULL,
    [Category1]                          NVARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NonPharmPainTxDetails]
    ON [ORM].[NonPharmPainTxDetails];

