CREATE TABLE [PRF].[Discrepancies] (
    [MVIPersonSID]                     INT           NOT NULL,
    [NationalPatientRecordFlag]        VARCHAR (25)  NULL,
    [Sta3n]                            INT           NULL,
    [Active_Sta3n]                     VARCHAR (1)   NULL,
    [OwnerFacility]                    VARCHAR (5)   NULL,
    [LastActionDateTime]               DATETIME2 (7) NULL,
    [LastActionType]                   VARCHAR (15)  NULL,
    [PatientRecordFlagHistoryComments] VARCHAR (100) NULL,
    [SourceEHR]                        VARCHAR (2)   NULL,
    [ActiveAnywhere]                   TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Discrepancies]
    ON [PRF].[Discrepancies];

