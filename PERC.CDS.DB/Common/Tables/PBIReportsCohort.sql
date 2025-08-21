CREATE TABLE [Common].[PBIReportsCohort] (
    [MVIPersonSID]          INT            NOT NULL,
    [PatientICN]            VARCHAR (50)   NULL,
    [ChecklistID]           NVARCHAR (10)  NULL,
    [FlowEligible]          VARCHAR (5)    NULL,
    [Report]                VARCHAR (50)   NULL,
    [HomelessSlicer]        VARCHAR (5)    NULL,
    [FullPatientName]       VARCHAR (150)  NULL,
    [MailAddress]           VARCHAR (255)  NULL,
    [StreetAddress]         VARCHAR (255)  NULL,
    [MailCityState]         VARCHAR (255)  NULL,
    [PhoneNumber]           VARCHAR (50)   NULL,
    [Zip]                   VARCHAR (5)    NULL,
    [AgeSort]               INT            NULL,
    [AgeCategory]           VARCHAR (10)   NULL,
    [BranchOfService]       VARCHAR (25)   NULL,
    [DateOfBirth]           DATE           NULL,
    [DisplayGender]         VARCHAR (50)   NULL,
    [Race]                  VARCHAR (1000) NULL,
    [ServiceSeparationDate] DATE           NULL,
    [DoDSeprationType]      VARCHAR (50)   NULL,
    [PeriodOfService]       VARCHAR (50)   NULL,
    [COMPACTEligible]       VARCHAR (50)   NULL,
    [BHIPAssessment]        VARCHAR (50)   NULL
);






GO
