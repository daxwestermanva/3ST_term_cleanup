CREATE TABLE [Maintenance].[MonitoringSSRSCount] (
    [ObjectFileName]       VARCHAR (200) NULL,
    [ObjectPath]           VARCHAR (500) NULL,
    [ReportLocation]       VARCHAR (50)  NULL,
    [Environment]          VARCHAR (50)  NULL,
    [GroupName]            VARCHAR (50)  NULL,
    [CountType]            VARCHAR (20)  NOT NULL,
    [Date]                 DATE          NULL,
    [Weekday]              INT           NULL,
    [Week]                 INT           NULL,
    [Month]                INT           NULL,
    [Year]                 INT           NULL,
    [FiscalYear]           INT           NULL,
    [HitCount]             INT           NULL,
    [UserCount]            INT           NULL,
    [SuccessRate]          FLOAT (53)    NULL,
    [RuntimeAvg]           INT           NULL,
    [TimeDataRetrievalAvg] INT           NULL,
    [TimeProcessingAvg]    INT           NULL,
    [TimeRenderingAvg]     INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MonitoringSSRSCount]
    ON [Maintenance].[MonitoringSSRSCount];

