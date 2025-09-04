CREATE TABLE [Common].[MVIPersonSIDPatientPersonSID] (
    [PatientPersonSID] INT           NULL,
    [Sta3n]            SMALLINT      NULL,
    [PatientICN]       VARCHAR (50)  NULL,
    [MVIPersonSID]     INT           NULL,
    [UpdateDate]       DATETIME2 (0) NULL
);






GO
CREATE UNIQUE CLUSTERED INDEX [PK_MVIPersonSIDPatientPersonSID_PatientPersonSID]
    ON [Common].[MVIPersonSIDPatientPersonSID]([PatientPersonSID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MVIPersonSIDPatientPersonSID_PatientICN]
    ON [Common].[MVIPersonSIDPatientPersonSID]([PatientICN] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MVIPersonSIDPatientPersonSID_MVIPersonSID]
    ON [Common].[MVIPersonSIDPatientPersonSID]([MVIPersonSID] ASC);

