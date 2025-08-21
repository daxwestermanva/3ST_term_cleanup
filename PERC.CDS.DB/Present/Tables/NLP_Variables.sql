CREATE TABLE [Present].[NLP_Variables] (
    [MVIPersonSID]          INT           NOT NULL,
    [ChecklistID]           VARCHAR (5)   NULL,
    [Concept]               VARCHAR (25)  NULL,
    [SubclassLabel]         VARCHAR (100) NULL,
    [Term]                  VARCHAR (75)  NULL,
    [EntryDateTime]         DATETIME2 (0) NULL,
    [ReferenceDateTime]     DATETIME2 (0) NULL,
    [TIUDocumentDefinition] VARCHAR (100) NULL,
    [StaffName]             VARCHAR (100) NULL,
    [Snippet]               VARCHAR (600) NULL,
    [CountDesc]             INT           NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NLP_Variables]
    ON [Present].[NLP_Variables];

