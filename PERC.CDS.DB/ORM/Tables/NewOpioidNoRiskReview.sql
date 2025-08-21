CREATE TABLE [ORM].[NewOpioidNoRiskReview] (
    [MVIPersonSID]                       INT            NOT NULL,
    [PatientICN]                         VARCHAR (50)   NULL,
    [PatientName]                        VARCHAR (200)  NULL,
    [LastFour]                           CHAR (4)       NULL,
    [VISN]                               INT            NULL,
    [ChecklistID]                        NVARCHAR (10)  NOT NULL,
    [Facility]                           NVARCHAR (100) NULL,
    [ProviderSID]                        INT            NULL,
    [MostRecentPrescriber]               VARCHAR (100)  NULL,
    [MostRecentPrescriber_PositionTitle] VARCHAR (100)  NULL,
    [MostRecentPrescriber_EmailAddress]  VARCHAR (100)  NULL,
    [MostRecentDrugNameWithoutDose]      VARCHAR (100)  NULL,
    [MostRecentDaysSupply]               INT            NULL,
    [MostRecentIssueDate]                DATE           NULL,
    [MostRecentReleaseDate]              DATE           NULL,
    [EarliestReleaseDate]                DATE           NULL,
    [DaysOld]                            INT            NULL,
    [MostRecentRxStatus]                 VARCHAR (100)  NULL,
    [PillsOnHand_Count]                  INT            NULL,
    [PillsOnHand_Date]                   DATE           NULL,
    [TotalDaysSupplyInPast200Days]       INT            NULL
);

