CREATE TABLE [BHIP].[Consults_PBI] (
    [MVIPersonSID]           INT            NULL,
    [ToRequestServiceName]   VARCHAR (100)  NOT NULL,
    [RequestDateTime]        DATE           NULL,
    [CPRSStatus]             VARCHAR (50)   NULL,
    [Facility]               NVARCHAR (255) NULL,
    [ProvisionalDiagnosis]   VARCHAR (255)  NULL,
    [ConsultActivityComment] VARCHAR (8000) NULL,
    [ActivityDateTime]       DATE           NULL,
    [ActionFollowUp]         VARCHAR (25)   NULL,
    [Team]                   VARCHAR (50)   NULL,
    [ChecklistID]            NVARCHAR (30)  NULL,
    [PatientName]            VARCHAR (200)  NULL,
    [DateofBirth]            DATE           NULL,
    [LastFour]               CHAR (4)       NULL
);

