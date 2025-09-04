CREATE TABLE [REACH].[NationalTiers] (
    [MVIPersonSID]        INT          NOT NULL,
    [PatientICN]          VARCHAR (50) NOT NULL,
    [RiskTierDescription] VARCHAR (85) NOT NULL,
    [RiskTier]            VARCHAR (9)  NOT NULL,
    [ReachVET_Ever]       BIT          NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Reach_NatlTiers]
    ON [REACH].[NationalTiers];



