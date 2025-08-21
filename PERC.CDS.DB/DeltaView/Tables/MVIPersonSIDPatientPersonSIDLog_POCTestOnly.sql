CREATE TABLE [DeltaView].[MVIPersonSIDPatientPersonSIDLog_POCTestOnly] (
    [PatientPersonSID] INT           NULL,
    [Sta3n]            SMALLINT      NULL,
    [PatientICN]       VARCHAR (50)  NULL,
    [MVIPersonSID]     INT           NULL,
    [UpdateDate]       DATETIME2 (0) NULL,
    [UpdateCode]       CHAR (1)      NULL
);


GO
CREATE CLUSTERED INDEX [CIX_MVIPersonSIDPatientPersonSIDLog_POCTestOnly_PatientPersonSID]
    ON [DeltaView].[MVIPersonSIDPatientPersonSIDLog_POCTestOnly]([PatientPersonSID] ASC);

