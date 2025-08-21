CREATE TABLE [LookUp].[CPT] (
    [CPTSID]                     BIGINT         NOT NULL,
    [CPTCode]                    VARCHAR (100)  NOT NULL,
    [Sta3n]                      SMALLINT       NOT NULL,
    [CPTName]                    VARCHAR (100)  NULL,
    [CPTDescription]             VARCHAR (8000) NULL,
    [InactiveFlag]               VARCHAR (10)   NULL,
    [Rx_AntipsychoticDepot_CPT]  BIT            NULL,
    [Psych_Assessment_CPT]       BIT            NULL,
    [Psych_Therapy_CPT]          BIT            NULL,
    [RM_PhysicalTherapy_CPT]     BIT            NULL,
    [RM_ChiropracticCare_CPT]    BIT            NULL,
    [RM_ActiveTherapies_CPT]     BIT            NULL,
    [RM_OccupationalTherapy_CPT] BIT            NULL,
    [RM_SpecialtyTherapy_CPT]    BIT            NULL,
    [RM_OtherTherapy_CPT]        BIT            NULL,
    [Rx_MedManagement_CPT]       BIT            NULL,
    [Rx_NaltrexoneDepot_CPT]     BIT            NULL,
    [Cancer_CPT]                 BIT            NULL,
    [Detox_CPT]                  BIT            NULL,
    [CAM_CPT]                    BIT            NULL,
    [Methadone_OTP_HCPCS]        BIT            NULL,
    [Buprenorphine_OTP_HCPCS]    BIT            NULL,
    [Naltrexone_OTP_HCPCS]       BIT            NULL,
    [OTP_HCPCS]                  BIT            NULL,
    [Hospice_CPT]                BIT            NULL
);


GO
CREATE CLUSTERED INDEX [CIX_LookUp_CPTSID]
    ON [LookUp].[CPT]([CPTSID] ASC);

