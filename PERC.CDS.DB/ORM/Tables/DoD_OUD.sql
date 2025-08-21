CREATE TABLE [ORM].[dod_oud] (
    [SOURCE]                        VARCHAR (34)  NOT NULL,
    [MVIPersonSID]                  INT           NULL,
    [EDIPI]                         VARCHAR (50)  NULL,
    [LastName]                      VARCHAR (50)  NULL,
    [FirstName]                     VARCHAR (50)  NULL,
    [MiddleName]                    VARCHAR (50)  NULL,
    [NameSuffix]                    VARCHAR (50)  NULL,
    [DateofBirth]                   DATE          NULL,
    [age]                           INT           NULL,
    [Gender]                        VARCHAR (50)  NULL,
    [instance_date]                 DATETIME2 (0) NULL,
    [InstanceDateType]              VARCHAR (15)  NOT NULL,
    [RecordID]                      INT           NOT NULL,
    [IDTYPE]                        VARCHAR (16)  NOT NULL,
    [ICD10]                         VARCHAR (50)  NULL,
    [ICD10_dot]                     VARCHAR (200) NOT NULL,
    [ben_cat]                       INT           NOT NULL,
    [ActiveDuty_PurchasedCare_Flag] INT           NOT NULL,
    [MaxDoDEncounter]               DATE          NULL,
    [CareType]                      VARCHAR (50)  NULL
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_dod_oud]
    ON [ORM].[dod_oud];
GO
