CREATE TABLE [SUD].[AW_Inpatient_Metrics] (
    [VISN]                        INT             NULL,
    [Facility]                    NVARCHAR (10)   NOT NULL,
    [FacilityName]                NVARCHAR (100)  NOT NULL,
    [IOCDate]                     DATETIME2 (0)   NULL,
    [Complexity]                  VARCHAR (3)     NULL,
    [MCGName]                     VARCHAR (50)    NULL,
    [FYQ]                         VARCHAR (11)    NULL,
    [Inpatients]                  INT             NOT NULL,
    [InpDischarges]               INT             NOT NULL,
    [AWinpatients]                INT             NOT NULL,
    [AWdischarges]                INT             NOT NULL,
    [AWdischarges_percent]        DECIMAL (10, 2) NOT NULL,
    [AverageLOS]                  DECIMAL (10, 2) NOT NULL,
    [InpatientDeaths]             INT             NOT NULL,
    [AMAdischarges]               INT             NOT NULL,
    [AMADisch_percent]            DECIMAL (10, 2) NOT NULL,
    [Readmissions]                INT             NOT NULL,
    [Readmission_Denominator]     INT             NOT NULL,
    [Readmission_Denominator_AMA] INT             NOT NULL,
    [ReadmissionRate]             DECIMAL (10, 2) NOT NULL,
    [ReadmissionRate_AMA]         DECIMAL (10, 2) NOT NULL,
    [Delirium]                    INT             NOT NULL,
    [Delirium_percent]            DECIMAL (10, 2) NULL,
    [Seizure]                     INT             NOT NULL,
    [Seizure_percent]             DECIMAL (10, 2) NULL,
    [AUDITC]                      INT             NOT NULL,
    [AUDITC_percent]              DECIMAL (10, 2) NULL,
    [AUD_RX]                      INT             NOT NULL,
    [AUDrx_percent]               DECIMAL (10, 2) NULL,
    [Clonidine]                   INT             NOT NULL,
    [Clonidine_percent]           DECIMAL (10, 2) NULL,
    [Chlordiazepoxide]            INT             NOT NULL,
    [Chlordiazepoxide_percent]    DECIMAL (10, 2) NULL,
    [Diazepam]                    INT             NOT NULL,
    [Diazepam_percent]            DECIMAL (10, 2) NULL,
    [Gabapentin]                  INT             NOT NULL,
    [Gabapentin_percent]          DECIMAL (10, 2) NULL,
    [Lorazepam]                   INT             NOT NULL,
    [Lorazepam_percent]           DECIMAL (10, 2) NULL,
    [Phenobarbital]               INT             NOT NULL,
    [Phenobarbital_percent]       DECIMAL (10, 2) NULL,
    [ICUadmissions]               INT             NOT NULL,
    [ICUadmissions_percent]       DECIMAL (10, 2) NOT NULL,
    [ICUtransfer]                 INT             NOT NULL,
    [ICUtransfer_percent]         DECIMAL (10, 2) NOT NULL,
    [SUD_RRTP7]                   INT             NOT NULL,
    [SUD_RRTP7_percent]           DECIMAL (10, 2) NULL
);










GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AW_Inpatient_Metrics]
    ON [SUD].[AW_Inpatient_Metrics];

