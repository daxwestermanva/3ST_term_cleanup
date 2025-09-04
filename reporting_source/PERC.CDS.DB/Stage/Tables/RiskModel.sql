CREATE TABLE [Stage].[RiskModel] (
    [ModelName]             VARCHAR (50) NULL,
    [RegressionType]        VARCHAR (50) NULL,
    [ModelDescription]      VARCHAR (50) NULL,
    [Intercept]             VARCHAR (50) NULL,
    [Criteria1VariableName] VARCHAR (50) NULL,
    [Criteria1Method]       VARCHAR (50) NULL,
    [Criteria2VariableName] VARCHAR (50) NULL,
    [Criteria2Method]       VARCHAR (50) NULL,
    [Criteria3VariableName] VARCHAR (50) NULL,
    [Criteria3Method]       VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskModel]
    ON [Stage].[RiskModel];

