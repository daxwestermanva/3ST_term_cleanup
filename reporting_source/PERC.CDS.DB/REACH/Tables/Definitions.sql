CREATE TABLE [REACH].[Definitions] (
    [Risk]                  NVARCHAR (255) NULL,
    [PrintName]             NVARCHAR (255) NULL,
    [RiskLabel]             NVARCHAR (255) NULL,
    [TimeFrame]             FLOAT (53)     NULL,
    [Coefficient]           FLOAT (53)     NULL,
    [LookupColumn]          NVARCHAR (255) NULL,
    [LookUpTable]           NVARCHAR (255) NULL,
    [ReachDefinition]       NVARCHAR (255) NULL,
    [CoefficientType]       VARCHAR (26)   NOT NULL,
    [Definitions]           VARCHAR (100)  NULL,
    [DefinitionDescription] VARCHAR (8000) NULL,
    [ColumnDescription]     VARCHAR (1000) NULL,
    [ColumnPrintName]       VARCHAR (1000) NULL,
    [DefinitionType]        VARCHAR (29)   NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Definitions]
    ON [REACH].[Definitions];

