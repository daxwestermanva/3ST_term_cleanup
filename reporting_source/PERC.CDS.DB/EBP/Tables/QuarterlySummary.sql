CREATE TABLE [EBP].[QuarterlySummary] (
    [ChecklistID]           NVARCHAR (50)  NULL,
    [Admparent_FCDM]        NVARCHAR (356) NULL,
    [VISN]                  INT            NULL,
    [Sta6aID]               NVARCHAR (255) NULL,
    [LocationOfFacility]    NVARCHAR (356) NULL,
    [TemplateName]          NVARCHAR (128) NULL,
    [TemplateValue]         INT            NULL,
    [Date2]                 VARCHAR (10)   NOT NULL,
    [Date]                  VARCHAR (19)   NOT NULL,
    [Quarter]               VARCHAR (10)   NULL,
    [Year]                  VARCHAR (10)   NULL,
    [TemplateNameShort]     VARCHAR (21)   NOT NULL,
    [TemplateNameClean]     VARCHAR (21)   NOT NULL,
    [PTSDKey]               INT            NULL,
    [DepKey]                INT            NULL,
    [SMIKey]                INT            NULL,
    [SUDKey]                INT            NULL,
    [MostRecentValue]       INT            NULL,
    [NationalTemplateValue] INT            NULL,
    [NationalPTSDkey]       INT            NULL,
    [NationalDepkey]        INT            NULL,
    [NationalSMIkey]        INT            NULL,
    [NationalSUDkey]        INT            NULL,
    [TemplateOrder]         INT            NOT NULL,
    [Temp]                  INT            NOT NULL,
    [InsomniaKey]           INT            NULL,
    [NationalInsomniaKey]   INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_QuarterlySummary]
    ON [EBP].[QuarterlySummary];

