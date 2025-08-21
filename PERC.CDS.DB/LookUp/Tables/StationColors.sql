CREATE TABLE [LookUp].[StationColors] (
    [Code]        NVARCHAR (255) NULL,
    [Facility]    NVARCHAR (255) NULL,
    [CheckListID] NVARCHAR (10)  NULL
);

GO
CREATE CLUSTERED INDEX [CIX_StationColors_ChecklistID]
    ON [LookUp].[StationColors]([CheckListID] ASC) WITH (DATA_COMPRESSION = PAGE);
GO
