CREATE TABLE [OMHSP_Standard].[SuicideRiskManagement] (
    [MVIPersonSID]            INT           NOT NULL,
    [PatientICN]              VARCHAR (50)  NOT NULL,
    [Sta3n]                   SMALLINT      NULL,
    [ChecklistID]             VARCHAR (5)   NULL,
    [VisitSID]                BIGINT        NULL,
    [DocFormActivitySID]      BIGINT        NULL,
    [HealthFactorDateTime]    DATETIME      NULL,
    [EntryDateTime]           DATETIME      NULL,
    [TIUDocumentDefinition]   VARCHAR (100) NULL,
    [OutreachStatus]          VARCHAR (25)  NULL,
    [Comment_PtDecline]       VARCHAR (MAX) NULL,
    [EDVisit]                 BIT           NULL,
    [MHDischarge]             BIT           NULL,
    [HRF]                     BIT           NULL,
    [VCL]                     BIT           NULL,
    [COVID]                   BIT           NULL,
    [OFRCare]                 BIT           NULL,
    [OtherReason]             VARCHAR (MAX) NULL,
    [RiskAssessmentDiscussed] BIT           NULL,
    [SafetyPlanDiscussed]     BIT           NULL,
    [TxEngagementDiscussed]   BIT           NULL,
    [OutpatTx]                BIT           NULL,
    [InpatTx]                 BIT           NULL,
    [AcuteRisk]               VARCHAR (12)  NULL,
    [ChronicRisk]             VARCHAR (12)  NULL,
    [RiskMitigationPlan]      VARCHAR (3)   NULL,
    [FutureFollowUp]          VARCHAR (30)  NULL,
    [WellnessCheck]           VARCHAR (6)   NULL,
    [AttemptToContact]        TINYINT       NULL,
    [NoContact]               VARCHAR (25)  NULL,
    [VoiceMail]               BIT           NULL,
    [Letter]                  BIT           NULL
);























