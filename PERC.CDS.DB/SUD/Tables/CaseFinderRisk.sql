CREATE TABLE [SUD].[CaseFinderRisk] (
    [MVIPersonSID] INT           NULL,
    [RiskType]     VARCHAR (100) NULL,
    [SortKey]      INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaseFinderRisk]
    ON [SUD].[CaseFinderRisk];

