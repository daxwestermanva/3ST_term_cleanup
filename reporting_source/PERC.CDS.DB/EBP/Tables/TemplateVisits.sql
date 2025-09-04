CREATE TABLE [EBP].[TemplateVisits] (
    [PatientICN]           VARCHAR (50)   NULL,
    [MVIPersonSID]         INT            NULL,
    [PatientSID]           INT            NULL,
    [VisitSID]             BIGINT         NULL,
    [LocationSID]          INT            NULL,
    [VISN]                 INT            NULL,
    [Sta3n]                SMALLINT       NOT NULL,
    [Sta6a]                NVARCHAR (50)  NULL,
    [StaPa]                NVARCHAR (50)  NULL,
    [AdmParent_FCDM]       NVARCHAR (100) NULL,
    [VisitDateTime]        DATETIME2 (0)  NULL,
    [HealthFactorDateTime] DATETIME2 (0)  NULL,
    [Month]                INT            NULL,
    [Year]                 INT            NULL,
    [EncounterStaffSID]    INT            NULL,
    [TemplateGroup]        NVARCHAR (128) NULL,
    [DiagnosticGroup]      VARCHAR (17)   NULL,
    [Cerner]               BIT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_TemplateVisits]
    ON [EBP].[TemplateVisits];

