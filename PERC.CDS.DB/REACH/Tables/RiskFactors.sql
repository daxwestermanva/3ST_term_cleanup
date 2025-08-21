CREATE TABLE [REACH].[RiskFactors] (
    [Risk]        NVARCHAR (255) NULL,
    [PrintName]   NVARCHAR (255) NULL,
    [TimeFrame]   INT            NULL,
    [Coefficient] FLOAT (53)     NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskFactors]
    ON [REACH].[RiskFactors];

