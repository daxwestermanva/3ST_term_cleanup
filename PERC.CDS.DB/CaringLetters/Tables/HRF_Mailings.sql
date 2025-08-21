CREATE TABLE [CaringLetters].[HRF_Mailings] (
    [MailingDate]         DATE          NOT NULL,
    [LetterNumber]        VARCHAR (1)   NOT NULL,
    [MVIPersonSID]        INT           NOT NULL,
    [PatientICN]          VARCHAR (20)  NULL,
    [FirstNameLegal]      VARCHAR (50)  NULL,
    [FullNameLegal]       VARCHAR (100) NULL,
    [FirstNamePreferred]  VARCHAR (50)  NULL,
    [FullNamePreferred]   VARCHAR (100) NULL,
    [PreferredName]       TINYINT       NULL,
    [NameChange]          TINYINT       NULL,
    [NameSource]          VARCHAR (5)   NULL,
    [StreetAddress1]      VARCHAR (100) NULL,
    [StreetAddress2]      VARCHAR (100) NULL,
    [StreetAddress3]      VARCHAR (50)  NULL,
    [City]                VARCHAR (100) NULL,
    [State]               VARCHAR (22)  NULL,
    [Zip]                 VARCHAR (5)   NULL,
    [Country]             VARCHAR (100) NULL,
    [AddressChange]       TINYINT       NULL,
    [AddressSource]       VARCHAR (5)   NULL,
    [DoNotSend]           TINYINT       NULL,
    [DoNotSendReason]     VARCHAR (20)  NULL,
    [ReviewRecordFlag]    TINYINT       NULL,
    [ReviewRecordReason]  VARCHAR (100) NULL,
    [ActiveMailingRecord] TINYINT       NULL,
    [ActiveRecord]        TINYINT       NULL,
    [InsertDate]          DATETIME      NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaringLettersMailings]
    ON [CaringLetters].[HRF_Mailings];

