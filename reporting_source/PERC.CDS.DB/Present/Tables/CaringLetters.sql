CREATE TABLE [Present].[CaringLetters] (
    [MVIPersonSID]            INT          NOT NULL,
    [ChecklistID]             VARCHAR (5)  NULL,
    [Program]                 VARCHAR (20) NULL,
    [EligibleDate]            DATE         NULL,
    [LastScheduledLetterDate] DATE         NULL,
    [EverEnrolled]            SMALLINT     NULL,
    [CurrentEnrolled]         SMALLINT     NULL,
    [PastYearEnrolled]        SMALLINT     NULL,
    [DoNotSend_Date]          DATE         NULL,
    [DoNotSend_Reason]        VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaringLetters]
    ON [Present].[CaringLetters];

