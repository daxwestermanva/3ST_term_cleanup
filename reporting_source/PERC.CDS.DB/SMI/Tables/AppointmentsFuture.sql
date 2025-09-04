CREATE TABLE [SMI].[AppointmentsFuture] (
    [MVIPersonSID]          INT            NULL,
    [AppointmentDateTime]   DATETIME2 (0)  NULL,
    [PrimaryStopCode]       VARCHAR (5)    NULL,
    [PrimaryStopCodeName]   VARCHAR (100)  NULL,
    [SecondaryStopCode]     VARCHAR (5)    NULL,
    [SecondaryStopCodeName] VARCHAR (50)   NULL,
    [ChecklistID]           NVARCHAR (100) NULL,
    [Facility]              NVARCHAR (100) NULL,
    [ClinicName]            VARCHAR (100)  NULL,
    [ApptCategory]          VARCHAR (20)   NULL,
    [MH_under10min]         INT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AppointmentsFuture]
    ON [SMI].[AppointmentsFuture];

