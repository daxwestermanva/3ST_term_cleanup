CREATE TABLE [Present].[CommunityStatusNote] (
    [MVIPersonSID]         INT           NOT NULL,
    [ChecklistID]          VARCHAR (5)   NULL,
    [VisitSID]             BIGINT        NULL,
    [HealthFactorDateTime] VARCHAR (16)  NULL,
    [Status1]              VARCHAR (100) NULL,
    [Status2]              VARCHAR (100) NULL,
    [Comments]             VARCHAR (MAX) NULL,
    [MostRecent]           SMALLINT      NULL,
    [PastOneMonth]         BIT           NULL,
    [PastThreeMonths]      BIT           NULL
);















