CREATE TABLE [PRF_HRS].[PatientAddress] (
    [MVIPersonSID]     INT           NOT NULL,
    [OwnerChecklistID] VARCHAR (5)   NULL,
    [StreetAddress1]   VARCHAR (100) NULL,
    [StreetAddress2]   VARCHAR (100) NULL,
    [StreetAddress3]   VARCHAR (50)  NULL,
    [City]             VARCHAR (50)  NULL,
    [State]            VARCHAR (22)  NULL,
    [Zip]              VARCHAR (5)   NULL,
    [Country]          VARCHAR (100) NULL,
    [TempAddress]      BIT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientAddress]
    ON [PRF_HRS].[PatientAddress];

