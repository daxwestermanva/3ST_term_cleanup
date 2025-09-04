CREATE TABLE [VBA].[MSTClaimsNotes] (
    [MVIPersonSID]         INT            NOT NULL,
    [NoteNumber]           BIGINT         NULL,
    [VisitSID]             BIGINT         NULL,
    [HealthFactorDateTime] DATETIME2 (0)  NULL,
    [StaPa]                NVARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MSTClaimsNotes]
    ON [VBA].[MSTClaimsNotes];

