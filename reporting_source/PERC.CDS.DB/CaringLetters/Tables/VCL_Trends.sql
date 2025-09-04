CREATE TABLE [CaringLetters].[VCL_Trends] (
    [WeekBegin]                  DATE NULL,
    [WeekEnd]                    DATE NULL,
    [NotEnrolledCount]           INT  NULL,
    [NotEnrolledDeceased]        INT  NULL,
    [NotEnrolledAddress]         INT  NULL,
    [NotEnrolledIneligible]      INT  NULL,
    [NotEnrolledVCLCL]           INT  NULL,
    [NotEnrolledOptOut]          INT  NULL,
    [NotEnrolledHRFCL]           INT  NULL,
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
    ON [CaringLetters].[VCL_Trends];

