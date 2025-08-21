CREATE TABLE [ORM].[PatientReport] (
    [Sta3n]                       SMALLINT         NULL,
    [ChecklistID]                 NVARCHAR (30)    NULL,
    [VISN]                        INT              NULL,
    [Facility]                    NVARCHAR (510)   NULL,
    [MVIPersonSID]                INT              NULL,
    [OpioidForPain_Rx]            SMALLINT         NULL,
    [OUD]                         INT              NULL,
    [SUDdx_poss]                  INT              NULL,
    [Hospice]                     INT              NULL,
    [Anxiolytics_Rx]              SMALLINT         NULL,
    [RiskScore]                   DECIMAL (38, 15) NULL,
    [RiskScoreAny]                DECIMAL (38, 15) NULL,
    [RiskScoreOpioidSedImpact]    DECIMAL (38, 6)  NULL,
    [RiskScoreAnyOpioidSedImpact] DECIMAL (38, 6)  NULL,
    [RiskCategory]                INT              NOT NULL,
    [RiskAnyCategory]             INT              NOT NULL,
    [RM_ActiveTherapies_Key]      INT              NULL,
    [RM_ActiveTherapies_Date]     DATETIME2 (0)    NULL,
    [RM_ChiropracticCare_Key]     INT              NULL,
    [RM_ChiropracticCare_Date]    DATETIME2 (0)    NULL,
    [RM_OccupationalTherapy_Key]  INT              NULL,
    [RM_OccupationalTherapy_Date] DATETIME2 (0)    NULL,
    [RM_OtherTherapy_Key]         INT              NULL,
    [RM_OtherTherapy_Date]        DATETIME2 (0)    NULL,
    [RM_PhysicalTherapy_Key]      INT              NULL,
    [RM_PhysicalTherapy_Date]     DATETIME2 (0)    NULL,
    [RM_SpecialtyTherapy_Key]     INT              NULL,
    [RM_SpecialtyTherapy_Date]    DATETIME2 (0)    NULL,
    [RM_PainClinic_Key]           INT              NULL,
    [RM_PainClinic_Date]          DATETIME2 (0)    NULL,
    [CAM_Key]                     INT              NULL,
    [CAM_Date]                    DATETIME2 (0)    NULL,
    [RiosordScore]                SMALLINT         NULL,
    [RiosordRiskClass]            INT              NULL,
    [PatientRecordFlag_Suicide]   INT              NOT NULL,
    [REACH_01]                    BIT              NULL,
    [REACH_Past]                  BIT              NULL,
    [RiskCategoryLabel]           VARCHAR (125)    NOT NULL,
    [RiskAnyCategoryLabel]        VARCHAR (125)    NOT NULL,
    [ODPastYear]                  BIT              NULL,
    [ODdate]                      DATE             NULL
);










































GO



GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientReport]
    ON [ORM].[PatientReport];

