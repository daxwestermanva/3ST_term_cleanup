CREATE TABLE [EBP].[Quarterly] (
    [ChecklistID]        NVARCHAR (50)  NULL,
    [Admparent_FCDM]     NVARCHAR (356) NULL,
    [VISN]               INT            NULL,
    [Sta6aid]            NVARCHAR (255) NULL,
    [LocationOfFacility] NVARCHAR (356) NULL,
    [TemplateName]       NVARCHAR (128) NULL,
    [TemplateValue]      INT            NULL,
    [Date]               VARCHAR (19)   NOT NULL,
    [FiscalQuarter]      TINYINT        NULL,
    [FiscalYear]         SMALLINT       NULL,
    [TemplateNameClean]  VARCHAR (21)   NOT NULL,
    [TemplateNameShort]  VARCHAR (21)   NOT NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Quarterly]
    ON [EBP].[Quarterly];

