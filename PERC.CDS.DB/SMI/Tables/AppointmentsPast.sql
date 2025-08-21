CREATE TABLE [SMI].[AppointmentsPast] (
    [MVIPersonSID]          BIGINT         NULL,
    [VisitSID]              BIGINT         NULL,
    [VisitDateTime]         DATETIME2 (3)  NULL,
    [PrimaryStopCode]       VARCHAR (5)    NULL,
    [PrimaryStopCodeName]   VARCHAR (100)  NULL,
    [SecondaryStopCode]     VARCHAR (5)    NULL,
    [SecondaryStopCodeName] VARCHAR (100)  NULL,
    [ChecklistID]           NVARCHAR (10)  NULL,
    [Facility]              NVARCHAR (100) NULL,
    [ClinicName]            VARCHAR (100)  NULL,
    [Provider]              VARCHAR (200)  NULL,
    [ApptCategory]          VARCHAR (100)  NULL,
    [MH_under10min]         INT            NULL,
    [ED_counts_pastyear]    INT            NULL,
    [MH_counts_pastyear]    INT            NULL,
    [ICMHR_counts_90day]    INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AppointmentsPast]
    ON [SMI].[AppointmentsPast];

