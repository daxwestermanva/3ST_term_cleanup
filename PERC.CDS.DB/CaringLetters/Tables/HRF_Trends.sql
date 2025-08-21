CREATE TABLE [CaringLetters].[HRF_Trends] (
    [WeekBegin]                  DATE NOT NULL,
    [WeekEnd]                    DATE NULL,
    [ActiveFlagCountAll]         INT  NULL,
    [ActivationCountAll]         INT  NULL,
    [InactivationCountAll]       INT  NULL,
    [ActiveFlagCountActiveCL]    INT  NULL,
    [ActivationCountActiveCL]    INT  NULL,
    [InactivationCountActiveCL]  INT  NULL,
    [NotEnrolledCount]           INT  NULL,
    [NotEnrolledDeceased]        INT  NULL,
    [NotEnrolledAddress]         INT  NULL,
    [NotEnrolledIneligible]      INT  NULL,
    [NotEnrolledVCLCL]           INT  NULL,
    [NotEnrolledOptOut]          INT  NULL,
    [NotEnrolledHRFCL]           INT  NULL,
    [NotEnrolledFlagReactivated] INT  NULL,
    [EnrolledCount]              INT  NULL,
    [MailingsSentCount]          INT  NULL,
    [DeceasedCount]              INT  NULL,
    [OptOutCount]                INT  NULL,
    [DataSetOptOutCount]         INT  NULL,
    [BadAddressCount]            INT  NULL,
    [CompletedInterventionCount] INT  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaringLettersTrends]
    ON [CaringLetters].[HRF_Trends];

