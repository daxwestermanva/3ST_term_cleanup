CREATE TABLE [ORM].[NonVAProviders] (
    [sta3n]                   INT             NULL,
    [ProviderSID]             INT             NULL,
    [ProviderName]            VARCHAR (100)   NULL,
    [PositionTitle]           VARCHAR (100)   NULL,
    [ServiceSection]          VARCHAR (250)   NULL,
    [ChoicePercent]           DECIMAL (10, 4) NULL,
    [ChoiceFlag]              SMALLINT        NULL,
    [ChoicePercentFlag]       SMALLINT        NULL,
    [SStaffNVAPrescriberFlag] SMALLINT        NULL,
    [NonVAPrescriberFlag_VA]  SMALLINT        NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NonVAProviders]
    ON [ORM].[NonVAProviders];

