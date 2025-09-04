CREATE TABLE [PRF].[ActiveCatII_Patients] (
    [MVIPersonSID]              INT           NOT NULL,
    [PatientSID]                INT           NULL,
    [LocalPatientRecordFlag]    VARCHAR (50)  NOT NULL,
    [LocalPatientRecordFlagSID] INT           NULL,
    [OwnerChecklistID]          VARCHAR (5)   NULL,
    [LastActionDateTime]        DATETIME2 (7) NULL,
    [LastAction]                VARCHAR (20)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ActiveCatII_Patients]
    ON [PRF].[ActiveCatII_Patients];

