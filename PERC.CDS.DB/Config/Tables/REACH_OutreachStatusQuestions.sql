CREATE TABLE [Config].[REACH_OutreachStatusQuestions] (
    [QuestionNumber]       FLOAT (53)     NULL,
    [Question]             NVARCHAR (255) NULL,
    [QuestionType]         NVARCHAR (255) NULL,
    [Role]                 NVARCHAR (255) NULL,
    [DashboardOrder]       FLOAT (53)     NULL,
    [SummaryType]          NVARCHAR (255) NULL,
    [SummaryTypePrintName] VARCHAR (200)  NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_REACH_OutreachStatusQuestions]
    ON [Config].[REACH_OutreachStatusQuestions];

