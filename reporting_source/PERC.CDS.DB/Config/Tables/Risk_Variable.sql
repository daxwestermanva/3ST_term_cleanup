CREATE TABLE [Config].[Risk_Variable] (
    [InstanceVariableID] FLOAT (53)      NULL,
    [InstanceVariable]   NVARCHAR (255)  NULL,
    [VariableID]         INT             NULL,
    [Variable]           NVARCHAR (255)  NULL,
    [Domain]             NVARCHAR (255)  NULL,
    [VariableStatus]     FLOAT (53)      NULL,
    [PossiblePredictor]  FLOAT (53)      NULL,
    [Suffix]             NVARCHAR (255)  NULL,
    [TimeframeEnd]       NVARCHAR (256)  NULL,
    [TimeframeStart]     NVARCHAR (4000) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Risk_Variable]
    ON [Config].[Risk_Variable];

