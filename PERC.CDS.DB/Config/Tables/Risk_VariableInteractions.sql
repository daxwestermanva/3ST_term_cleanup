CREATE TABLE [Config].[Risk_VariableInteractions] (
    [Strat]         VARCHAR (255)   NULL,
    [Theta]         DECIMAL (18, 9) NULL,
    [InteractionID] INT             NULL,
    [Interaction]   VARCHAR (255)   NULL,
    [VariableID]    INT             NULL,
    [Variable]      VARCHAR (255)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Risk_VariableInteractions]
    ON [Config].[Risk_VariableInteractions];

