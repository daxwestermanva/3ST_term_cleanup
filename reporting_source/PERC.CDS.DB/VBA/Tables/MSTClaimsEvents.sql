CREATE TABLE [VBA].[MSTClaimsEvents] (
    [MVIPersonSID] INT            NOT NULL,
    [EventNumber]  BIGINT         NULL,
    [EventType]    VARCHAR (100)  NULL,
    [EventDate]    DATETIME       NULL,
    [RecentEvent]  INT            NOT NULL,
    [NoteNeeded]   INT            NULL,
    [StaPa_Event]  NVARCHAR (30)  NULL,
    [StaPa_Note]   NVARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MSTClaimsEvents]
    ON [VBA].[MSTClaimsEvents];

