CREATE TABLE [RiskScore].[RiskModel] (
    [ModelID]             TINYINT        IDENTITY (1, 1) NOT NULL,
    [ModelName]           VARCHAR (255)  NOT NULL,
    [RegressionType]      VARCHAR (255)  NULL,
    [ModelDescription]    VARCHAR (255)  NULL,
    [Intercept]           DECIMAL (8, 6) NULL,
    [Criteria1VariableID] SMALLINT       NULL,
    [Criteria1Method]     VARCHAR (100)  NULL,
    [Criteria2VariableID] SMALLINT       NULL,
    [Criteria2Method]     VARCHAR (100)  NULL,
    [Criteria3VariableID] SMALLINT       NULL,
    [Criteria3Method]     VARCHAR (100)  NULL,
    CONSTRAINT [PK__RiskModel__ModelID] PRIMARY KEY CLUSTERED ([ModelID] ASC),
    CONSTRAINT [UQ__RiskModel__ModelName] UNIQUE NONCLUSTERED ([ModelName] ASC)
);







