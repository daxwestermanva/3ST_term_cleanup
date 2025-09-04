CREATE TABLE [App].[Log_ExecutionProcedureLog] (
    [ExecutionProcedureID] INT           IDENTITY (1, 1) NOT NULL,
    [LogID]                INT           NOT NULL,
    [ProcedureName]        VARCHAR (255) NOT NULL,
    [TaskName]             VARCHAR (255) NULL,
    [RowsAffected]         INT           NULL,
    [CaptureTime]          DATETIME      NULL,
    CONSTRAINT [PK_ExecutionProcedureLog] PRIMARY KEY CLUSTERED ([ExecutionProcedureID] ASC) WITH (DATA_COMPRESSION = PAGE)
);


GO
