CREATE TABLE [Present].[UDSLabResults] (
    [MVIPersonSID]        INT           NULL,
    [PatientICN]          VARCHAR (50)  NULL,
    [Sta3n]               VARCHAR (10)  NULL,
    [ChecklistID]         VARCHAR (30)  NULL,
    [LabDate]             DATE          NULL,
    [LabGroup]            VARCHAR (40)  NULL,
    [LabResults]          VARCHAR (255) NULL,
    [PrintNameLabResults] VARCHAR (15)  NULL,
    [LabRank]             INT           NULL,
    [UDS]                 INT           NULL,
    [LabScore]            INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_UDSLabResults]
    ON [Present].[UDSLabResults];

