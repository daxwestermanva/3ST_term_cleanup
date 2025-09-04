CREATE TABLE [EBP].[FacilityMonthly] (
    [VISN]               INT            NULL,
    [StaPa]              NVARCHAR (50)  NULL,
    [AdmParent_FCDM]     NVARCHAR (255) NOT NULL,
    [LocationOfFacility] NVARCHAR (255) NULL,
    [Year]               NVARCHAR (30)  NULL,
    [Month]              NVARCHAR (30)  NULL,
    [Date]               DATETIME       NULL,
    [TemplateName]       NVARCHAR (128) NULL,
    [TemplateValue]      INT            NULL,
    [TemplateNameClean]  VARCHAR (17)   NULL,
    [TemplateNameShort]  VARCHAR (8)    NULL
);










GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_FacilityMonthly]
    ON [EBP].[FacilityMonthly];

