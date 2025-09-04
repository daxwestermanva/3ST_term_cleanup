CREATE TABLE [BHIP].[PatientDetails] (
    [MVIPersonSID]            INT            NULL,
    [PatientICN]              VARCHAR (50)   NULL,
    [PatientName]             VARCHAR (200)  NULL,
    [TeamSID]                 INT            NULL,
    [Team]                    VARCHAR (50)   NULL,
    [MHTC_Provider]           VARCHAR (100)  NULL,
    [BHIP_ChecklistID]        NVARCHAR (30)  NULL,
    [BHIP_Facility]           NVARCHAR (255) NULL,
    [BHIP_StartDate]          DATETIME2 (0)  NULL,
    [Code]                    NVARCHAR (255) NULL,
    [CSRE_Score]              INT            NULL,
    [HRF_Score]               INT            NULL,
    [Behavioral_Score]        INT            NULL,
    [SBOR_Score]              INT            NULL,
    [MHInpat_Score]           INT            NULL,
    [ED_Score]                INT            NULL,
    [OverdueforFill]          INT            NULL,
    [NoMHAppointment6mo]      INT            NULL,
    [TotalMissedAppointments] INT            NULL,
    [OverdueForLab]           INT            NULL,
    [AcuteEventScore]         INT            NULL,
    [ChronicCareScore]        INT            NULL,
    [LastBHIPContact]         DATETIME2 (0)  NULL,
    [FLOWEligible]            VARCHAR (3)    NOT NULL,
    [Homeless]                VARCHAR (25)   NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientDetails]
    ON [BHIP].[PatientDetails];

