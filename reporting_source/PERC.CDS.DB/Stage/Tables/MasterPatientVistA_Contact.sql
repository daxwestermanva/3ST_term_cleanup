CREATE TABLE [Stage].[MasterPatientVistA_Contact] (
    [MVIPersonSID]          INT           NOT NULL,
    [MasterPatientFieldID]  TINYINT       NOT NULL,
    [FieldValue]            VARCHAR (100) NOT NULL,
    [FieldModifiedDateTime] DATETIME2 (0) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_StageMasterPatVContact]
    ON [Stage].[MasterPatientVistA_Contact];

