CREATE TABLE [PDE_Daily].[PDE_PatientLevel] (
    [MVIPersonSID]                   INT            NOT NULL,
    [AMADischarge]                   INT            NULL,
    [Census]                         INT            NULL,
    [DisDay]                         DATE           NULL,
    [DischargeDateTime]              DATETIME2 (0)  NULL,
    [AdmitDateTime]                  DATETIME2 (0)  NULL,
    [POD]                            VARCHAR (50)   NULL,
    [Exclusion30]                    INT            NULL,
    [RF_DisDay]                      DATE           NULL,
    [Group2_High_Den]                INT            NULL,
    [Group1_Low_Den]                 INT            NULL,
    [Group3_HRF]                     INT            NULL,
    [G1_MH]                          INT            NULL,
    [G1_NMH]                         INT            NULL,
    [Disch_BedSecn]                  VARCHAR (50)   NULL,
    [Disch_BedSecName]               VARCHAR (50)   NULL,
    [DischBed_MH_Acute]              SMALLINT       NULL,
    [DischBed_MH_Res]                SMALLINT       NULL,
    [DischBed_NMH]                   SMALLINT       NULL,
    [Discharge_Sta6a]                VARCHAR (50)   NULL,
    [PrincipalDiagnosisICD10DESC]    VARCHAR (8000) NULL,
    [PrincipalDiagnosisICD10Code]    VARCHAR (100)  NULL,
    [AdmitDiagnosis]                 VARCHAR (50)   NULL,
    [PostDisch_30days]               DATETIME2 (0)  NULL,
    [PDE_GRP]                        INT            NOT NULL,
    [HRF]                            INT            NOT NULL,
    [G1_MH_Final]                    INT            NULL,
    [NumberOfMentalHealthVisits]     INT            NULL,
    [PDE1]                           INT            NULL,
    [PDE1_GRP1]                      INT            NULL,
    [PDE1_GRP2]                      INT            NULL,
    [PDE1_GRP3]                      INT            NULL,
    [FutureApptDate]                 DATETIME2 (0)  NULL,
    [FirstVisitDateTime]             DATETIME2 (0)  NULL,
    [FirstCL]                        VARCHAR (100)  NULL,
    [FirstClName]                    VARCHAR (100)  NULL,
    [FirstClc]                       VARCHAR (100)  NULL,
    [FirstClcName]                   VARCHAR (100)  NULL,
    [FirstProviderName]              VARCHAR (100)  NULL,
    [LastVisitDateTime]              DATETIME2 (0)  NULL,
    [LastCL]                         VARCHAR (100)  NULL,
    [LastClName]                     VARCHAR (100)  NULL,
    [LastClc]                        VARCHAR (100)  NULL,
    [LastClcName]                    VARCHAR (100)  NULL,
    [LastProviderName]               VARCHAR (100)  NULL,
    [NonCountSum]                    INT            NULL,
    [PDE1_Met]                       INT            NULL,
    [NumberOfVisits]                 INT            NOT NULL,
    [Facility_Discharge]             NVARCHAR (510) NULL,
    [ChecklistID_Discharge]          NVARCHAR (30)  NULL,
    [ChecklistID_Metric]             NVARCHAR (15)  NULL,
    [Facility_Metric]                NVARCHAR (510) NULL,
    [MetricHomeUpdate]               DATE           NULL,
    [ChecklistID_Home]               NVARCHAR (30)  NULL,
    [Facility_Home]                  NVARCHAR (510) NULL,
    [StaffName_MHTC]                 VARCHAR (100)  NULL,
    [ProviderSID_MHTC]               INT            NULL,
    [DivisionName_MHTC]              VARCHAR (100)  NULL,
    [ChecklistID_MHTC]               NVARCHAR (30)  NULL,
    [StaffName_PCP]                  VARCHAR (100)  NULL,
    [DivisionName_PCP]               VARCHAR (100)  NULL,
    [ChecklistID_PCP]                NVARCHAR (30)  NULL,
    [TeamName_BHIP]                  VARCHAR (100)  NULL,
    [TeamSID_BHIP]                   INT            NULL,
    [DivisionName_BHIP]              VARCHAR (100)  NULL,
    [ChecklistID_BHIP]               NVARCHAR (30)  NULL,
    [PatientRecordFlagHistoryAction] VARCHAR (50)   NULL,
    [HRF_ActionDate]                 DATE           NULL,
    [RNTMM]                          INT            NULL,
    [VNTMM]                          INT            NULL,
    [UpdateDate]                     DATETIME       NOT NULL,
    [MedicalService]                 VARCHAR (500)  NULL,
    [Accommodation]                  VARCHAR (500)  NULL,
    [SUD_Dx]                         SMALLINT       NULL,
    [SUD_Dx_Label]                   VARCHAR (8000) NULL,
    [Overdose_Dx]                    SMALLINT       NULL,
    [SI_Dx]                          SMALLINT       NULL,
    [SuicideRelated_Dx_Label]        VARCHAR (8000) NULL,
    [ApptDays]                       INT            NULL
);




























GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PDE_PatientLevel]
    ON [PDE_Daily].[PDE_PatientLevel];

