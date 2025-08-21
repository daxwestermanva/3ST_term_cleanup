CREATE TABLE [LookUp].[ListMappingRule_v02] (
    [List]            VARCHAR (50)  NOT NULL,
    [Domain]          VARCHAR (50)  NOT NULL,
    [Attribute1]      VARCHAR (50)  NOT NULL,
    [SearchTerm1]     VARCHAR (500) NOT NULL,
    [Attribute2]      VARCHAR (50)  NULL,
    [SearchTerm2]     VARCHAR (500) NULL,
    [SearchType]      CHAR (1)      NOT NULL,
    [CreatedDateTime] SMALLDATETIME CONSTRAINT [DF_ListMappingRule_v02_CreatedDateTime] DEFAULT (getdate()) NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ListMappingRule_v02]
    ON [LookUp].[ListMappingRule_v02];

