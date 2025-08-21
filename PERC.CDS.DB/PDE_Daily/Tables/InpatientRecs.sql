CREATE TABLE [PDE_Daily].[InpatientRecs] (
    [MVIPersonSID]                INT            NOT NULL,
    [AMADischarge]                INT            NULL,
    [Census]                      INT            NULL,
    [DisDay]                      DATE           NULL,
    [DischargeDateTime]           DATETIME2 (0)  NULL,
    [AdmitDateTime]               DATETIME2 (0)  NULL,
    [POD]                         VARCHAR (50)   NULL,
    [Exclusion30]                 INT            NULL,
    [RF_DisDay]                   DATE           NULL,
    [Group2_High_Den]             INT            NULL,
    [Group1_Low_Den]              INT            NULL,
    [Group3_HRF]                  INT            NULL,
    [G1_MH]                       INT            NULL,
    [G1_NMH]                      INT            NULL,
    [Disch_BedSecn]               VARCHAR (50)   NULL,
    [Disch_BedSecName]            VARCHAR (50)   NULL,
    [DischBed_MH_Acute]           SMALLINT       NULL,
    [DischBed_MH_Res]             SMALLINT       NULL,
    [DischBed_NMH]                SMALLINT       NULL,
    [Discharge_Sta6a]             VARCHAR (50)   NULL,
    [PrincipalDiagnosisICD10Desc] VARCHAR (8000) NULL,
    [PrincipalDiagnosisICD10Code] VARCHAR (100)  NULL,
    [AdmitDiagnosis]              VARCHAR (50)   NULL,
    [PostDisch_30days]            DATETIME2 (0)  NULL,
    [PDE_GRP]                     INT            NOT NULL,
    [HRF]                         INT            NOT NULL,
    [G1_MH_Final]                 INT            NULL,
    [MedicalService]              VARCHAR (500)  NULL,
    [Accommodation]               VARCHAR (500)  NULL,
    [SUD_Dx]                      SMALLINT       NULL,
    [SUD_Dx_Label]                VARCHAR (8000) NULL,
    [Overdose_Dx]                 SMALLINT       NULL,
    [SI_Dx]                       SMALLINT       NULL,
    [SuicideRelated_Dx_Label]     VARCHAR (8000) NULL
);


















GO
CREATE CLUSTERED INDEX [CIX_PDEInpt_MVIPersonSID]
    ON [PDE_Daily].[InpatientRecs]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

