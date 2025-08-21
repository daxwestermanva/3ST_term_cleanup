CREATE TABLE [PRF].[BehavioralMissingPatient] (
    [MVIPersonSID]              INT           NOT NULL,
    [OwnerChecklistID]          VARCHAR (5)   NULL,
    [OwnerFacility]             VARCHAR (50)  NULL,
    [NationalPatientRecordFlag] VARCHAR (15)  NULL,
    [ActiveFlag]                CHAR (1)      NULL,
    [InitialActivation]         DATETIME2 (2) NULL,
    [ActionDateTime]            DATETIME2 (0) NOT NULL,
    [ActionType]                TINYINT       NULL,
    [ActionTypeDescription]     VARCHAR (32)  NULL,
    [HistoricStatus]            CHAR (1)      NULL,
    [EntryCountDesc]            TINYINT       NULL,
    [EntryCountAsc]             TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_BehavioralMissingPatient]
    ON [PRF].[BehavioralMissingPatient];

