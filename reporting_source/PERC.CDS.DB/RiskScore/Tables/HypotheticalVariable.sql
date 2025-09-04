CREATE TABLE [RiskScore].[HypotheticalVariable] (
    [HypotheticalVariableID] INT             IDENTITY (1, 1) NOT NULL,
    [HypotheticalModelID]    TINYINT         NOT NULL,
    [VariableID]             SMALLINT        NULL,
    [HypotheticalValue]      DECIMAL (15, 8) NULL,
    [HypotheticalOperator]   VARCHAR (10)    NULL,
    CONSTRAINT [PK__HypotheticalVariable_HypotheticalVariableID] PRIMARY KEY CLUSTERED ([HypotheticalVariableID] ASC),
    CONSTRAINT [UC_HypotheticalVariable_HypotheticalModelID_VariableID] UNIQUE NONCLUSTERED ([HypotheticalModelID] ASC, [VariableID] ASC)
);



