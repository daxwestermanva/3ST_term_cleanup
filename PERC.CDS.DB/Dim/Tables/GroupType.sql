CREATE TABLE [Dim].[GroupType] (
    [grouptype] VARCHAR (25) NULL,
    [groupid]   INT          NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_GroupType]
    ON [Dim].[GroupType];

