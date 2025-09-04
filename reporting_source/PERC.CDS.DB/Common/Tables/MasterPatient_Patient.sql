CREATE TABLE [Common].[MasterPatient_Patient] (
    [MVIPersonSID]          INT            NOT NULL,
    [PatientICN]            VARCHAR (50)   NULL,
    [PatientSSN]            VARCHAR (50)   NULL,
    [EDIPI]                 INT            NULL,
    [LastName]              VARCHAR (50)   NULL,
    [FirstName]             VARCHAR (50)   NULL,
    [MiddleName]            VARCHAR (50)   NULL,
    [NameSuffix]            VARCHAR (50)   NULL,
    [PreferredName]         VARCHAR (100)  NULL,
    [PatientName]           VARCHAR (200)  NULL,
    [LastFour]              CHAR (4)       NULL,
    [NameFour]              CHAR (5)       NULL,
    [PatientSSN_Hyphen]     VARCHAR (12)   NULL,
    [DateOfBirth]           DATE           NULL,
    [DateOfDeath]           DATE           NULL,
    [DateOfDeath_SVeteran]  DATE           NULL,
    [DateOfDeath_Combined]  DATE           NULL,
    [Age]                   INT            NULL,
    [Gender]                CHAR (1)       NULL,
    [SelfIdentifiedGender]  VARCHAR (50)   NULL,
    [DisplayGender]         VARCHAR (50)   NULL,
    [SexualOrientation]     VARCHAR (100)  NULL,
    [Pronouns]              VARCHAR (100)  NULL,
    [MaritalStatus]         VARCHAR (25)   NULL,
    [Veteran]               BIT            NULL,
    [VHAEligibilityFlag]    VARCHAR (25)   NULL,
    [SensitiveFlag]         BIT            NULL,
    [PossibleTestPatient]   BIT            NULL,
    [TestPatient]           BIT            NULL,
    [Race]                  VARCHAR (1000) NULL,
    [PatientHeight]         VARCHAR (65)   NULL,
    [HeightDate]            DATE           NULL,
    [PatientWeight]         VARCHAR (65)   NULL,
    [WeightDate]            DATE           NULL,
    [PercentServiceConnect] VARCHAR (10)   NULL,
    [PeriodOfService]       VARCHAR (50)   NULL,
    [BranchOfService]       VARCHAR (25)   NULL,
    [OEFOIFStatus]          VARCHAR (25)   NULL,
    [ServiceSeparationDate] DATE           NULL,
    [PriorityGroup]         INT            NULL,
    [PrioritySubGroup]      VARCHAR (50)   NULL,
    [COMPACTEligible]       BIT            NULL,
    [Homeless]              BIT            NULL,
    [Hospice]               BIT            NULL,
    [SourceEHR]             VARCHAR (2)    NULL
);






GO
CREATE NONCLUSTERED INDEX [IX_MasterPatient_ICN_Patient]
    ON [Common].[MasterPatient_Patient]([PatientICN] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MasterPatient_SSN_Patient]
    ON [Common].[MasterPatient_Patient]([PatientSSN] ASC);


GO
CREATE UNIQUE CLUSTERED INDEX [CIX_MasterPatient_MVISID_Patient]
    ON [Common].[MasterPatient_Patient]([MVIPersonSID] ASC) WITH (DATA_COMPRESSION = PAGE);

