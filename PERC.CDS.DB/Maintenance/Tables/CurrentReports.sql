CREATE TABLE [Maintenance].[CurrentReports] (
    [ReportName]        NVARCHAR (425)  NOT NULL,
    [Project]           NVARCHAR (4000) NULL,
    [ReportDescription] VARCHAR (2000)  NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CurrentReports]
    ON [Maintenance].[CurrentReports];

