CREATE TABLE [CaringLetters].[HRF_Cohort] (
    [MVIPersonSID]       INT           NOT NULL,
    [PatientICN]         VARCHAR (20)  NULL,
    [OwnerChecklistID]   VARCHAR (7)   NULL,
    [EpisodeEndDateTime] DATETIME      NULL,
    [InsertDate]         DATE          NULL,
    [DoNotSend]          TINYINT       NULL,
    [DoNotSendDate]      DATETIME      NULL,
    [DoNotSendReason]    VARCHAR (100) NULL,
    [FirstLetterDate]    DATE          NULL,
    [SecondLetterDate]   DATE          NULL,
    [ThirdLetterDate]    DATE          NULL,
    [FourthLetterDate]   DATE          NULL,
    [FifthLetterDate]    DATE          NULL,
    [SixthLetterDate]    DATE          NULL,
    [SeventhLetterDate]  DATE          NULL,
    [EighthLetterDate]   DATE          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaringLettersCohort]
    ON [CaringLetters].[HRF_Cohort];

