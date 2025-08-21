CREATE TABLE [REACH].[History] (
    [MVIPersonSID]                        INT         NULL,
    [MonthsIdentifiedAllTime]             INT         NULL,
    [MonthsIdentified12]                  INT         NULL,
    [MonthsIdentified24]                  INT         NULL,
    [FirstRVDate]                         DATE        NULL,
    [MostRecentRVDate]                    DATE        NULL,
    [LastIdentifiedExcludingCurrentMonth] DATE        NULL,
    [MostRecentRun]                       DATE        NULL,
    [Top01Percent]                        INT         NOT NULL,
    [RemovedByRandomization]              INT         NULL,
    [ChecklistID]                         VARCHAR (5) NULL,
    [Sta3n_EHR]                           INT         NULL,
    [PatientPersonSID]                    INT         NULL
);












GO
CREATE CLUSTERED INDEX [CIX_ReachHistory_MVISID]
    ON [REACH].[History]([MVIPersonSID] ASC) WITH (DATA_COMPRESSION = PAGE);

