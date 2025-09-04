CREATE TABLE [RiskScore].[HypotheticalModel] (
    [HypotheticalModelID]          INT       IDENTITY (1, 1) NOT NULL,
    [ModelID]                      TINYINT       NOT NULL,
    [HypotheticalModelName]        VARCHAR (100) NOT NULL,
    [HypotheticalModelDescription] VARCHAR (255) NULL,
    [Criteria1VariableID]          SMALLINT      NULL,
    [Criteria1Method]              VARCHAR (100) NULL,
    CONSTRAINT [PK__HypotheticalModel_HypotheticalModelID] PRIMARY KEY CLUSTERED ([HypotheticalModelID] ASC),
    CONSTRAINT [UC_HypotheticalModel_ModelID_HypotheticalModelName] UNIQUE NONCLUSTERED ([ModelID] ASC, [HypotheticalModelName] ASC)
);



