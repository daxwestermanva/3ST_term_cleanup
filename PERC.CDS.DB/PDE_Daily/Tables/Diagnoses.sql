CREATE TABLE [PDE_Daily].[Diagnoses] (
    [MVIPersonSID]          INT            NOT NULL,
    [InpatientEncounterSID] BIGINT         NOT NULL,
    [DisDay]                DATE           NULL,
    [ICD10Code]             VARCHAR (100)  NULL,
    [ICD10Description]      VARCHAR (8000) NULL,
    [Overdose_Dx]           SMALLINT       NULL,
    [DxSource]              VARCHAR (100)  NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Diagnoses]
    ON [PDE_Daily].[Diagnoses];

