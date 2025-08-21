CREATE TABLE [REACH].[MonthlyMetrics] (
    [ReleaseDate] DATE           NULL,
    [VISN]        TINYINT        NULL,
    [ChecklistID] VARCHAR (5)    NULL,
    [Wk]          TINYINT        NULL,
    [Metric]      VARCHAR (12)   NULL,
    [Denominator] INT            NULL,
    [Numerator]   INT            NULL,
    [Score]       DECIMAL (6, 5) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MonthlyMetrics]
    ON [REACH].[MonthlyMetrics];

