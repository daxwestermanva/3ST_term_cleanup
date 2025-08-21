CREATE TABLE [SMI].[PatientReport_Writeback] (
    [sta3n]           VARCHAR (10)  NULL,
    [MVIPersonSID]    INT           NULL,
    [PatientReviewed] BIT           NULL,
    [ExecutionDate]   DATETIME2 (0) NULL,
    [UserID]          VARCHAR (20)  NULL,
    [Comments]        VARCHAR (255) NULL,
    [VariableName]    VARCHAR (10)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientReport_Writeback]
    ON [SMI].[PatientReport_Writeback];

