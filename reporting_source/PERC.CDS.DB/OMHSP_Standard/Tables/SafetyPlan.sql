CREATE TABLE [OMHSP_Standard].[SafetyPlan] (
    [MVIPersonSID]                INT           NOT NULL,
    [PatientICN]                  VARCHAR (50)  NULL,
    [Sta3n]                       SMALLINT      NULL,
    [ChecklistID]                 VARCHAR (5)   NULL,
    [VisitSID]                    BIGINT        NULL,
    [SafetyPlanDateTime]          DATETIME2 (0) NOT NULL,
    [TIUDocumentDefinition]       VARCHAR (MAX) NULL,
    [TIUDocumentSID]              BIGINT        NULL,
    [HealthFactorType]            VARCHAR (50)  NULL,
    [List]                        VARCHAR (50)  NULL,
    [SP_RefusedSafetyPlanning_HF] BIT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SafetyPlan]
    ON [OMHSP_Standard].[SafetyPlan];

