CREATE TABLE [REACH].[RiskFactorCurrent] (
    [Category]        NVARCHAR (255) NULL,
    [Risk]            NVARCHAR (255) NULL,
    [PrintName]       NVARCHAR (255) NULL,
    [RiskLabel]       NVARCHAR (255) NULL,
    [TimeFrame]       FLOAT (53)     NULL,
    [Coefficient]     FLOAT (53)     NULL,
    [LookupColumn]    NVARCHAR (255) NULL,
    [LookUpTable]     NVARCHAR (255) NULL,
    [ReachDefinition] NVARCHAR (255) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskFactorCurrent]
    ON [REACH].[RiskFactorCurrent];

