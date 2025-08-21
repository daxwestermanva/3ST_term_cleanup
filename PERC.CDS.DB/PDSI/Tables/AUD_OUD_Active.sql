CREATE TABLE [PDSI].[AUD_OUD_Active] (
    [MVIPersonSID]        INT NULL,
    [AUDactiveMostrecent] INT NOT NULL,
    [OUDactiveMostrecent] INT NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AUD_OUD_Active]
    ON [PDSI].[AUD_OUD_Active];

