CREATE TABLE [LookUp].[StopCode] (
    [StopCodeSID]                 BIGINT        NOT NULL,
    [Sta3n]                       SMALLINT      NOT NULL,
    [StopCodeName]                VARCHAR (100) NULL,
    [StopCode]                    VARCHAR (10)  NULL,
    [InactiveDate]                VARCHAR (10)  NULL,
    [SUDTx_NoDxReq_Stop]          SMALLINT      NULL,
    [SUDTx_DxReq_Stop]            SMALLINT      NULL,
    [RM_PhysicalTherapy_Stop]     SMALLINT      NULL,
    [RM_ChiropracticCare_Stop]    SMALLINT      NULL,
    [RM_ActiveTherapies_Stop]     SMALLINT      NULL,
    [RM_OccupationalTherapy_Stop] SMALLINT      NULL,
    [RM_SpecialtyTherapy_Stop]    SMALLINT      NULL,
    [RM_OtherTherapy_Stop]        SMALLINT      NULL,
    [RM_PainClinic_Stop]          SMALLINT      NULL,
    [Rx_MedManagement_Stop]       SMALLINT      NULL,
    [OUDTx_DxReq_Stop]            SMALLINT      NULL,
    [ORM_TimelyAppt_Stop]         SMALLINT      NULL,
    [Hospice_Stop]                SMALLINT      NULL,
    [MHOC_Homeless_Stop]          SMALLINT      NULL,
    [EmergencyRoom_Stop]          SMALLINT      NULL,
    [Reach_EmergencyRoom_Stop]    SMALLINT      NULL,
    [Reach_MH_Stop]               SMALLINT      NULL,
    [Reach_Homeless_Stop]         SMALLINT      NULL,
    [ORM_CIH_Stop]                SMALLINT      NULL,
    [ORM_OS_Education_Stop]       SMALLINT      NULL,
    [Any_Stop]                    SMALLINT      NULL,
    [ClinRelevant_Stop]           SMALLINT      NULL,
    [PC_Stop]                     SMALLINT      NULL,
    [Pain_Stop]                   SMALLINT      NULL,
    [Other_Stop]                  SMALLINT      NULL,
    [GeneralMentalHealth_Stop]    SMALLINT      NULL,
    [PrimaryCare_PDSI_Stop]       SMALLINT      NULL,
    [Incarcerated_Stop]           SMALLINT      NULL,
    [Justice_Outreach_Stop]       SMALLINT      NULL,
    [Cancer_Stop]                 SMALLINT      NULL,
    [OAT_Stop]                    SMALLINT      NULL,
    [MHOC_MentalHealth_Stop]      SMALLINT      NULL,
    [PeerSupport_Stop]            SMALLINT      NULL,
    [Telephone_MH_Stop]           SMALLINT      NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_StopCode]
    ON [LookUp].[StopCode];

