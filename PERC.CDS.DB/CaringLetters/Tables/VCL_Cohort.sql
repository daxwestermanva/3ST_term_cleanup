CREATE TABLE [CaringLetters].[VCL_Cohort] (
    [VCL_ID]                      INT           NOT NULL,
    [MVIPersonSID]                INT           NOT NULL,
    [PatientICN]                  VARCHAR (20)  NULL,
    [ICNSource]                   VARCHAR (35)  NULL,
    [VCL_NearestFacilitySiteCode] VARCHAR (7)   NULL,
    [VCL_IsVet]                   VARCHAR (5)   NULL,
    [VCL_IsActiveDuty]            VARCHAR (10)  NULL,
    [VCL_VeteranStatus]           SMALLINT      NULL,
    [VCL_MilitaryBranch]          SMALLINT      NULL,
    [VCL_Call_Date]               DATE          NULL,
    [DoNotSend]                   TINYINT       NULL,
    [DoNotSendDate]               DATETIME      NULL,
    [DoNotSendReason]             VARCHAR (100) NULL,
    [FirstLetterDate]             DATE          NULL,
    [SecondLetterDate]            DATE          NULL,
    [ThirdLetterDate]             DATE          NULL,
    [FourthLetterDate]            DATE          NULL,
    [FifthLetterDate]             DATE          NULL,
    [SixthLetterDate]             DATE          NULL,
    [SeventhLetterDate]           DATE          NULL,
    [EighthLetterDate]            DATE          NULL,
    [LetterFrom]                  VARCHAR (10)  NULL,
    [InsertDate]                  DATE          NULL
);


GO
CREATE CLUSTERED INDEX [CIX_VCLCohort_MVISID]
    ON [CaringLetters].[VCL_Cohort]([MVIPersonSID] ASC);

