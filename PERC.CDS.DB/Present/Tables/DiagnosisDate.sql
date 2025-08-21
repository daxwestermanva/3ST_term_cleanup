CREATE TABLE [Present].[DiagnosisDate] (
    [MVIPersonSID]   INT           NOT NULL,
    [Sta3n]          INT           NULL,
    [ChecklistID]    NVARCHAR (10) NULL,
    [ICD10Code]      VARCHAR (100) NULL,
    [MostRecentDate] DATETIME2 (0) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DiagnosisDate]
    ON [Present].[DiagnosisDate];

