CREATE TABLE [BHIP].[MHTC_FollowUp] (
    [VISN]             INT            NULL,
    [ADMPARENT_FCDM]   NVARCHAR (100) NULL,
    [Mvipersonsid]     INT            NOT NULL,
    [PATIENTNAME]      VARCHAR (200)  NULL,
    [PATIENTSSN]       VARCHAR (50)   NULL,
    [Last4]            VARCHAR (4)    NULL,
    [PATIENTICN]       VARCHAR (50)   NULL,
    [CHECKLISTID]      NVARCHAR (30)  NULL,
    [MHTC_PCMM]        VARCHAR (30)   NULL,
    [Visit_Date]       DATETIME2 (0)  NULL,
    [Note_Date]        DATETIME2 (0)  NULL,
    [Note_Title]       VARCHAR (100)  NULL,
    [Author]           VARCHAR (100)  NULL,
    [Next_Appt]        DATETIME2 (0)  NULL,
    [Appt_date_Groups] VARCHAR (16)   NOT NULL,
    [Clinic]           VARCHAR (50)   NULL,
    [FOLLOWUP]         INT            NULL,
    [ONGOING]          INT            NULL,
    [HF_KEY]           NVARCHAR (122) NOT NULL
);




GO
CREATE CLUSTERED INDEX [ClusteredIndex-20250606-083645]
    ON [BHIP].[MHTC_FollowUp]([Mvipersonsid] ASC, [CHECKLISTID] ASC);

