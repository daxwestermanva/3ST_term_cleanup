CREATE TABLE [SUD].[IDU_Rx] (
    [ChecklistID]     NVARCHAR (10) NOT NULL,
    [MVIPersonSID]    INT           NULL,
    [ReleaseDateTime] DATETIME2 (0) NULL,
    [MedicationType]  VARCHAR (20)  NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_IDU_Rx]
    ON [SUD].[IDU_Rx];

