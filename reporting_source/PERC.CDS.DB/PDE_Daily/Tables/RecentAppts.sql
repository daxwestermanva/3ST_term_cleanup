CREATE TABLE [PDE_Daily].[RecentAppts] (
    [MVIPersonSID]        INT           NOT NULL,
    [DisDay]            DATE          NULL,
    [Cl]                VARCHAR (100) NULL,
    [Clc]               VARCHAR (100) NULL,
    [ClName]            VARCHAR (100) NULL,
    [ClcName]           VARCHAR (100) NULL,
    [VisitDateTime]     DATETIME2 (0) NULL,
    [FollowUpDays]      INT           NULL,
    [VisitDate]         DATE          NULL,
    [ProviderName]      VARCHAR (100) NULL,
    [ProviderType]      VARCHAR (100) NULL,
    [WorkloadLogicFlag] CHAR (1)      NULL,
    [RN]                BIGINT        NULL
);




GO
CREATE CLUSTERED INDEX [CIX_PDERecentAppts_MVIPersonSIDDisDay]
    ON [PDE_Daily].[RecentAppts]([MVIPersonSID] ASC, [DisDay] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

