CREATE TABLE [Stage].[VariableAggSub] (
    [VariableName]          VARCHAR (100) NOT NULL,
    [ReferenceVariableName] VARCHAR (100) NOT NULL,
    [VariableMethod]        VARCHAR (25)  NOT NULL,
    [LowerLimit]            VARCHAR (12)  NULL,
    [UpperLimit]            VARCHAR (12)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_VariableAggSub]
    ON [Stage].[VariableAggSub];

