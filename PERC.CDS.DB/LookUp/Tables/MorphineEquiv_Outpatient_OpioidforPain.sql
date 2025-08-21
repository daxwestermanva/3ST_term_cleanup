CREATE TABLE [LookUp].[MorphineEquiv_Outpatient_OpioidforPain] (
    [NationalDrugSID]            BIGINT          NOT NULL,
    [Sta3n]                      SMALLINT        NOT NULL,
    [VUID]                       VARCHAR (50)    NULL,
    [DrugNameWithDose]           VARCHAR (100)   NULL,
    [Opioid]                     VARCHAR (50)    NULL,
    [DosageForm]                 VARCHAR (100)   NULL,
    [DoseType]                   VARCHAR (20)    NULL,
    [StrengthNumeric]            DECIMAL (19, 4) NULL,
    [StrengthPer_ml]             DECIMAL (10, 2) NULL,
    [StrengthPer_NasalSpray]     DECIMAL (10, 2) NULL,
    [NasalSprays_PerBottle]      INT             NULL,
    [ConversionFactor_Report]    DECIMAL (10, 2) NULL,
    [ConversionFactor_RiskScore] DECIMAL (10, 2) NULL,
    [LongActing]                 INT             NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MorphineEquiv_Outpatient_OpioidforPain]
    ON [LookUp].[MorphineEquiv_Outpatient_OpioidforPain];

