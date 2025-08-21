CREATE TABLE [Present].[HomestationMonthly] (
    [MVIPersonSID]     INT           NULL,
    [ChecklistID]      NVARCHAR (30) NULL,
    [FYM]              VARCHAR (7)   NULL,
    [MonthBeginDate]   DATE          NULL,
    [Sta3n_EHR]        INT           NULL,
    [PatientPersonSID] INT           NULL
);


GO
CREATE CLUSTERED INDEX [CIX_HomestationMonthly_MVI]
    ON [Present].[HomestationMonthly]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100);

