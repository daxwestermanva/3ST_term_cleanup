CREATE TABLE [Log].[MessageLog] (
    [MessageLogID]    INT           IDENTITY (1, 1) NOT NULL,
    [ExecutionLogID]  INT           NULL,
    [Type]            VARCHAR (50)  NOT NULL,
    [Name]            VARCHAR (100) NULL,
    [Message]         VARCHAR (MAX) NULL,
    [StackTrace]      VARCHAR (MAX) NULL,
    [CreatedBy]       VARCHAR (50)  NOT NULL,
    [CreatedDateTime] DATETIME      NOT NULL,
    CONSTRAINT [PK_Log_Message] PRIMARY KEY CLUSTERED ([MessageLogID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IDX_Log_MessageLog_ExecutionLogID]
    ON [Log].[MessageLog]([ExecutionLogID] ASC);

