CREATE TABLE [Stage].[MasterPatientVistA_Patient] (
    [MVIPersonSID]          INT           NOT NULL,
    [MasterPatientFieldID]  TINYINT       NOT NULL,
    [FieldValue]            VARCHAR (100) NOT NULL,
    [FieldModifiedDateTime] DATETIME2 (0) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_StageMasterPatVPatient]
    ON [Stage].[MasterPatientVistA_Patient];

