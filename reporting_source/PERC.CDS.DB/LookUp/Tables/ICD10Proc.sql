CREATE TABLE [LookUp].[ICD10Proc] (
    [ICD10ProcedureSID]                BIGINT         NOT NULL,
    [Sta3n]                            SMALLINT       NOT NULL,
    [ICD10ProcedureDescription]        VARCHAR (8000) NULL,
    [ICD10ProcedureShort]              VARCHAR (100)  NULL,
    [ICD10ProcedureCode]               VARCHAR (100)  NULL,
    [Psych_Therapy_ICD10Proc]          BIT            NULL,
    [RM_ActiveTherapies_ICD10Proc]     BIT            NULL,
    [RM_OccupationalTherapy_ICD10Proc] BIT            NULL,
    [RM_ChiropracticCare_ICD10Proc]    BIT            NULL,
    [CIH_ICD10Proc]                    BIT            NULL,
    [MedMgt_ICD10Proc]                 BIT            NULL,
    [SAE_Detox_ICD10Proc]              BIT            NULL
);


GO
CREATE CLUSTERED INDEX [CIX_LookUp_ICD10ProcSID]
    ON [LookUp].[ICD10Proc]([ICD10ProcedureSID] ASC);

