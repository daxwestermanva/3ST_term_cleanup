CREATE TABLE [PDSI].[Writeback] (
    [Sta3n]           VARCHAR (10)  NULL,
    [MVIPersonSID]    INT           NULL,
    [PatientReviewed] INT           NULL,
    [ExecutionDate]   DATETIME2 (7) NULL,
    [UserID]          VARCHAR (150) NULL,
    [ActionType]      VARCHAR (255) NULL,
    [Comments]        VARCHAR (255) NULL,
    [VariableName]    VARCHAR (255) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Writeback]
    ON [PDSI].[Writeback];

