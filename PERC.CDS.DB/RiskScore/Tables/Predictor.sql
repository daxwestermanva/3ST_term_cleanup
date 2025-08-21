CREATE TABLE [RiskScore].[Predictor] (
    [PredictorID]   INT             IDENTITY (1, 1) NOT NULL,
    [ModelID]       TINYINT         NOT NULL,
    [Variable1ID]   SMALLINT        NOT NULL,
    [Variable2ID]   SMALLINT        NULL,
    [IsInteraction] BIT             NULL,
    [Coefficient]   DECIMAL (15, 8) NULL,
    CONSTRAINT [PK__Predictor_PredictorID] PRIMARY KEY CLUSTERED ([PredictorID] ASC),
    CONSTRAINT [UC_Predictor_ModelID_Variable1ID_Variable2ID] UNIQUE NONCLUSTERED ([ModelID] ASC, [Variable1ID] ASC, [Variable2ID] ASC)
);



