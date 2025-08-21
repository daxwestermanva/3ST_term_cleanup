CREATE TABLE [Log].[ExecutionLog] (
    [ExecutionLogID]        INT           IDENTITY (1, 1) NOT NULL,
    [ParentExecutionLogID]  INT           NULL,
    [PrimaryExecutionLogID] INT           NULL,
    [Name]                  VARCHAR (100) NOT NULL,
    [Description]           VARCHAR (200) NULL,
    [ExecutionServer]       VARCHAR (50)  NOT NULL,
    [ExecutionUserName]     VARCHAR (50)  NOT NULL,
    [StartDateTime]         DATETIME      NOT NULL,
    [EndDateTime]           DATETIME      NULL,
    [Status]                VARCHAR (50)  NULL,
    [SessionID]             INT           NOT NULL,
    [SessionDateTime]       DATETIME      NOT NULL,
    CONSTRAINT [PK_Log_ExecutionLog] PRIMARY KEY NONCLUSTERED ([ExecutionLogID] ASC) WITH (FILLFACTOR = 90)
);






GO
CREATE NONCLUSTERED INDEX [IDX_Log_ExecutionLog_StartTime]
    ON [Log].[ExecutionLog]([StartDateTime] ASC);




GO
CREATE NONCLUSTERED INDEX [IDX_Log_ExecutionLog_Primary]
    ON [Log].[ExecutionLog]([PrimaryExecutionLogID] ASC);


GO
CREATE NONCLUSTERED INDEX [IDX_Log_ExecutionLog_Parent]
    ON [Log].[ExecutionLog]([ParentExecutionLogID] ASC);

