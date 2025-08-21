CREATE TABLE [CaringLetters].[VCL_LMS_Writeback] (
    [MVIPersonSID]              INT           NULL,
    [VCL_ID]                    INT           NOT NULL,
    [DoNotSend]                 TINYINT       NULL,
    [UpdateName]                TINYINT       NULL,
    [UpdateFirstName]           VARCHAR (50)  NULL,
    [UpdateFullName]            VARCHAR (100) NULL,
    [UpdateAddress]             TINYINT       NULL,
    [UpdateStreetAddress]       VARCHAR (100) NULL,
    [UpdateCity]                VARCHAR (100) NULL,
    [UpdateState]               VARCHAR (22)  NULL,
    [UpdateZip]                 VARCHAR (5)   NULL,
    [UpdateCountry]             VARCHAR (2)   NULL,
    [UpdateGunlockQuantity]     SMALLINT      NULL,
    [UpdateMedEnvelopeQuantity] SMALLINT      NULL,
    [InsertDate]                DATETIME      NULL,
    [UserID]                    VARCHAR (100) NULL
);

