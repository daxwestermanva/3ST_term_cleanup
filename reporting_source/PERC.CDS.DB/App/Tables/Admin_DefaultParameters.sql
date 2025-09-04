CREATE TABLE [App].[Admin_DefaultParameters] (
    [UserID]         VARCHAR (50)   NULL,
    [ReportName]     VARCHAR (100)  NULL,
    [ParameterName]  VARCHAR (100)  NULL,
    [ParameterValue] VARCHAR (1000) NULL,
    [LastUpdated]    DATETIME2 (0)  NULL
);


GO
CREATE CLUSTERED INDEX [cdx_App_Admin_DefaultParameters_ReportName]
    ON [App].[Admin_DefaultParameters]([ReportName] ASC) WITH (FILLFACTOR = 80, DATA_COMPRESSION = PAGE);


GO
CREATE NONCLUSTERED INDEX [idx_App_Admin_DefaultParameters_UserID]
    ON [App].[Admin_DefaultParameters]([UserID] ASC) WITH (FILLFACTOR = 80, DATA_COMPRESSION = PAGE);

