CREATE TABLE [PDSI].[OUD_Details] (
    [patientsid] INT           NULL,
    [OUDdxdate]  DATETIME2 (0) NULL,
    [OUDsetting] VARCHAR (11)  NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_OUD_Details]
    ON [PDSI].[OUD_Details];

