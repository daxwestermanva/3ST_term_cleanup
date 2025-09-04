CREATE TABLE [SUD].[IDUCohort] (
    [CheckListID]           NVARCHAR (10) NULL,
    [MVIPersonSID]          INT           NULL,
    [Confirmed]             INT           NOT NULL,
    [InSSP]                 VARCHAR (13)  NOT NULL,
    [LastInclusionDate]     DATETIME2 (0) NULL,
    [PatientName]           VARCHAR (200) NULL,
    [LastFour]              CHAR (4)      NULL,
    [DateOfBirth]           DATE          NULL,
    [SUDDx]                 VARCHAR (9)   NOT NULL,
    [Prep]                  VARCHAR (3)   NOT NULL,
    [Naloxone]              VARCHAR (3)   NOT NULL,
    [Condom]                VARCHAR (3)   NOT NULL,
    [FentanylTS]            VARCHAR (3)   NOT NULL,
    [Homeless]              BIT           NULL,
    [MostRecentAppointment] INT           NOT NULL,
    [WorkPhoneNumber]       VARCHAR (50)  NULL,
    [PhoneNumber]           VARCHAR (50)  NULL,
    [CellPhoneNumber]       VARCHAR (50)  NULL,
    [ActiveHepVL]           VARCHAR (3)   NULL
);




GO
