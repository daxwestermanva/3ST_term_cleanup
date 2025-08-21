CREATE TABLE [App].[Log_ExecutionErrorLog] (
    [ExecutionOnErrorLogID] INT              IDENTITY (1, 1) NOT NULL,
    [ExecutionLogID]        INT              NOT NULL,
    [ExecutionGuid]         UNIQUEIDENTIFIER NULL,
    [TaskName]              VARCHAR (255)    NOT NULL,
    [TaskID]                UNIQUEIDENTIFIER NULL,
    [ErrorCode]             INT              NOT NULL,
    [ErrorDescription]      VARCHAR (MAX)    NULL,
    [ErrorTime]             DATETIME         NOT NULL,
    CONSTRAINT [PK_ExecutionOnErrorLog] PRIMARY KEY CLUSTERED ([ExecutionOnErrorLogID] ASC) WITH (DATA_COMPRESSION = PAGE)
);


GO
