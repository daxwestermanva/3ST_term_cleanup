CREATE TABLE [PDSI].[AUD_Details] (
    [patientsid] INT           NULL,
    [AUDdxdate]  DATETIME2 (0) NULL,
    [AUDsetting] VARCHAR (11)  NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AUD_Details]
    ON [PDSI].[AUD_Details];

