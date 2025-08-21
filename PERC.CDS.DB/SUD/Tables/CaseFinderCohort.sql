CREATE TABLE [SUD].[CaseFinderCohort] (
    [MVIPersonSID]      INT           NOT NULL,
    [PatientICN]        VARCHAR (65)  NULL,
    [PatientName]       VARCHAR (200) NULL,
    [LastFour]          CHAR (5)      NULL,
    [ChecklistID]       NVARCHAR (10) NOT NULL,
    [DetoxHF]           INT           NULL,
    [Withdrawal]        INT           NULL,
    [CSRE]              INT           NULL,
    [NLPDetox]          INT           NULL,
    [NLPIVDU]           INT           NULL,
    [AuditC]            INT           NULL,
    [CIWA]              INT           NULL,
    [COWS]              INT           NULL,
    [PositiveDS]        INT           NULL,
    [OD]                INT           NULL,
    [OD_OMHSP_Standard] INT           NULL,
    [OD_ICD10]          INT           NULL,
    [OD_DoD]            INT           NULL,
    [SUDDxNoTx]         INT           NULL,
    [VJO]               INT           NULL,
    [IVDU]              INT           NULL,
    [Homeless]          INT           NULL,
    [IPV]               INT           NULL,
    [FoodInsecure]      INT           NULL,
    [SUDDxPastYear]     INT           NULL,
    [SUDDx]             INT           NULL,
    [SDV]               INT           NULL,
    [HRFActive]         INT           NULL,
    [AdverseEvnts]      INT           NULL,
    [HepC]              INT           NULL,
    [HIV]               INT           NULL
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaseFinderCohort]
    ON [SUD].[CaseFinderCohort];
GO
