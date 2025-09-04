CREATE TABLE [Stage].[Predictor] (
    [ModelName]     VARCHAR (50) NULL,
    [Variable1Name] VARCHAR (50) NULL,
    [Variable2Name] VARCHAR (50) NULL,
    [IsInteraction] VARCHAR (50) NULL,
    [Coefficient]   VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Predictor]
    ON [Stage].[Predictor];

