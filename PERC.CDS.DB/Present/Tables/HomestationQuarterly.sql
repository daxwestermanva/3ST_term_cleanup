CREATE TABLE [Present].[HomestationQuarterly] (
    [MVIPersonSID]     INT          NULL,
    [ChecklistID]      VARCHAR (15) NULL,
    [Sta3n_EHR]        INT          NULL,
    [PatientPersonSID] INT          NULL,
    [FYM]              VARCHAR (7)  NULL,
    [FYQ]              VARCHAR (9)  NULL,
    [UpdateDate]       DATE         NULL
);


GO
CREATE CLUSTERED INDEX [CIX_HomestationQuarterly_MVIPersonSID]
    ON [Present].[HomestationQuarterly]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100);

