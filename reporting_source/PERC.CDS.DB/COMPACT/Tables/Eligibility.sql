CREATE TABLE [COMPACT].[Eligibility] (
    [MVIPersonSID]    INT           NOT NULL,
    [CompactEligible] TINYINT       NULL,
    [StartDate]       DATETIME2 (7) NULL,
    [EndDate]         DATETIME2 (7) NULL,
    [ActiveRecord]    TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Eligibility]
    ON [COMPACT].[Eligibility];

