CREATE TABLE [Config].[EBP_TemplateLookUp] (
    [TemplateName]      NVARCHAR (128) NULL,
    [TemplateNameClean] VARCHAR (17)   NULL,
    [TemplateNameShort] VARCHAR (8)    NULL,
    [TemplateOrder]     INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_EBP_TemplateLookUp]
    ON [Config].[EBP_TemplateLookUp];

