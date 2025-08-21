CREATE TABLE [LookUp].[Lab] (
    [LabChemTestSID]                BIGINT        NULL,
    [Sta3n]                         SMALLINT      NOT NULL,
    [LabChemTestName]               VARCHAR (MAX) NULL,
    [LabChemPrintTestName]          VARCHAR (MAX) NULL,
    [LOINCSID]                      VARCHAR (50)  NULL,
    [TopographySID]                 INT           NULL,
    [LOINC]                         VARCHAR (200) NULL,
    [Topography]                    VARCHAR (100) NULL,
    [WorkloadCode]                  VARCHAR (50)  NULL,
    [A1c_Blood]                     BIT           NULL,
    [AbsoluteNeutrophilCount_Blood] BIT           NULL,
    [ALT_Blood]                     BIT           NULL,
    [AST_Blood]                     BIT           NULL,
    [BandNeutrophils_Blood]         BIT           NULL,
    [Creatinine_Blood]              BIT           NULL,
    [EGFR_Blood]                    BIT           NULL,
    [Glucose_Blood]                 BIT           NULL,
    [HDL_Blood]                     BIT           NULL,
    [Hemoglobin_Blood]              BIT           NULL,
    [LDL_Blood]                     BIT           NULL,
    [Morphine_UDS]                  BIT           NULL,
    [NonMorphineOpioid_UDS]         BIT           NULL,
    [NonOpioidAbusable_UDS]         BIT           NULL,
    [Platelet_Blood]                BIT           NULL,
    [PolysNeutrophils_Blood]        BIT           NULL,
    [Potassium_Blood]               BIT           NULL,
    [ProLactin_Blood]               BIT           NULL,
    [Sodium_Blood]                  BIT           NULL,
    [TotalCholesterol_Blood]        BIT           NULL,
    [Trig_Blood]                    BIT           NULL,
    [WhiteBloodCell_Blood]          BIT           NULL,
    [Clozapine_Blood]               BIT           NULL
);


GO
CREATE CLUSTERED INDEX [CIX_LookUpLab_LabChemTestSID]
    ON [LookUp].[Lab]([LabChemTestSID] ASC) WITH (FILLFACTOR = 100);

