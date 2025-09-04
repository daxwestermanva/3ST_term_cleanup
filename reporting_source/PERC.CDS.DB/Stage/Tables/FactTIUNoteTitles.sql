CREATE TABLE [Stage].[FactTIUNoteTitles] (
    [MVIPersonSID]             INT           NOT NULL,
    [TIUDocumentSID]           BIGINT        NULL,
    [TIUDocumentDefinitionSID] INT           NULL,
    [DocFormActivitySID]       BIGINT        NULL,
    [EntryDateTime]            DATETIME2 (7) NULL,
    [ReferenceDateTime]        DATETIME2 (7) NULL,
    [VisitSID]                 BIGINT        NULL,
    [SecondaryVisitSID]        BIGINT        NULL,
    [Sta3n]                    SMALLINT      NULL,
    [Sta6a]                    VARCHAR (15)  NULL,
    [StaPa]                    VARCHAR (10)  NULL,
    [TIUDocumentDefinition]    VARCHAR (100) NULL,
    [List]                     VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_FactTIUNoteTitles]
    ON [Stage].[FactTIUNoteTitles];

