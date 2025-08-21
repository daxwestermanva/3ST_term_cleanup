CREATE TABLE [ORM].[DoDOUDVAContact] (
    [MVIPersonSID]   INT           NULL,
    [VisitDateTime]  DATETIME2 (0) NULL,
    [Sta3n]          INT           NOT NULL,
    [MostRecent_ICN] BIGINT        NULL,
    [ChecklistID]    NVARCHAR (10) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DoDOUDVAContact]
    ON [ORM].[DoDOUDVAContact];

