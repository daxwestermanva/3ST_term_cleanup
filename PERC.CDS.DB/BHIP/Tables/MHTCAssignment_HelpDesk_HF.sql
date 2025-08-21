CREATE TABLE [BHIP].[MHTCAssignment_HelpDesk_HF] (
    [PatientICN]           VARCHAR (50)  NULL,
    [MVIPersonSID]         INT           NOT NULL,
    [Patientsid]           INT           NULL,
    [Sta3n]                SMALLINT      NOT NULL,
    [ChecklistID]          NVARCHAR (10) NULL,
    [VisitSID]             BIGINT        NULL,
    [HealthFactorSID]      BIGINT        NOT NULL,
    [Healthfactordatetime] DATETIME2 (0) NULL,
    [Comments]             VARCHAR (255) NULL,
    [Category]             VARCHAR (100) NULL,
    [List]                 VARCHAR (50)  NOT NULL,
    [PrintName]            VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHTCAssignment_HelpDesk_HF]
    ON [BHIP].[MHTCAssignment_HelpDesk_HF];

