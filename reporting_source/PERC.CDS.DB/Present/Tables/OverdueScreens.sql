CREATE TABLE [Present].[OverdueScreens] (
    [MVIPersonSID]          INT          NOT NULL,
    [ChecklistID]           VARCHAR (10) NULL,
    [Screen]                VARCHAR (50) NULL,
    [OverdueFlag]           INT          NULL,
    [Next30DaysOverdueFlag] INT          NULL,
    [MostRecentScreenDate]  DATE         NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_OverdueScreens]
    ON [Present].[OverdueScreens];

