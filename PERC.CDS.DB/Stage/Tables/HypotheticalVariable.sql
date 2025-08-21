CREATE TABLE [Stage].[HypotheticalVariable] (
    [HypotheticalModelName] VARCHAR (50) NULL,
    [VariableName]          VARCHAR (50) NULL,
    [HypotheticalValue]     VARCHAR (50) NULL,
    [HypotheticalOperator]  VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HypotheticalVariable]
    ON [Stage].[HypotheticalVariable];

