CREATE TABLE [CDS].[DashboardHits_PBI_Stage] (
    [Year]     SMALLINT      NULL,
    [Month]    TINYINT       NULL,
    [Report]   VARCHAR (60)  NULL,
    [UserName] VARCHAR (100) NULL,
    [Hits]     INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DashboardHits_PBI_Stage]
    ON [CDS].[DashboardHits_PBI_Stage];

