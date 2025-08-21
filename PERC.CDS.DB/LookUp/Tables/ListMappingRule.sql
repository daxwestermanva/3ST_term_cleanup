CREATE TABLE [LookUp].[ListMappingRule] (
    [List]            VARCHAR (50)   NOT NULL,
    [Domain]          VARCHAR (50)   NOT NULL,
    [Attribute]       VARCHAR (100)  NOT NULL,
    [SearchTerm]      VARCHAR (1000) NOT NULL,
    [SearchTerm2]     VARCHAR (500)  NULL,
    [SearchType]      CHAR (1)       NOT NULL,
    [CreatedDateTime] SMALLDATETIME  CONSTRAINT [DF_ListMappingRule_CreatedDateTime] DEFAULT (getdate()) NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ListMappingRule]
    ON [LookUp].[ListMappingRule];

