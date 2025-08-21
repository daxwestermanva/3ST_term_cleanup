CREATE TABLE [BHIP].[Templates] (
    [MVIPersonSID]          INT           NULL,
    [Sta3n]                 INT           NOT NULL,
    [ChecklistID]           NVARCHAR (10) NULL,
    [VisitSID]              BIGINT        NULL,
    [VisitDateTime]         DATETIME2 (0) NULL,
    [TIUDocumentDefinition] VARCHAR (500) NULL,
    [EntryDateTime]         DATETIME2 (0) NULL,
    [HealthFactorDTAType]   VARCHAR (703) NULL,
    [HealthFactorSID]       BIGINT        NULL,
    [DocFormActivitySID]    BIGINT        NULL,
    [HealthFactorDateTime]  DATETIME2 (0) NULL,
    [Comments]              VARCHAR (601) NULL,
    [StaffName]             VARCHAR (100) NULL,
    [Category]              VARCHAR (100) NULL,
    [List]                  VARCHAR (50)  NOT NULL,
    [PrintName]             VARCHAR (100) NULL
);

