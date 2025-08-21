CREATE TABLE [EBP].[TemplateVisitsHF] (
    [MVIPersonSID]                INT    NULL,
    [VisitSID]                    BIGINT NULL,
    [CategoryHealthFactorTypeSID] INT    NULL,
    [HealthFactorTypeSID]         INT    NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_TemplateVisitsHF]
    ON [EBP].[TemplateVisitsHF];

