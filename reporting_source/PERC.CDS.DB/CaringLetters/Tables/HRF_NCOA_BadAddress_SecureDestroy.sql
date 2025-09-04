CREATE TABLE [CaringLetters].[HRF_NCOA_BadAddress_SecureDestroy] (
    [Company]           VARCHAR (20)  NULL,
    [FullName]          VARCHAR (100) NULL,
    [Prefix]            VARCHAR (10)  NULL,
    [First_Name]        VARCHAR (50)  NULL,
    [Mddlnm]            VARCHAR (20)  NULL,
    [Last_Name]         VARCHAR (50)  NULL,
    [Suffix1]           VARCHAR (10)  NULL,
    [DelAddr]           VARCHAR (100) NULL,
    [AltAddr]           VARCHAR (100) NULL,
    [City]              VARCHAR (100) NULL,
    [State]             VARCHAR (22)  NULL,
    [ZipCode]           VARCHAR (10)  NULL,
    [IMBRCDDGTS]        BIGINT        NULL,
    [BLNKSCKPCK]        VARCHAR (10)  NULL,
    [LetterNumber]      INT           NULL,
    [DataPullDate]      VARCHAR (10)  NULL,
    [MVIPersonSID]      INT           NOT NULL,
    [Job]               INT           NULL,
    [SecureDestruction] DATE          NULL
);

