CREATE TABLE [App].[Log_ExecutionTaskLog] (
    [ExecutionTaskLogID] INT              IDENTITY (1, 1) NOT NULL,
    [ExecutionLogID]     INT              NOT NULL,
    [ExecutionGuid]      UNIQUEIDENTIFIER NOT NULL,
    [TaskName]           VARCHAR (255)    NOT NULL,
    [TaskID]             UNIQUEIDENTIFIER NULL,
    [TaskDesc]           VARCHAR (50)     NULL,
    [OnPreExecuteTime]   DATETIME         NULL,
    [OnPostExecuteTime]  DATETIME         NULL,
    [OnErrorTime]        DATETIME         NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
