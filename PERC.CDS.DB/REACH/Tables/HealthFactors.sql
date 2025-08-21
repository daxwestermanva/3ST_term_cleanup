CREATE TABLE [REACH].[HealthFactors] (
    [MVIPersonSID]         INT           NULL,
    [Sta3n]                INT           NULL,
    [ChecklistID]          NVARCHAR (30) NULL,
    [QuestionNumber]       INT           NULL,
    [Question]             VARCHAR (MAX) NULL,
    [HealthFactorDateTime] DATETIME2 (3) NULL,
    [Comments]             VARCHAR (255) NULL,
    [Coordinator]          TINYINT       NULL,
    [Provider]             TINYINT       NULL,
    [CareEval]             TINYINT       NULL,
    [OutreachAttempted]    TINYINT       NULL,
    [OutreachUnsuccess]    TINYINT       NULL,
    [OutreachSuccess]      TINYINT       NULL,
    [PatientStatus]        TINYINT       NULL,
    [Source]               INT           NOT NULL,
    [LastActivity]         DATETIME2 (3) NULL,
    [StaffName]            VARCHAR (100) NULL,
    [QuestionStatus]       INT           NOT NULL,
    [MostRecent]           BIGINT        NULL,
    [MostRecentFlag]       INT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HealthFactors]
    ON [REACH].[HealthFactors];

