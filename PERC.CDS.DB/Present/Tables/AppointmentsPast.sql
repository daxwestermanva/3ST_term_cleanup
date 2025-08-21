CREATE TABLE [Present].[AppointmentsPast] (
    [MVIPersonSID]             INT            NULL,
    [PatientSID]               INT            NULL,
    [VisitSID]                 BIGINT         NULL,
    [VisitDateTime]            DATETIME2 (0)  NULL,
    [PrimaryStopCode]          VARCHAR (5)    NULL,
    [PrimaryStopCodeName]      VARCHAR (100)  NULL,
    [SecondaryStopCode]        VARCHAR (5)    NULL,
    [SecondaryStopCodeName]    VARCHAR (100)  NULL,
    [Sta3n]                    SMALLINT       NULL,
    [ApptCategory]             NVARCHAR (128) NULL,
    [MostRecent_SID]           BIGINT         NULL,
    [MostRecent_ICN]           BIGINT         NULL,
    [ChecklistID]              VARCHAR (5)    NULL,
    [ActivityType]             VARCHAR (50)   NULL,
    [ActivityTypeCodeValueSID] INT            NULL
);




























GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AppointmentsPast]
    ON [Present].[AppointmentsPast];

