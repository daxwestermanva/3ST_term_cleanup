CREATE TABLE [CaringLetters].[VCL_Writeback] (
    [MVIPersonSID]         INT           NOT NULL,
    [DoNotSend]            TINYINT       NULL,
    [DoNotSendReason]      VARCHAR (20)  NULL,
    [UsePreferredName]     TINYINT       NULL,
    [UpdateName]           TINYINT       NULL,
    [UpdateFirstName]      VARCHAR (50)  NULL,
    [UpdateFullName]       VARCHAR (100) NULL,
    [UpdateAddress]        TINYINT       NULL,
    [UpdateStreetAddress1] VARCHAR (100) NULL,
    [UpdateStreetAddress2] VARCHAR (100) NULL,
    [UpdateStreetAddress3] VARCHAR (50)  NULL,
    [UpdateCity]           VARCHAR (100) NULL,
    [UpdateState]          VARCHAR (22)  NULL,
    [UpdateZip]            VARCHAR (5)   NULL,
    [UpdateCountry]        VARCHAR (100) NULL,
    [InsertDate]           DATETIME      NULL,
    [UserID]               VARCHAR (100) NULL
);


GO
CREATE CLUSTERED INDEX [CIX_VCLWriteback_MVISID]
    ON [CaringLetters].[VCL_Writeback]([MVIPersonSID] ASC);

