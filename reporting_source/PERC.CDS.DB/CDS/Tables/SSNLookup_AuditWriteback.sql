CREATE TABLE [CDS].[SSNLookup_AuditWriteback] (
    [PatientICN]    VARCHAR (55)  NULL,
    [UserID]        VARCHAR (55)  NULL,
    [ExecutionDate] DATETIME      NULL,
    [Report]        VARCHAR (100) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SSNLookup_AuditWriteback]
    ON [CDS].[SSNLookup_AuditWriteback];

