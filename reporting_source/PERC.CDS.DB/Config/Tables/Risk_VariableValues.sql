CREATE TABLE [Config].[Risk_VariableValues] (
    [variablevalue] NVARCHAR (255) NULL,
    [ValueLow]      FLOAT (53)     NULL,
    [ValueHigh]     FLOAT (53)     NULL,
    [ValueVarchar]  NVARCHAR (255) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Risk_VariableValues]
    ON [Config].[Risk_VariableValues];

