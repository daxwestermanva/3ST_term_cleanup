CREATE TABLE [Stage].[HypotheticalModel] (
    [HypotheticalModelName]        VARCHAR (50) NULL,
    [ModelName]                    VARCHAR (50) NULL,
    [HypotheticalModelDescription] VARCHAR (50) NULL,
    [Criteria1VariableName]        VARCHAR (50) NULL,
    [Criteria1Method]              VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HypotheticalModel]
    ON [Stage].[HypotheticalModel];

