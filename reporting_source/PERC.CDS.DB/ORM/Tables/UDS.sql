CREATE TABLE [ORM].[UDS] (
    [MVIPersonSID]                   INT           NULL,
    [Sta3n]                          INT           NULL,
    [UDS_Any]                        INT           NULL,
    [UDS_Any_DateTime]               DATETIME2 (0) NULL,
    [UDS_MorphineHeroin_Key]         INT           NULL,
    [UDS_MorphineHeroin_DateTime]    DATETIME2 (0) NULL,
    [UDS_NonMorphineOpioid_Key]      INT           NULL,
    [UDS_NonMorphineOpioid_DateTime] DATETIME2 (0) NULL,
    [UDS_NonOpioidAbusable_Key]      INT           NULL,
    [UDS_NonOpioidAbusable_DateTime] DATETIME2 (0) NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_UDS]
    ON [ORM].[UDS];

