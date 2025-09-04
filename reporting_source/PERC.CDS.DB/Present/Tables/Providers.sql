CREATE TABLE [Present].[Providers] (
    [MVIPersonSID]          INT           NOT NULL,
    [PatientICN]            VARCHAR (50)  NULL,
    [PatientSID]            INT           NULL,
    [Sta3n]                 SMALLINT      NULL,
    [ChecklistID]           NVARCHAR (30) NOT NULL,
    [Sta6a]                 VARCHAR (50)  NOT NULL,
    [DivisionName]          VARCHAR (100) NULL,
    [ProviderSID]           INT           NULL,
    [ProviderEDIPI]         VARCHAR (30)  NULL,
    [RelationshipStartDate] DATETIME2 (0) NULL,
    [RelationshipEndDate]   DATETIME2 (0) NULL,
    [TeamSID]               INT           NULL,
    [Team]                  VARCHAR (50)  NULL,
    [TeamRole]              VARCHAR (100) NULL,
    [PCP]                   INT           NOT NULL,
    [MHTC]                  INT           NOT NULL,
    [PrimaryProviderSID]    INT           NULL,
    [PrimaryProviderEDIPI]  VARCHAR (30)  NULL,
    [StaffName]             VARCHAR (100) NULL,
    [TerminationDate]       DATE          NULL,
    [ActiveStaff]           BIT           NULL,
    [AssociateProviderSID]  INT           NULL,
    [StaffNameA]            VARCHAR (100) NULL,
    [TerminationDateA]      DATE          NULL,
    [ActiveStaffA]          BIT           NULL,
    [AssociateProviderFlag] VARCHAR (1)   NULL,
    [ActiveAny]             INT           NULL,
    [ProvType]              VARCHAR (4)   NULL,
    [TeamType]              VARCHAR (4)   NULL,
    [CernerSiteFlag]        INT           NULL,
    [ProvRank_ICN]          SMALLINT      NULL,
    [TeamRank_ICN]          SMALLINT      NULL,
    [ProvRank_SID]          SMALLINT      NULL,
    [TeamRank_SID]          SMALLINT      NULL
);
























GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Present_Providers]
    ON [Present].[Providers];







