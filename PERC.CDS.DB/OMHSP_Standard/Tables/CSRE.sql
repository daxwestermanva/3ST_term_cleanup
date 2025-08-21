CREATE TABLE [OMHSP_Standard].[CSRE] (
    [MVIPersonSID]          INT           NOT NULL,
    [PatientICN]            VARCHAR (50)  NULL,
    [Sta3n]                 SMALLINT      NULL,
    [ChecklistID]           NVARCHAR (30) NULL,
    [VisitSID]              BIGINT        NULL,
    [DocFormActivitySID]    BIGINT        NULL,
    [VisitDateTime]         SMALLDATETIME NULL,
    [EntryDateTime]         SMALLDATETIME NULL,
    [TIUDocumentDefinition] VARCHAR (100) NULL,
    [EvaluationType]        VARCHAR (50)  NULL,
    [Ideation]              VARCHAR (30)  NULL,
    [IdeationComments]      VARCHAR (MAX) NULL,
    [Intent]                VARCHAR (10)  NULL,
    [IntentComments]        VARCHAR (MAX) NULL,
    [SuicidePlan]           VARCHAR (10)  NULL,
    [PlanComments]          VARCHAR (MAX) NULL,
    [LethalMeans]           VARCHAR (50)  NULL,
    [LethalMeansComments]   VARCHAR (MAX) NULL,
    [PriorAttempts]         VARCHAR (10)  NULL,
    [PriorAttemptComments]  VARCHAR (MAX) NULL,
    [AcuteRisk]             VARCHAR (15)  NULL,
    [AcuteRiskComments]     VARCHAR (MAX) NULL,
    [ChronicRisk]           VARCHAR (15)  NULL,
    [ChronicRiskComments]   VARCHAR (MAX) NULL,
    [Setting]               VARCHAR (15)  NULL,
    [OrderDesc]             SMALLINT      NULL
);









