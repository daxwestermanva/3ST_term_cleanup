CREATE TABLE [SUD].[IDUEvidence] (
    [ChecklistID]  NVARCHAR (100) NULL,
    [MVIPersonSID] INT            NULL,
    [EvidenceType] VARCHAR (30)   NOT NULL,
    [EvidenceDate] DATETIME2 (3)  NULL,
    [Details]      VARCHAR (8000) NULL,
    [Details2]     VARCHAR (MAX)  NULL,
    [Details3]     VARCHAR (1600) NULL,
    [Code]         NVARCHAR (255) NULL,
    [Facility]     NVARCHAR (255) NULL
);



