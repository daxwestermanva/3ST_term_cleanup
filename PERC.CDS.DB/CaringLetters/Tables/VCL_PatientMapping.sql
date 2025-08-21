CREATE TABLE [CaringLetters].[VCL_PatientMapping] (
    [VCL_ID]                      INT           NOT NULL,
    [Name]                        VARCHAR (20)  NULL,
    [MVIPersonSID]                INT           NULL,
    [PatientICN]                  VARCHAR (20)  NULL,
    [ICNSource]                   VARCHAR (35)  NULL,
    [VeteranName]                 VARCHAR (255) NULL,
    [CallerName]                  VARCHAR (255) NULL,
    [VCL_NearestFacilitySiteCode] VARCHAR (7)   NULL,
    [VCL_IsVet]                   VARCHAR (5)   NULL,
    [VCL_IsActiveDuty]            VARCHAR (10)  NULL,
    [VCL_VeteranStatus]           SMALLINT      NULL,
    [VCL_MilitaryBranch]          SMALLINT      NULL,
    [VCL_Call_Date]               DATE          NULL,
    [CaringLetterEligible]        TINYINT       NULL
);






GO
