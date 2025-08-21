CREATE TABLE [Maintenance].[MonitoringSSRSLinearRegression] (
    [ObjectFileName]  VARCHAR (200) NOT NULL,
    [ReportLocation]  VARCHAR (50)  NULL,
    [Environment]     VARCHAR (50)  NOT NULL,
    [HitCount]        INT           NOT NULL,
    [UserCount]       INT           NOT NULL,
    [ColumnName]      VARCHAR (50)  NOT NULL,
    [DaysSpan]        INT           NOT NULL,
    [StartedOn]       DATETIME2 (0) NOT NULL,
    [EndedOn]         DATETIME2 (0) NOT NULL,
    [XMin]            FLOAT (53)    NOT NULL,
    [XMax]            FLOAT (53)    NOT NULL,
    [XBar]            FLOAT (53)    NOT NULL,
    [YMin]            FLOAT (53)    NOT NULL,
    [YMax]            FLOAT (53)    NOT NULL,
    [YBar]            FLOAT (53)    NOT NULL,
    [YAvg]            FLOAT (53)    NOT NULL,
    [VectorLength]    FLOAT (53)    NOT NULL,
    [Slope]           FLOAT (53)    NOT NULL,
    [Intercept]       FLOAT (53)    NOT NULL,
    [SlopeNormalized] FLOAT (53)    NOT NULL,
    [Projected]       FLOAT (53)    NOT NULL,
    [Sigma]           FLOAT (53)    NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MonitoringSSRSLinearRegression]
    ON [Maintenance].[MonitoringSSRSLinearRegression];

