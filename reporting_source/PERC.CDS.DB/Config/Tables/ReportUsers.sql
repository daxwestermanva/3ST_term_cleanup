CREATE TABLE [Config].[ReportUsers] (
    [NetworkId] VARCHAR (50) NULL,
    [Project]   VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ReportUsers]
    ON [Config].[ReportUsers];

