CREATE TABLE [Present].[AppointmentsFuture] (
    [MVIPersonSID]               INT            NULL,
    [PatientSID]                 INT            NULL,
    [Sta3n]                      SMALLINT       NULL,
    [VisitSID]                   BIGINT         NULL,
    [AppointmentDateTime]        DATETIME2 (0)  NULL,
    [PrimaryStopCode]            VARCHAR (5)    NULL,
    [PrimaryStopCodeName]        VARCHAR (100)  NULL,
    [SecondaryStopCode]          VARCHAR (5)    NULL,
    [SecondaryStopCodeName]      VARCHAR (100)  NULL,
    [MedicalService]             VARCHAR (50)   NULL,
    [AppointmentLength]          SMALLINT       NULL,
    [AppointmentDivisionName]    VARCHAR (100)  NULL,
    [AppointmentInstitutionName] VARCHAR (50)   NULL,
    [AppointmentLocationName]    VARCHAR (50)   NULL,
    [LocationSID]                INT            NULL,
    [Sta6a]                      VARCHAR (50)   NULL,
    [ApptCategory]               NVARCHAR (128) NULL,
    [NextAppt_SID]               BIGINT         NULL,
    [NextAppt_ICN]               BIGINT         NULL,
    [ChecklistID]                VARCHAR (5)    NULL,
    [AppointmentType]            VARCHAR (100)  NULL,
    [OrganizationNameSID]        INT            NULL
);
























GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AppointmentsFuture]
    ON [Present].[AppointmentsFuture];

