CREATE TABLE [CDS].[DashboardHits] (
    [ReportCategory] VARCHAR (20) NULL,
    [ReportFileName] VARCHAR (60) NULL,
    [Users]          INT          NULL,
    [Hits]           INT          NULL,
    [Month]          TINYINT      NULL,
    [FiscalQuarter]  TINYINT      NULL,
    [Year]           SMALLINT     NULL,
    [FiscalYear]     SMALLINT     NULL,
    [Period]         VARCHAR (15) NULL,
    [PeriodComplete] BIT          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DashboardHits]
    ON [CDS].[DashboardHits];

