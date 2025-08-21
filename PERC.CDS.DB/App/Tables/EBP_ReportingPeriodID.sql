CREATE TABLE [App].[EBP_ReportingPeriodID] (
    [ReportingPeriodID]    FLOAT (53)     NULL,
    [ReportingPeriodShort] DATETIME       NULL,
    [ReportingPeriod]      NVARCHAR (255) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_EBP_ReportingPeriodID]
    ON [App].[EBP_ReportingPeriodID];

