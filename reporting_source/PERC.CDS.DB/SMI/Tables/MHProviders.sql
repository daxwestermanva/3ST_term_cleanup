CREATE TABLE [SMI].[MHProviders] (
    [PatientICN]   VARCHAR (50)  NULL,
    [MVIPersonSID] BIGINT        NULL,
    [GroupID]      INT           NOT NULL,
    [GroupType]    VARCHAR (11)  NOT NULL,
    [ProviderSID]  INT           NULL,
    [ProviderName] VARCHAR (200) NULL,
    [ChecklistID]  NVARCHAR (10) NULL,
    [STA3N]        INT           NULL,
    [VISN]         INT           NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHProviders]
    ON [SMI].[MHProviders];

