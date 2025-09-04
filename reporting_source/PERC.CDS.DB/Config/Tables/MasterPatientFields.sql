CREATE TABLE [Config].[MasterPatientFields] (
    [MasterPatientFieldID]   TINYINT       IDENTITY (1, 1) NOT NULL,
    [MasterPatientFieldName] VARCHAR (25)  NOT NULL,
    [FieldSource]            VARCHAR (50)  NULL,
    [FieldSourceDetail]      VARCHAR (100) NULL,
    [FieldSourceID]          TINYINT       NULL,
    [VistAMillMethod]        VARCHAR (4)   NULL,
    [Category]               VARCHAR (10)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MasterPatientFields]
    ON [Config].[MasterPatientFields];

