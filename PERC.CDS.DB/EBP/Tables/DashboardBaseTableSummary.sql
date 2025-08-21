CREATE TABLE [EBP].[DashboardBaseTableSummary] (
    [StaPa]              NVARCHAR (50)  NULL,
    [Admparent_FCDM]     NVARCHAR (510) NOT NULL,
    [VISN]               INT            NULL,
    [PTSDKey]            INT            NULL,
    [DepKey]             INT            NULL,
    [SMIKey]             INT            NULL,
    [SUDKey]             INT            NULL,
    [LocationOfFacility] NVARCHAR (510) NULL,
    [TemplateName]       NVARCHAR (128) NULL,
    [TemplateValue]      INT            NULL,
    [UpdateDate]         VARCHAR (10)   NULL,
    [TemplateNameClean]  VARCHAR (25)   NULL,
    [TemplateNameShort]  VARCHAR (25)   NULL,
    [InsomniaKey]        INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DashboardBaseTableSummary]
    ON [EBP].[DashboardBaseTableSummary];

