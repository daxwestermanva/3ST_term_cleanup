CREATE TABLE [LookUp].[List] (
    [List]            VARCHAR (50)  NOT NULL,
    [Category]        VARCHAR (100) NULL,
    [PrintName]       VARCHAR (100) NULL,
    [Description]     VARCHAR (500) NULL,
    [DefinitionOwner] VARCHAR (100) NULL,
    CONSTRAINT [PK_LookUp_List] PRIMARY KEY CLUSTERED ([List] ASC)
)
;

