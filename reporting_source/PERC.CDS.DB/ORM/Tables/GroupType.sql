CREATE TABLE [ORM].[GroupType] (
    [groupid]   INT           NOT NULL,
    [grouptype] VARCHAR (200) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_GroupType]
    ON [ORM].[GroupType];

