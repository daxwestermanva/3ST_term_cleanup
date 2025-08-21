CREATE TABLE [Present].[RxTransitionsMH] (
    [MVIPersonSID]             INT            NULL,
    [PatientSID]               INT            NULL,
    [PrescriberName]           VARCHAR (100)  NULL,
    [PrescribingFacility]      NVARCHAR (510) NULL,
    [RxOutpatSID]              BIGINT         NULL,
    [RxCategory]               VARCHAR (21)   NULL,
    [ReleaseDate]              DATE           NULL,
    [DrugNameWithoutDose]      VARCHAR (100)  NULL,
    [DrugNameWithDose]         VARCHAR (100)  NULL,
    [DrugChange]               INT            NOT NULL,
    [PreviousDrugNameWithDose] VARCHAR (100)  NULL,
    [DaysSinceRelease]         INT            NULL,
    [NoPoH]                    INT            NOT NULL,
    [NoPoH_RxDisc]             INT            NOT NULL,
    [NoPoH_RxActive]           INT            NOT NULL,
    [DaysWithNoPoH]            INT            NULL,
    [TrialLength]              VARCHAR (17)   NULL,
    [TrialStart]               DATE           NULL
);
















GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RxTransitionsMH]
    ON [Present].[RxTransitionsMH];

