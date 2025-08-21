CREATE TABLE [CaringLetters].[VCL_NCOA_BadAddress] (
    [VCL_ID]                          INT           NULL,
    [ext_id]                          INT           NULL,
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
    [Zip]                             VARCHAR (10)  NULL,
    [Updated_Information]             VARCHAR (250) NULL,
    [InputSeq]                        VARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NCOA_BadAddress]
    ON [CaringLetters].[VCL_NCOA_BadAddress];

