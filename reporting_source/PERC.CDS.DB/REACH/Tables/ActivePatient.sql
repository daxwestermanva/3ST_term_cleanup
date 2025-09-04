CREATE TABLE [REACH].[ActivePatient] (
    [MVIPersonSID]     INT          NOT NULL,
    [ChecklistID]      VARCHAR (5)  NULL,
    [AssignmentSource] VARCHAR (50) NULL,
    [PatientPersonSID] INT          NULL,
    [Sta3n_EHR]        SMALLINT     NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ActivePatient]
    ON [REACH].[ActivePatient];

