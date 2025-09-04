CREATE TABLE [App].[Log_MasterPatientAudit] (
    [PatientSID]  INT           NULL,
    [PatientICN]  VARCHAR (50)  NULL,
    [PreviousICN] VARCHAR (50)  NULL,
    [Status]      VARCHAR (255) NULL,
    [LogID]       INT           NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
