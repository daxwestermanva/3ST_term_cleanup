CREATE TABLE [Alex].[Blueprint] (
    [Name]            VARCHAR (50)   NULL,
    [Type]            VARCHAR (50)   NULL,
    [Code]            VARCHAR (1000) NULL,
    [Description]     VARCHAR (200)  NULL,
    [LastModifiedOn]  DATETIME2 (0)  NULL,
    [ETLLoadDateTime] DATETIME2 (0)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Blueprint]
    ON [Alex].[Blueprint];

