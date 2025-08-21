CREATE TABLE [PDSI].[APDEM1] (
    [FYQ]             VARCHAR (6)  NULL,
    [ChecklistID]     NVARCHAR (6) NULL,
    [VISN]            INT          NULL,
    [Numerator]       INT          NULL,
    [Denominator]     INT          NULL,
    [Score]           FLOAT (53)   NULL,
    [MeasureMnemonic] VARCHAR (12) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_APDEM1]
    ON [PDSI].[APDEM1];

