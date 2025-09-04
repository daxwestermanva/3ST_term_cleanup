CREATE TABLE [Pharm].[Antidepressant_Writeback] (
    [ChecklistID]     VARCHAR (5)   NULL,
    [PatientSID]      INT           NULL,
    [PatientReviewed] BIT           NULL,
    [ExecutionDate]   DATETIME      NULL,
    [UserID]          VARCHAR (100) NULL,
    [Comments]        VARCHAR (255) NULL,
    [VariableName]    VARCHAR (25)  NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Antidepressant_Writeback]
    ON [Pharm].[Antidepressant_Writeback];

