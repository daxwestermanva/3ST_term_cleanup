CREATE TABLE [PBIReports].[ReportType] (
    [MVIPersonSID]      INT            NULL,
    [Report]            VARCHAR (100)  NULL,
    [ProviderName]      VARCHAR (100)  NULL,
    [Team]              VARCHAR (100)  NULL,
    [TeamRole]          VARCHAR (100)  NULL,
    [ChecklistID]       NVARCHAR (30)  NULL,
    [VISN]              INT            NULL,
    [Facility]          NVARCHAR (100) NULL,
    [AppointmentInfo]   NVARCHAR (255) NULL,
    [AppointmentSlicer] VARCHAR (50)   NULL,
    [AppointmentSort]   INT            NULL
);

