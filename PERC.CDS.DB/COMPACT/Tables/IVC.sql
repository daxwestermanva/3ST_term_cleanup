CREATE TABLE [COMPACT].[IVC] (
    [MVIPersonSID]       INT           NOT NULL,
    [ReferralID]         VARCHAR (15)  NULL,
    [ConsultID]          VARCHAR (25)  NULL,
    [NotificationID]     VARCHAR (25)  NULL,
    [ClaimID]            VARCHAR (25)  NULL,
    [VisitSID]           BIGINT        NULL,
    [StaPa]              VARCHAR (5)   NULL,
    [BeginDate]          DATE          NULL,
    [TxDate]             DATE          NULL,
    [DischargeDate]      DATE          NULL,
    [TxSetting]          VARCHAR (25)  NULL,
    [Hospital]           VARCHAR (500) NULL,
    [Claim_Total_Amount] MONEY         NULL,
    [Paid]               TINYINT       NULL,
    [HealthFactorType]   VARCHAR (100) NULL,
    [ReferenceDateTime]  DATETIME2 (7) NULL,
    [ClaimCount]         SMALLINT      NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_IVC]
    ON [COMPACT].[IVC];

