CREATE TABLE [REACH].[RiskScore] (
    [MVIPersonSID]            INT              NOT NULL,
    [ChecklistID]             VARCHAR (5)      NULL,
    [Sta3n_EHR]               SMALLINT         NOT NULL,
    [PatientPersonSID]        INT              NULL,
    [RiskScoreSuicide]        NUMERIC (38, 9)  NULL,
    [RiskRanking]             BIGINT           NULL,
    [DashboardPatient]        INT              NOT NULL,
    [PercRanking]             DECIMAL (29, 21) NULL,
    [RunDate]                 DATETIME         NOT NULL,
    [RunDatePatientICN]       VARCHAR (50)     NULL,
    [PriorityGroup]           INT              NULL,
    [PrioritySubGroup]        VARCHAR (50)     NULL,
    [TopPercentAllGroups]     INT              NOT NULL,
    [ImpactedByRandomization] INT              NOT NULL,
    [Randomized]              INT              NOT NULL,
    [Engaged]                 INT              NOT NULL,
    [MHVisits]                INT              NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskScore]
    ON [REACH].[RiskScore];

