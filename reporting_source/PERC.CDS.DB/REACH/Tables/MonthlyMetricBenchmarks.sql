CREATE TABLE [REACH].[MonthlyMetricBenchmarks] (
    [ReleaseDate]                 DATE         NULL,
    [VISN]                        TINYINT      NULL,
    [ChecklistID]                 VARCHAR (5)  NULL,
    [Wk]                          TINYINT      NULL,
    [Benchmark]                   VARCHAR (20) NULL,
    [ConsecMonthsUnderperforming] INT          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MonthlyMetricBenchmarks]
    ON [REACH].[MonthlyMetricBenchmarks];

