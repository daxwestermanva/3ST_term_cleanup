CREATE TABLE [REACH].[RiskScoreHistoric] (
    [PatientPersonSID]        INT             NULL,
    [Sta3n_EHR]               SMALLINT        NULL,
    [ChecklistID]             VARCHAR (5)     NULL,
    [RunDatePatientICN]       VARCHAR (50)    NULL,
    [RiskScoreSuicide]        DECIMAL (38, 9) NULL,
    [RiskRanking]             BIGINT          NULL,
    [DashboardPatient]        INT             NULL,
    [ADRPriorityGroup]        SMALLINT        NULL,
    [RunDate]                 DATE            NULL,
    [ReleaseDate]             DATE            NULL,
    [EditError]               INT             NULL,
    [ImpactedByRandomization] INT             NULL,
    [Randomized]              INT             NULL,
    [ModelName]               VARCHAR (13)    NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_REACH_RiskScoreHistoric]
    ON [REACH].[RiskScoreHistoric];

