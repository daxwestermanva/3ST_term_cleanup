CREATE TABLE [PRF].[ActiveCatII_Counts] (
    [LocalPatientRecordFlag]            VARCHAR (50)   NOT NULL,
    [LocalPatientRecordFlagDescription] VARCHAR (8000) NULL,
    [LocalPatientRecordFlagSID]         INT            NULL,
    [TIUDocumentDefinition]             VARCHAR (100)  NULL,
    [Sta3n]                             INT            NULL,
    [OwnerChecklistID]                  VARCHAR (5)    NULL,
    [Count]                             INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ActiveCatII_Counts]
    ON [PRF].[ActiveCatII_Counts];

