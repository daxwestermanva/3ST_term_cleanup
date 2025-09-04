CREATE TABLE [BHIP].[MissedAppointments_PBI] (
    [MVIPersonSID]           INT            NULL,
    [AppointmentSID]         BIGINT         NOT NULL,
    [AppointmentDate]        DATE           NULL,
    [CancellationReason]     VARCHAR (50)   NULL,
    [CancellationReasonType] NVARCHAR (MAX) NULL,
    [CancellationRemarks]    VARCHAR (255)  NULL,
    [LocationName]           VARCHAR (50)   NULL,
    [ChecklistID]            NVARCHAR (30)  NULL
);

