CREATE TABLE [CaringLetters].[VCL_NCOA_UpdateAddress] (
    [VCL_ID]                          INT           NULL,
    [Randomization]                   VARCHAR (10)  NULL,
    [Letter]                          SMALLINT      NULL,
    [Letter_toPrinter_Date_Scheduled] DATE          NULL,
    [Salutation]                      VARCHAR (100) NULL,
    [FullName]                        VARCHAR (100) NULL,
    [StreetAddress1]                  VARCHAR (100) NULL,
    [StreetAddress2]                  VARCHAR (100) NULL,
    [StreetAddress3]                  VARCHAR (100) NULL,
    [City]                            VARCHAR (100) NULL,
    [State]                           VARCHAR (5)   NULL,
    [Zip4]                            VARCHAR (10)  NULL,
    [NCOAUpdated]                     VARCHAR (1)   NOT NULL,
    [NCOA FULL NAME]                  VARCHAR (100) NULL,
    [NCOA ADDRESS1]                   VARCHAR (100) NULL,
    [NCOA ADDRESS2]                   VARCHAR (100) NULL,
    [NCOA ADDRESS3]                   VARCHAR (100) NULL,
    [NCOA CITY]                       VARCHAR (100) NULL,
    [NCOA STATE]                      VARCHAR (5)   NULL,
    [NCOA ZIP +4]                     VARCHAR (10)  NULL,
    [NCOA RETURN CODE]                VARCHAR (1)   NOT NULL,
    [MAIL or FAIL]                    VARCHAR (1)   NOT NULL,
    [InputSEQ]                        VARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NCOA_UpdateAddress]
    ON [CaringLetters].[VCL_NCOA_UpdateAddress];

