CREATE TABLE [Log].[PublishedTableLog] (
    [PublishedTableLogID] INT           IDENTITY (1, 1) NOT NULL,
    [ExecutionLogID]      INT           NULL,
    [SchemaName]          VARCHAR (128) NOT NULL,
    [TableName]           VARCHAR (128) NOT NULL,
    [SourceTableName]     VARCHAR (128) NOT NULL,
    [PublishedType]       VARCHAR (50)  NOT NULL,
    [PublishedRowCount]   BIGINT        NULL,
    [PublishedBy]         VARCHAR (258) NOT NULL,
    [PublishedDateTime]   DATETIME      NOT NULL,
    CONSTRAINT [PK_PublishedTableLog_PublishedTableLogID] PRIMARY KEY CLUSTERED ([PublishedTableLogID] ASC)
);



