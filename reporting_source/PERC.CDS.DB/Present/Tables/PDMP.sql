CREATE TABLE [Present].[PDMP] (
    [MVIPersonSID]      INT           NOT NULL,
    [DataType]          VARCHAR (65)  NULL,
    [PerformedDateTime] DATETIME2 (0) NULL,
    [Sta3n]             INT           NULL,
    [ChecklistID]       VARCHAR (5)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PDMP]
    ON [Present].[PDMP];

