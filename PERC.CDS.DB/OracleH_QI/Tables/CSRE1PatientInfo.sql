CREATE TABLE [OracleH_QI].[CSRE1PatientInfo] (
    [Encountersid]       BIGINT         NULL,
    [EncounterTypeClass] VARCHAR (100)  NULL,
    [mvipersonsid]       INT            NOT NULL,
    [patienticn]         VARCHAR (50)   NULL,
    [EDIPI]              INT            NULL,
    [patientname]        VARCHAR (200)  NULL,
    [DateOfBirth]        DATE           NULL,
    [lastfour]           CHAR (4)       NULL,
    [VISN]               INT            NULL,
    [checklistid]        NVARCHAR (5)   NULL,
    [ADMPARENT_FCDM]     NVARCHAR (100) NULL,
    [surveyname]         VARCHAR (75)   NULL,
    [CSSRS_Date]         SMALLDATETIME  NULL,
    [CSSRS_location]     VARCHAR (100)  NULL,
    [CSRE_Date]          SMALLDATETIME  NULL,
    [CSRETimeframe]      VARCHAR (24)   NOT NULL,
    [Veteran_Status]     VARCHAR (11)   NOT NULL
);






GO
