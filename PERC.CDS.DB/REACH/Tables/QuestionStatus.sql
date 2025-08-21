CREATE TABLE [REACH].[QuestionStatus] (
    [MVIPersonSID]            INT           NULL,
    [CareEvaluationChecklist] INT           NOT NULL,
    [FollowUpWiththeVeteran]  INT           NOT NULL,
    [NoCareChanges]           INT           NOT NULL,
    [InitiationChecklist]     INT           NOT NULL,
    [ProviderAcknowledgement] INT           NOT NULL,
    [PatientStatus]           INT           NULL,
    [PatientDeceased]         INT           NULL,
    [LastCoordinatorActivity] DATETIME2 (0) NULL,
    [LastProviderActivity]    DATETIME2 (0) NULL,
    [CoordinatorName]         VARCHAR (50)  NULL,
    [ProviderName]            VARCHAR (50)  NULL,
    [UpdateDate]              DATETIME2 (0) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_QuestionStatus]
    ON [REACH].[QuestionStatus];

