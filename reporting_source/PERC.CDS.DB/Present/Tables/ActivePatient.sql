CREATE TABLE [Present].[ActivePatient] (
    [MVIPersonSID]     INT         NOT NULL,
    [ChecklistID]      VARCHAR (5) NULL,
    [RequirementID]    SMALLINT    NOT NULL,
    [SourceEHR]        VARCHAR (2) NULL,
    [Sta3n_Loc]        SMALLINT    NULL,
    [PatientPersonSID] INT         NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_ActivePatient_MVISta3n]
    ON [Present].[ActivePatient]([MVIPersonSID] ASC, [Sta3n_Loc] ASC);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ActivePatient]
    ON [Present].[ActivePatient];

