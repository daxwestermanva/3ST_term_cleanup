CREATE TABLE [SUD].[Cohort] (
    [MVIPersonSID]                  INT NULL,
    [PDSI]                          BIT NULL,
    [STORM]                         BIT NULL,
    [OUD_DoD]                       BIT NULL,
    [OUD]                           BIT NULL,
    [AUD_ORM]                       BIT NULL,
    [CocaineUD_AmphUD]              BIT NULL,
    [SUDdx_poss]                    BIT NULL,
    [OpioidForPain_Rx]              BIT NULL,
    [RecentlyDiscontinuedOpioid_Rx] BIT NULL,
    [TramadolOnly]                  BIT NULL,
    [Bowel_Rx]                      BIT NULL,
    [Anxiolytics_Rx]                BIT NULL,
    [SedatingPainORM_Rx]            BIT NULL,
    [Benzodiazepine_Rx]             BIT NULL,
    [StimulantADHD_Rx]              BIT NULL,
    [Hospice]                       BIT NULL,
    [CancerDx]                      BIT NULL,
    [PTSD]                          BIT NULL,
    [SedativeUseDisorder]           BIT NULL,
    [ODPastYear]                    BIT NULL,
    [CommunityCare_ODPastYear]      INT NULL,
    [Schiz]                         BIT NULL,
    [DementiaExcl]                  BIT NULL,
    [antipsychotic_geri_rx]         BIT NULL
);






























GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Cohort]
    ON [SUD].[Cohort];

