CREATE TABLE [App].[UserActivityLog] (
    [UserName]         VARCHAR (300) NULL,
    [ReportID]         INT           NOT NULL,
    [ReportName]       VARCHAR (100) NULL,
    [TimeStart]        DATETIME      NULL,
    [VISN]             VARCHAR (30)  NULL,
    [YEAR]             INT           NULL,
    [ReportFileName]   VARCHAR (100) NULL,
    [MONTH]            INT           NULL,
    [MMM]              VARCHAR (3)   NULL,
    [Count_Displays]   INT           NULL,
    [CountUniqueUsers] INT           NULL,
    [RecType]          VARCHAR (1)   NULL,
    [ReportAction]     VARCHAR (50)  NULL
);

