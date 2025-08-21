CREATE TABLE [CHOICE].[Providers] (
    [CHOICECount]      INT    NULL,
    [NonCHOICECount]   INT    NULL,
    [CHOICEPercentage] INT    NULL,
    [ProviderSID]      BIGINT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Providers]
    ON [CHOICE].[Providers];

