CREATE TABLE [Common].[MasterPatient_Contact] (
    [MVIPersonSID]                INT           NOT NULL,
    [PatientICN]                  VARCHAR (50)  NULL,
    [PhoneNumber]                 VARCHAR (50)  NULL,
    [WorkPhoneNumber]             VARCHAR (50)  NULL,
    [CellPhoneNumber]             VARCHAR (50)  NULL,
    [TempPhoneNumber]             VARCHAR (50)  NULL,
    [NextOfKinPhone]              VARCHAR (50)  NULL,
    [NextOfKinPhone_Name]         VARCHAR (100) NULL,
    [EmergencyPhone]              VARCHAR (50)  NULL,
    [EmergencyPhone_Name]         VARCHAR (100) NULL,
    [StreetAddress1]              VARCHAR (100) NULL,
    [StreetAddress2]              VARCHAR (100) NULL,
    [StreetAddress3]              VARCHAR (50)  NULL,
    [City]                        VARCHAR (100) NULL,
    [State]                       VARCHAR (22)  NULL,
    [Zip]                         VARCHAR (5)   NULL,
    [Country]                     VARCHAR (100) NULL,
    [GISURH]                      CHAR (1)      NULL,
    [County]                      VARCHAR (50)  NULL,
    [CountyFIPS]                  VARCHAR (50)  NULL,
    [AddressModifiedDateTime]     DATETIME2 (7) NULL,
    [TempStreetAddress1]          VARCHAR (100) NULL,
    [TempStreetAddress2]          VARCHAR (100) NULL,
    [TempStreetAddress3]          VARCHAR (50)  NULL,
    [TempCity]                    VARCHAR (100) NULL,
    [TempStateAbbrev]             VARCHAR (50)  NULL,
    [TempPostalCode]              VARCHAR (50)  NULL,
    [TempCountry]                 VARCHAR (100) NULL,
    [TempAddressModifiedDateTime] DATETIME2 (7) NULL,
    [MailStreetAddress1]          VARCHAR (100) NULL,
    [MailStreetAddress2]          VARCHAR (100) NULL,
    [MailStreetAddress3]          VARCHAR (50)  NULL,
    [MailCity]                    VARCHAR (100) NULL,
    [MailState]                   VARCHAR (50)  NULL,
    [MailZip]                     VARCHAR (50)  NULL,
    [MailCountry]                 VARCHAR (100) NULL,
    [MailAddressModifiedDateTime] DATETIME2 (7) NULL
);








GO
CREATE NONCLUSTERED INDEX [IX_MasterPatient_ICN_Contact]
    ON [Common].[MasterPatient_Contact]([PatientICN] ASC);


GO
CREATE UNIQUE CLUSTERED INDEX [CIX_MasterPatient_MVISID_Contact]
    ON [Common].[MasterPatient_Contact]([MVIPersonSID] ASC) WITH (DATA_COMPRESSION = PAGE);

