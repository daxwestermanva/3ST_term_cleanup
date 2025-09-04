CREATE TABLE [REACH].[Predictors] (
    [Strat]              NVARCHAR (255) NULL,
    [theta]              FLOAT (53)     NULL,
    [InstanceVariableID] FLOAT (53)     NULL,
    [InstanceVariable]   NVARCHAR (255) NULL,
    [VariableID]         INT            NULL,
    [Variable]           NVARCHAR (255) NULL,
    [ValueLow]           FLOAT (53)     NULL,
    [ValueHigh]          FLOAT (53)     NULL,
    [ValueVarchar]       NVARCHAR (255) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Predictors]
    ON [REACH].[Predictors];

