CREATE TABLE [PDE_Daily].[PDE_FollowUpMHVisits] (
    [MVIPersonSID]               INT           NOT NULL,
    [DisDay]                     DATE          NULL,
    [Exclusion30]                INT           NULL,
    [Group3_HRF]                 INT           NULL,
    [Group2_High_Den]            INT           NULL,
    [Group1_Low_Den]             INT           NULL,
    [FollowUp]                   INT           NULL,
    [FollowUpDays]               INT           NULL,
    [VisitSID]                   BIGINT        NULL,
    [Cl]                         VARCHAR (100) NULL,
    [Clc]                        VARCHAR (100) NULL,
    [ClName]                     VARCHAR (100) NULL,
    [ClcName]                    VARCHAR (100) NULL,
    [WorkloadLogicFlag]          CHAR (1)      NULL,
    [VisitDateTime]              DATETIME2 (0) NULL,
    [ProviderType]               VARCHAR (100) NULL,
    [ProviderName]               VARCHAR (100) NULL,
    [ExcludeRuleVSSC]            INT           NULL,
    [NumberOfMentalHealthVisits] INT           NULL,
    [NonCountVisits]             INT           NULL,
    [PDE1]                       INT           NOT NULL,
    [ProviderSID]                BIGINT        NULL
);








GO
CREATE CLUSTERED INDEX [CIX_PDEVisits_MVIPersonSID]
    ON [PDE_Daily].[PDE_FollowUpMHVisits]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

