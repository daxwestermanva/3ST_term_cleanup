CREATE TABLE [COMPACT].[Template] (
    [MVIPersonSID]      INT           NOT NULL,
    [Sta3n]             SMALLINT      NULL,
    [ChecklistID]       VARCHAR (5)   NULL,
    [VisitSID]          BIGINT        NULL,
    [TemplateDateTime]  DATETIME2 (7) NULL,
    [List]              VARCHAR (50)  NULL,
    [TemplateSelection] VARCHAR (200) NULL,
    [StaffName]         VARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Template]
    ON [COMPACT].[Template];

