CREATE TABLE [ORM].[MeasureDetails] (
    [MeasureID]                 FLOAT (53)     NULL,
    [PrintName]                 VARCHAR (500)  NULL,
    [OpioidForPain_Rx]          SMALLINT       NULL,
    [OUD]                       SMALLINT       NULL,
    [RecentlyDiscontinued]      SMALLINT       NULL,
    [ODPastYear]                SMALLINT       NULL,
    [DisplayRules]              VARCHAR (MAX)  NULL,
    [CheckBoxRules]             VARCHAR (MAX)  NULL,
    [DetailsRedRules]           VARCHAR (2000) NULL,
    [ColumnName]                NVARCHAR (255) NULL,
    [RiskMitigationStrategy]    NVARCHAR (255) NULL,
    [MeasureNameClean]          NVARCHAR (255) NULL,
    [MeasureName]               NVARCHAR (255) NULL,
    [Description]               NVARCHAR (255) NULL,
    [Rationale]                 NVARCHAR (MAX) NULL,
    [DataSource]                NVARCHAR (255) NULL,
    [Codes]                     NVARCHAR (255) NULL,
    [ActionableCohort]          NVARCHAR (MAX) NULL,
    [NumeratorCohort]           NVARCHAR (300) NULL,
    [DenominatorCohort]         NVARCHAR (MAX) NULL,
    [Exclusion]                 NVARCHAR (255) NULL,
    [DiagnosisCohort]           NVARCHAR (255) NULL,
    [MedicationCohort]          NVARCHAR (255) NULL,
    [CPTCohort]                 NVARCHAR (255) NULL,
    [LabCohort]                 NVARCHAR (255) NULL,
    [StopCodeCohort]            NVARCHAR (255) NULL,
    [ICD10ProcedureCohort]      NVARCHAR (255) NULL,
    [ExclusionDiagnosisCohort]  NVARCHAR (255) NULL,
    [ExclusionMedicationCohort] NVARCHAR (255) NULL,
    [ExclusionCPTCohort]        NVARCHAR (255) NULL,
    [ExclusionStopcodeCohort]   NVARCHAR (255) NULL,
    [UpdateFrequency]           NVARCHAR (255) NULL,
    [TimePeriod]                NVARCHAR (255) NULL,
    [ScoreDirection]            NVARCHAR (255) NULL,
    [Notes]                     NVARCHAR (255) NULL,
    [Category]                  NVARCHAR (255) NULL
);




















GO


