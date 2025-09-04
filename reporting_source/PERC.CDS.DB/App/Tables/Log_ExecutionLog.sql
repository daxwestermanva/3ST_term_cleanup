CREATE TABLE [App].[Log_ExecutionLog] (
    [ExecutionLogID]          INT              IDENTITY (1, 1) NOT NULL,
    [SSISDBServerExecutionID] INT              NULL,
    [ParentExecutionLogID]    INT              NULL,
    [PrimaryExecutionLogID]   INT              NULL,
    [Description]             VARCHAR (200)    NULL,
    [PackageName]             VARCHAR (100)    NOT NULL,
    [PackageID]               UNIQUEIDENTIFIER NOT NULL,
    [PackageVersionMajor]     INT              NULL,
    [PackageVersionMinor]     INT              NULL,
    [PackageVersionBuild]     INT              NULL,
    [MachineName]             VARCHAR (50)     NOT NULL,
    [ExecutionInstanceGUID]   UNIQUEIDENTIFIER NOT NULL,
    [LogicalDate]             DATETIME         NULL,
    [UserName]                VARCHAR (50)     NOT NULL,
    [StartTime]               DATETIME         NOT NULL,
    [EndTime]                 DATETIME         NULL,
    [Status]                  VARCHAR (50)     NULL,
    [FailureTask]             VARCHAR (MAX)    NULL,
    [FailureMessage]          VARCHAR (MAX)    NULL,
    CONSTRAINT [PK_Log_ExecutionLog] PRIMARY KEY NONCLUSTERED ([ExecutionLogID] ASC) WITH (FILLFACTOR = 90)
);


GO
CREATE NONCLUSTERED INDEX [NDX_Log_ExecutionLog_ParentExecutionLogID]
    ON [App].[Log_ExecutionLog]([ParentExecutionLogID] ASC) WITH (FILLFACTOR = 90);


GO
CREATE CLUSTERED INDEX [NDX_Log_ExecutionLog_StartTime]
    ON [App].[Log_ExecutionLog]([StartTime] ASC) WITH (FILLFACTOR = 90, DATA_COMPRESSION = PAGE);


GO
