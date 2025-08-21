CREATE TABLE [SUD].[IDU_Writeback] (
    [MVIPersonSID]  INT           NULL,
    [Confirmed]     BIT           NULL,
    [ExecutionDate] DATETIME2 (0) NULL,
    [UserID]        VARCHAR (20)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_IDU_Writeback]
    ON [SUD].[IDU_Writeback];

