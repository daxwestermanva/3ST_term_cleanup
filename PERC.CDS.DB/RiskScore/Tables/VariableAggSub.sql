CREATE TABLE [RiskScore].[VariableAggSub] (
    [VariableID]          SMALLINT     NOT NULL,
    [ReferenceVariableID] SMALLINT     NOT NULL,
    [VariableMethod]      VARCHAR (12) NOT NULL,
    [LowerLimit]          VARCHAR (12) NULL,
    [UpperLimit]          VARCHAR (12) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_VariableAggSub]
    ON [RiskScore].[VariableAggSub];

