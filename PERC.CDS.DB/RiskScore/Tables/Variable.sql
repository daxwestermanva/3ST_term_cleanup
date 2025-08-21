CREATE TABLE [RiskScore].[Variable] (
    [VariableID]             SMALLINT        IDENTITY (1, 1) NOT NULL,
    [VariableName]           VARCHAR (100)   NOT NULL,
    [VariableDescription]    VARCHAR (500)   NULL,
    [VariableType]           VARCHAR (25)    NULL,
    [Domain]                 VARCHAR (25)    NULL,
    [TimeFrameUnit]          CHAR (1)        NULL,
    [TimeFrame]              INT             NULL,
    [ImputeValue]            DECIMAL (15, 8) NULL,
    [Impute1UsingVariableID] SMALLINT        NULL,
    [Impute1Method]          VARCHAR (100)   NULL,
    [Impute2UsingVariableID] SMALLINT        NULL,
    [Impute2Method]          VARCHAR (100)   NULL,
    CONSTRAINT [PK__Variable__VariableID] PRIMARY KEY CLUSTERED ([VariableID] ASC),
    CONSTRAINT [UQ__Variable_VariableName] UNIQUE NONCLUSTERED ([VariableName] ASC)
);









