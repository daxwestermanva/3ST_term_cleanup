CREATE TABLE [App].[Log_ExecutionVariableLog] (
    [ExecutionVariableID] INT           IDENTITY (1, 1) NOT NULL,
    [ExecutionLogID]      INT           NOT NULL,
    [VariableName]        VARCHAR (255) NOT NULL,
    [VariableValue]       VARCHAR (MAX) NULL,
    [VariableDescription] VARCHAR (MAX) NULL,
    [CaptureTime]         DATETIME      NULL,
    CONSTRAINT [PK_VariableValueLog] PRIMARY KEY CLUSTERED ([ExecutionVariableID] ASC) WITH (DATA_COMPRESSION = PAGE)
);


GO
