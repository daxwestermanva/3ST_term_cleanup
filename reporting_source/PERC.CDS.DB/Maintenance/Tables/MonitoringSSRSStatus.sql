CREATE TABLE [Maintenance].[MonitoringSSRSStatus] (
    [ObjectFileName]                          VARCHAR (200) NOT NULL,
    [ObjectPath]                              VARCHAR (500) NOT NULL,
    [ReportLocation]                          VARCHAR (50)  NULL,
    [Environment]                             VARCHAR (50)  NULL,
    [GroupName]                               VARCHAR (50)  NULL,
    [LastDayAccessed]                         DATETIME      NULL,
    [HitCount]                                INT           NULL,
    [UserCount]                               INT           NULL,
    [SuccessRate]                             FLOAT (53)    NULL,
    [DaysSpan]                                INT           NOT NULL,
    [HitTotalCount]                           INT           NOT NULL,
    [UserTotalCount]                          INT           NOT NULL,
    [TimeDataRetrievalDayAvg]                 INT           NULL,
    [TimeDataRetrievalAvg]                    FLOAT (53)    NULL,
    [TimeDataRetrievalProjected]              FLOAT (53)    NULL,
    [TimeDataRetrievalProjectedDeviation]     FLOAT (53)    NULL,
    [TimeDataRetrievalStandardDeviation]      FLOAT (53)    NULL,
    [TimeDataRetrievalStandardDeviationDelta] FLOAT (53)    NULL,
    [TimeProcessingDayAvg]                    INT           NULL,
    [TimeProcessingAvg]                       FLOAT (53)    NULL,
    [TimeProcessingProjected]                 FLOAT (53)    NULL,
    [TimeProcessingProjectedDeviation]        FLOAT (53)    NULL,
    [TimeProcessingStandardDeviation]         FLOAT (53)    NULL,
    [TimeProcessingStandardDeviationDelta]    FLOAT (53)    NULL,
    [TimeRenderingDayAvg]                     INT           NULL,
    [TimeRenderingAvg]                        FLOAT (53)    NULL,
    [TimeRenderingProjected]                  FLOAT (53)    NULL,
    [TimeRenderingProjectedDeviation]         FLOAT (53)    NULL,
    [TimeRenderingStandardDeviation]          FLOAT (53)    NULL,
    [TimeRenderingStandardDeviationDelta]     FLOAT (53)    NULL,
    [RuntimeDayAvg]                           INT           NULL,
    [RuntimeAvg]                              FLOAT (53)    NULL,
    [RuntimeProjected]                        FLOAT (53)    NULL,
    [RuntimeProjectedDeviation]               FLOAT (53)    NULL,
    [RuntimeStandardDeviation]                FLOAT (53)    NULL,
    [RuntimeStandardDeviationDelta]           FLOAT (53)    NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MonitoringSSRSStatus]
    ON [Maintenance].[MonitoringSSRSStatus];

