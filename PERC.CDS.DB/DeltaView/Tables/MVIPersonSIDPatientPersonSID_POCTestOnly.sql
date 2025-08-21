CREATE TABLE [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly] (
    [PatientPersonSID] INT           NULL,
    [Sta3n]            SMALLINT      NULL,
    [PatientICN]       VARCHAR (50)  NULL,
    [MVIPersonSID]     INT           NULL,
    [UpdateDate]       DATETIME2 (0) NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_MVIPersonSIDPatientPersonSID_POCTestOnly_MVIPersonSID]
    ON [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly]([MVIPersonSID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MVIPersonSIDPatientPersonSID_POCTestOnly_PatientICN]
    ON [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly]([PatientICN] ASC);


GO
CREATE UNIQUE CLUSTERED INDEX [PK_MVIPersonSIDPatientPersonSID_POCTestOnly_PatientPersonSID]
    ON [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly]([PatientPersonSID] ASC);

