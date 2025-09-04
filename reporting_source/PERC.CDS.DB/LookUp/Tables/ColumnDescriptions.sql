CREATE TABLE [LookUp].[ColumnDescriptions] (
    [TableID]           INT            NOT NULL,
    [TableName]         VARCHAR (100)  NOT NULL,
    [ColumnName]        VARCHAR (100)  NOT NULL,
    [Category]          VARCHAR (100)  NULL,
    [PrintName]         VARCHAR (1000) NULL,
    [ColumnDescription] VARCHAR (1000) NULL,
    [DefinitionOwner]   VARCHAR (1000) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ColumnDescriptions]
    ON [LookUp].[ColumnDescriptions];

