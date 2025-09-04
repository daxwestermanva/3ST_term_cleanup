CREATE TABLE [SPPRITE].[RiskIDandDisplay] (
    [MVIPersonSID] INT         NOT NULL,
    [RiskFactorID] CHAR (1)    NULL,
    [ChecklistID]  VARCHAR (5) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskIDandDisplay]
    ON [SPPRITE].[RiskIDandDisplay];

