CREATE TABLE [SDH].[ScreenResults] (
    [MVIPersonSID]   INT           NOT NULL,
    [ChecklistID]    NVARCHAR (30) NULL,
    [Category]       VARCHAR (100) NULL,
    [ScreenDateTime] VARCHAR (16)  NULL,
    [Score]          INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ScreenResults]
    ON [SDH].[ScreenResults];

