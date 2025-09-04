CREATE TABLE [ORM].[OpioidHistory] (
    [PatientPersonSID]      INT           NULL,
    [MVIPersonSID]          INT           NULL,
    [ChecklistID]           NVARCHAR (30) NULL,
    [IssueDate]             DATE          NULL,
    [ProviderSID]           INT           NULL,
    [StaffName]             VARCHAR (100) NULL,
    [ReleaseDateTime]       DATETIME2 (0) NULL,
    [DaysSupply]            INT           NULL,
    [Qty]                   VARCHAR (50)  NULL,
    [RxOutpatSID]           BIGINT        NULL,
    [RxStatus]              VARCHAR (50)  NULL,
    [ActiveRxStatusVM]      INT           NULL,
    [NationalDrugSID]       BIGINT        NULL,
    [Sta3n]                 SMALLINT      NULL,
    [VUID]                  VARCHAR (50)  NULL,
    [DrugNameWithDose]      VARCHAR (100) NULL,
    [DrugNameWithoutDose]   VARCHAR (100) NULL,
    [MostRecentFill]        INT           NOT NULL,
    [NonTramadol]           INT           NOT NULL,
    [LongActing]            INT           NOT NULL,
    [ChronicOpioid]         INT           NOT NULL,
    [NonChronicShortActing] INT           NOT NULL,
    [ChronicShortActing]    INT           NOT NULL,
    [Active]                INT           NOT NULL,
    [OpioidOnHand]          INT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_OpioidHistory]
    ON [ORM].[OpioidHistory];

