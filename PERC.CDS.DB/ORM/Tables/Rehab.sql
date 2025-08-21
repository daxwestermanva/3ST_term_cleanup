CREATE TABLE [ORM].[Rehab] (
    [MVIPersonSID]                INT           NULL,
    [RM_ActiveTherapies_Key]      INT           NOT NULL,
    [RM_ActiveTherapies_Date]     DATETIME2 (0) NULL,
    [RM_ChiropracticCare_Key]     INT           NOT NULL,
    [RM_ChiropracticCare_Date]    DATETIME2 (0) NULL,
    [RM_OccupationalTherapy_Key]  INT           NOT NULL,
    [RM_OccupationalTherapy_Date] DATETIME2 (0) NULL,
    [RM_OtherTherapy_Key]         INT           NOT NULL,
    [RM_OtherTherapy_Date]        DATETIME2 (0) NULL,
    [RM_PhysicalTherapy_Key]      INT           NOT NULL,
    [RM_PhysicalTherapy_Date]     DATETIME2 (0) NULL,
    [RM_SpecialtyTherapy_Key]     INT           NOT NULL,
    [RM_SpecialtyTherapy_Date]    DATETIME2 (0) NULL,
    [RM_PainClinic_Key]           INT           NOT NULL,
    [RM_PainClinic_Date]          DATETIME2 (0) NULL,
    [CAM_Key]                     INT           NOT NULL,
    [CAM_Date]                    DATETIME2 (0) NULL
);










GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Rehab]
    ON [ORM].[Rehab];

