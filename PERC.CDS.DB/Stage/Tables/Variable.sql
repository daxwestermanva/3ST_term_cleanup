CREATE TABLE [Stage].[Variable] (
    [VariableName]             VARCHAR (100) NOT NULL,
    [VariableDescription]      VARCHAR (500) NULL,
    [VariableType]             VARCHAR (50)  NULL,
    [Domain]                   VARCHAR (50)  NULL,
    [TimeFrameUnit]            CHAR (1)      NULL,
    [TimeFrame]                VARCHAR (3)   NULL,
    [ImputeValue]              VARCHAR (100) NULL,
    [Impute1UsingVariableName] VARCHAR (100) NULL,
    [Impute1Method]            VARCHAR (100) NULL,
    [Impute2UsingVariableName] VARCHAR (100) NULL,
    [Impute2Method]            VARCHAR (100) NULL,
    [NotInModel]               CHAR (1)      NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Variable]
    ON [Stage].[Variable];

