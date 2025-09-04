CREATE TABLE [COVID].[HRF_SurveillancePatient] (
    [MVIPersonSID]      INT           NOT NULL,
    [HRF_ChecklistID]   VARCHAR (5)   NULL,
    [Elig_HRFC19_Date]  DATETIME2 (0) NULL,
    [FUDateTime]        DATETIME2 (0) NULL,
    [OutreachStatus]    VARCHAR (20)  NULL,
    [Elig_NonVALabTest] INT           NULL,
    [MHIP_AtElig]       BIT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HRF_SurveillancePatient]
    ON [COVID].[HRF_SurveillancePatient];

