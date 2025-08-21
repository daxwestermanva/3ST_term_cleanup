CREATE TABLE [Common].[MVIPerson_NoEHR] (
    [MVIPersonSID]      INT           NOT NULL,
    [PatientICN]        VARCHAR (50)  NULL,
    [PatientSSN]        VARCHAR (50)  NULL,
    [EDIPI]             INT           NULL,
    [PatientName]       VARCHAR (200) NULL,
    [NameFour]          VARCHAR (5)   NULL,
    [PatientSSN_Hyphen] VARCHAR (12)  NULL,
    [DateOfBirth]       DATE          NULL,
    [PhoneNumber]       VARCHAR (50)  NULL,
    [CellPhoneNumber]   VARCHAR (50)  NULL,
    [StreetAddress]     VARCHAR (250) NULL,
    [City]              VARCHAR (100) NULL,
    [State]             VARCHAR (5)   NULL,
    [Zip]               VARCHAR (5)   NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_SSN_Patient]
    ON [Common].[MVIPerson_NoEHR]([PatientSSN] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ICN_Patient]
    ON [Common].[MVIPerson_NoEHR]([PatientICN] ASC);


GO
CREATE UNIQUE CLUSTERED INDEX [CIX_MVISID_Patient]
    ON [Common].[MVIPerson_NoEHR]([MVIPersonSID] ASC);

