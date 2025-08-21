CREATE TABLE [App].[DefaultParameters] (
    [User]           VARCHAR (100)  NULL,
    [ReportName]     VARCHAR (100)  NULL,
    [ParameterName]  VARCHAR (100)  NULL,
    [ParameterValue] VARCHAR (1000) NULL,
    [LastUpdated]    DATETIME2 (0)  NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [cci_App_DefaultParameters]
    ON [App].[DefaultParameters];





