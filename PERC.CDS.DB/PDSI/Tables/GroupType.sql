CREATE TABLE [PDSI].[GroupType] (
    [grouptype] VARCHAR (25) NULL,
    [groupid]   INT          NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_GroupType]
    ON [PDSI].[GroupType];

