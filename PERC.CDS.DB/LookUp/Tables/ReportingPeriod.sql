CREATE TABLE [LookUp].[ReportingPeriod] (
    [ID]                INT            NOT NULL,
    [ReportingPeriodID] FLOAT (53)     NULL,
    [ReportingPeriod]   NVARCHAR (255) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ReportingPeriod]
    ON [LookUp].[ReportingPeriod];

